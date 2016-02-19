#!/usr/bin/python

from Queue import Queue
import threading
from threading import Thread
import urllib2, time, argparse, multiprocessing

dev_null = open('/dev/null', 'w')

url_resource = "/export/entries.xml?chromosome="
all_chromosomes = range (1, 23) + ["MT", "Y", "X", "unknown"]
max_thread = len(all_chromosomes)
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
    def __enter__(self):
        self.__start = time.time()
    def __exit__(self, type, value, traceback):
        self.__finish = time.time()
    def duration_in_seconds(self):
        return self.__finish - self.__start

def parse_args():
    parser = argparse.ArgumentParser(description='Create cache in neXtProt api server')
    parser.add_argument('api', help='the api url example: build-api.nextprot.org')
    parser.add_argument('-t', '--thread', metavar='num', default=default_threads, type=int, help='the number of threads (default='+ str(default_threads) + ')')
    args = parser.parse_args()

    # check number of thread
    if args.thread > max_thread:
        parser.error("cannot run "+str(args.thread)+" threads (max="+str(max_thread)+")")
    elif args.thread <= 0:
        parser.error(str(args.thread)+" should be a positive number of threads")

    return args

def add_tasks(url, pool):
    #for chr in ["unknown"]:
    for chr in all_chromosomes:
        pool.add_task(url_chromosome_open, url, str(chr))

def url_chromosome_open(url, chromosome):
    url = url + chromosome

    timer = Timer()
    with timer:
        print threading.current_thread().name+": starting generating cache for chromosome " + chromosome +" ... "
        try:
            dev_null.write(urllib2.urlopen(url).read())
        except urllib2.URLError as e:
            print threading.current_thread().name+": "+str(e)
            return None
    print threading.current_thread().name+": cache generated for chromosome "+chromosome +" [" + str(timer.duration_in_seconds()) + " seconds]"

if __name__ == '__main__':
    args = parse_args()

    pool = ThreadPool(args.thread)
    
    globalTimer = Timer()
    with globalTimer:

        # add tasks
        add_tasks('http://' + args.api + url_resource, pool)

        # run tasks
        pool.wait_completion()
    print "\nCache generated in " + str(globalTimer.duration_in_seconds()) + " seconds"
