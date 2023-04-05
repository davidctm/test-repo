## Description

This shell script ([**alerts_to_bhom.sh**](alerts_to_bhom.sh)) sends Control-M alerts as events to BMC Helix Operations Management.

It parses the alert data coming from Control-M (**CTM**) into JSON format, and then sends it to Helix Operations Management (**BHOM**) using its event ingestion API. The JSON data is structured according to an event class which has to be previously created in BHOM.

## Pre-requisites

- **Configure your CTM environment to execute the script when an alert is raised**. 

  For more information, check the CTM documentation (Administrator Guide) > Alerts > "Sending Alerts and xAlerts to a script" (*please note that the provided script is intended for "Alerts", and not for "xAlerts"*). In order to enable sending alerts to a script, you must configure the following CTM/EM (Enterprise Manager) system parameters:

  - "**SendSNMP**" : should be set to "1" (run user-defined script) or "2" (run user-defined script and send SNMP).

  - "**SendAlarmToScript**" : should be set to the path of the provided script.

  - You can also tune when/how alerts are sent via additional CTM/EM system parameters such as "AlertOnAbend" (whether alerts are sent or not for jobs that end Not OK), "AlertOnAbendTableEntity" (same, but for Smart Folders), "SendAlertNotesSnmp" (whether to include or not the "notes" field in the alert data) and "AlertOnAbendUrgency" (alert severity used for jobs that end Not OK).

- **Create a new Event Class in BHOM**, using the definition from the [**bhom_ctm_event_class.json**](bhom_ctm_event_class.json) file.

  This event class called "**ControlMAlert**" includes all the required fields from the CTM alert data, plus one additional field to include a link to the job that generated the alert (when applicable). It also inherits all fields from its parent classes "IIMonitorEvent", "MonitorEvent" and the "Event" base class (check the BHOM documentation on [Event classification and formatting](https://docs.bmc.com/docs/helixoperationsmanagement/231/event-classification-and-formatting-1160751038.html) for more details).

  - To create the event class, contact your BHOM administrator or follow the documentation for [Event management endpoints in the REST API](https://docs.bmc.com/docs/helixoperationsmanagement/231/event-management-endpoints-in-the-rest-api-1160751462.html) (*remember to select your product version*), and use the "POST /events/classes" endpoint.

  - If the "IIMonitorEvent" event class is not available in your BHOM environment, you can update the json file to use the "MonitorEvent" class instead.
   
- **Import an Event Policy in BHOM**, using the [**bhom_ctm_event_policy.json**](bhom_ctm_event_policy.json) file.  **[OPTIONAL]**

  This event policy can be useful when alerts are also managed from CTM (e.g. when an operator uses the CTM user interface to close/handle an alert, modify the urgency or add a comment), and we want to automatically reflect those changes in BHOM. If the CTM alerts are only going to be managed from BHOM, there is no need to import this event policy.

  Depending on the case, remember to set the "**alert_updates**" variable in the script accordingly (Y/N). If set to "N", alert updates are not sent to BHOM (and the policy will never apply, even if imported). If set to "Y", it is recommended to use the policy to avoid creating duplicate events in BHOM every time the alert details are updated from CTM.

  The event policy will automatically 1) update existing events coming from CTM if they already exist in BHOM (which happens when the alert "Status", "Urgency" or "Comment" are updated in CTM), 2) map the status from the CTM alert to the BHOM event (e.g. close the event in BHOM if the alert is closed/handled in CTM), and 3) record the last alert comment into the BHOM notes history. Be aware that, if the event is closed in BHOM and the associated alert is updated from CTM, a new event (with the same "alertId") will be created.

  - To import the event policy from the BHOM console, go to the "Configuration" menu and select "Event Policies", click on the import button (located on the top right corner, right to the "Create" button) and attach the json file. Once imported, remember to select the policy name and click on the "Enable" button.

  - To import the event policy using the API, follow the BHOM documentation for [Event policy management endpoints in the REST API](https://docs.bmc.com/docs/helixoperationsmanagement/231/event-policy-management-endpoints-in-the-rest-api-1160751484.html), and use the "POST /event_policies" endpoint.

## Instructions

Before using the script, update the following variables:

- **ctm_host** : enter the hostname or IP address of the CTM/EM (Enterprise Manager) server.
- **ctm_port** : enter the port used to connect to the CTM/EM Web Server from the CTM Web Client (required for creating the job link).
- **ctm_name** : the default is "Control-M", but can be updated to e.g. use different names for multiple CTM environments (the value is assigned to the BHOM "location" field).
- **bhom_url** : enter the URL for the BHOM event data endpoint (e.g. "*https://\<BMC Helix Portal URL\>/events-service/api/v1.0/events*"), as described in the BHOM documentation for [Policy, event data, and metric data management endpoints in the REST API](https://docs.bmc.com/docs/helixoperationsmanagement/231/policy-event-data-and-metric-data-management-endpoints-in-the-rest-api-1160751457.html).
- **bhom_api_key** : enter a valid BHOM API key, which you can obtain from the BHOM console in the "Administration" menu, selecting "Repository" and clicking on "Copy API Key".
- **sev_V/U/R** : update the three variables to set the CTM to BHOM correspondence for the "severity" field according to your preferences (alerts coming from CTM can be Very urgent, Urgent or Regular; while BHOM event severity can be CRITICAL, MAJOR, MINOR, WARNING, INFO, OK or UNKNOWN).
- **alert_updates** : select whether you want to send or not updates of existing CTM alerts to BHOM (which happens when the alert "Status", "Urgency" or "Comment" are updated in CTM).

Do NOT modify the following variables:

- **bhom_class** : leave as is to use the previously imported "ControlMAlert" event class.
- **alert_fields** : leave as is to use the default field names for CTM alerts. If you have previously modified the JSON template for alerts in CTM, restore the default alert fields (as documented in the [Alerts Template reference](https://docs.bmc.com/docs/saas-api/alerts-template-reference-1144242602.html)).
- **bhom_slots** : leave as is to use the default event slots defined in the "ControlMAlert" class.

## Additional information

- The integration has been tested with:

   - Control-M 9.0.20.200
   - BMC Helix Operations Management 23.1

- You can create an **Event Group** in BHOM to show CTM alerts only:

   - In the BHOM console, go to the "Configuration" menu, select "Groups" and click on "Create".
   - In the "Group Information" section, enter the group name (e.g. "Control-M") and a description.
   - In the "Selection Query" section, go to "Event Selection Criteria" and add "Class Equals ControlMAlert".
   - Save the Group. Now you can go to the "Monitoring" menu, select "Groups" and click on the one you just created to view only events related to CTM.

- You can create a custom **Table View** in BHOM to show any CTM alert fields of your choice in the "Events" or "Groups" dashboards.

   - Follow the steps in the BHOM documentation for [Creating table views](https://docs.bmc.com/docs/helixoperationsmanagement/231/creating-table-views-1160750840.html).
   - For example, a custom table view can be used to show the "jobLink" field in the main event dashboard, which when clicked will open the CTM web interface with a monitoring viewpoint showing the problematic job and its neighborhood (when the alert is related to a job, and as long as the user has access to the CTM web interface).

- If you get the error "*curl: (48) An unknown option was passed in to libcurl*" when testing the script, uncomment the following line: 

  ``export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH"``

- The following table shows the correspondence between the CTM alert fields and the BHOM event slots (defined in the "ControlMAlert" class or inherited from its parent classes), plus additional information for fields which are modified in the script.

  For more information on the alert fields, please check the CTM documentation (Administrator Guide) > System Configuration > CTM/EM system parameters > "SendAlarmToScript" parameter.
  
  | CTM alert field | BHOM event slot | Comments |
  | - | - | - |
  | ``call_type`` | ``eventType`` | |
  | ``alert_id`` | ``alertId`` | |
  | ``data_center`` | ``ctmServer`` | |
  | ``memname`` | ``fileName`` | |
  | ``order_id`` | ``runId`` | |
  | ``severity`` | ``severity`` | The value is updated to map the CTM to BHOM correspondence. Not included in the "ControlMAlert" class, as it is inherited from the base class "Event". |
  | ``status`` | ``alertStatus`` | |
  | ``send_time`` | ``creation_time`` | The value is converted to the format expected by BHOM (Epoch time, in milliseconds). Not included in the "ControlMAlert" class, as it is inherited from the base class "Event". |
  | ``last_user`` | ``ctmUser`` | |
  | ``last_time`` | ``updateTime`` | The value is converted to the format expected by BHOM (Epoch time, in milliseconds). |
  | ``message`` | ``msg`` | Not included in the "ControlMAlert" class, as it is inherited from the base class "Event". |
  | ``run_as`` | ``runAs`` | |
  | ``sub_application`` | ``subApplication`` | |
  | ``application`` | ``application`` | |
  | ``job_name`` | ``jobName`` | |
  | ``host_id`` | ``source_hostname`` | When the alert "host_id" value is empty, it defaults to the "source_identifier" event slot. Not included in the "ControlMAlert" class, as it is inherited from the base class "Event". |
  | ``alert_type`` | ``alertType`` | |
  | ``closed_from_em`` | ``closedByControlM`` | |
  | ``ticket_number`` | ``ticketNumber`` | |
  | ``run_counter`` | ``runNo`` | |
  | ``notes`` | ``alertNotes`` | This event slot is only included when the script variable "alert_notes" is set to "Y". |
  | | ``jobLink`` | Additional slot included in the "ControlMAlert" class, which value is defined in the script using the "ctm_host" and "ctm_port" variables, and the "order_id", "data_center" and "job_name" alert fields.  |
  | | ``location`` | The value is defined in the script using the "ctm_name" variable. Not included in the "ControlMAlert" class, as it is inherited from the base class "Event".  |
  | | ``source_identifier`` | The value is defined in the script using the "ctm_host" variable. Not included in the "ControlMAlert" class, as it is inherited from the base class "Event". |

- The script could be modified to also include the ``external_id`` slot from the "IIMonitorEvent" class, in order to associate the event with a CI (configuration item).*

## Versions

| Date | Updated by | Changes |
| - | - | - |
| 2023-03-18 | David Fernández | First release |
