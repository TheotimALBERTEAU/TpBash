#!/bin/bash

# check if the user has correctly entered 3 arguments
# if not, we show how to correctly execute the script and exit with error code 1
if ! [ "$#" -eq 3 ]; then
    echo "Usage: $0 <actix_log> <nginx_access_log> <nginx_error_log>"
    exit 1
fi

# Init variables with absolute path of Actix_log, nginx_access_log and nginx_error_log
ACTIX_LOG=$(realpath "$1")
NGINX_ACCESS_LOG=$(realpath "$2")
NGINX_ERROR_LOG=$(realpath "$3")

# Filtering most frequents "200 | GET" requests of ACTIX_LOG
# Extract the resource path (7th field), count unique occurrences, and sort numerically
MOST_SERVED=$(grep "200 | GET" $ACTIX_LOG | awk '{print $7}' | sort | uniq -c | sort -n)

echo "$MOST_SERVED" > tmp.txt

# Define extensions to be excluded
EXTENSIONS=(".png" ".css" ".ico" ".js")
# Loop through extensions to filter out common static files
for extension in "${EXTENSIONS[@]}"; do
    # Read the current list and filter out lines containing the current extension
    SUPPR=$(cat ./tmp.txt | grep -v "$extension")
    # Overwrite the temp file with the filtered list
    echo "$SUPPR" > ./tmp.txt
done
MOST_SERVED=$(cat ./tmp.txt)

# Keep only those that have been done more than 10 times
# Format the output as "RESOURCE_PATH : COUNT"
TMP=$(echo "$MOST_SERVED" | awk '$1 > 10 { print $2 " : " $1}')
# Add this requests on a txt files
echo "$TMP" > ./most_served.txt
rm -f ./tmp.txt

# Add IPs to a blacklist from NGINX_ACCESS_LOG
# IPs blacklisted are those who tried to access admin, debug, login or .git
# Define suspicious endpoints
ENDPOINTS=("admin" "debug" "login" ".git")
# Loop through the endpoints
for endpoint in ${ENDPOINTS[@]}; do
    # Filter log for endpoint access and extract the IP (1st field)
    IPS=$(cat $NGINX_ACCESS_LOG | grep "$endpoint" | awk '{print $1}')
    # Append the extracted IPs to the blacklist file
    echo "$IPS" >> ./ip_blacklist.txt
done

# Add more IPs who don't do GET, POST or HEAD
# Define standard accepted methods
METHODS=("GET" "POST" "HEAD")
# Loop through standard methods
for method in ${METHOD[@]}; do
    # Filter log for lines NOT containing the method (-v) and extract the IP
    IPS=$(cat $NGINX_ACCESS_LOG | grep -v "$method" | awk '{print $1}')
    # Add the second list to the txt file
    echo "$IPS" >> ./ip_blacklist.txt
done

# Sort numerically and remove duplicate IPs (uniq)
echo "$(cat ./ip_blacklist.txt | sort -n | uniq)" > ./ip_blacklist.txt

# Create DOWNTIME variable to detect where nginx isn't able to discuss with actix_web
# Search NGINX error log for the "111: Unknown error" connection failure
# We keep the date and hour of the error and add "DOWN"
DOWNTIME=$(grep "111: Unknown error" $NGINX_ERROR_LOG| awk '{print $1" "$2 " DOWN" }')

# Creating regex of Date and Time to detect them in logs
DATE_REGEX="([0-9]{4})-([0-9]{2})-([0-9]{2})"
TIME_REGEX="([0-9]{2}):([0-9]{2}):([0-9]{2})"

# Getting Captures groups of Date and Hours of ACTIX_LOG with regexs
# We keep the date and hour and add "UP"
UPTIME=$(cat "$ACTIX_LOG" | sed -nr "s+\[$DATE_REGEX.$TIME_REGEX.*+\1/\2/\3 \4:\5:\6 UP +p")

# Creating variable "TEMP" with DOWNTIME and UPTIME
# Sort TEMP by Dates and pipe to awk for state change detection
echo -e "$DOWNTIME\n$UPTIME" | sort | awk '{ 
    # Creating variable "OLD_STATUS" which represents the state of the previous line, initialized to DOWN
    OLD_STATUS="DOWN"
    
    # Verifying if actual state = "UP" and previous = "DOWN"
    if ($3 == "UP" && OLD_STATUS == "DOWN") {
        # Writing the date, hour, and "UP"
        print $1 " " $2 " UP"
        # put "OLD_STATUS" = "UP"
        OLD_STATUS=$3
    }
    
    # else if actual state = "DOWN" and previous = "UP"
    else if ($3 == "DOWN" && OLD_STATUS == "UP") {
        # Writing the date, hour, and "DOWN"
        print $1" " $2 " DOWN"
        # put "OLD_STATUS" = "DOWN"
        OLD_STATUS=$3
    }
}' # This block only outputs lines where the state changes.