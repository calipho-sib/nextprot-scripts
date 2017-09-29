from threading import Thread
from Queue import Queue
import time


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

    def size(self):
        return self.tasks.qsize()

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
