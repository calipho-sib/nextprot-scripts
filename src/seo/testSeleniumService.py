import csv
import requests
import lxml.html
import re
import time
from nxs_utils import ThreadPool

content = ""
fail_list = []


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


def getURLsFromEntries(entries, view):
    return ["http://localhost:8082/https://www.nextprot.org/entry/"+entry+"/"+view for entry in entries]


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
        fail_list.append(url);
    elif not matchFind_h1 or not matchFind_title or matchFind_loader:
        fail_list.append(url);


if __name__ == '__main__':

    entries = readCSV("count-annotation.csv")
    entries.pop(0)
    entries.reverse()

    regex_pattern = {
        "pattern_desc": re.compile(r"<meta name=\"description\" content=(.*).*\/>"),
        "pattern_h1": re.compile(r'<h.*ng-bind="nm\.h1".*>(.*)<\/h.>'),
        "pattern_title": re.compile(r"<title.*ng-bind.*>(.*)<\/title>"),
        "pattern_loader": re.compile(r"<div\sid=\"spinnerContainer\"\sclass=\"active")
    }

    pool = ThreadPool(4)
    start = time.time()

    for url in getURLsFromEntries(entries, "function"):
        pool.add_task(func=testContentWithRegex,
                      regex_pattern=regex_pattern,
                      url=url)

    pool.wait_completion()

    print("time=", round(time.time() - start, 3))

    print "fail_list :"
    print fail_list

    saveToFile(fail_list, "pages_with_missing_content.txt")