definition module EstherPostParser

import EstherParser, EstherBackend

:: PostParseException
	= InfixRightArgumentMissing
	| InfixLeftArgumentMissing
	| UnsolvableInfixOrder
	| NameNotFound !String

generic resolveNames e :: !e ![(String, GenConsPrio)] !*env -> (!e, ![(String, GenConsPrio)], !*env) | resolveFilename env
derive resolveNames NTstatements

desugar :: !NTsugar -> NTexpression

generic fixInfix e :: !e -> e
derive fixInfix NTstatements
