implementation module StdError

import StdString, StdMisc

:: Error a = Ok a
		   | Error String
 
isError :: !(Error a) -> Bool
isError (Error _) = True
isError _		  = False

fromOk :: !(Error a) -> a
fromOk (Ok a) = a
fromOk _	  = abort "fromOk (StdError.icl): the value was an error value"

