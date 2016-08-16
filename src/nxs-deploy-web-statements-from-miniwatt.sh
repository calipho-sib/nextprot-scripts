#!/bin/bash

# This script deploy web statements application from an artifact in miniwatt

# ex1: bash -x nxs-build-and-deploy-spa.sh /Users/fnikitin/Projects/nextprot-ui/ dev
# ex2: bash nxs-build-and-deploy-spa.sh /Users/fnikitin/Projects/nextprot-snorql/ dev

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

color='\e[1;34m'         # begin color
error_color='\e[1;32m'   # begin error color
warning_color='\e[1;33m' # begin warning color
_color='\e[0m'           # end Color


export PATH=/share/sib/apps/linux/64/jdk1.8.0_74/bin:$PATH
export JAVA_HOME=/share/sib/apps/linux/64/jdk1.8.0_74/
export JAVA_PATH=/share/sib/apps/linux/64/jdk1.8.0_74/bin

NX_PATH=/work/projects/

function stop-web-statements() {

    ws_pid=$(ps aux | grep play | grep stage |  cut -d" " -f4)
    if [ -x ${ws_pid} ];then
    echo "web statements was not running"
    else
    echo "killing web statements process ${ws_pid}"
    kill ${ws_pid}
    fi
}

function get-web-statements() {

    URL=http://miniwatt:8900/job/web-statements/lastSuccessfulBuild/artifact/web-statements.zip

    mkdir web-statements-new

    wget ${URL} -O ws.zip 

    unzip ws.zip -d web-statements-new

    rm ws.zip

    echo "extracting to web statements new"

}

function rename-web-statements() {

    mv web-statements /tmp/web-statements-old-$(date +%s)
    mv web-statements-new web-statements
    
}


function start-web-statements() {

    echo "restarting web statements"

    nohup web-statements/target/universal/stage/bin/web-statements &

}

cd $NX_PATH

get-web-statements
stop-web-statements
rename-web-statements
start-web-statements

cd -
