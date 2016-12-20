#!/usr/bin/python

import threading, json, sys, os
from nxs_utils import ThreadPool, Timer
import urllib2, argparse, multiprocessing

# maximum number of thread
import datetime

max_thread = multiprocessing.cpu_count()*2
# default number of thread
default_threads = multiprocessing.cpu_count()/2

thread_lock = threading.Lock()


def parse_arguments():
    """Parse arguments
    :return: a parsed arguments object
    """
    parser = argparse.ArgumentParser(description='Create cache for all entries in neXtProt api server (with'
                                                 ' an optional export feature)')
    parser.add_argument('api', help='nextprot api uri (ie: build-api.nextprot.org)')
    parser.add_argument('-o', '--export_out', metavar='dir',
                        help='export destination directory (default export format: xml)')
    parser.add_argument('-f', '--export_format', metavar="{ttl,xml}", help='export format: ttl or xml')
    parser.add_argument('-t', '--thread', metavar='num', default=default_threads, type=int,
                        help='number of threads (default=' + str(default_threads) + ')')
    parser.add_argument('-n', metavar='entries', default=-1, type=int, help='export n entries only')

    arguments = parser.parse_args()

    # check number of thread
    if arguments.thread > max_thread:
        parser.error("cannot run "+str(arguments.thread)+" threads (max="+str(max_thread)+")")
    elif arguments.thread <= 0:
        parser.error(str(arguments.thread)+" should be a positive number of threads")

    if arguments.export_out is not None and not os.path.isdir(arguments.export_out):
        parser.error(arguments.export_out+" is not a directory")

    if not arguments.api.startswith("http"):
        arguments.api = 'http://' + arguments.api

    print "Parameters"
    print "  nextprot api host : " + arguments.api
    print "  thread number     : " + str(arguments.thread)
    if arguments.export_out is not None:
        if arguments.export_format is None:
            arguments.export_format = 'xml'
        print "  output directory : "+arguments.export_out
        print "  output format    : "+arguments.export_format
    if arguments.n > 0:
        print "  export n entries : "+str(arguments.n)
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


def build_nextprot_entry_url(api_host, np_entry, export_type):
    """Build url from specified parameters
    :param api_host: the api host
    :param np_entry: the nextprot entry name
    :param export_type: the export type of None if export disabled
    :return:
    """
    # 2 caches generated: /entry/{entry} + /entry/{entry}/page-display
    if export_type is None:
        return api_host + "/entry/" + np_entry + "/page-display"
    elif export_type == "xml":
        return api_host + "/export/entries.xml?query=id:" + np_entry
    elif export_type == "ttl":
        return api_host + "/export/entries.ttl?query=id:" + np_entry


def fetch_nextprot_entry(api_host, np_entry, export_type, export_dir):
    """Get nextprot entry
    :param api_host: the API url
    :param np_entry: the nextprot entry id
    :param export_type: the export type (ttl,xml or None)
    :param export_dir: the export directory
    """
    url = build_nextprot_entry_url(api_host, np_entry, export_type)
    outstream = build_output_stream(export_dir=export_dir, np_entry=np_entry,
                                    export_format=export_type)
    call_api_service(url=url, outstream=outstream, service_name="/entry/"+np_entry)


def fetch_gene_names(api_host):
    """Get nextprot gene names
    :param api_host: the API url
    """
    call_api_service(url=api_host + "/gene-names", outstream=open('/dev/null', 'w'), service_name="/gene-names")


def fetch_sitemap(api_host):
    """Get sitemap
    :param api_host: the API url
    """
    call_api_service(url=api_host + "/seo/sitemap", outstream=open('/dev/null', 'w'), service_name="/seo/sitemap")


def call_api_service(url, outstream, service_name):
    """Make a get API request and time execution
    :param url: the API url
    :param outstream: the output to put answer
    :param service_name: the API service name
    """

    timer = Timer()
    with timer:
        try:
            outstream.write(urllib2.urlopen(url).read())
            sys.stdout.write("SUCCESS: " + threading.current_thread().name + " has generated cache for "+service_name)
        except urllib2.URLError as e:
            sys.stdout.write("FAILURE: " + threading.current_thread().name+" failed with error '"+str(e)+"' for "+service_name)
            thread_lock.acquire()
            global error_counter
            error_counter += 1
            thread_lock.release()

    print " [" + str(datetime.timedelta(seconds=timer.duration_in_seconds())) + " seconds]"


def build_output_stream(export_dir, np_entry, export_format):
    """Build the output stream based on entry name and export mode
    :param export_dir: the export directory
    :param np_entry: the nextprot entry id
    :param export_format: the export type (ttl,xml or None)
    :return: the output stream where entry is written
    """
    if export_dir is not None:
        return open(export_dir+"/"+np_entry+"."+export_format, 'w')

    # redirects output to the null device if export is disabled
    return open('/dev/null', 'w')

if __name__ == '__main__':
    args = parse_arguments()

    all_nextprot_entries = get_all_nextprot_entries(api_host=args.api)

    if args.n > 0:
        all_nextprot_entries = all_nextprot_entries[0:args.n]

    pool = ThreadPool(args.thread)

    # global variable to count errors
    error_counter = 0
    
    globalTimer = Timer()
    with globalTimer:
        print "* Generating cache for services /entry/{entry} and /entry/{entry}/page-display (" + str(len(all_nextprot_entries)) + " nextprot entries)..."

        # add a task by entry to get
        for nextprot_entry in all_nextprot_entries:
            pool.add_task(func=fetch_nextprot_entry,
                          api_host=args.api,
                          np_entry=nextprot_entry,
                          export_type=args.export_format,
                          export_dir=args.export_out)
        pool.wait_completion()

    print "["+str(len(all_nextprot_entries)-error_counter) + "/" + str(len(all_nextprot_entries)) + " task"+ ('s' if error_counter>1 else '')\
          + " executed in " + str(datetime.timedelta(seconds=globalTimer.duration_in_seconds())) + " seconds]"

    print "\n* Generating cache for service /gene-names..."
    fetch_gene_names(args.api)

    #TODO: CACHE HAS TO BE FIRST CONFIGURED IN API
    #TODO: Add seo site-map cache generation
    # print "\n* Generating cache for resource /seo/sitemap..."
    # fetch_sitemap(args.api)
    #TODO: Add seo tags cache generation

    print "\n-------------------------------------------------------------------------------------"
    print "Overall cache generated with " + str(error_counter) + " error" + ('s' if error_counter>1 else '') + \
      " in " + str(datetime.timedelta(seconds=globalTimer.duration_in_seconds())) + " seconds"
