#!/bin/bash
#
# Sends Control-M (CTM) alerts as events to BMC Helix Operations Management (BHOM)
#
# Notes : - The alert data is sent in JSON format to BHOM using its event ingestion API
#         - The "ControlMAlert" event class must be previously imported in BHOM
#         - Update variables below according to your environment and preferences
#

# Set CTM parameters
ctm_host=ctm-em.acme.com
ctm_port=8443
ctm_name="Control-M"

# Set BHOM parameters
bhom_url=https://my-bmc-helix-portal.com/events-service/api/v1.0/events
bhom_api_key=mybh0m12-1234-1234-1234-ap1k3y123456
bhom_class="ControlMAlert"

# Set CTM to BHOM correspondence for the "severity" field
# CTM : V (Very urgent), U (Urgent), R (Regular) | BHOM : CRITICAL, MAJOR, MINOR, WARNING, INFO, OK, UNKNOWN
sev_V="CRITICAL"
sev_U="MAJOR"
sev_R="MINOR"

# Send updates of existing alerts? (Y/N)
alert_updates="Y"

# Declare arrays with the CTM alert fields and BHOM slot names - DO NOT MODIFY
alert_fields=("call_type" "alert_id" "data_center" "memname" "order_id" "severity" "status" "send_time" "last_user" "last_time" "message" "run_as" "sub_application" "application" "job_name" "host_id" "alert_type" "closed_from_em" "ticket_number" "run_counter" "notes")
bhom_slots=("eventType" "alertId" "ctmServer" "fileName" "runId" "severity" "alertStatus" "creation_time" "ctmUser" "updateTime" "msg" "runAs" "subApplication" "application" "jobName" "source_hostname" "alertType" "closedByControlM" "ticketNumber" "runNo" "alertNotes")

# If alert updates are not needed, exit if "call_type" = "U"
if [ $alert_updates == "N" ] ; then
   if [ $2 == "U" ] ; then exit 0 ; fi
fi

# Start JSON and add first BHOM slots
json_data="[ { \"class\" : \"$bhom_class\", \"location\" : \"$ctm_name\", \"source_identifier\" : \"$ctm_host\""

# Start creating url for the job link (using https, update when required)
job_link="https://$ctm_host:$ctm_port/ControlM/#Neighborhood:"

# Calculate number of alert fields to process
num_fields=${#alert_fields[@]}

# Skip last field ("notes") if not sent from CTM
echo $* | grep -oP "(?<=\b${alert_fields[-2]}\b: ).*?(?= \b${alert_fields[-1]}\b:)" > /dev/null 2>&1
if [ $? != 0 ] ; then num_fields=$((num_fields-1)) ; fi

# START PROCESSING ALERT DATA
for (( i=0; i<=$((num_fields-1)); i++ )) ; do
   field=${alert_fields[$i]}
   next_field=${alert_fields[$i+1]}
   if [ $i != $((num_fields-1)) ] ; then
      value=`echo $* | grep -oP "(?<=\b${field}\b: ).*?(?= \b${next_field}\b:)"`

      # Update some fields for BHOM compatibility
      case $field in
         data_center)
            # Save "data_center" value in a variable (for the job link)
            ctm_server=$value
         ;;
         order_id)
            # Add "order_id" and "data_center" to the job link
            job_link=$job_link"id="$value"&ctm="$ctm_server
         ;;
         severity)
            # Convert "severity" format from CTM to BHOM
            bhom_severity="sev_${value}"
            value=${!bhom_severity}
         ;;
         send_time | last_time)
            # Convert to Epoch time, in milisecs
            D="$value"
            value=`date -d "${D:0:8} ${D:8:2}:${D:10:2}:${D:12:2} +0000" "+%s%3N"`
         ;;
         job_name)
            # Add "job_name" to the final job link
            job_name="${value// /%20}"  # Replace spaces by "%20"
            job_link=$job_link"&name="$job_name"&direction=1&radius=3"  # Direction and radius can be customized
         ;;
         host_id)
            # Save "host_id" value in a variable (used to determine whether to include the job link)
            saved_host=$value
         ;;
      esac

   else
      # If last field, capture until EOL
      value=`echo $* | grep -oP "(?<=\b${field}\b: ).*"`
   fi
   slot_name=${bhom_slots[$i]}
   text=", \"$slot_name\" : \"$value\"" 
   json_data=$json_data$text
done

# Add link to the problematic job (only if "host_id" was not empty, meaning it is an alert related to a job)
if [ ! -z "$saved_host" ] ; then
   json_data=$json_data", \"jobLink\" : \"$job_link\""
fi

# Close JSON
json_data=$json_data" } ]"

# Set library path to solve curl error when Helix Control-M Agent is installed
# USE ONLY if you get the error: "curl: (48) An unknown option was passed in to libcurl"
# See https://bmcsites.force.com/casemgmt/sc_KnowledgeArticle?sfdcid=kA33n000000YHinCAG&type=Solution
# export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH"

# Send CTM alert data to BHOM
curl -X POST $bhom_url -H "Authorization: apiKey $bhom_api_key" -H 'Content-Type: application/json' -d "$json_data"

exit 0
