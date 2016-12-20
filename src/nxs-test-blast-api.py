#!/usr/bin/python

import argparse, json, urllib2, multiprocessing, time, threading, sys, datetime
from pprint import pprint
from Queue import Queue
from threading import Thread

# ./nxs-test-blast-api.py localhost:8080 request.json --repeat-blast 2 --out /tmp/blast.out

def parse_arguments():
    """Parse arguments
    :return: a parsed arguments object
    """
    parser = argparse.ArgumentParser(description='Testing neXtProt API blast')
    parser.add_argument('host', help='API host (ie: build-api.nextprot.org)')
    parser.add_argument('json_file', help='input json file containing queries and expected results')
    parser.add_argument('-o', '--out', metavar='path', default='output.json',
                        help='file path to flush json output responses')
    parser.add_argument('-r', '--repeat-blast', metavar='num', default=1, type=int,
                        help='blast sequences n times (default=1)')

    arguments = parser.parse_args()

    # Update API host address
    if not arguments.host.startswith("http"):
        arguments.host = 'http://' + arguments.host

    print "Parameters"
    print "  API host         : " + arguments.host
    print "  JSON input file  : " + arguments.json_file
    print "  blasts sequence  : " + str(arguments.repeat_blast) + " times"
    print "  JSON output file : " + arguments.out
    print "-------------------------------------------------------------------------------------"

    return arguments


def run_requests_sequential(blast_api, sequences, results):

    for sequence in sequences:
        url = blast_api + sequence+".json"
        result = json.loads(urllib2.urlopen(url).read())

        results[sequence] = result


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


def run_requests_parallel(blast_api, sequences, results):

    pool = ThreadPool(multiprocessing.cpu_count()*2)

    for sequence in sequences:

        pool.add_task(func=call_blast_service,
                      blast_api=blast_api,
                      sequence=sequence,
                      results=results)
    pool.wait_completion()


def call_blast_service(blast_api, sequence, results):

    timer = Timer()
    with timer:
        try:
            url = blast_api + sequence+".json"
            result = json.loads(urllib2.urlopen(url).read())
            results[sequence] = result
            sys.stdout.write("SUCCESS: " + threading.current_thread().name)
        except urllib2.URLError as e:
            sys.stdout.write("FAILURE: " + threading.current_thread().name+" failed with error '"+e+"' for "+url)

    print " [" + str(datetime.timedelta(seconds=timer.duration_in_seconds())) + " seconds]"


def compare_json_results(sequential_results, parallel_results):

    if sorted(sequential_results.items()) != sorted(parallel_results.items()):
        raise ValueError("json content differs between "+pprint(sequential_results) + "\n and \n"+
                         pprint(parallel_results))

if __name__ == '__main__':

    args = parse_arguments()
    blast_api = args.host + '/blast/sequence/'

    sequences = json.loads(open(args.json_file).read()) * args.repeat_blast

    print "Blasting "+str(len(sequences)) + " sequences to " + args.host + "..."

    sequential_results = {}

    timer = Timer()

    with timer:
        run_requests_sequential(blast_api, sequences, sequential_results)

    duration = timer.duration_in_seconds()
    duration_per_seconds = len(sequences) / duration
    print "Sequential execution in "+str(datetime.timedelta(seconds=duration)) + " seconds [" + \
          str(duration_per_seconds) + " sequence/seconds]"

    time.sleep(2)

    parallel_results = {}
    timer = Timer()

    with timer:
        run_requests_parallel(blast_api, sequences, parallel_results)

    duration = timer.duration_in_seconds()
    duration_per_seconds = len(sequences) / duration

    print "Parallel execution in "+str(datetime.timedelta(seconds=duration)) + " seconds [" + \
          str(duration_per_seconds) + " sequence/seconds]"

    compare_json_results(sequential_results, parallel_results)

    f = open(args.out, 'w')
    all_results = dict()
    all_results["sequencial"] = sequential_results
    all_results["parallel"] = parallel_results
    f.write(json.dumps(all_results))
    f.close()

# example of json file
#[
#    "GTTYVTDKSEEDNEIESEEEVQPKTQGSRR",
#    "KGGHFYSAKPEILRAMQRADEALNKDKIKRLELAVCDEPSEPEEEEEMEVGTTYVTDK",
#    "NDILIGCEEE",
#    "TQTYSVLEGDPSEN",
#    "SKKKIIDFLSALEGFKVMCK",
#    "MSRQSTLYSFFPKSP",
#    "LLALPVLASPAYVAPAPGQA",
#    "HDSCQGDSGGPLVCKV",
#    "HLYYQDQLLPVSRIIVHP",
#    "VMVIGNLVVLNLFLALLLSSFSSDNLTAIEEDPDANNLQIAVTRIKKGIN",
#    "GNKIQGCIFDLVTNQAFDISIMVLICLN",
#    "WRFSCCQVN",
#    "RTSLFSFKGRGRDIGSETEFADD",
#    "GESGEMDSLRSQMEERFMSANPSK"
#]

