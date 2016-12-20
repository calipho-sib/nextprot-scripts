#!/usr/bin/python

from nxs_utils import ThreadPool, Timer
from threading import current_thread
import urllib2, argparse
import multiprocessing

max_thread = multiprocessing.cpu_count()
default_threads = multiprocessing.cpu_count()/2

print "max threads    :" + str(max_thread)
print "default threads:" + str(default_threads)

def export(url, filename):
    tim = Timer()
    with tim:
        print current_thread().name + " - calling " + url + "\n"
        file(filename, "w").write(urllib2.urlopen(url).read())
    print current_thread().name + " - output of " + url + " saved in " + filename + ", done in " + str(tim.duration_in_seconds()) + "\n"

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='Export neXtProt entries')
    parser.add_argument('api', help='the api url example: build-api.nextprot.org')
    parser.add_argument('output', help='the directory where to save the output files. example /work/ttldata/operations')
    parser.add_argument('-t', '--thread', metavar='num', default=default_threads, type=int, help='the number of threads (default='+ str(default_threads) + ')')

    args = parser.parse_args()

    if args.thread > max_thread:
        parser.error("cannot run "+str(args.thread)+" threads (max="+str(max_thread)+")")
    elif args.thread <= 0:
        parser.error(str(args.thread)+" should be a positive number of threads")
    
    print("thread count:" + str(args.thread) + "\n")

    # these 2 tasks should be completed before running the thread pool
    export('http://' + args.api + "/tasks/solr/entries/init", args.output + "/tasks-solr-entries-init.log")
    export('http://' + args.api + "/tasks/solr/gold-entries/init", args.output + "/tasks-solr-gold-entries-init.log")

    pool = ThreadPool(args.thread)
    
    globalTimer = Timer()
    with globalTimer:
        pool.add_task(export, 'http://' + args.api + "/tasks/solr/publications/reindex" , args.output + "/publications-reindex-log")
        pool.add_task(export, 'http://' + args.api + "/tasks/solr/terminologies/reindex" , args.output + "/terminologies-reindex-log")
        chromosomes = ['1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20','21','22','MT','Y','X','unknown']
        #chromosomes = ['MT','unknown']
        
        # 2 loops to avoid threads to work on same chromosome at the same time
        url1 = 'http://' + args.api + "/tasks/solr/entries/index/chromosome/"
        out1 = args.output + "/tasks-solr-entries-index-chromosome-"
        for chr in chromosomes:
            pool.add_task(export, url1 + chr , out1 + chr + '.log')

        url2 = 'http://' + args.api + "/tasks/solr/gold-entries/index/chromosome/"
        out2 = args.output + "/tasks-solr-gold-entries-index-chromosome-"
        for chr in chromosomes:
            pool.add_task(export, url2 + chr , out2 + chr + '.log')

        pool.wait_completion()

    print "Process finished in " + str(globalTimer.duration_in_seconds()) + "\n"
