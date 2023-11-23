implementation module pdExtInt;

// winos
import StdEnv;

FromIntToString :: !Int -> String;
FromIntToString v
	= { (toChar v), (toChar (v>>8)), (toChar (v>>16)), (toChar (v>>24)) };
	
FromStringToInt :: !String !Int -> Int;
FromStringToInt array i
	= (toInt v0)+(toInt v1<<8)+(toInt v2<<16)+(toInt v3<<24);
where {
	v0
		= array.[i];
	v1
		= array.[i+1];
	v2 
		= array.[i+2];
	v3  
		= array.[i+3];
}

WriteLong :: !*{#Char} !Int !Int -> *{#Char};
WriteLong array i v
	= { array & [i] 	= (toChar v)		,	[i+1] = (toChar (v>>8)),
				[i+2]	= (toChar (v>>16))  ,	[i+3] = (toChar (v>>24))};

FromStringToIntU :: !*{#Char} !Int -> (!Int,!*{#Char});
FromStringToIntU array i
	#! (v0,array)
		= array![i];
	#! (v1,array)
		= array![i+1];
	#! (v2,array)
		= array![i+2];
	#! (v3,array)
		= array![i+3];
	#! i
		= (toInt v0)+(toInt v1<<8)+(toInt v2<<16)+(toInt v3<<24);
	= (i,array);
		
print_string :: !String -> String;
print_string s
	= ps2 0 (size s) "";
where {
	ps2 i limit d
		| i == limit 
			= d;
		
		#! v
			= FromStringToInt s i;
		#! w
			= hex_word i +++ ": " +++ hex_int v +++ ", ";
		= ps2 (i + 4) limit (d +++ w);	
}

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
	= b3 +++ b2 +++ b1 +++ b0;
	
hex_int_without_prefixed_zeroes :: !Int -> String;
hex_int_without_prefixed_zeroes i
	#! b0 
		= hex  (i bitand 0x000000ff);
	#! b1
		= hex  ((i bitand 0x0000ff00) >> 8);
	#! b2 
		= hex  ((i bitand 0x00ff0000) >> 16);
	#! b3
		= hex  ((i bitand 0xff000000) >> 24);
	#! s
		= b3 +++ b2 +++ b1 +++ b0;
	#! l
		= [ c \\ c <-: s ];
	# s
		= { c \\ c <- (strip_leading_zeroes l)};
	= if ((size s) == 0) "0" s;
		
where {
	strip_leading_zeroes []
		= [];
	strip_leading_zeroes ['0':xs]
		= strip_leading_zeroes xs;
	strip_leading_zeroes l
		= l;
}		

		