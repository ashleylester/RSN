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
R packages: "RCurl","jsonlite","lu
