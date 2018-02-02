
rsn_check_packages=function(x){
	# load the required packages. Ensure the below packages are installed:
	reqd_packages=x
	installed_packages=rownames(installed.packages())
	lapply(reqd_packages, require, character.only = TRUE)	
	if(!all(reqd_packages %in% installed_packages)){stop(paste0("RSN ERROR: Please install the following packages: ",toString(reqd_packages[!(reqd_packages %in% installed_packages)])))}
}

rsn_check_inputs=function(r){
	# check if inputs are valid
	lapply(seq(1,length(r)),function(x){ifelse((names(r[x]) %in% c("x2","x3")),	ifelse(	length(eval(r[[x]]))==1,"",	stop(paste0("RSN ERROR: ",names(r[x])," must be length=1 character string"))),	""	)})
}

rsn_collect_args=function(x){
	# collect optional arguments	
	if(length(x)==0){opt_args_url=""}else{		
		opt_array=unlist(x)
		if(is.null(names(opt_array))){opt_args_url=paste(opt_array,collapse="&")}else{opt_args_url=paste0(paste(paste(names(opt_array),as.character(opt_array),sep="="),collapse="&"),"&")}
	}
	opt_args_url
}


rsn_get_data=function(ur,usr,pwd){
	xData=GET(ur);
	if(grepl("401",http_status(xData)$message)){
		print("unauthorized, trying to authenticate")
		xData_auth=GET(ur, authenticate(usr,pwd, type = "basic"))
		return(tryCatch({fromJSON(content(xData_auth, type="text/json"))$result},error=function(e){print("non-json")}))
	}else if(grepl("200",http_status(xData)$message)){
		print("success")
		return(tryCatch({fromJSON(content(xData, type="text/json"))$result},error=function(e){print("non-json")}))
	}else{
		print(paste0("got: ",http_status(xData)$message))
		return="NA"
	}		
}
		

rsn_table_api=function(
	domain="https://demo021.service-now.com",	# if this returns error, try this instance: "https://demo016.service-now.com"												,	
	user_pwd="itil:itils"												,				
	table_name="incident"										,					
	sysparm_query="numberSTARTSWITHINC&state=2"									,	
	sysparm_fields=c("number","active","assigned_to.name","business_duration","state")					,
	sysparm_limit=10,
	retry=TRUE,
	inital_check=FALSE,
	...	
){
	### ServiceNow Table API
	### COPYRIGHT HOLDER: Kirill Savine 
	### YEAR: 2016
	### original source: https://github.com/kirillsavine/RSN
	
	st=Sys.time()	
	options(scipen = 999)	
	
	# load the required packages. Ensure the below packages are installed:	
	rsn_check_packages(c("RCurl","jsonlite","lubridate","utils","gsubfn","httr"))
	
	# check if inputs are valid
	rsn_check_inputs(as.list(match.call())[c("domain","user_pwd","table_name","sysparm_query","stringr")])
	
	# collect optional arguments	
	opt_args_url=rsn_collect_args(list(...))
	

	#	opt_args_url="sysparm_display_value='true'"
	
	
	# authentication usr and pwd
	auth=strsplit(user_pwd,":")[[1]]
	
	
	# construct a single url string to feed into the REST API
	xml_url=paste0(
		paste0(domain,"/api/now/table/",table_name,"?"),
		paste0("sysparm_query=",URLencode(sysparm_query),"&"),
		ifelse(any(is.na(sysparm_fields)),"",paste0("sysparm_fields=",paste(sysparm_fields,collapse=","),"&"))		,
		paste0("sysparm_limit=",toString(sysparm_limit),"&"),
		opt_args_url,
		paste0("sysparm_view=")
	)
	
	if(inital_check){	
		xml_url_test=paste0(
			paste0(domain,"/api/now/table/",table_name,"?"),
			paste0("sysparm_query=",URLencode(sysparm_query),"&"),
			paste0("sysparm_fields=sys_id&")		,
			paste0("sysparm_limit=1&"),
			paste0("sysparm_view=")
		)		
		
		xData <- rsn_get_data(xml_url_test,auth[1],auth[2])		
		if(length(xData)==0){stop("RSN ERROR: inital check faild. Likely there is no data. ")}	
	}
	
  
  print(xml_url)
	
		
	
	
	# sometimes a SN API instance does not return result right away. 
	# Instead it returns a web-page saying "System initializing, please try later" 
	# the script will keep trying until a valid json string is returned.
	success=0;count=0
	while(success==0){
		
		res=rsn_get_data(xml_url,auth[1],auth[2])
		if(is.data.frame(res)){success=1}
		
		if(retry==TRUE){		
			count=count+1
			if(count==9){
				xml_url=paste0("https://",xml_url)			
			}else if(count>19){
				print(xml_url)
				stop("RSN ERROR: cannot extract data, check your inputs")		
			}			
		}else{
			print(xml_url)
			stop("RSN ERROR: cannot extract data, check your inputs")	
		}
	}

	# ensure that the output data.frame's colums each represent a flat array of objects, otherwise return a warning
	check_class=which(as.character(unlist(lapply(res,class)))=="data.frame")
	if(length(check_class)>0){
		warning(paste0("RSN WARNING: Please ensure you are requesting the right value for the following fields: ",toString(names(res)[check_class])))
	}else{
		if(!any(is.na(sysparm_fields))){
			if(length(names(res))!=sysparm_fields){warning("Not all fields returned")}else{
				names(res)=sysparm_fields
			}
		}
	}

	secs=as.numeric(difftime(Sys.time(),st,units="secs") )
	print(paste0(nrow(res)," x ",length(names(res))," done in: ",gsubfn(".", list("S" = " sec.", "M" = " min.", "H" = " hr.", "d" = " days"), toString(round(seconds_to_period(secs),0)))," (or ",round(secs,2)," sec.)"),quote=FALSE)
	res
}



rsn_aggr_api=function(
	domain="https://demo021.service-now.com",	# if this returns error, try this instance: "https://demo016.service-now.com"												,	
	user_pwd="itil:itil"												,				
	table_name="incident"										,					
	sysparm_query="numberSTARTSWITHINC&state=2&approval=not requested"									,	
    sysparm_group_by=c("assigned_to.name","state")			,
	sysparm_aggregate_fields=list("avg"="reassignment_count","sum"="business_duration")	,		
	retry=TRUE,	
	...	
){
	### ServiceNow Aggregate API
	### COPYRIGHT HOLDER: Kirill Savine 
	### YEAR: 2016
	
	st=Sys.time()	
	options(scipen = 999)	
	
	# load the required packages. Ensure the below packages are installed:	
	rsn_check_packages(c("RCurl","jsonlite","lubridate","utils","gsubfn","httr"))
	
	# check if inputs are valid
	rsn_check_inputs(as.list(match.call())[c("domain","user_pwd","table_name","sysparm_query")])
	
	# authentication usr and pwd
	auth=strsplit(user_pwd,":")[[1]]	

	# validate aggregate functions	
	if(is.null(names(sysparm_aggregate_fields))){
		stop("RSN ERROR: 'sysparm_aggregate_fields' argument must be a named array or a named list containing names of columns and names of aggregation function to be used, for example: sysparm_aggregate_fields=c('business_duration'='sum','duration'='avg')")
	}else{
		if(is.list(sysparm_aggregate_fields)){sysparm_aggregate_fields=unlist(sysparm_aggregate_fields)}
		lapply(seq(1,length(sysparm_aggregate_fields)),function(x){if(!(names(sysparm_aggregate_fields[x]) %in% c("sum","avg","min","max"))){stop(paste0("RSN ERROR: '",names(sysparm_aggregate_fields[x]), "' is not one the available aggregation functions. Please refer to wiki for details on SN Aggregate API: http://wiki.servicenow.com/index.php?title=Aggregate_API"))}})
	}
	
		
	# collect optional arguments	
	opt_args_url=rsn_collect_args(list(...))
	

	# construct a single url string to feed into the REST API
	xml_url=paste0(
		paste0(domain,"/api/now/stats/",table_name,"?"),
		paste0("sysparm_query=",URLencode(sysparm_query),"&"),
		paste0("sysparm_group_by=",paste(sysparm_group_by,collapse=","),"&")		,
		paste(paste0(paste0("sysparm_",names(sysparm_aggregate_fields),"_fields"),"=",as.character(sysparm_aggregate_fields)),collapse="&"),"&",
		opt_args_url,
		paste0("sysparm_view=")
	)
				
	print(xml_url);
	
	# sometimes a SN API instance does not return result right away. Instead it returns a web-page saying "System initializing, please try later"
	# the script will keep trying until a valid json string is returned.
	success=0;count=0
	while(success==0){
		res=rsn_get_data(xml_url,auth[1],auth[2])
		if(is.data.frame(res)){success=1}
		if(retry==TRUE){
			count=count+1		
			if(count>9){stop("RSN ERROR: cannot extract data, check your inputs")}
		}else{
			print(xml_url)
			stop("RSN ERROR: cannot extract data, check your inputs")
		}
	}
	
	# ensure category fields are separated
	cats=do.call("rbind", lapply(res$groupby_fields,function(x){as.data.frame(t(x))[2,]}))
	names(cats)=as.character(res$groupby_fields[[1]]$field)
	rownames(cats)=NULL
	res=cbind(res,cats)
	res=res[,names(res)[names(res)!="groupby_fields"]]
	
	# ensure value fields are separated
	stats_df=res$stats
	stats_names=lapply(stats_df,names)
	stats_names=unlist(lapply(seq(1,length(stats_names)),function(x){ifelse(is.null(stats_names[x][[1]]),names(stats_names[x]),stats_names[[x]])}))
	names(stats_df)=stats_names
	res=res[,names(res)[names(res)!="stats"]]
	res=cbind(stats_df,res)

	secs=as.numeric(difftime(Sys.time(),st,units="secs") )
	print(paste0(nrow(res)," x ",length(names(res))," done in: ",gsubfn(".", list("S" = " sec.", "M" = " min.", "H" = " hr.", "d" = " days"), toString(round(seconds_to_period(secs),0)))," (or ",round(secs,2)," sec.)"),quote=FALSE)
	res
}



