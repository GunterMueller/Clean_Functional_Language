definition module EstherBackend

import EstherParser, StdMaybe

:: ComposeException 
	= ApplyTypeError !(Dynamic) !(Dynamic)
	| UnboundVariable !String
	| InstanceNotFound !String !Dynamic
	| InvalidInstance !String !Dynamic !Dynamic
	| UnsolvableOverloading
	| NotSupported` !String

:: EstherRuntimeException
	= PatternMismatch
	| UndefEvaluated
	| AbortEvaluated !String

:: Core
	= CoreApply !Core !Core
	| CoreCode !Dynamic 
	| CoreVariable !String
//	| CoreEta !Core

class resolveFilename env :: !String !*env -> (!Maybe (Dynamic, GenConsPrio), !*env)

generateCode :: !Core !*env -> (!Dynamic, !*env) | resolveFilename env

overloaded :: !String !Dynamic -> Dynamic
overloaded2 :: !String !String !Dynamic -> Dynamic
overloaded3 :: !String !String !String !Dynamic -> Dynamic

abstract :: !String !Core -> Core
abstract_ :: !Core -> Core

toStringDynamic :: !Dynamic -> ([String], String)

