implementation module UtilDiagnostics

import StdFile, StdString

// Unexpected :: .a {#Char} -> .a
Unexpected message defaultValue
	:== UnexpectedEvalBefore defaultValue (UnexpectedReport message)

UnexpectedEvalBefore :: !.a !.b -> .a
UnexpectedEvalBefore defaultValue _
	=	defaultValue

Don`tCareValue :== 0

UnexpectedReport :: !{#Char} -> Int
UnexpectedReport message
	=	UnexpectedEvalBefore Don`tCareValue (fwrites message stderr)

UnexpectedConstructor :: !{#Char} !{#Char} !.a -> .a
UnexpectedConstructor typeName string defaultValue
	=	Unexpected ( "fromString (" +++ typeName +++ "): unknown value (" +++ string +++ ")\n") defaultValue

