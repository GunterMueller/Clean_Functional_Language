implementation module pdExtString;

import StdArray;
from StdString import String, +++, toString;
from StdInt import <<, bitor, +, toInt;

/*
(CHAR) string i :== string.[i];

(BYTE) string i :== toInt (string.[i]);

(WORD) :: !String !Int -> Int;
(WORD) string i = (string BYTE i<<8) bitor (string BYTE (i+1));

(LONG) string i
	= (string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3));
*/

(BYTE) string i :== toInt (string.[i]);

(WORD) :: !String !Int -> Int;
(WORD) string i = (string BYTE i<<8) bitor (string BYTE (i+1));

(LONG) :: !String !Int -> Int;
(LONG) string i
	= (string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3));

from StdInt import ==;
from StdMisc import abort;
read_long :: *{#Char} Int -> (!Int,!*{#Char});
read_long s i
	| size s == 0
		= abort ("read_long: leeg " +++ toString i);
		= read_long s i;
where {
		
read_long a=:{[i]=e0,[i1]=e1,[i2]=e2,[i3]=e3} i
	= ((toInt e0<<24) bitor (toInt e1<<16) bitor (toInt e2<<8) bitor (toInt e3),a);
{
	i1=i+1;
	i2=i+2;
	i3=i+3;
}
}

/*
(WORD) :: !String !Int -> Int;
(WORD) string i = (string BYTE i<<8) bitor (string BYTE (i+1));

(LONG) :: !String !Int -> Int;
(LONG) string i
	= (string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3));
	
read_long :: *{#Char} Int -> (!Int,!*{#Char});
read_long a=:{[i]=e0,[i1]=e1,[i2]=e2,[i3]=e3} i
	= ((toInt e0<<24) bitor (toInt e1<<16) bitor (toInt e2<<8) bitor (toInt e3),a);
{
	i1=i+1;
	i2=i+2;
	i3=i+3;
}
*/