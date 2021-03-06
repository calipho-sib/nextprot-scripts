""" This client module prints html uses a selenium server
    The selenium standalone server chrome must be running in dockerdev  https://hub.docker.com/r/selenium/standalone-chrome/
    To run the container use the following command:
    ssh dteixeir@dockerdev.vital-it.ch
    docker run -p 32768:4444 -d --add-host www.nextprot.org:10.0.30.90 --add-host api.nextprot.org:10.0.30.90 --add-host bed-search.nextprot.org:10.2.0.104 --add-host dev-api.nextprot.org:10.2.0.104 selenium/standalone-chrome
"""

import sys
import time
from selenium import webdriver
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities

def getPageUsingSelenium(url):
    driver = webdriver.Remote(command_executor='http://dockerdev.vital-it.ch:32768/wd/hub', desired_capabilities=DesiredCapabilities.CHROME)
    driver.get(url)
    #driver.implicitly_wait(20) # seconds
    #time.sleep(2)
    #if("function" in url):
    #    driver.find_element_by_class_name("quality-label")
    print "getting with selenium " + url
    content =  driver.page_source
    driver.quit()
    return content

"""
    Use it like this: 
    > python selenium-client.py https://www-search.nextprot.org/
"""
if __name__ == "__main__":
    print(getPageUsingSelenium(sys.argv[1]))
