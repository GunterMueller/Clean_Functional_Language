definition module pdExtInt;

hex :: !Int -> String;
hex_int :: !Int -> String;

FromStringToIntU :: !*{#Char} !Int -> (!Int,!*{#Char});

FromIntToString :: !Int -> String;
FromStringToInt :: !String !Int -> Int;
print_string :: !String -> String;
hex_int_without_prefixed_zeroes :: !Int -> String;
WriteLong :: !*{#Char} !Int !Int -> *{#Char};
