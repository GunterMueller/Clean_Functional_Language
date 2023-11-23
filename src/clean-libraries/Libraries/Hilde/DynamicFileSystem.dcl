definition module DynamicFileSystem

import StdDynamic

:: DynamicPath :== [String]
:: DynamicDirectory :== [DynamicFile]
:: DynamicFile = DynamicFile !String | DynamicDirectory !String

class DynamicFileSystem env
where
	dynamicExists :: !DynamicPath !*env -> (!Bool, !*env)
	dynamicRead :: !DynamicPath !*env -> (!Bool, !Dynamic, !*env)
	dynamicWrite :: !DynamicPath !Dynamic !*env -> (!Bool, !*env)
	dynamicRemove :: !DynamicPath !*env -> (!Bool, !*env)
	dynamicSetRoot :: !String !*env -> *env

instance DynamicFileSystem World
