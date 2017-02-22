#!/usr/bin/python

import threading, json, sys, os
from nxs_utils import ThreadPool, Timer
import urllib2, argparse, multiprocessing
import csv, operator

import datetime

# maximum number of thread
max_thread = multiprocessing.cpu_count()*2
# default number of thread
default_threads = multiprocessing.cpu_count()/2


def parse_arguments():
    """Parse arguments
    :return: a parsed arguments object
    """
    parser = argparse.ArgumentParser(description='Count number of annotations for all entries from neXtProt api server')
    parser.add_argument('api', help='nextprot api uri (ie: build-api.nextprot.org)')
    parser.add_argument('-o', '--output', metavar='csv', default="/tmp/count-annotation.csv", help='csv file')
    parser.add_argument('-t', '--thread', metavar='num', default=default_threads, type=int,
                        help='number of threads (default=' + str(default_threads) + ')')
    parser.add_argument('-n', metavar='entries', default=-1, type=int, help='export n first entries')

    arguments = parser.parse_args()

    # check number of thread
    if arguments.thread > max_thread:
        parser.error("cannot run "+str(arguments.thread)+" threads (max="+str(max_thread)+")")
    elif arguments.thread <= 0:
        parser.error(str(arguments.thread)+" should be a positive number of threads")

    if not arguments.api.startswith("http"):
        arguments.api = 'http://' + arguments.api

    arguments.entries = get_all_nextprot_entries(api_host=arguments.api)

    if arguments.n > 0:
        arguments.entries = arguments.entries[0:arguments.n]

    print "Parameters"
    print "  nextprot api host : " + arguments.api
    print "  thread number     : " + str(arguments.thread)
    print "  output file       : " + arguments.output
    print "  export n entries  : " + str(len(arguments.entries))
    print

    return arguments


def get_all_nextprot_entries(api_host):
    """Extract all entry names using the nexprot API service
    :param
        api_host: the host where nextprot API is located
    :return:
    """
    url_all_identifiers = api_host + "/entry-accessions.json"

    try:
        response = urllib2.urlopen(url_all_identifiers)
        return json.loads(response.read())
    except urllib2.URLError as e:
        print "error getting all entries from neXtProt API host "+api_host+": "+str(e)
        sys.exit(1)


def count_annotations_for_entry(api_host, np_entry, dico):
    """Get nextprot entry
    :param api_host: the API url
    :param np_entry: the nextprot entry id
    :param dico: dictionary to store annotations count by entry accession
    """
    url = api_host + "/entry/" + np_entry + "/annotation-count.json"
    dico[np_entry] = int(call_api_service(url=url, service_name="/entry/"+np_entry))
    if len(dico) % 100 == 0:
        sys.stdout.write("INFO: " + str(len(dico)) + " entries processed")


def call_api_service(url, service_name):
    """Make a get API request and time execution
    :param url: the API url
    :param service_name: the API service name
    """

    timer = Timer()
    with timer:
        try:
            count = urllib2.urlopen(url).read()
            return count
        except urllib2.URLError as e:
            sys.stdout.write("FAILURE: " + threading.current_thread().name+" failed with error '"+str(e)+"' for "
                             + service_name+"/n")

    print " [" + str(datetime.timedelta(seconds=timer.duration_in_seconds())) + " seconds]/n"


if __name__ == '__main__':
    args = parse_arguments()

    pool = ThreadPool(args.thread)

    # global variable to count errors
    error_counter = 0

    count_annotations = {}

    globalTimer = Timer()
    with globalTimer:

        # add a task by entry to get
        for nextprot_entry in args.entries:
            pool.add_task(func=count_annotations_for_entry,
                          api_host=args.api,
                          np_entry=nextprot_entry,
                          dico=count_annotations)
        pool.wait_completion()

    count_annotations_items = sorted(count_annotations.items(), key=operator.itemgetter(1), reverse=True)

    with open(args.output, 'wb') as csv_file:
        writer = csv.writer(csv_file)
        for key, value in count_annotations_items:
            writer.writerow([key, value])