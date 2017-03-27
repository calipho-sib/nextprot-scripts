import csv
import requests
import lxml.html
import re
import time, argparse
from nxs_utils import ThreadPool

content = ""
fail_list = []
default_threads = 4


# For not admin users like me :(
#
# Install virtualenv then execute the following commands:
#
# $ virtualenv -p /usr/local/bin/python2.7 venv
# $ source venv/bin/activate
# $ pip install lxml requests
# $ scp npteam@crick:/work/npdata/np2_static/count-annotation.csv .
# (venv) $ python testSeleniumService.py --host http://localhost:8082 -t 8 -n 10


def parse_arguments():
    """Parse arguments
    :return: a parsed arguments object
    """
    parser = argparse.ArgumentParser(description='Query all neXtProt entry pages to sparender server for rendering')
    parser.add_argument('--host', default="http://nextp-vm2b.vital-it.ch:8082", help='sparender host uri')
    parser.add_argument('-t', '--thread', metavar='num', default=default_threads, type=int,
                        help='number of threads (default=' + str(default_threads) + ')')
    parser.add_argument('-n', metavar='entries', default=-1, type=int, help='query n first entries only')

    arguments = parser.parse_args()

    # check number of thread
    if arguments.thread <= 0:
        parser.error(str(arguments.thread)+" should be a positive number of threads")

    if not arguments.host.startswith("http"):
        arguments.host = 'http://' + arguments.host

    print "Parameters"
    print "  sparender host  : " + arguments.host
    print "  thread number   : " + str(arguments.thread)
    if arguments.n > 0:
        print "  query n entries : "+str(arguments.n)
    print

    return arguments

def saveToFile(content, filename):
    with open(filename,'w+') as f:
        f.seek(0)
        contentStr = str(content);
        f.write(contentStr)
        f.close()


def readCSV(file):
    entries = []
    with open(file, 'rb') as f:
        reader = csv.reader(f)
        for row in reader:
            entries.append(row[0])

    return entries


def getURLsFromEntries(host, entries, view):
    return [host+"/https://www.nextprot.org/entry/"+entry+"/"+view for entry in entries]


def getContentOfUrl(url):
    print "asking for " + url
    return requests.get(url, verify=False).content


def testContentWithlxml():
    dom = lxml.html.fromstring(content)
    description = dom.xpath("//meta[@name='description']/@content")[0]
    h1 = dom.xpath("//*[self::h1 or self::h2][@ng-bind='nm.h1']/text()")[0]
    title = dom.xpath("//title[@ng-bind='nm.title']/text()")[0]


def testContentWithRegex(regex_pattern, url):

    content = getContentOfUrl(url=url)

    matchFind_desc = regex_pattern["pattern_desc"].findall(content)
    matchFind_h1 = regex_pattern["pattern_h1"].findall(content)
    matchFind_title = regex_pattern["pattern_title"].findall(content)
    matchFind_loader = regex_pattern["pattern_loader"].findall(content)

    if not matchFind_desc or matchFind_desc[0] == "{{nm.description}}":
        fail_list.append(url)
    elif not matchFind_h1 or not matchFind_title or matchFind_loader:
        fail_list.append(url)


if __name__ == '__main__':

    args = parse_arguments()

    entries = readCSV("count-annotation.csv")
    entries.pop(0)
    entries.reverse()

    if args.n > 0:
        entries = entries[0:args.n]

    regex_pattern = {
        "pattern_desc": re.compile(r"<meta name=\"description\" content=(.*).*\/>"),
        "pattern_h1": re.compile(r'<h.*ng-bind="nm\.h1".*>(.*)<\/h.>'),
        "pattern_title": re.compile(r"<title.*ng-bind.*>(.*)<\/title>"),
        "pattern_loader": re.compile(r"<div\sid=\"spinnerContainer\"\sclass=\"active")
    }

    pool = ThreadPool(args.thread)
    start = time.time()

    for url in getURLsFromEntries(args.host, entries, "function"):
        pool.add_task(func=testContentWithRegex,
                      regex_pattern=regex_pattern,
                      url=url)

    pool.wait_completion()

    print("time=", round(time.time() - start, 3))

    print "failed urls count:", len(fail_list)

    saveToFile(fail_list, "pages_with_missing_content.txt")