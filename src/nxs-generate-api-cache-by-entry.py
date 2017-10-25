#!/usr/bin/python

import threading, json, sys, os
from nxs_utils import ThreadPool, Timer
import urllib2, argparse, multiprocessing

# maximum number of thread
import datetime

max_thread = multiprocessing.cpu_count()*2
# default number of thread
default_threads = multiprocessing.cpu_count()/2

# global variable collecting API call errors (shared between threads)
api_call_errors = []

# lock available to update previous global variable concurrently
thread_lock = threading.Lock()


def parse_arguments():
    """Parse arguments
    :return: a parsed arguments object
    """
    parser = argparse.ArgumentParser(description='Create cache for all entries in neXtProt api server (with'
                                                 ' an optional export feature)')
    parser.add_argument('api', help='nextprot api uri (ie: build-api.nextprot.org)')
    parser.add_argument('-o', '--export_dir', metavar='dir', default="./",
                        help='export destination directory (default export format: xml)')
    parser.add_argument('-f', '--export_entry_format', metavar="{ttl,xml}", help='export format: ttl or xml')
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

    # check validity of export folder
    if arguments.export_dir is not None and not os.path.isdir(arguments.export_dir):
        parser.error(arguments.export_dir+" is not a directory")

    if not arguments.api.startswith("http"):
        arguments.api = 'http://' + arguments.api

    print "Parameters"
    print "----------"
    print "  nextprot api host          : " + arguments.api
    print "  thread number              : " + str(arguments.thread)
    # if some export has to be done
    if arguments.export_entry_format is not None:
        print "  export directory           : " + arguments.export_dir
        if arguments.export_entry_format is not None:
            print "  entry entry output format  : " + arguments.export_entry_format
    if arguments.chromosomes:
            print "  on chromosomes             : " + str(arguments.chromosomes)
    if arguments.n > 0:
            print "  export n entries           : " + str(arguments.n)
    print

    return arguments


def get_all_nextprot_entries(api_host):
    """Extract all entry names using the nexprot API service
    :param
        api_host: the host where nextprot API is located
    :return:
    """
    sys.stdout.write("* Getting all nextprot entry accessions... ")
    sys.stdout.flush()

    url_all_identifiers = api_host + "/entry-accessions.json"

    try:
        response = urllib2.urlopen(url_all_identifiers)
        npe_list = json.loads(response.read())
        print len(npe_list), "accessions"
        return npe_list
    except urllib2.URLError as e:
        print "error getting all entries accessions from neXtProt API host "+api_host+": "+str(e)
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
    sys.stdout.write("* Getting all chromosomes names... ")
    sys.stdout.flush()

    url_all_identifiers = api_host + "/chromosomes.json"

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
    if export_type is None:
        return api_host + "/entry/" + np_entry
    elif export_type == "xml":
        return api_host + "/export/entries.xml?query=id:" + np_entry
    elif export_type == "ttl":
        return api_host + "/export/entries.ttl?query=id:" + np_entry
    elif export_type == "peff" or export_type == "fasta":
        return api_host + "/export/entry/" + np_entry + "." + export_type


def fetch_nextprot_entry(api_host, np_entry, export_type, export_dir):
    """Get nextprot entry
    :param api_host: the API url
    :param np_entry: the nextprot entry id
    :param export_type: the export type (ttl,xml or None)
    :param export_dir: the export directory
    """
    url = build_nextprot_entry_url(api_host, np_entry, export_type)
    outstream = build_output_stream(export_dir=export_dir, basename=np_entry, format=export_type)
    call_api_service(url=url, outstream=outstream, service_name="/entry/"+np_entry)


def cache_nextprot_entry_for_peff(api_host, np_entry):
    """Export nextprot entry in peff format
    :param api_host: the API url
    :param np_entry: the nextprot entry id
    :param export_dir: the export directory
    """
    url = build_nextprot_entry_url(api_host, np_entry, "peff")
    call_api_service(url=url, outstream=open('/dev/null', 'w'), service_name="/export/entry/"+np_entry + ".peff")


def fetch_chromosome_report(api_host, chromosome):
    """Get chromosome report
    :param api_host: the API url
    :param chromosome: the chromosome name
    """
    service_path = "/chromosome-report/" + chromosome
    url = api_host + service_path + ".json"
    call_api_service(url=url, outstream=open('/dev/null', 'w'), service_name=service_path)


def fetch_chromosome_summary_report(api_host, chromosome):
    """Get chromosome summary report
    :param api_host: the API url
    :param chromosome: the chromosome name
    """

    service_path = "/chromosome-report/" + chromosome + "/summary"
    url = api_host + service_path + ".json"
    call_api_service(url=url, outstream=open('/dev/null', 'w'), service_name=service_path)


def fetch_gene_names(api_host):
    """Get nextprot gene names
    :param api_host: the API url
    """
    print "\n* Caching service /gene-names..."

    call_api_service(url=api_host + "/gene-names", outstream=open('/dev/null', 'w'), service_name="/gene-names")


def fetch_sitemap(api_host):
    """Get sitemap
    :param api_host: the API url
    """
    print "\n* Caching resource /seo/sitemap..."

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
            sys.stdout.flush()
        except urllib2.URLError as e:
            sys.stdout.write("FAILURE: " + threading.current_thread().name+" failed with error '"+str(e)+"' for "+service_name)
            sys.stdout.flush()
            thread_lock.acquire()
            global api_call_errors
            api_call_errors.append(url)
            thread_lock.release()

    print " [" + str(datetime.timedelta(seconds=timer.duration_in_seconds())) + " seconds]"


def add_nextprot_entries_tasks(arguments, nextprot_entries, pool):
    """
    add tasks to export and cache nextprot entries
    :param arguments: the program arguments
    :param nextprot_entries: a list of protein entries
    :param pool: the task pool
    """
    for nextprot_entry in nextprot_entries:
        pool.add_task(func=fetch_nextprot_entry,
                      api_host=arguments.api,
                      np_entry=nextprot_entry,
                      export_type=arguments.export_entry_format,
                      export_dir=arguments.export_dir)
        pool.add_task(func=cache_nextprot_entry_for_peff,
                      api_host=arguments.api,
                      np_entry=nextprot_entry)

    return len(nextprot_entries) * 2


def fetch_nextprot_entries(arguments, nextprot_entries, pool):
    """
    Fetch neXtProt entries from the API
    :param arguments: the program arguments
    :param nextprot_entries: a list of protein entries
    :return: the number of API call errors
    :param pool: the task pool
    """
    print "\n* Caching service /entry/{entry} (" + str(len(nextprot_entries)) + " nextprot entries)..."

    timer = Timer()
    with timer:
        task_count = add_nextprot_entries_tasks(arguments, nextprot_entries, pool)
        pool.wait_completion()

    sys.stdout.write("["+str(task_count) + " tasks executed in " +
                     str(datetime.timedelta(seconds=timer.duration_in_seconds())) + " seconds]\n")
    sys.stdout.flush()


def _fetch_chromosome_reports_given_func(report_func, arguments, chromosome_names, pool):
    """Fetch chromosome reports from the API
    :param report_func: the report function
    :param arguments: the program arguments
    :param chromosome_names: a list of chromosome entries
    :param pool: the pool of reusable threads
    :return: the number of API call errors
    """
    timer = Timer()
    with timer:
        for chromosome_name in chromosome_names:
            pool.add_task(func=report_func,
                          api_host=arguments.api,
                          chromosome=chromosome_name)
        pool.wait_completion()

    sys.stdout.write("["+str(len(chromosome_names)) + " tasks executed in " +
                             str(datetime.timedelta(seconds=timer.duration_in_seconds())) + " seconds]\n")
    sys.stdout.flush()


def fetch_chromosome_reports(arguments, chromosome_names, pool):
    """Fetch chromosome reports from the API
    :param arguments: the program arguments
    :param chromosome_names: a list of chromosome entries
    :param pool: the pool of reusable threads
    :return: the number of API call errors
    """
    print "\n* Caching service /chromosome-report/{chromosome} (" + str(len(chromosome_names)) \
          + " chromosome entries)..."

    return _fetch_chromosome_reports_given_func(report_func=fetch_chromosome_report,
                                                arguments=arguments,
                                                chromosome_names=chromosome_names,
                                                pool=pool)


def fetch_chromosome_summaries(arguments, chromosome_names, pool):
    """Fetch chromosome summary reports from the API
    :param arguments: the program arguments
    :param chromosome_names: a list of chromosome entries
    :param pool: the pool of reusable threads
    :return: the number of API call errors
    """
    print "\n* Caching service /chromosome-reports/{chromosome}/summary..."

    return _fetch_chromosome_reports_given_func(report_func=fetch_chromosome_summary_report,
                                                arguments=arguments,
                                                chromosome_names=chromosome_names,
                                                pool=pool)


def build_output_stream(export_dir, basename, format):
    """Build the output stream based on entry name and export mode
    :param export_dir: the export directory
    :param basename: the basename
    :param format: the export format
    :return: the output stream where entry is written
    """
    if format is not None:
        return open(export_dir+"/"+basename+"."+format, 'w')

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


def get_all_nacetylated_entries(api_host):
    """Extract all accessions of nacetylated entries
    :param
        api_host: the host where nextprot API is located
    :return:
    """
    print "\n* Caching nacetylated entries... "

    call_api_service(url=api_host + "/chromosome-report/export/hpp/nacetylated-entries.tsv",
                     outstream=open('/dev/null', 'w'),
                     service_name="/chromosome-report/export/hpp/nacetylated-entries")


def get_all_unconfirmed_ms_data_entries(api_host):
    """Extract all accessions of unconfirmed ms data entries
    :param
        api_host: the host where nextprot API is located
    :return:
    """
    print "\n* Caching unconfirmed ms data entries... "

    call_api_service(url=api_host + "/chromosome-report/export/hpp/unconfirmed-ms-data-entries.txt",
                     outstream=open('/dev/null', 'w'),
                     service_name="/chromosome-report/export/hpp/unconfirmed-ms-data-entries")


def get_all_phosphorylated_entries(api_host):
    """Extract all accessions of phosphorylated entries
    :param
        api_host: the host where nextprot API is located
    :return:
    """
    print "\n* Caching phosphorylated entries... "

    call_api_service(url=api_host + "/chromosome-report/export/hpp/phosphorylated-entries.tsv",
                     outstream=open('/dev/null', 'w'),
                     service_name="/chromosome-report/export/hpp/phosphorylated-entries")


def build_all_terminology_graphs(api_host):
    """Build all terminology graph using the nexprot API service
    :param
        api_host: the host where nextprot API is located
    :return:
    """
    sys.stdout.write("* Building all terminology graphs... ")
    sys.stdout.flush()

    url_build_all_graphs = api_host + "/terminology-graph/build-all.json"

    try:
        response = urllib2.urlopen(url_build_all_graphs)
        building_time_by_terminology = json.loads(response.read())
        print (len(building_time_by_terminology)-1), "graphs built"
        return building_time_by_terminology
    except urllib2.URLError as e:
        print "error getting all entries from neXtProt API host "+api_host+": "+str(e)
        sys.exit(1)


def run(arguments):

    pool = ThreadPool(arguments.thread)

    global_timer = Timer()

    with global_timer:
        chromosomes = get_chromosomes(arguments=arguments)

        nextprot_entries = get_nextprot_entries(arguments=arguments)
        nextprot_entries_to_cache = nextprot_entries[0:arguments.n] if arguments.n >= 0 else nextprot_entries

        if len(nextprot_entries_to_cache) > 0:
             fetch_nextprot_entries(arguments=arguments, nextprot_entries=nextprot_entries_to_cache, pool=pool)
        fetch_gene_names(arguments.api)

        # fetch chromosome report only if all entries
        if len(nextprot_entries) == len(nextprot_entries_to_cache):
            fetch_chromosome_reports(arguments=arguments, chromosome_names=chromosomes, pool=pool)
            fetch_chromosome_summaries(arguments=arguments, chromosome_names=chromosomes, pool=pool)

        # cache other infos
        get_all_nacetylated_entries(api_host=arguments.api)
        get_all_phosphorylated_entries(api_host=arguments.api)
        get_all_unconfirmed_ms_data_entries(api_host=arguments.api)

    build_all_terminology_graphs(api_host=arguments.api)

    print "\n-------------------------------------------------------------------------------------"
    print "Overall cache generated with " + str(len(api_call_errors)) + " error" + ('s' if len(api_call_errors) > 1 else '') \
          + " in " + str(datetime.timedelta(seconds=global_timer.duration_in_seconds())) + " seconds"

    if len(api_call_errors)>0:
        print "API call errors: " + api_call_errors

if __name__ == '__main__':
    run(arguments=parse_arguments())
