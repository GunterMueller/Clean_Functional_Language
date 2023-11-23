implementation module UtilPatch

import StdOverloaded,StdBool,StdClass,StdArray,StdMisc,StdInt,StdChar,StdString

// RWS ...
/* this function is compatible with patchbin in the Unix Clean
   distribution (1.3), variableName should be ' ' (space) padded
   to 10 characters, value should end with a null character
*/ 
PatchableValue :: {#Char} !{#Char} -> {#Char};
PatchableValue variableName patchableString
    | patchableString % (0,2) <> "#$@"
        || patchableString % (13,15) <> "%*&"
        || nullIndex >= sizePatchableString
        =   abort ("patchableValue: malformed patchable value " +++ patchableString +++ "\n");
    | patchableString % (3,12) <> variableName
        =   abort ("patchableValue: wrong variableName " +++ patchableString +++ "\n");
    // otherwise
        = patchableString % (16, nullIndex-1);
	where 
		sizePatchableString = size patchableString;
		nullIndex = findNullCharacter 0 sizePatchableString patchableString;
		findNullCharacter i n s
			| i >= n
				=	n;
			| s.[i] == '\0'
				=	i;
			// otherwise
				=  findNullCharacter (i+1) n s;
	
// ... RWS
