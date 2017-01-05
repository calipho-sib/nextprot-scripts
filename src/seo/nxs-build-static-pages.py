import os, urllib2, sys, ssl
from xml.dom import minidom
from decorators import retry
from nxs_utils import ThreadPool, Timer
from subprocess import call
import subprocess
import seleniumclient

import xml.etree.ElementTree as ET

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

WORKERS = 1

siteBase = "https://bed-search.nextprot.org/"
#siteBase = "https://www.nextprot.org/" # Important to add the / at the end
sitemapUrl = siteBase + "sitemap.xml"
#Where to save static site
dirlocation = "/tmp/static-site/"


def saveToFile (content, filename):
    text_file = open(filename, "w")
    text_file.write(content)
    text_file.close()
    print str(incrementCounter()) + " creating file " + filename + " " 

def createDirectoryStructureIfNeeded(URLS):
    for url in URLS:
        filename = getFilename(url)
        if(filename):
            directoryname = os.path.dirname(filename)
            if(directoryname):
                if not os.path.exists(directoryname):
                    os.makedirs(directoryname)

def getSitmapUrls():
    xml_str = getUrlAsContentWithPrerender(sitemapUrl)
    xmldoc = minidom.parseString(xml_str)

    # Gets urls
    xmlUrls = xmldoc.getElementsByTagName('loc')

    # Gets a list of urls
    return [url.firstChild.nodeValue.replace("https://www.nextprot.org/", siteBase) for url in xmlUrls]


@retry(urllib2.URLError, tries=10, delay=2, backoff=2)
def getUrlAsContentWithPrerender(url):
    print "asking for " + url
    return urllib2.urlopen(url + "?_escaped_fragment_=", timeout=60, context=ctx).read()


@retry(urllib2.URLError, tries=10, delay=2, backoff=2)
def getUrlAsContentWithSelenium(url):
    print "asking for " + url
    return seleniumclient.getPageUsingSelenium(url)


@retry(urllib2.URLError, tries=10, delay=2, backoff=2)
def getUrlAsContentWithPhantomJs(url):
    print "asking for " + url
    proc = subprocess.Popen(["./phantomjs-mac --ignore-ssl-errors=true print-html-content.js " +  url], stdout=subprocess.PIPE, shell=True)
    (out, err) = proc.communicate()
    return out


def getFilename(url):
    truncatedUrl = url.replace(siteBase, "")
    if truncatedUrl:
	return dirlocation + truncatedUrl
    else:
	return dirlocation + "index.html"

COUNT = 0
def incrementCounter():
    global COUNT
    COUNT = COUNT+1
    return COUNT

def getPage(url, filename):
#    try:
    content = getUrlAsContentWithSelenium(url)
    saveToFile(content, filename)
#    except:
#        print "FAILED FOR " + url
#        print("Unexpected error:", sys.exc_info()[0])

    
def getAllPagesInParallel(URLS):
    pool = ThreadPool(WORKERS)
    for url in URLS:
        pool.add_task(func=getPage,
                      url=url,
                      filename=getFilename(url))
    pool.wait_completion()
    
if __name__ == '__main__':
    URLS = getSitmapUrls()
    #URLS = ["https://bed-search.nextprot.org/entry/NX_P52701/function"]
    createDirectoryStructureIfNeeded(URLS)
    getAllPagesInParallel(URLS)
