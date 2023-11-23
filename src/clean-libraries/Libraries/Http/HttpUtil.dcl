definition module HttpUtil

import Http

//General utility functions
http_urlencode :: !String -> String
http_urldecode :: !String -> String

http_splitMultiPart :: !String !String -> [([HTTPHeader], String)]

//Incremental construction of a request
http_addRequestData :: !HTTPRequest !Bool !Bool !Bool !String -> (HTTPRequest, Bool, Bool, Bool, Bool)


//Parsing of HTTP Request messages
http_parseRequestLine :: !String -> (!String, !String, !String, !String, !Bool)
http_parseHeader :: !String -> (!HTTPHeader, !Bool)

http_parseArguments :: !HTTPRequest -> HTTPRequest
http_parseGetArguments :: !HTTPRequest -> [HTTPArgument]
http_parsePostArguments :: !HTTPRequest -> [HTTPArgument]
http_parseUrlEncodedArguments :: !String -> [HTTPArgument]
http_parseMultiPartPostArguments :: !HTTPRequest -> ([HTTPArgument],[HTTPUpload]) 

//Construction of HTTP Response messages
http_makeResponse :: !HTTPRequest [((String -> Bool),(HTTPRequest *World -> (HTTPResponse, *World)))] !Bool !*World -> (!HTTPResponse,!*World)
http_encodeResponse :: !HTTPResponse !Bool !*World -> (!String,!*World)

//Error responses
http_notfoundResponse :: !HTTPRequest !*World -> (!HTTPResponse, !*World)
http_forbiddenResponse :: !HTTPRequest !*World -> (!HTTPResponse, !*World)

//Static content
http_staticResponse :: !HTTPRequest !*World -> (!HTTPResponse, !*World)
http_staticFileContent :: !String !*World -> (!Bool, !String, !*World)
http_staticFileMimeType :: !String !*World -> (!String, !*World)

