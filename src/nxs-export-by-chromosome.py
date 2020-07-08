#!/usr/bin/python

from nxs_utils import ThreadPool, Timer
import urllib2, argparse
import multiprocessing
import sys

url_path = "/export/entries"
max_thread = multiprocessing.cpu_count()
default_threads = multiprocessing.cpu_count()/2

print "max threads    :" + str(max_thread)
print "default threads:" + str(default_threads)
sys.stdout.flush()

def export(url, filename):
    tim = Timer()
    with tim:
        print "fetching " + url + "\n"
        sys.stdout.flush()
        file(filename, "w").write(urllib2.urlopen(url).read())
    print url + " saved in " + filename + " done in " + str(tim.duration_in_seconds()) + "\n"
    sys.stdout.flush()

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='Export neXtProt entries')
    parser.add_argument('api', help='the api url example: build-api.nextprot.org')
    #New in Python 2.7: parser.add_argument('format', choices={'ttl', 'xml'}, help='the export format')
    parser.add_argument('format', help='the export format: ttl or xml')
    parser.add_argument('output', help='the directory where to save the output files. example /work/ttldata/chromosome-new')
    parser.add_argument('-t', '--thread', metavar='num', default=default_threads, type=int, help='the number of threads (default='+ str(default_threads) + ')')

    args = parser.parse_args()

    if args.thread > max_thread:
        parser.error("cannot run "+str(args.thread)+" threads (max="+str(max_thread)+")")
    elif args.thread <= 0:
        parser.error(str(args.thread)+" should be a positive number of threads")

    pool = ThreadPool(args.thread)
    
    globalTimer = Timer()
    with globalTimer:
        url = 'http://' + args.api + url_path  + "." + args.format + "?chromosome="
        for n in range (1, 23):
            filepath = args.output + "/" + str(n) + "." + args.format
            pool.add_task(export, url + str(n) , filepath)
        #Adding other chromosomes   
        pool.add_task(export, url + "MT" , args.output + "/MT." + args.format)
        pool.add_task(export, url + "Y" , args.output + "/Y." + args.format)
        pool.add_task(export, url + "X" , args.output + "/X." + args.format)
        pool.add_task(export, url + "unknown" , args.output + "/unknown." + args.format)

        if args.format == 'ttl':
            #Adding publications, schema, terminology and experimental contexts
            pool.add_task(export, 'http://' + args.api + "/rdf/schema.ttl" , args.output + "/schema.ttl")
            pool.add_task(export, 'http://' + args.api + "/rdf/experimentalcontext.ttl" , args.output + "/experimentalcontext.ttl")
            pool.add_task(export, 'http://' + args.api + "/rdf/terminology.ttl" , args.output + "/terminology.ttl")
            pool.add_task(export, 'http://' + args.api + "/rdf/publication.ttl" , args.output + "/publication.ttl")

        pool.wait_completion()
    print "Process finished in " + str(globalTimer.duration_in_seconds()) + "\n"
    sys.stdout.flush()
