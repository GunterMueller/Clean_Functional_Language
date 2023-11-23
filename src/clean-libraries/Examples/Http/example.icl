module example
import Http, HttpServer, HttpCGI, HttpUtil, HttpSubServer
import StdString, StdList, StdArray, StdInt
serverFunction = http_startServer
serverOptions = [HTTPServerOptPort 80, HTTPServerOptStaticFallback True, HTTPServerOptParseArguments True]
//serverFunction = http_startCGI
//serverOptions = [HTTPCGIOptParseArguments True]
//serverFunction = http_startSubServer
//serverOptions = [HTTPSubServerOptPort 80, HTTPSubServerOptStaticFallback True, HTTPSubServerOptParseArguments True]
Start :: *World -> *World
Start world = serverFunction serverOptions	[ ((==) "/debug",debug)
											, ((==) "/upload", upload)
											, ((==) "/show",show)
											, ( \_ -> True, http_staticResponse)
											] world
welcome :: HTTPRequest *World -> (HTTPResponse, *World)
welcome req world = ({http_emptyResponse & rsp_data = body},world)
where
	body = "<html><head><title>Clean HTTP Server Example</title></head><body>"
		+++	"<a href=\"/upload\">Upload example</a><br />"
		+++ "<a href=\"/debug\">Debug page</a><br />"
		+++ "</body></html>"
debug :: HTTPRequest *World -> (HTTPResponse, *World)
debug req world = ({http_emptyResponse & rsp_data = body req},world)
where
	body req = "<pre>"
		 +++ "Method: " +++ req.req_method +++ "\n"
		 +++ "Path: " +++ req.req_path +++ "\n"
		 +++ "Query: " +++ req.req_query +++ "\n"
		 +++ "Version: " +++ req.req_version +++ "\n"
		 +++ "Client Name: " +++ req.client_name +++ "\n"
		 +++ "Server Name: " +++ req.server_name +++ "\n"
		 +++ "Server Port: " +++ (toString req.server_port) +++ "\n"
		 +++ "Headers:\n" +++ (foldr (+++) "" ["\t" +++ n +++ ": " +++ v +++ "\n" \\ (n,v) <- req.req_headers]) +++ "\n" 
		 +++ "Get arguments:\n" +++ (foldr (+++) "" [n +++ " = " +++ v +++ "\n" \\ (n,v) <- req.arg_get]) +++ "\n"
		 +++ "Post arguments:\n" +++ (foldr (+++) "" [n +++ " = " +++ v +++ "\n" \\ (n,v) <- req.arg_post]) +++ "\n"
		 +++ "Uploads: \n" +++ (foldr (+++) "" [upl.upl_name +++ " = " +++ upl.upl_filename +++ " (" +++ upl.upl_mimetype +++ ")\n" \\ upl <- req.arg_uploads]) +++ "\n"
		 +++ "Data:\n" +++ req.req_data +++ "\n"
		 +++ "</pre>"
			  
upload :: HTTPRequest *World -> (HTTPResponse,*World)
upload req world = ({http_emptyResponse & rsp_data = body req},world)
where
	body req = 	"<html><body><h1>Upload example page</h1> "
		+++	"<form method=\"post\" action=\"/show\" enctype=\"multipart/form-data\" >"
		+++ "<input name=\"bar\" type=\"file\" />"
		+++ "<input type=\"submit\" value=\"Show\" />"
		+++ "</form>"
		+++ "</body><html>"
		
show :: HTTPRequest *World -> (HTTPResponse,*World)
show req world
	| length req.arg_uploads == 1
		# upload	= hd req.arg_uploads
		# mimetype	= upload.upl_mimetype
		# body		= upload.upl_content
		= ({http_emptyResponse & rsp_headers =
				[("Content-Type", mimetype)
				,("Content-Length",toString (size body))
				]
		   ,rsp_data = body
		   },world)
	| otherwise	= ({http_emptyResponse & rsp_data = "Something went wrong :("},world)
