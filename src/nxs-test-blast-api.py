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

    arguments.sequences = json.loads(open(arguments.json_file).read())

    print "Parameters"
    print "  API host         : " + arguments.host
    print "  JSON input file  : " + arguments.json_file + " (found "+str(len(arguments.sequences))+" sequences)"
    print "  JSON output file : " + arguments.out
    print
    print "  repeat blast     : " + str(arguments.repeat_blast) + " times"
    print "  thread number    : " + str(arguments.thread)
    print "-------------------------------------------------------------------------------------"

    return arguments


def call_blast(blast_api, sequence):

    url = blast_api + sequence+".json"

    try:
        response = urllib2.urlopen(url).read()
        return json.loads(response)
    except urllib2.URLError:
        thread.interrupt_main()
        sys.exit("cannot connect to nextprot API " + url)


def test_parallel_run(blast_api, sequences, expected_results, threads_num):

    pool = ThreadPool(threads_num)

    for sequence in sequences:
        pool.add_task(func=blast_and_test_correctness,
                      blast_api=blast_api,
                      sequence=sequence,
                      expected_results=expected_results)
    pool.wait_completion()


def blast_and_test_correctness(blast_api, sequence, expected_results):

    local_timer = Timer()
    with local_timer:
        try:
            result = call_blast(blast_api, sequence)
            compare_json_results(expected_results[sequence], result)
            sys.stdout.write("SUCCESS: " + threading.current_thread().name)
        except urllib2.URLError as e:
            sys.stdout.write("FAILURE: " + threading.current_thread().name+" failed with error '"+str(e))

    print " [" + str(datetime.timedelta(seconds=local_timer.duration_in_seconds())) + " seconds]"


def compare_json_results(sequential_results, parallel_results):

    if sorted(sequential_results.items()) != sorted(parallel_results.items()):
        raise ValueError("json content differs between "+pprint(sequential_results) + "\n and \n" +
                         pprint(parallel_results))


def blast_sequences_sequential(blast_api, sequences):

    print "Blasting "+str(len(sequences)) + " sequences to " + args.host + "..."

    results = {}

    local_timer = Timer()

    with local_timer:
        for sequence in sequences:
            results[sequence] = call_blast(blast_api, sequence)

    duration = local_timer.duration_in_seconds()
    duration_per_seconds = len(sequences) / duration
    print "Sequential execution in "+str(datetime.timedelta(seconds=duration)) + " seconds [" + \
          str(duration_per_seconds) + " sequences/second]"

    return results


def test_parallel_run_time(blast_api, sequences, expected_results):

    sequences *= args.repeat_blast

    local_timer = Timer()

    with local_timer:
        test_parallel_run(blast_api, sequences, expected_results, args.thread)

    duration = local_timer.duration_in_seconds()
    duration_per_seconds = len(sequences) / duration

    print "Parallel execution in "+str(datetime.timedelta(seconds=duration)) + " seconds [" + \
          str(duration_per_seconds) + " sequences/second]"


if __name__ == '__main__':

    args = parse_arguments()
    blast_api = args.host + '/blast/sequence/'

    sequential_results = blast_sequences_sequential(blast_api=blast_api, sequences=args.sequences)

    print "sleeping..."
    time.sleep(2)

    test_parallel_run_time(blast_api=blast_api, sequences=args.sequences, expected_results=sequential_results)

    f = open(args.out, 'w')
    f.write(json.dumps(sequential_results))
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

