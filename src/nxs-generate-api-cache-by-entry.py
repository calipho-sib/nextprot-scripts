#!/usr/bin/python

import threading, json, sys, os
from nxs_utils import ThreadPool, Timer
import urllib2, argparse, multiprocessing

# maximum number of thread
import datetime

max_thread = multiprocessing.cpu_count()*2
# default number of thread
default_threads = multiprocessing.cpu_count()/2

# global variable to count API call errors (shared between threads)
api_call_error_counter = 0

# lock available to update previous global variable concurrently
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
    parser.add_argument('-k', '--chromosomes', metavar='name', type=str, nargs='+', help='export entries from specified chromosomes')
    parser.add_argument('-n', metavar='entries', default=-1, type=int, help='export the n first entries')

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
    if arguments.chromosomes:
        print "  on chromosomes   : "+str(arguments.chromosomes)
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
    sys.stdout.write("* Getting all nextprot entries... ")
    sys.stdout.flush()

    url_all_identifiers = api_host + "/entry-accessions.json"

    try:
        response = urllib2.urlopen(url_all_identifiers)
        npe_list = json.loads(response.read())
        print len(npe_list), "entries"
        return npe_list
    except urllib2.URLError as e:
        print "error getting all entries from neXtProt API host "+api_host+": "+str(e)
        sys.exit(1)


def get_nextprot_entries_on_chromosomes(api_host, on_chromosomes_only):
    """Extract all entry names in the specified chromosomes using the nexprot API service
    :param
        api_host: the host where nextprot API is located
    :return:
        all entries found on specified chromosomes
    """
    entries = []
    for k in on_chromosomes_only:
        entries.append(get_nextprot_entries_on_chromosome(api_host=api_host, on_chromosome=k))
    return reduce(list.__add__, entries)


def get_nextprot_entries_on_chromosome(api_host, on_chromosome):
    """Extract entry names of the specified chromosome using the nexprot API service
    :param    
        api_host: the host where nextprot API is located
    :param    
        on_chromosome: the chromosome to get entries identifiers from 
    :return:
    """
    sys.stdout.write("* Getting nextprot entries on chromosome " + on_chromosome+"... ")
    sys.stdout.flush()

    all_entries_on_chromosome = api_host + "/entry-accessions/chromosome/" + on_chromosome + ".json"

    try:
        response = urllib2.urlopen(all_entries_on_chromosome)
        npe_list = json.loads(response.read())
        print len(npe_list), "entries"
        return npe_list
    except urllib2.URLError as e:
        print "error getting entries on chromosome "+on_chromosome + " from neXtProt API host "+api_host+": "+str(e)
        sys.exit(3)


def get_all_chromosomes(api_host):
    """Extract all chromosome names using the nexprot API service
    :param
        api_host: the host where nextprot API is located
    :return:
    """
    sys.stdout.write("* Getting all chromosomes... ")
    sys.stdout.flush()

    url_all_identifiers = api_host + "/chromosome-names.json"

    try:
        response = urllib2.urlopen(url_all_identifiers)
        ce_list = json.loads(response.read())
        print len(ce_list), "chromosomes"
        return ce_list
    except urllib2.URLError as e:
        print "error getting all chromosome names from neXtProt API host "+api_host+": "+str(e)
        sys.exit(2)


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


def fetch_chromosome_report(api_host, chromosome_entry):
    """Get chromosome report
    :param api_host: the API url
    :param chromosome_entry: the chromosome entry id
    """
    url = api_host + "/chromosome-report/" + chromosome_entry + ".json"
    call_api_service(url=url, outstream=open('/dev/null', 'w'), service_name="/chromosome-report/"+chromosome_entry)


def fetch_gene_names(api_host):
    """Get nextprot gene names
    :param api_host: the API url
    """
    print "\n* Caching service /gene-names..."

    global api_call_error_counter
    api_call_error_counter = 0

    call_api_service(url=api_host + "/gene-names", outstream=open('/dev/null', 'w'), service_name="/gene-names")

    return api_call_error_counter


def fetch_sitemap(api_host):
    """Get sitemap
    :param api_host: the API url
    """
    print "\n* Caching resource /seo/sitemap..."

    global api_call_error_counter
    api_call_error_counter = 0

    call_api_service(url=api_host + "/seo/sitemap", outstream=open('/dev/null', 'w'), service_name="/seo/sitemap")

    return api_call_error_counter


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
            sys.stdout.flush()
        except urllib2.URLError as e:
            sys.stdout.write("FAILURE: " + threading.current_thread().name+" failed with error '"+str(e)+"' for "+service_name)
            sys.stdout.flush()
            thread_lock.acquire()
            global api_call_error_counter
            api_call_error_counter += 1
            thread_lock.release()

    print " [" + str(datetime.timedelta(seconds=timer.duration_in_seconds())) + " seconds]"


def fetch_nextprot_entries(arguments, nextprot_entries):
    """
    Fetch neXtProt entries from the API
    :param arguments: the program arguments
    :param nextprot_entries: a list of protein entries
    :return: the number of API call errors
    """
    print "* Caching services /entry/{entry} and /entry/{entry}/page-display (" + str(len(nextprot_entries)) \
          + " nextprot entries)..."

    pool = ThreadPool(arguments.thread)

    global api_call_error_counter
    api_call_error_counter = 0

    timer = Timer()
    with timer:
        for nextprot_entry in nextprot_entries:
            pool.add_task(func=fetch_nextprot_entry,
                          api_host=arguments.api,
                          np_entry=nextprot_entry,
                          export_type=arguments.export_format,
                          export_dir=arguments.export_out)
        pool.wait_completion()

    sys.stdout.write("["+str(len(nextprot_entries)-api_call_error_counter) + "/" + str(len(nextprot_entries)) + " task"
                     + ('s' if api_call_error_counter > 1 else ''))
    sys.stdout.write(" executed in " +
                     str(datetime.timedelta(seconds=timer.duration_in_seconds())) + " seconds]\n")
    sys.stdout.flush()

    return api_call_error_counter


def fetch_chromosome_reports(arguments, chromosome_entries):
    """
    Fetch chromosome reports from the API    
    :param arguments: the program arguments
    :param chromosome_entries: a list of chromosome entries
    :return: the number of API call errors
    """
    print "* Caching service /chromosome-report/{chromosome_entry} (" + str(len(chromosome_entries)) \
          + " chromosome entries)..."

    pool = ThreadPool(arguments.thread)

    global api_call_error_counter
    api_call_error_counter = 0

    timer = Timer()
    with timer:
        for chromosome_entry in chromosome_entries:
            pool.add_task(func=fetch_chromosome_report,
                          api_host=arguments.api,
                          chromosome_entry=chromosome_entry)
        pool.wait_completion()

    sys.stdout.write("["+str(len(chromosome_entries)-api_call_error_counter) + "/" + str(len(chromosome_entries))
                     + " task" + ('s' if api_call_error_counter > 1 else ''))
    sys.stdout.write(" executed in " +
                     str(datetime.timedelta(seconds=timer.duration_in_seconds())) + " seconds]\n")
    sys.stdout.flush()

    return api_call_error_counter


def fetch_all_chromosome_summaries(api_host):
    """Get all nextprot chromosome summaries
    :param api_host: the API url
    """
    print "\n* Caching service /chromosomes..."

    global api_call_error_counter
    api_call_error_counter = 0

    call_api_service(url=api_host + "/chromosomes", outstream=open('/dev/null', 'w'), service_name="/chromosomes")

    return api_call_error_counter


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


def get_chromosomes(arguments):

    if arguments.chromosomes:
        return arguments.chromosomes
    return get_all_chromosomes(api_host=arguments.api)


def get_nextprot_entries(arguments):

    if arguments.chromosomes:
        return get_nextprot_entries_on_chromosomes(api_host=arguments.api, on_chromosomes_only=arguments.chromosomes)
    return get_all_nextprot_entries(api_host=arguments.api)


def run(arguments):

    count_errors = 0

    global_timer = Timer()

    with global_timer:
        chromosomes = get_chromosomes(arguments=arguments)
        nextprot_entries = get_nextprot_entries(arguments=arguments)

        nextprot_entries_to_cache = nextprot_entries[0:arguments.n] if arguments.n > 0 else nextprot_entries

        count_errors = fetch_nextprot_entries(arguments=arguments, nextprot_entries=nextprot_entries)
        count_errors += fetch_gene_names(arguments.api)

        if len(nextprot_entries) == len(nextprot_entries_to_cache):
            count_errors += fetch_chromosome_reports(arguments=arguments, chromosome_entries=chromosomes)
        if len(chromosomes) == len(get_all_chromosomes(api_host=arguments.api)):
            count_errors += fetch_all_chromosome_summaries(arguments.api)

            # fetch_sitemap(args.api)

    print "\n-------------------------------------------------------------------------------------"
    print "Overall cache generated with " + str(count_errors) + " error" + ('s' if count_errors > 1 else '') \
          + " in " + str(datetime.timedelta(seconds=global_timer.duration_in_seconds())) + " seconds"


if __name__ == '__main__':
    run(arguments=parse_arguments())
