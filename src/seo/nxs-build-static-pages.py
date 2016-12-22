import socket
import os
from xml.dom import minidom
import urllib2
from decorators import retry

import xml.etree.ElementTree as ET

# Important to add the / at the end
siteBase = "https://www.nextprot.org/"
sitemapUrl = siteBase + "sitemap.xml"

def saveToFile (content, filename):
    text_file = open(filename, "w")
    text_file.write(content)
    text_file.close()
    print str(cnt) + " creating file " + filename + " " 

def createDirectoryStructureIfNeeded(url, filename):
    if(filename):
        directoryname = os.path.dirname(filename)
        if(directoryname):
            if not os.path.exists(directoryname):
                os.makedirs(directoryname)

def getSitmapUrls():
    xml_str = getUrlAsContent(sitemapUrl)
    xmldoc = minidom.parseString(xml_str)

    # Gets urls
    xmlUrls = xmldoc.getElementsByTagName('loc')

    # Gets a list of urls
    return [url.firstChild.nodeValue for url in xmlUrls]


@retry(urllib2.URLError, tries=10, delay=3, backoff=2)
def getUrlAsContent(url):
    print "asking for " + url
    return urllib2.urlopen(url + "?_escaped_fragment_=", timeout=60).read()


#Where to save stie
dirlocation = "static-site/"

cnt = 0
# For each url in the sitemap
for url in getSitmapUrls():
    cnt += 1
    filename = url.replace(siteBase, "")
    createDirectoryStructureIfNeeded(url, dirlocation + filename)
    content = getUrlAsContent(url)
    if(filename):
        saveToFile(content, dirlocation + filename)
    else: 
        saveToFile(content, dirlocation + "index.html")