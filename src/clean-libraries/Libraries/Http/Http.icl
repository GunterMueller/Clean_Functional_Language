implementation module Http

import StdOverloaded, StdString, StdList

http_emptyRequest :: HTTPRequest
http_emptyRequest	= {	req_method		= ""
					,	req_path		= ""
					,	req_query		= ""
					,	req_version		= ""
					,	req_protocol	= HTTPProtoHTTP
					,	req_headers		= []
					,	req_data		= ""
					,	arg_get			= []
					,	arg_post		= []
					,	arg_uploads		= []	
					,	server_name		= ""
					,	server_port		= 0
					,	client_name		= ""
					}
					
http_emptyResponse :: HTTPResponse					
http_emptyResponse	= {	rsp_headers		= []
					,	rsp_data		= ""
					}

http_emptyUpload :: HTTPUpload
http_emptyUpload	= {	upl_name		= ""
					,	upl_filename	= ""
					,	upl_mimetype	= ""
					,	upl_content		= ""
					}

instance toString HTTPRequest
where
	toString {	req_method
			 ,	req_path
	 		 ,	req_query
			 ,	req_version
			 ,	req_protocol
			 ,	req_headers	
			 ,	req_data		
			 ,	arg_get
			 ,	arg_post
			 ,	arg_uploads	
			 ,	server_name
			 ,	server_port
			 ,	client_name
			 }
			 = "Method: " +++ req_method +++ "\n" +++
			   "Path: " +++ req_path +++ "\n" +++
			   "Query: " +++ req_query +++ "\n" +++
			   "Version: " +++ req_version +++ "\n" +++
			   "Protocol: " +++  toString req_protocol +++ "\n" +++
			   "---Begin headers---\n" +++
			   (foldr (+++) "" [ n +++ ": " +++ v +++ "\n" \\ (n,v) <- req_headers]) +++
			   "---End headers---\n" +++
			   "---Begin data---\n" +++
			   req_data +++
			   "--- End data---\n"
			   
instance toString HTTPResponse
where
	toString {	rsp_headers
			 ,	rsp_data
			 }
			 = "---Begin headers---\n" +++
			   (foldr (+++) "" [ n +++ ": " +++ v +++ "\n" \\ (n,v) <- rsp_headers]) +++
			   "---End headers---\n" +++
			   "---Begin data---\n" +++
			   rsp_data +++
			   "--- End data---\n"

	
instance toString HTTPProtocol
where
	toString HTTPProtoHTTP = "Http"
	toString HTTPProtoHTTPS = "Https"
		   



http_getValue :: String [(String, String)] a -> a | fromString a
http_getValue name values def = hd ([fromString v \\ (n,v) <- values | n == name] ++ [def])

