import urllib
import os
from xml.dom import minidom

import xml.etree.ElementTree as ET

# Important to add the / at the end
siteBase = "https://www.nextprot.org/"
url = "https://api.nextprot.org/seo/sitemap.xml";

xml_str = urllib.urlopen(url).read()
xmldoc = minidom.parseString(xml_str)

# Gets urls
xmlUrls = xmldoc.getElementsByTagName('loc')

# Gets a list of urls
urls = [url.firstChild.nodeValue for url in xmlUrls]

print urls

for url in urls:
    htmlfile = urllib.URLopener()
    filename = url.replace(siteBase, "")
    if(filename):
        directoryname = os.path.dirname(filename)
        if not os.path.exists(directoryname):
            os.makedirs(directoryname)
        htmlfile.retrieve(url + "?_escaped_fragment_=", filename)
    else:
        htmlfile.retrieve(url + "?_escaped_fragment_=", "index.html")

        