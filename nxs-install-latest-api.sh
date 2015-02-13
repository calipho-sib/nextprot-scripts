#!/bin/bash
#TODO should ask from version: If 0.1.0 should go to repos if 0.1.0-SNAPSHOT goes to snapshot-repos or LATEST-SNASPHOT and LATEST
#TODO should also ask if one wants to keep the cache
red='\e[0;31m'
NC='\e[0m' # No Color

echo -e "${red}stopping current jetty instance ...${NC}"
/work/jetty/bin/jetty.sh stop
echo -e "${red}removing cache and repository ${NC}"
rm -r /work/jetty/cache
rm -r /work/jetty/repository
echo -e "${red} removing log files ${NC}"
rm -r /work/jetty/logs/*
rm /work/jetty/webapps/nextprot-api-web.war
echo -e "${red} getting latest version of snapshot ${NC}"
wget -O /work/jetty/webapps/nextprot-api-web.war "http://miniwatt:8800/nexus/service/local/artifact/maven/redirect?r=nextprot-repo&g=org.nextprot&a=nextprot-api-web&v=LATEST&p=war"
echo -e "${red} restarting jetty server ${NC}"
/work/jetty/bin/jetty.sh start
