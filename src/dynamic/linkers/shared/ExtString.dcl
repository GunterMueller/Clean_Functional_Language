definition module ExtString;

from StdArray import class Array (select);
from StdMaybe import :: Maybe;

(CHAR) string i :== string.[i];
(BYTE) :: !String !Int -> Int;
u_char_array_slice :: !*{#Char} !Int !Int -> (!*{#Char},!*{#Char});
CharIndex  :: !String !Int !Char -> (!Bool,!Int);
CharIndexFunc  :: !String !Int (Char -> Bool) -> (!Bool,!Int); 
CharIndexBackwards :: !String !Int !Char -> (!Bool,!Int);


starts :: !String !String -> (!Bool,!Int);
starts_at :: !String !String !Int -> (!Bool,!Int);

ends :: !String !String -> Bool;
ExtractArguments :: !Char !Int !String [String] -> [String];
contains_substring :: !String !String -> (Maybe (!Int,!Int));
