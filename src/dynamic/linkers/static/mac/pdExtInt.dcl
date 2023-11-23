definition module pdExtInt;

import
	StdEnv;
	
write_long :: Int Int *{#Char} -> *{#Char};
FromIntToString :: !Int -> !String;
FromStringToInt :: !String !Int -> !Int;