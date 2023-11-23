definition module StdError

:: Error a = Ok a
		   | Error String

isError :: !(Error a) -> Bool
fromOk	:: !(Error a) -> a
