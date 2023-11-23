definition module HttpCGI

import Http

:: HTTPCGIOption 	= HTTPCGIOptStaticFallback Bool // If all request handlers fail, should the static file handler be tried (default False)
					| HTTPCGIOptParseArguments Bool	// Should the query and body of the request be parsed (default True)

http_startCGI :: [HTTPCGIOption] [((String -> Bool),(HTTPRequest *World-> (HTTPResponse,*World)))] *World -> *World