#!/usr/bin/python

from nxs_utils import ThreadPool, Timer
import argparse, json, urllib2, multiprocessing, time, threading, thread, sys, datetime
from pprint import pprint

default_threads = multiprocessing.cpu_count()/2

# Blast given sequences (from json file) via neXtProt API sequencially + in parallel then check correctness of responses
#
# Example:
# ./nxs-test-blast-api.py localhost:8080 request.json --repeat-blast 2 --out /tmp/blast.out --thread 16


def parse_arguments():
    """Parse arguments
    :return: a parsed arguments object
    """
    parser = argparse.ArgumentParser(description='Testing neXtProt API blast')
    parser.add_argument('host', help='API host (ie: build-api.nextprot.org)')
    parser.add_argument('json_file', help='sequences to search (json file)')
    parser.add_argument('-o', '--out', metavar='path', default='output.json',
                        help='file path to flush json output responses')
    parser.add_argument('-r', '--repeat-blast', metavar='num', default=1, type=int,
                        help='blast sequences n times (default=1)')
    parser.add_argument('-t', '--thread', metavar='num', default=default_threads, type=int,
                        help='number of threads (default=' + str(default_threads) + ')')

    arguments = parser.parse_args()

    # Update API host address
    if not arguments.host.startswith("http"):
        arguments.host = 'http://' + arguments.host

    if not arguments.json_file.endswith(".json"):
        raise ValueError(arguments.json_file+": invalid json file name")

    print "Parameters"
    print "  API host         : " + arguments.host
    print "  JSON input file  : " + arguments.json_file
    print "  JSON output file : " + arguments.out
    print
    print "  repeat blast     : " + str(arguments.repeat_blast) + " times"
    print "  thread number    : " + str(arguments.thread)
    print "-------------------------------------------------------------------------------------"

    return arguments


def run_request(blast_api, sequence):

    url = blast_api + sequence+".json"

    try:
        response = urllib2.urlopen(url).read()
        return json.loads(response)
    except:
        thread.interrupt_main()
        sys.exit(str(url)+": cannot connect to nextprot API")


def run_requests_parallel(blast_api, sequences, results, threads_num):

    pool = ThreadPool(threads_num)

    for sequence in sequences:

        pool.add_task(func=call_blast_service,
                      blast_api=blast_api,
                      sequence=sequence,
                      results=results)
    pool.wait_completion()


def call_blast_service(blast_api, sequence, results):

    local_timer = Timer()
    with local_timer:
        try:
            results[sequence] = run_request(blast_api, sequence)
            sys.stdout.write("SUCCESS: " + threading.current_thread().name)
        except urllib2.URLError as e:
            sys.stdout.write("FAILURE: " + threading.current_thread().name+" failed with error '"+str(e))

    print " [" + str(datetime.timedelta(seconds=local_timer.duration_in_seconds())) + " seconds]"


def compare_json_results(sequential_results, parallel_results):

    if sorted(sequential_results.items()) != sorted(parallel_results.items()):
        raise ValueError("json content differs between "+pprint(sequential_results) + "\n and \n" +
                         pprint(parallel_results))


def search_blast_sequential(blast_api, sequences):

    print "Blasting "+str(len(sequences)) + " sequences to " + args.host + "..."

    results = {}

    local_timer = Timer()

    with local_timer:
        for sequence in sequences:
            results[sequence] = run_request(blast_api, sequence)

    duration = local_timer.duration_in_seconds()
    duration_per_seconds = len(sequences) / duration
    print "Sequential execution in "+str(datetime.timedelta(seconds=duration)) + " seconds [" + \
          str(duration_per_seconds) + " sequences/second]"

    return results


def search_blast_parallel(blast_api, sequences):

    results = {}

    sequences *= args.repeat_blast

    local_timer = Timer()

    with local_timer:
        run_requests_parallel(blast_api, sequences, results, args.thread)

    duration = local_timer.duration_in_seconds()
    duration_per_seconds = len(sequences) / duration

    print "Parallel execution in "+str(datetime.timedelta(seconds=duration)) + " seconds [" + \
          str(duration_per_seconds) + " sequences/second]"

    return results


if __name__ == '__main__':

    args = parse_arguments()
    blast_api = args.host + '/blast/sequence/'

    sequences = json.loads(open(args.json_file).read())

    sequential_results = search_blast_sequential(blast_api=blast_api, sequences=sequences)

    print "sleeping..."
    time.sleep(2)

    parallel_results = search_blast_parallel(blast_api=blast_api, sequences=sequences)

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

