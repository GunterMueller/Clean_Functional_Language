implementation module ExtString;

import StdArray, StdInt, StdString;
from StdClass import inc, dec;
from StdMisc import abort;
import StdMaybe;
from StdChar import class ==;
from StdBool import ||;
import StdList;

(CHAR) string i :== string.[i];

(BYTE) :: !String !Int -> Int;
(BYTE) string i = toInt (string.[i]);

u_char_array_slice :: !*{#Char} !Int !Int -> (!*{#Char},!*{#Char});
u_char_array_slice array begin_index end_index = code {
		push_a 0
	.d 1 2 ii
		jsr	sliceAC
	.o 1 0 
};

CharIndex  :: !String !Int !Char -> (!Bool,!Int); 
CharIndex s i char
	| i == (size s)
		= (False,size s);
		
		| i < (size s)
			| s.[i] == char
				= (True,i);
				= CharIndex s (inc i) char;
			= abort "CharIndex: index out of range";
			
CharIndexFunc  :: !String !Int (Char -> Bool) -> (!Bool,!Int); 
CharIndexFunc s i f
	| i < 0 || (i == (size s))
		= (False,size s);
		
		| i < (size s)
			| f s.[i]
				= (True,i);
				= CharIndexFunc s (inc i) f;
			= abort "CharIndexFunc: index out of range";

			
ends :: !String !String -> Bool;
	ends s postfix
		#! s_length
			= size s;
		#! postfix_length 
			= size postfix; 
		= (s % (s_length-postfix_length, s_length-1)) == postfix;
		
CharIndexBackwards :: !String !Int !Char -> (!Bool,!Int);
CharIndexBackwards s i char
	| i == (-1)
		= (False,size s);
		
		| s.[i] == char
			= (True,i);
			= CharIndexBackwards s (dec i) char;
			
starts :: !String !String -> (!Bool,!Int);
starts prefix s
	| l_s < l_prefix 
		= (False,10);
		
		// s has at least size of prefix
		| (s % (0, l_prefix - 1)) == prefix
			= (True,l_prefix);
			= (False,11);
where {
	l_prefix 
		= size prefix;
	l_s
		= size s;
}

starts_at :: !String !String !Int -> (!Bool,!Int);
starts_at prefix s index
	| l_s < l_prefix 
		= (False,10);
		
		// s has at least size of prefix
		| (s % (index, l_prefix - 1)) == prefix
			= (True,l_prefix);
			= (False,11);
where {
	l_prefix 
		= size prefix;
	l_s
		= (index + size s);
}

ExtractArguments :: !Char !Int !String [String] -> [String];
ExtractArguments sep i request args
	| size request == i
		= args;
		| (request.[i]) == sep
			= args;
		
			#! (found, index)
				= CharIndex request i sep;
			| found
				= ExtractArguments sep (inc index) request (args ++ [request % (i,index-1)]);
				= abort ("ExtractArguments: separator not found:" +++ request);

contains_substring :: !String !String -> (Maybe (!Int,!Int));
contains_substring sub s
	# s_s = size s;
	# s_sub = size sub;
	| s_sub == 0
		= Just (0,0);	// "" is a substring of any string
	| s_sub > s_s
		= Nothing;
		
	// sub is a non zero sized string AND smaller than s
	= contains_substring_ s_sub 0 s_s;
where {
	contains_substring_ :: !Int !Int !Int -> (Maybe (!Int,!Int));
	contains_substring_ s_sub i_s n_left
		| n_left < s_sub
			= Nothing;
			
		// n_left >= (size sub) i.e. s contains at least the characters required by the substring
		#! new_i_s
			= compare 0 i_s;
			with {
				// returns index of first unmatched character
				compare :: !Int !Int -> Int;
				compare i_sub i_s
					| i_sub == s_sub
						= i_s;
					| sub.[i_sub] <> s.[i_s]
						= i_s;
						= compare (inc i_sub) (inc i_s);
			}
		#! delta = new_i_s - i_s;
		| delta == 0
			// first char not equal, skip it
			= contains_substring_ s_sub (inc i_s) (dec n_left);
		| delta <> s_sub
			= contains_substring_ s_sub new_i_s (n_left - delta);
			
			= Just (i_s,dec new_i_s);
}