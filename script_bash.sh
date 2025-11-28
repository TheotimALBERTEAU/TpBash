#!/bin/bash

if ! [ "$#" -eq 3 ]; then
	echo "Usage: $0 <actix_log> <nginx_access_log> <nginx_error_log>"
	exit 1
fi
ACTIX_LOG=$(realpath "$1")
NGINX_ACCESS_LOG=$(realpath "$2")
NGINX_ERROR_LOG=$(realpath "$3")

MOST_SERVED=$(grep "200 | GET" $ACTIX_LOG | awk '{print $7}' | sort | uniq -c | sort -n)	# ligne 10
# echo "$MOST_SERVED"

echo "$MOST_SERVED" > tmp.txt

EXTENSIONS=(".png" ".css" ".ico" ".js")
for extension in "${EXTENSIONS[@]}"; do
	SUPPR=$(cat ./tmp.txt | grep -v "$extension")
	echo "$SUPPR" > ./tmp.txt
done
MOST_SERVED=$(cat ./tmp.txt)									# ligne 20
# echo "$MOST_SERVED"

TMP=$(echo "$MOST_SERVED" | awk '$1 > 10 { print $2 " : " $1}')
echo "$TMP" > ./most_served.txt

ENDPOINTS=("admin" "debug" "login" ".git")
for endpoint in ${ENDPOINTS[@]}; do
	IPS=$(cat $NGINX_ACCESS_LOG | grep "$endpoint" | awk '{print $1}')
	echo "$IPS" >> ./ip_blacklist.txt
done												# ligne 30

METHODS=("GET" "POST" "HEAD")
for method in ${METHOD[@]}; do
	IPS=$(cat $NGINX_ACCESS_LOG | grep -v "$method" | awk '{print $1}')
	echo "$IPS" >> ./ip_blacklist.txt
done

echo "$(cat ./ip_blacklist.txt | sort -n | uniq)" > ./ip_blacklist.txt
												# ligne 40

DOWNTIME=$(grep "111: Unknown error" $NGINX_ERROR_LOG| awk '{print $1" "$2 " DOWN" }')
# echo "$DOWNTIME"

DATE_REGEX="([0-9]{4})-([0-9]{2})-([0-9]{2})"
TIME_REGEX="([0-9]{2}):([0-9]{2}):([0-9]{2})"

UPTIME=$(cat "$ACTIX_LOG" | sed -nr "s+\[$DATE_REGEX.$TIME_REGEX.*+\1/\2/\3 \4:\5:\6 UP +p")
# echo "$UPTIME"

echo -e "$DOWNTIME\n$UPTIME" | sort | awk '{ 
	OLD_STATUS="DOWN"
	if ($3 == "UP" && OLD_STATUS == "DOWN") {
		print $1 " " $2 " UP"
		OLD_STATUS=$3
		$3="UP"
	}
	
	else if ($3 == "DOWN" && OLD_STATUS == "UP") {
		print $1" " $2 " DOWN"
		OLD_STATUS=$3
		$3="DOWN"
	}
}'

