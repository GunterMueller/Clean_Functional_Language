implementation module Marshall

import StdArray, StdInt, StdMisc, StdString, StdClass, StdChar, CleanTricks

zeroString :: !Int -> *{#Char}
zeroString n 
	| n < 0 = abort "zeroString: n < 0"
	= createArray n '\0'

copyInt :: !Int -> *Int
copyInt x = code {
		pop_b	0
	}

instance marshall Int {#Char}
where
	marshall i = {toChar i, toChar (i >> 8), toChar (i >> 16), toChar (i >> 24)}

instance unmarshall Int {#Char}
where
	unmarshall x = copyInt (toInt x.[0] + toInt x.[1] << 8 + toInt x.[2] << 16 + toInt x.[3] << 24)

instance marshall String {#Char}
where
	marshall s = s +++. "\0"

instance unmarshall String {#Char}
where
	unmarshall x = "" +++. x % (0, strlen x 0)
	where
		strlen x i
			| i >= size x = i - 1
			| x.[i] == '\0' = i - 1
			= strlen x (i + 1)
