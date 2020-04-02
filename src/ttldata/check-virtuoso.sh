sleep_time=300
response_timeout=10
recipients="pierre-andre.michel@sib.swiss,Kasun.Samarasinghe@sib.swiss"

QUERY="select count(*) where {?s ?p ?o}"
previous_state="UNKNOWN"

body=""                
body="$body \nHi,\n\nIn case of problem, use the following link"
body="$body \nhttp://miniwatt:8900/view/operations/job/restart-virtuoso"
body="$body \nto restart the service if you think it is necessary."
body="$body \n\nCheers,\n/work/ttldata/check-virtuoso.sh"

while :
do
	echo "$(date) - sending request..."
	curl -s -S -m$response_timeout -X POST -H "Accept:application/sparql-results+json" --data-urlencode query="$QUERY" http://localhost:8890/sparql > /dev/null
	result=$?
        if [ $result -eq 0 ]; then state="OK"; else state="ERROR"; fi 
	echo "$(date) - exit status: $result , state: $state"
	if [ $previous_state != $state ]; then
		subject="$(hostname) - virtuoso service status has changed from $previous_state to $state"
		echo "$(date) - sending mail to tell status is now $state"
		echo -e "$body" | mail -s "$subject" "$recipients"
	fi
	previous_state=$state
	sleep $sleep_time
done

