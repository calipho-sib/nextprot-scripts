#!/usr/bin/python

from Queue import Queue
import threading, json, sys, os
from threading import Thread
import urllib2, time, argparse, multiprocessing

# maximum number of thread
max_thread = multiprocessing.cpu_count()*2
# default number of thread
default_threads = multiprocessing.cpu_count()/2


class Worker(Thread):
    """Thread executing tasks from a given tasks queue"""
    def __init__(self, tasks):
        Thread.__init__(self)
        self.tasks = tasks
        self.daemon = True
        self.start()
    
    def run(self):
        while True:
            func, args, kargs = self.tasks.get()
            try: func(*args, **kargs)
            except Exception, e: print e
            self.tasks.task_done()


class ThreadPool:
    """Pool of threads consuming tasks from a queue"""
    def __init__(self, num_threads):
        self.tasks = Queue(num_threads)
        for _ in range(num_threads): Worker(self.tasks)

    def add_task(self, func, *args, **kargs):
        """Add a task to the queue"""
        self.tasks.put((func, args, kargs))

    def wait_completion(self):
        """Wait for completion of all the tasks in the queue"""
        self.tasks.join()


class Timer(object):
    """Estimate elapsed time between __enter__ and __exit__ calls
    """

    def __enter__(self):
        self.__start = time.time()

    def __exit__(self, exc_type, exc_value, traceback):
        if exc_type is not None:
            print "exit with error:", exc_type, exc_value, traceback

        self.__finish = time.time()
        return self

    def duration_in_seconds(self):
        return self.__finish - self.__start


def parse_arguments():
    """Parse arguments
    :return: a parsed arguments object
    """
    parser = argparse.ArgumentParser(description='Create cache for all entries in neXtProt api server (with'
                                                 ' optional export)')
    parser.add_argument('api', help='nextprot api uri (ie: build-api.nextprot.org)')
    parser.add_argument('-o', '--export_out', metavar='dir',
                        help='export destination directory (default export format: xml)')
    parser.add_argument('-f', '--export_format', metavar="{ttl,xml}", help='export format: ttl or xml')
    parser.add_argument('-t', '--thread', metavar='num', default=default_threads, type=int,
                        help='number of threads (default='+ str(default_threads) + ')')
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
    url_all_identifiers = api_host + "/master-identifiers.json"

    try:
        response = urllib2.urlopen(url_all_identifiers)
        return json.loads(response.read())['stringList']
    except urllib2.URLError as e:
        print "error getting all entries from neXtProt API host "+api_host+": "+str(e)
        sys.exit()


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
    timer = Timer()
    with timer:
        print threading.current_thread().name+": starting generating cache for entry " + np_entry + " ... "
        try:
            outstream.write(urllib2.urlopen(url).read())
        except urllib2.URLError as e:
            print threading.current_thread().name+": "+str(e)
    print threading.current_thread().name + ": cache generated for entry "+np_entry + " [" + str(timer.duration_in_seconds()) + " seconds]"


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

    globalTimer = Timer()
    with globalTimer:
        print "Running tasks..."

        # add a task by entry to get
        for nextprot_entry in all_nextprot_entries:
            pool.add_task(func=fetch_nextprot_entry,
                          api_host=args.api,
                          np_entry=nextprot_entry,
                          export_type=args.export_format,
                          export_dir=args.export_out)
        pool.wait_completion()

    print "\nCache generated in " + str(globalTimer.duration_in_seconds()) + " seconds"
