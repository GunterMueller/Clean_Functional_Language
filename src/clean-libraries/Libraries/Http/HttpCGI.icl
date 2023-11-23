implementation module HttpCGI

import Http, HttpUtil, HttpTextUtil
import StdFile, StdInt, StdBool, StdArray, ArgEnv

//Http headers for which should be checked if they exist in the environment
HTTP_CGI_HEADERS :==[ ("Content-Type","CONTENT_TYPE")
					, ("Content-Length","CONTENT_LENGTH")
					, ("Content-Encoding","HTTP_CONTENT_ENCODING")
					, ("Accept","HTTP_ACCEPT")
					, ("User-Agent","HTTP_USER_AGENT")
					, ("Host", "HTTP_HOST")
					, ("Authorization","HTTP_AUTHORIZATION")
					, ("If-Modified-Since","HTTP_IF_MODIFIED_SINCE")
					, ("Referer","HTTP_REFERER")
					]

//Starts the CGI Wrapper
http_startCGI :: [HTTPCGIOption] [((String -> Bool),(HTTPRequest *World-> (HTTPResponse,*World)))] *World -> *World
http_startCGI options handlers world
	# (console, world)		= stdio world
	# (ok,console)			= freopen console FReadData
	# (data, console)		= getData getDataLength console											//Read post data
	# request				= {http_emptyRequest &	req_method = getFromEnv "REQUEST_METHOD",		//Create the request
													req_path = getFromEnv "SCRIPT_NAME",
													req_query = getFromEnv "QUERY_STRING",
													req_version = getFromEnv "SERVER_PROTOCOL",
													req_headers = makeHeaders HTTP_CGI_HEADERS,
													req_data = data,
													server_name = getFromEnv "SERVER_NAME",
													server_port = toInt (getFromEnv "SERVER_PORT"),
													client_name = getClientName}
	
	# request				= if (getParseOption options) (http_parseArguments request) request
	# (response,world)		= http_makeResponse request handlers (getStaticOption options) world
	# (response,world)		= http_encodeResponse response False world
	# (ok,console)			= freopen console FWriteData
	# console				= fwrites response console
	# (ok,world)			= fclose console world
	= world

getDataLength :: Int
getDataLength
	# len		= getFromEnv "CONTENT_LENGTH"
	| len == ""	= 0
				= toInt len

getData :: !Int !*File -> (!String, !*File)
getData len file = freads file len

getFromEnv :: String -> String
getFromEnv name
	# value	= getEnvironmentVariable name
	= case value of 	EnvironmentVariableUndefined	= ""
						(EnvironmentVariable v)			= v
						
getClientName :: String
getClientName
	# name 			= getFromEnv "REMOTE_HOST"
	| name == ""	= getFromEnv "REMOTE_ADDR"
					= name
									
makeHeaders :: [(String,String)] -> [HTTPHeader]
makeHeaders [] = []
makeHeaders [(name,envname):xs]
	# value		= getEnvironmentVariable envname
	= case value of	EnvironmentVariableUndefined	= makeHeaders xs
					(EnvironmentVariable v)			= [(name,v): makeHeaders xs]

getStaticOption :: [HTTPCGIOption] -> Bool
getStaticOption [] = False
getStaticOption [x:xs] = case x of	(HTTPCGIOptStaticFallback b) = b
									_							 = getStaticOption xs

getParseOption	:: [HTTPCGIOption] -> Bool
getParseOption [] = True
getParseOption [x:xs] = case x of (HTTPCGIOptParseArguments b)	= b
								  _								= getParseOption xs
