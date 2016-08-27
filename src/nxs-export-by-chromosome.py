#!/usr/bin/python
from Queue import Queue
from threading import Thread
import urllib2, time, argparse
import multiprocessing

url_path = "/export/entries"
max_thread = multiprocessing.cpu_count()
default_threads = multiprocessing.cpu_count()/2
#max_thread = 1
#default_threads = 1

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

def export(url, filename):
    tim = Timer()
    with tim:
        print "fetching " + url + "\n"
        file(filename, "w").write(urllib2.urlopen(url).read())
    print url + " saved in " + filename + " done in " + str(tim.duration_in_seconds()) + "\n"

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
