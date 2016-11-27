# RSN
R interface for ServiceNow REST API

Use R to load ServiceNow table data into R data.frames.
If your company leverages R for your data needs and uses ServiceNow, this repository can become useful to quickly extract data from ServiceNow into R.
Currently there are 2 quick functions for ServiceNow Table API and Aggregate API:
 - Table API - obtain raw table data from ServiceNow - rsn_table_api(). More details here: http://wiki.servicenow.com/index.php?title=Table_API 
 - Aggregate API - use SN native function to aggregate data before returning it into R - rsn_aggr_api():  http://wiki.servicenow.com/index.php?title=Aggregate_API


# Requirements
ServiceNow access to REST API
R>=3.2.0
R packages: "RCurl","jsonlite","lubridate","utils","gsubfn"

# Example

This example uses ServiceNow demo instance:
https://demo021.service-now.com
login: itill
password: itil

## Table API:
source(file=url("https://raw.githubusercontent.com/kirillsavine/RSN/master/rsn.r"))
rsn_table_api(
	domain="https://demo021.service-now.com"													,	
	user_pwd="itil:itil"												,				
	table_name="incident"										,					
	sysparm_query="numberSTARTSWITHINC&state=2&assigned_to.name=Don Goodliffe"									,	
	sysparm_fields=c("number","active","assigned_to.name","business_duration","state")					,
	sysparm_limit=10
)
		
## Aggregate API:
source(file=url("https://raw.githubusercontent.com/kirillsavine/RSN/master/rsn.r"))

rsn_aggr_api(
	domain="https://demo021.service-now.com",	
	user_pwd="itil:itil",				
	table_name="incident",					
	sysparm_query="numberSTARTSWITHINC&state=2&approval=not requested",	
    sysparm_group_by=c("assigned_to.name","state"),
	sysparm_aggregate_fields=list("avg"="reassignment_count","sum"="business_duration")			
)		
		
		

# notes
1.	in table API when setting the list of columns to return (the sysparm_fields argument), be aware that certain field names are looked up in other tables, although it might not look like the case when you browse the  table in a browser using the user interface. Therefore, for situations like this you have to specify the column you need to return from the looked-up table. For example, at the time of writing this, the demo021 instance had a table named 'incident' with a column 'assigned_to', however when you just include 'assigned_to' in sysparm_fields list, the function will return a list of assigned_to 'assigned_to.link' and 'assigned_to.value'. None of those contain the name of the 'assigned_to' person. To return the name, include assigned_to.name' in sysparm_fields because the name of the 'assigned_to' person is located in the 'sys_user' tablewhich we can tell by looking at URL api call found in the 'assigned_to.link' column value.



