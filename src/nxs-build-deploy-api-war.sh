#!/usr/bin/env bash

function echoUsage() {
    echo "Deploy nextprot-api war in a given dev machine."
    echo "usage: $(basename $0) [-hd] <path> <host>"
    echo "Params:"
    echo " <path> nextprot-api git repository path"
    echo " <host> machine to install nexprot-api on (crick, kant or uat-web2)"
    echo "Options:"
    echo " -h print usage"
    echo " -d delete jetty cache/"
}

DELETE_CACHE=

while getopts 'hd:' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
        ;;
    d) DELETE_CACHE=1
        ;;
    ?) echoUsage
        exit 1
        ;;
    esac
done

shift $(($OPTIND - 1))

NX_API_REPO=$1
HOST=$2

checkProjectId () {

    path=$1

    # check it is a maven project
    if [ ! -f "pom.xml" ]; then

        echo "FAILS: pom.xml was not found (not a maven project)"
        exit 2
    fi

    # get artifact id (http://stackoverflow.com/questions/3545292/how-to-get-maven-project-version-to-the-bash-command-line)
    artifactId=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.artifactId -f ${path}/pom.xml | grep -Ev '(^\[|Download\w+:)'`

    if [ ${artifactId} != "nextprot-api-master" ]; then

        echo "FAILS: ${artifactId} is not a valid project, can only build and deploy nextprot-api web app"
        echoUsage
        exit 3
    fi
}

function stop_jetty() {
  host=$1
  if ! ssh npteam@${host} test -f /work/jetty/jetty.pid; then
      echo -e "${warning_color}Jetty was not running at $host "
      return 0
  fi
  echo -e "Stopping jetty at ${host}..."
  ssh npteam@${host} "/work/jetty/bin/jetty.sh stop"
  echo -e "Jetty has been correctly stopped at ${host} "
}

function start_jetty() {
  host=$1
  echo -e "Starting jetty at ${host}..."
  ssh npteam@${host} "source .bash_profile; /work/jetty/bin/jetty.sh start"
  echo -e "Jetty has been correctly started at ${host} "
}

function clean_jetty_host() {

    host=$1

    if [ ${DELETE_CACHE} ]; then
        echo -e "removing cache: delete /work/jetty/cache"
        ssh npteam@${HOST} "rm -r /work/jetty/cache"
    else
        echo -e "keeping cache: /work/jetty/cache"
    fi
}

function deploy_war_to_host() {

    source_path=$1
    host=$2

    echo deploy ${source_path} to npteam@${host}:/work/jetty/webapps/nextprot-api-web.war
    scp ${source_path} npteam@${host}:/work/jetty/webapps/nextprot-api-web.war
}

function build_web_app() {

    mvn clean package install -DskipTests -f ${NX_API_REPO}/pom.xml
}

checkProjectId ${NX_API_REPO}

build_web_app

stop_jetty ${HOST}

clean_jetty_host ${HOST}

deploy_war_to_host ${NX_API_REPO}/web/target/nextprot-api-web.war ${HOST}

start_jetty ${HOST}
