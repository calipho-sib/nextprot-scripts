import os, urllib2, sys, ssl
from xml.dom import minidom
from decorators import retry
from nxs_utils import ThreadPool, Timer
from subprocess import call
import subprocess
import seleniumclient
import xml.etree.ElementTree as ET
import re, lxml
from lxml.html.clean import Cleaner

WORKERS = 1

siteBase = "https://bed-search.nextprot.org/"
sitemapUrl = siteBase + "sitemap.xml"
#Where to save static site
dirlocation = "/work/tmp/static-site/"


cleaner = Cleaner()
#cleaner.scripts = True # This is True because we want to activate the javascript filter
cleaner.scripts = True # This is True because we want to activate the javascript filter


def saveToFile (content, filename):
    text_file = open(filename, "w")
    text_file.write(content.encode('UTF-8'))
    text_file.close()
    print str(incrementCounter()) + " creating file " + filename + " " 
    sys.stdout.flush()

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
    return urllib2.urlopen(url + "?_escaped_fragment_=", timeout=60).read()


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
    try:
        if not os.path.exists(filename):
            content = getUrlAsContentWithSelenium(url)
            content = re.sub(r"<script(.|\n)*?<\/script>", "" ,content)
	    #dataclean = cleaner.clean_html(content)
            saveToFile(content, filename)
        else: 
            incrementCounter()
            #print "skipping " + filename + "and counting " + str(incrementCounter())
    except Exception as e:
        print "FAILED FOR " + url
        exc_type, exc_obj, exc_tb = sys.exc_info()
        fname = os.path.split(exc_tb.tb_frame.f_code.co_filename)[1]
        print(exc_type, fname, exc_tb.tb_lineno)
        print "Unexpected error: ", sys.exc_info()[0], sys.exc_info()[1]

    
def getAllPagesInParallel(URLS):
    pool = ThreadPool(WORKERS)
    for url in URLS:
        pool.add_task(func=getPage,
                      url=url,
                      filename=getFilename(url))
    print "done with " + str(COUNT) + " files"
    pool.wait_completion()
    
if __name__ == '__main__':
    URLS = getSitmapUrls()
    #URLS = ["https://bed-search.nextprot.org/entry/NX_P52701/function"]
    createDirectoryStructureIfNeeded(URLS)
    getAllPagesInParallel(URLS)
