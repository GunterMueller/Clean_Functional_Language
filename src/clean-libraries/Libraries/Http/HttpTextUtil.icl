implementation module HttpTextUtil

import StdOverloaded, StdString, StdArray, StdChar, StdInt, StdBool, StdClass, StdList

//Trim functions
text_trim :: String -> String
text_trim s = text_ltrim (text_rtrim s)

text_ltrim :: String -> String
text_ltrim ""			= ""
text_ltrim s
	| isSpace s.[0] 	= if (size s == 1) "" (text_ltrim (s % (1, size s - 1)))
						= s

text_rtrim :: String -> String
text_rtrim ""					= ""
text_rtrim s
	| isSpace s.[size s - 1]	= if (size s == 1) "" (text_rtrim (s % (0, size s - 2)))
								= s
//Split and join
text_split :: String String -> [String]
text_split sep s
	# index = text_indexOf sep s
	| index == -1	= [s]
					= [s % (0, index - 1): text_split sep (s % (index + (size sep), size s))]

text_join :: String [String] -> String
text_join sep [] = ""
text_join sep [x:[]] = x
text_join sep [x:xs] = x +++ sep +++ (text_join sep xs)

//Searching and replacement
text_indexOf :: String String -> Int
text_indexOf "" haystack = -1
text_indexOf needle haystack = `text_indexOf needle haystack 0
where
	`text_indexOf needle haystack n
		| (n + size needle) > (size haystack)									= -1
		| and [needle.[i] == haystack.[n + i] \\ i <- [0..((size needle) - 1)]]	= n
																				= `text_indexOf needle haystack (n + 1)

text_replace :: (String,String) String -> String
text_replace (needle, replacement) s = s

text_replaceMany :: [(String,String)] String -> String
text_replaceMany replacements s = s

