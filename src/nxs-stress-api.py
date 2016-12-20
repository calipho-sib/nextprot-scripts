#!/usr/bin/python

import argparse, multiprocessing


max_batch_size = multiprocessing.cpu_count()*2

default_batch_size = 1
default_request_num = 10


def parse_arguments():
    """Parse arguments
    :return: a parsed arguments object
    """
    parser = argparse.ArgumentParser(description='Testing neXtProt API load by sending batches of n same '
                                                 'request multiple times')
    parser.add_argument('host', help='API host (ie: build-api.nextprot.org)')
    parser.add_argument('request', help='GET request (ie: /entry/NX_O00533/positional-annotation.json)')
    parser.add_argument('-b', '--batch_size', metavar='num', default=default_batch_size, type=int,
                        help='number of requests by batch (default=' + str(default_batch_size) + ')')
    parser.add_argument('-s', '--send', metavar='num', default=default_request_num, type=int,
                        help='stop after sending (and receiving) num requests (default=' +
                             str(default_request_num) + ')')
    parser.add_argument('-w', '--wait', metavar='secs', default=1, type=int,
                        help='seconds to wait between REST requests (or between parallel batches)')

    arguments = parser.parse_args()

    # Check API host address
    if not arguments.host.startswith("http"):
        arguments.host = 'http://' + arguments.host

    # Check number of request by batch
    if arguments.batch_size > max_batch_size:
        print 'beyond maximum requests by batch: reset to '+ max_batch_size
        arguments.batch_size = max_batch_size
    elif arguments.batch_size <= 0:
        parser.error("cannot send "+str(arguments.batch_size)+" requests by batch")

    # Check number of requests
    try:
        if arguments.send <= 0:
            parser.error(str(arguments.send)+" should send a positive number of requests")
    except ValueError as value_error:
        parser.error("cannot send "+str(arguments.send)+" requests: "+value_error)

    batch_count = arguments.send / arguments.batch_size

    print "Parameters"
    print "  API host            : " + arguments.host
    print "  API request         : " + arguments.request
    print "  Load testing"
    if arguments.send > 0:
        print "    requests sent     : " + str(arguments.send)
    print "    requests/batch    : " + str(arguments.batch_size)
    print "    batches           : " + str(batch_count)
    print

    return arguments


if __name__ == '__main__':

    args = parse_arguments()
