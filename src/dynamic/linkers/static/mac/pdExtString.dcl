definition module pdExtString;

import StdArray;
from StdString import String;
from StdInt import toInt;

/*
(WORD) :: !String !Int -> Int;
(LONG) :: !String !Int -> Int;
read_long :: *{#Char} Int -> (!Int,!*{#Char});
*/

//(BYTE) string i :== toInt (string.[i]);

(WORD) :: !String !Int -> Int;

(LONG) :: !String !Int -> Int;
read_long :: *{#Char} Int -> (!Int,!*{#Char});
