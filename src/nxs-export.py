#!/usr/bin/python
from Queue import Queue
from threading import Thread
import urllib2, time, argparse

url_path = "/export/entries/chromosome/"

number_of_chromosome = 23
num_threads = 1

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

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='Export neXtProt entries')
    parser.add_argument('api', help='the api url example: dev-api.nextprot.org')
    parser.add_argument('format', help='the output format, example: ttl or xml')
    parser.add_argument('directory', help='the directory where to save the ouput files. example /tmp/export')
    args = parser.parse_args()
   
    def export(url, filename):
        tim = Timer()
        with tim:
            print "fetching " + url + "\n"
            file(filename, "w").write(urllib2.urlopen(url).read())
        print url + " saved in " + filename + " done in " + str(tim.duration_in_seconds()) + "\n"
 
    pool = ThreadPool(num_threads)
    
    globalTimer = Timer()
    with globalTimer:
        for n in range (0, 23):
            pool.add_task(export, 'http://' + args.api + url_path + str(n) + "." + args.format, args.directory + "/chromosome-" + str(n) + "." + args.format)
        #pool.add_task(export, url_base + str(n), "file" + str(n) + "-" + str(n+batch_size))
        pool.wait_completion()
    print "Process finished in " + str(globalTimer.duration_in_seconds()) + "\n"
