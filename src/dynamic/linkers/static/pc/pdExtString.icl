implementation module pdExtString;

import StdArray, StdInt, StdString;

(BYTE) string i :== toInt (string.[i]);

(IWORD) :: !String !Int -> Int;
(IWORD) string i = (string BYTE (i+1)<<8) bitor (string BYTE i);


(ILONG) :: !String !Int -> Int;
(ILONG) string i
	= (string BYTE (i+3)<<24) bitor (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);