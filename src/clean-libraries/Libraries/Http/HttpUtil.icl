implementation module HttpUtil

import Http, HttpTextUtil
import StdArray, StdOverloaded, StdString, StdFile, StdBool, StdInt, StdArray, StdList
import StdTime

//General utility functions
http_urlencode :: !String -> String
http_urlencode s = mkString (urlEncode` (mkList s))
where
	urlEncode` :: ![Char] -> [Char]
	urlEncode` []						= []
	urlEncode` [x:xs] 
	| isAlphanum x						= [x  : urlEncode` xs]
	| otherwise							= urlEncodeChar x ++ urlEncode` xs
	where
		urlEncodeChar x 
		# (c1,c2)						= charToHex x
		= ['%', c1 ,c2]
	
		charToHex :: !Char -> (!Char, !Char)
		charToHex c						= (toChar (digitToHex (i >> 4)), toChar (digitToHex (i bitand 15)))
		where
		        i						= toInt c
		        digitToHex :: !Int -> Int
		        digitToHex d
		                | d <= 9		= d + toInt '0'
		                | otherwise		= d + toInt 'A' - 10

http_urldecode :: !String -> String
http_urldecode s						= mkString (urlDecode` (mkList s))
where
	urlDecode` :: ![Char] -> [Char]
	urlDecode` []						= []
	urlDecode` ['%',hex1,hex2:xs]		= [hexToChar(hex1, hex2):urlDecode` xs]
	where
		hexToChar :: !(!Char, !Char) -> Char
		hexToChar (a, b)				= toChar (hexToDigit (toInt a) << 4 + hexToDigit (toInt b))
		where
		        hexToDigit :: !Int -> Int
		        hexToDigit i
		                | i<=toInt '9'	= i - toInt '0'
		                | otherwise		= 10 + (i - toInt 'A')
	urlDecode` ['+':xs]				 	= [' ':urlDecode` xs]
	urlDecode` [x:xs]				 	= [x:urlDecode` xs]

mkString	:: ![Char] -> *String
mkString	listofchar				= {c \\ c <- listofchar }

mkList		:: !String -> [Char]
mkList		string					= [c \\ c <-: string ]



http_splitMultiPart :: !String !String -> [([HTTPHeader], String)]
http_splitMultiPart boundary body
	# startindex		= text_indexOf ("--" +++ boundary +++ "\r\n") body //Locate the first boundary
	| startindex == -1	= [] //Fail
	# endindex			= text_indexOf ("\r\n" +++ "--" +++ boundary +++ "--") body //Locate the final boundary
	| endindex == -1	= [] //Fail
	# body				= body % (startindex + (size boundary) + 4, endindex - 1)
	# parts				= text_split ("\r\n" +++ "--" +++ boundary +++ "\r\n") body
	= map parsePart parts
where
	parsePart :: String -> ([HTTPHeader], String)
	parsePart part 
		# index 		= text_indexOf "\r\n\r\n" part
		| index < 1 	= ([], part)
						= ([header \\ (header,error) <- map http_parseHeader (text_split "\r\n" (part % (0, index - 1))) | not error]
							, part % (index + 4, size part))

//Parsing of HTTP Request messages

//Add new data to a request
http_addRequestData :: !HTTPRequest !Bool !Bool !Bool !String -> (HTTPRequest, Bool, Bool, Bool, Bool)
http_addRequestData req requestline_done headers_done data_done data
	# req	= {req & req_data = req.req_data +++ data}	//Add the new data
	//Parsing of the request line
	| not requestline_done
		# index = text_indexOf "\r\n" req.req_data
		| index == -1	= (req,False,False,False,False)	//The first line is not complete yet
		| otherwise
			# (method,path,query,version,error) = http_parseRequestLine (req.req_data % (0, index - 1))
			| error	= (req,False,False,False,True)			//We failed to parse the request line
			# req = {req & req_method = method, req_path = path, req_query = query, req_version = version, req_data = req.req_data % (index + 2, size req.req_data) }
			= http_addRequestData req True False False ""	//We are done with the request line but still need to inspect the rest of the data
	//Parsing of headers
	| not headers_done
		# index = text_indexOf "\r\n" req.req_data
		| index == -1	= (req,True,False,False,False)		//We do not have a full line yet
		| index == 0										//We have an empty line, this means we have received all the headers
			# req = {req & req_data = req.req_data % (2, size req.req_data)}
			= http_addRequestData req True True False ""	//Headers are finished, continue with the data part
		| otherwise
			# (header,error) = http_parseHeader (req.req_data % (0, index - 1))
			| error = (req,True,False,False,True)			//We failed to parse the header
			# req = {req & req_headers = [header:req.req_headers], req_data = req.req_data % (index + 2, size req.req_data)}
			= http_addRequestData req True False False ""	//We continue to look for more headers
	//Addition of data
	| not data_done
		# datalength	= toInt (http_getValue "Content-Length" req.req_headers "0")
		| (size req.req_data) < datalength	= (req,True,True,False,False)	//We still need more data
											= (req,True,True,True,False)	//We have all data and are done
	//Data is added while we were already done
	= (req,True,True,True,False) 


http_parseRequestLine :: !String -> (!String,!String,!String,!String,!Bool)
http_parseRequestLine line
	# parts	= text_split " " line
	| length parts <> 3	= ("","","","",True)
	# [method,path,version:_]	= parts
	# qindex					= text_indexOf "?" path
	| qindex <> -1				= (method, path % (0, qindex - 1), path % (qindex + 1, size path), version, False)
								= (method, path, "", version, False)
								
http_parseHeader :: !String -> (!HTTPHeader, !Bool)
http_parseHeader header
	# index					= text_indexOf ":" header
	| index < 1				= (("",""), False)
	# name					= text_trim (header % (0, index - 1))
	# value					= text_trim (header % (index + 1, size header))
	= ((name,value), False)

http_parseArguments :: !HTTPRequest -> HTTPRequest
http_parseArguments req
	# req 							= {req & arg_get = http_parseGetArguments req}		//Parse get arguments
	| isPost req.req_headers		= {req & arg_post = http_parsePostArguments req}	//Parse post arguments
	| isMultiPart req.req_headers
		# (post,uploads)			= http_parseMultiPartPostArguments req
		= {req & arg_post = post, arg_uploads = uploads}								//Parse post arguments + uploads
	| otherwise						= req
where
	isPost headers = (http_getValue "Content-Type" headers "") == "application/x-www-form-urlencoded"
	isMultiPart headers = (http_getValue "Content-Type" headers "") % (0,18) == "multipart/form-data"
	
http_parseGetArguments :: !HTTPRequest -> [HTTPArgument]
http_parseGetArguments req
	| req.req_query == ""	= []
							= http_parseUrlEncodedArguments req.req_query

http_parsePostArguments :: !HTTPRequest -> [HTTPArgument]
http_parsePostArguments req	= http_parseUrlEncodedArguments req.req_data

http_parseUrlEncodedArguments :: !String -> [HTTPArgument]
http_parseUrlEncodedArguments s = [(http_urldecode name, http_urldecode (text_join "=" value)) \\ [name:value] <- map (text_split "=") (text_split "&" s)]

http_parseMultiPartPostArguments :: !HTTPRequest -> ([HTTPArgument],[HTTPUpload])
http_parseMultiPartPostArguments req
	# mimetype		= http_getValue "Content-Type" req.req_headers ""
	# index			= text_indexOf "boundary=" mimetype
	| index == -1	= ([],[])
	# boundary		= mimetype % (index + 9, size mimetype)
	# parts			= http_splitMultiPart boundary req.req_data
	= parseParts parts [] []
where
	parseParts [] arguments uploads	= (arguments, uploads)
	parseParts [(headers, body):xs] arguments uploads
		# disposition		= http_getValue "Content-Disposition" headers ""
		| disposition == ""	= parseParts xs arguments uploads
		# name				= getParam "name" disposition
		| name == ""		= parseParts xs arguments uploads
		# filename			= getParam "filename" disposition
		| filename == ""	= parseParts xs [(name,body):arguments] uploads
		| otherwise			= parseParts xs arguments [	{ http_emptyUpload
														& upl_name		= name
														, upl_filename	= filename
														, upl_mimetype	= http_getValue "Content-Type" headers ""
														, upl_content	= body
														}:uploads]
	getParam name header
		# index	= text_indexOf (name +++ "=") header
		| index == -1	= ""
		# header = header % (index + (size name) + 1, size header)
		# index	= text_indexOf ";" header
		| index == -1	= removequotes header
						= removequotes (header % (0, index - 1))

	removequotes s
		| size s < 2	= s
		# start	= if (s.[0] == '"') 1 0
		# end = if (s.[size s - 1] == '"') (size s - 2) (size s - 1)
		= s % (start, end) 

//Construction of HTTP Response messages
http_makeResponse :: !HTTPRequest [((String -> Bool),(HTTPRequest *World -> (HTTPResponse, *World)))] !Bool !*World -> (!HTTPResponse,!*World)
http_makeResponse request [] fallback world 										//None of the request handlers matched
	= if fallback
		(http_staticResponse request world)											//Use the static response handler
		(http_notfoundResponse request world)										//Raise an error
http_makeResponse request [(pred,handler):rest] fallback world
	| (pred request.req_path)		= handler request world							//Apply handler function
									= http_makeResponse request rest fallback world	//Search the rest of the list


http_encodeResponse :: !HTTPResponse !Bool !*World -> (!String, !*World)
http_encodeResponse {rsp_headers = headers, rsp_data = data} withreply world //When used directly the 'Status' header should be converted to 
	# (date,world)	= getCurrentDate world
	# (time,world)	= getCurrentTime world
	# reply = if withreply
			("HTTP/1.0 " +++ (http_getValue "Status" headers "200 OK") +++ "\r\n")
			("Status: " +++ (http_getValue "Status" headers "200 OK") +++ "\r\n")
	# reply = reply +++ ("Date: " +++ (http_getValue "Date" headers (now date time)) +++ "\r\n")								//Date
	# reply = reply +++ ("Server: " +++ (http_getValue "Server" headers "Clean HTTP 1.0 Server") +++ "\r\n")					//Server identifier	
	# reply = reply +++	("Content-Type: " +++ (http_getValue "Content-Type" headers "text/html") +++ "\r\n")					//Content type header
	# reply = reply +++	("Content-Length: " +++ (toString (size data)) +++ "\r\n")												//Content length header
	# reply = reply +++ ("Last-Modified: " +++ (http_getValue "Last-Modified" headers (now date time)) +++ "\r\n")				//Timestamp for caching
	# reply = reply +++	(foldr (+++) "" [(n +++ ": " +++ v +++ "\r\n") \\ (n,v) <- headers | not (skipHeader n)])				//Additional headers
	# reply = reply +++	("\r\n" +++ data)																						//Separator + data
	= (reply, world)
where
	//Do not add these headers two times
	skipHeader s = isMember s ["Status","Date","Server","Content-Type","Content-Lenght","Last-Modified"]

	//Format the current date/time
	now date time				=	(weekday date.dayNr) +++ ", " +++ (toString date.day) +++ " " +++ (month date.month) +++ " " +++ (toString date.year) +++ " "
								+++	(toString time.hours) +++ ":" +++ (toString time.minutes) +++ ":" +++ (toString time.seconds) +++ " GMT"
								
	weekday 1					= "Sun"
	weekday 2					= "Mon"
	weekday 3					= "Tue"
	weekday 4					= "Wed"
	weekday 5					= "Thu"
	weekday 6					= "Fri"
	weekday 7					= "Sat"
	
	month	1					= "Jan"
	month	2					= "Feb"
	month	3					= "Mar"
	month	4					= "Apr"
	month	5					= "May"
	month	6					= "Jun"
	month	7					= "Jul"
	month	8					= "Aug"
	month	9					= "Sep"
	month  10					= "Oct"
	month  11					= "Nov"
	month  12					= "Dec"
	

//Error responses
http_notfoundResponse :: !HTTPRequest !*World -> (!HTTPResponse, !*World)
http_notfoundResponse req world = ({rsp_headers = [("Status","404 Not Found")], rsp_data = "404 - Not found"},world)

http_forbiddenResponse :: !HTTPRequest !*World -> (!HTTPResponse, !*World)
http_forbiddenResponse req world = ({rsp_headers = [("Status","403 Forbidden")], rsp_data = "403 - Forbidden"},world)

//Static content
http_staticResponse :: !HTTPRequest !*World -> (!HTTPResponse, !*World)
http_staticResponse req world
	# filename				= req.req_path % (1, size req.req_path)		//Remove first slash
	# (type, world)			= http_staticFileMimeType filename world
	# (ok, content, world)	= http_staticFileContent filename world
	| not ok 				= http_notfoundResponse req world
							= ({rsp_headers = [("Status","200 OK"),
											   ("Content-Type", type),
											   ("Content-Length", toString (size content))]
							   ,rsp_data = content}, world)						
							
http_staticFileContent :: !String !*World -> (!Bool, !String, !*World)
http_staticFileContent filename world
	# (ok, file, world)	= fopen filename FReadData world
	| not ok			= (False, "Could not open file", world)
	# (ok, file)		= fseek file 0 FSeekEnd
	| not ok			= (False, "Seek to end of file does not succeed", world)
	# (pos, file)		= fposition file
	# (ok, file)		= fseek file (~pos) FSeekCur
	| not ok			= (False, "Seek to begin of file does not succeed", world)
	# (content, file)	= freads file pos
	# (ok, world)		= fclose file world
	= (True, content, world)

http_staticFileMimeType :: !String !*World -> (!String, !*World)
http_staticFileMimeType ".jpg" world = ("image/jpeg",world)
http_staticFileMimeType ".png" world = ("image/png",world)
http_staticFileMimeType ".gif" world = ("image/gif",world)
http_staticFileMimeType ".bmp" world = ("image/bmp",world)

http_staticFileMimeType ".htm" world = ("text/html",world)
http_staticFileMimeType ".html" world = ("text/html",world)
http_staticFileMimeType ".txt" world = ("text/plain",world)
http_staticFileMimeType ".css" world = ("text/css",world)
http_staticFileMimeType ".js" world = ("text/javascript",world)
http_staticFileMimeType "" world = ("application/octet-stream",world)
http_staticFileMimeType name world = http_staticFileMimeType (name % (1, size name)) world