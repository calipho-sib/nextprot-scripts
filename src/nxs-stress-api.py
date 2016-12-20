#!/usr/bin/python

from nxs_utils import ThreadPool, Timer
import argparse, multiprocessing
import urllib2, sys, threading, datetime, json

max_batch_size = multiprocessing.cpu_count()*2

default_batch_size = 1
default_request_num = 10

# ./nxs-stress-api.py http://localhost:8080 blast/sequence/GTTYVTDKSEEDNEIESEEEVQPKTQGSRR
# --send 10
# --batch-size 3
# --exp-fields query data success
# --exp-assertions result['success']
def parse_arguments():
    """Parse arguments
    :return: a parsed arguments object
    """
    parser = argparse.ArgumentParser(description='Testing neXtProt API load by sending batches of n same '
                                                 'request multiple times')
    parser.add_argument('host', help='API host (ie: build-api.nextprot.org)')
    parser.add_argument('request', help='GET request (ie: /entry/NX_O00533/positional-annotation.json)')
    parser.add_argument('-b', '--batch-size', metavar='num', default=default_batch_size, type=int,
                        help='number of requests launched in parallel (default=' + str(default_batch_size) + ')')
    parser.add_argument('--send', metavar='num', default=default_request_num, type=int,
                        help='stop after sending (and receiving) num requests (default=' +
                             str(default_request_num) + ')')
    # ['query', 'data', 'success']
    parser.add_argument('--exp-fields', nargs='+', type=str, help='list of expected response field names')
    # result['success']
    parser.add_argument('--exp-assertions', nargs='*', type=str, help='list of response assertions')
    parser.add_argument('--exp-json-bytes', metavar='num', type=int, help='expected byte size of json response')
    arguments = parser.parse_args()

    # Update API host address
    if not arguments.host.startswith("http"):
        arguments.host = 'http://' + arguments.host

    if not arguments.request.endswith(".json"):
        arguments.request += '.json'

    # Check number of request by batch
    if arguments.batch_size > max_batch_size:
        print 'beyond maximum requests by batch: reset to ' + str(max_batch_size)
        arguments.batch_size = max_batch_size
    elif arguments.batch_size <= 0:
        parser.error("cannot send "+str(arguments.batch_size)+" requests by batch")

    # Check number of requests
    try:
        if arguments.send <= 0:
            parser.error(str(arguments.send)+" should send a positive number of requests")
    except ValueError as value_error:
        parser.error("cannot send "+str(arguments.send)+" requests: " + str(value_error))

    batch_count = arguments.send / arguments.batch_size

    print "Parameters"
    print "  API host            : " + arguments.host
    print "  API request         : " + arguments.request
    print "  Load testing"
    if arguments.send > 0:
        print "    requests sent     : " + str(arguments.send)
    print "    requests/batch    : " + str(arguments.batch_size)
    print "    batches           : " + str(batch_count)
    print "  Expected results"
    print "    exp. fields       : " + str(arguments.exp_fields)
    print "    exp. assertions   : " + str(arguments.exp_assertions)
    print "    exp. json bytes   : " + str(arguments.exp_json_bytes)
    print

    return arguments


def call_api_service(api_request_url, api_results):
    """Make a get API request and time execution
    :param api_request_url: the API url
    :param api_results: collector to put response
    """

    timer = Timer()
    with timer:
        try:
            result = json.loads(urllib2.urlopen(api_request_url).read())
            api_results.append(result)

            sys.stdout.write("SUCCESS: " + threading.current_thread().name)
        except urllib2.URLError as e:
            sys.stdout.write("FAILURE: " + threading.current_thread().name+" failed with error '"+e+"' for "+url)

    print " [" + str(datetime.timedelta(seconds=timer.duration_in_seconds())) + " seconds]"


def check_correctness(api_results, expected_fields, expected_predicates, expected_json_bytes):

    for result in api_results:
        if expected_fields is not None:
            for expected_field in expected_fields:
                if expected_field not in result:
                    raise ValueError("invalid result "+str(result))
        if expected_predicates is not None:
            for expected_predicate in expected_predicates:
                if not expected_predicate:
                    raise ValueError("assertion error: "+expected_predicate+" was false ("+str(result)+")")

        if expected_json_bytes is not None:
            if sys.getsizeof(result) != expected_json_bytes:
                raise ValueError("unexpected json bytes size " + str(sys.getsizeof(result)) + " (expected "
                                 + str(expected_json_bytes)+")")


if __name__ == '__main__':

    args = parse_arguments()

    pool = ThreadPool(args.batch_size)

    collector = list()

    globalTimer = Timer()
    with globalTimer:
        print "* Stressing API with " + str(args.send) + " identical requests..."

        url = args.host + '/' + args.request

        for i in range(args.send):
            pool.add_task(func=call_api_service,
                          api_request_url=url,
                          api_results=collector)
        pool.wait_completion()

    print "\n-------------------------------------------------------------------------------------"
    print "Executed in "+str(datetime.timedelta(seconds=globalTimer.duration_in_seconds())) + " seconds"

    check_correctness(collector, args.exp_fields, args.exp_assertions, args.exp_json_bytes)
