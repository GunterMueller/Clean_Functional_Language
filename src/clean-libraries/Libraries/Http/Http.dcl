definition module Http

// This library defines HTTP related types and functions
import StdString

:: HTTPRequest	= {	req_method		:: 	String			// The HTTP request method (eg. GET, POST, HEAD)
				,	req_path		::	String			// The requested location (eg. /foo)
				,	req_query		::	String			// The query part of a location (eg. ?foo=bar&baz=42)
				,	req_version		::	String			// The http version (eg. HTTP/1.0 or HTTP/1.1)
				,	req_protocol	::	HTTPProtocol	// Protocol info, http or https
				,	req_headers		::	[HTTPHeader]	// The headers sent with the request parsed into name/value pairs
				,	req_data		::	String			// The raw data of the request (without the headers)
				,	arg_get			::	[HTTPArgument]	// The arguments passed in the url 
				,	arg_post		::	[HTTPArgument]	// The arguments passed via the POST method
				,	arg_uploads		::	[HTTPUpload]	// Uploads that are sent via the POST method
				,	server_name		::	String			// Server host name or ip address
				,	server_port		::	Int				// Server port
				,	client_name		::	String			// Client host name or ip address
				}

:: HTTPProtocol	= HTTPProtoHTTP | HTTPProtoHTTPS		// The protocol used for a request

:: HTTPHeader 	:== (String, String)					// Headers are parsed into name/value pairs

:: HTTPArgument	:== (String, String)					// Arguments are parsed into name/value pairs as well

:: HTTPResponse	= {	rsp_headers		::	[HTTPHeader]	// Extra return headers that should be sent (eg. ("Content-Type","text/plain"))
				,	rsp_data		::	String			// The body of the response. (eg. html code or file data)
				}
			
:: HTTPUpload	= { upl_name		::	String			// The name of the file input in the form
				,	upl_filename	::	String			// The filename of the uploaded file
				,	upl_mimetype	::	String			// The MIME content type of the file
				,	upl_content		::	String			// The actual content of the file.
				}

//Construction functions which create empty records		
http_emptyRequest	:: HTTPRequest
http_emptyResponse	:: HTTPResponse
http_emptyUpload	:: HTTPUpload

//String instances
instance toString HTTPRequest
instance toString HTTPResponse

//Lookup a value in a list of arguments or headers. When the argument or header is not found
//return the default value.
//Eg: foo = http_getValue "foo" arguments 0 
http_getValue :: String [(String, String)] a -> a | fromString a