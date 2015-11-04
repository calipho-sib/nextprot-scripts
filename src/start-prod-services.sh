# --------------------------------
# START PROD SERVICES
# --------------------------------

# virtuoso
ssh npteam@godel "/usr/bin/virtuoso-t +configfile /var/lib/virtuoso/db/virtuoso.ini"

# solr
ssh npteam@jung "sh -c 'cd /work/devtools/solr-4.5.0/example; nohup java -Dnextprot.solr -Xmx1024m -jar -Djetty.port=44455 start.jar  > solr.log 2>&1  &'"

# postgres
ssh npdb@jung "pg_ctl -D /work/postgres/pg5432_nextprot/ start < /dev/null > pg-start.log 2>&1 &"

# api
ssh npteam@jung "/work/jetty/bin/jetty.sh start > /dev/null 2>&1 &"

