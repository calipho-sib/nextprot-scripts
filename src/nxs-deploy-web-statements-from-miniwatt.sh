#!/bin/bash

# This script build and remotely copy a single page application in dev, build, alpha or pro machine

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

NX_PATH=/work/projects/web-statements

function stop-web-statements() {

    ws_pid=$(ps aux | grep play | cut -d" " -f4)
    if [ -x ${ws_pid} ];then
    echo "web statements was not running on ${host}"
    else
    echo "killing web statements process ${ws_pid} on ${host}"
    ssh npteam@${host} kill ${ws_pid}
    fi
}

function get-web-statements() {

    URL=http://miniwatt:8900/job/web-statements/lastSuccessfulBuild/artifact/web-statements.zip


    wget ${URL} -O ws.zip

    unzip ws.zip web-statements-new

    rm ws.zip
    echo "deploying ${NX_PATH}"


}

function rename-web-statements() {

    mv web-statements /tmp/web-statements-old-$(date +%s)
    mv web-statements-old web-statements
    
}


function start-web-statements() {


    echo "restarting web statements"

    nohup target/universal/stage/bin/web-statements &

}

cd $NX_PATH

get-web-statements
stop-web-statements
rename-web-statements
start-web-statements

cd -
