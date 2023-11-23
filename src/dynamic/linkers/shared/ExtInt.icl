implementation module ExtInt;

import StdEnv;
from StdInt import class +, class *, bitand, class -;
from StdClass import class IncDec;
import StdEnv;

roundup_to_multiple s m :== (s + (dec m)) bitand (~m);

hexdigit :: !Int -> Char;
hexdigit i
	| i<10
		= toChar (toInt '0'+i);
		= toChar (toInt 'A'+i-10);

hex :: !Int -> String;
hex i
	#! i1 
		=(i bitand 0xf0) >> 4;
	#! i2
		=i bitand 0xf;
	= toString (hexdigit i1)+++toString (hexdigit i2);
	
hex_byte :: !Char -> String;
hex_byte i
	# s 
		= hex (toInt i);
	= "0x" +++ s;
	
	
hex_word :: !Int -> String;
hex_word w
	#! b0 
		= hex (w bitand 0x000000ff);
	#! b1
		= hex ((w bitand 0x0000ff00) >> 8);
	= b1 +++ b0;
	
	
hex_int :: !Int -> String;
hex_int i
	#! b0 
		= hex (i bitand 0x000000ff);
	#! b1
		= hex ((i bitand 0x0000ff00) >> 8);
	#! b2 
		= hex ((i bitand 0x00ff0000) >> 16);
	#! b3
		= hex ((i bitand 0xff000000) >> 24);
	= /*"0x" +++ */ b3 +++ b2 +++ b1 +++ b0;
	
	
// converts a string representation of a number of certian base to an (decimal) integer
from_base :: !String !Int -> Int;
from_base s base 
	#! s_s
		= size s;
	= from_base_loop (dec s_s) 1 0;
where {
	from_base_loop i m n
		| i < 0
			= n;
			= from_base_loop (dec i) (m * base) (n + (convert_digit s.[i] * m));
} // from_base 

// converts a string representation of a number of certian base to an (decimal) integer
from_base_i :: !String !Int !Int !Int -> Int;
from_base_i s base start_i length
	#! s_s
		= start_i + length
	= from_base_loop (dec s_s) 1 0
where {
	from_base_loop i m n
		| i < start_i
			= n;
			= from_base_loop (dec i) (m * base) (n + (convert_digit s.[i] * m));
} // from_base_i

convert_digit :: !Char -> Int;
convert_digit d 
	| isDigit d
		= (toInt d) - zero;
	| isAlpha d
		= (toInt (toLower d)) - a + 10
where {
	zero	=> toInt '0';
	a		=> toInt 'a';
} // convert_digit
	
between start middle end	:==  start <= middle && middle <= end;

