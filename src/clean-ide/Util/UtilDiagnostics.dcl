definition module UtilDiagnostics

// Unexpected :: {#Char} .a -> .a
Unexpected message defaultValue
	:== UnexpectedEvalBefore defaultValue (UnexpectedReport message)

UnexpectedEvalBefore	:: !.a !.b -> .a
UnexpectedReport		:: !{#Char} -> Int
UnexpectedConstructor	:: !{#Char} !{#Char} !.a -> .a
