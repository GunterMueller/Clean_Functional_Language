implementation module ExtSystem;

from StdReal import entier; // RWS marker

import
	StdEnv;
	
ParseCommandLine :: !String -> {#{#Char}}
ParseCommandLine s
	# command_line
		= parse_command_line s 0 [];
	= { s \\ s <- command_line };
where
	parse_command_line :: String Int [{#Char}] -> ![{#Char}]
	parse_command_line s i l
		| i == (size s) 
			= l
			| not (s.[i] == '\"')
				// not found, no " then search for space
				#! (_,index)
					= CharIndex s i ' '
				= parse_command_line s (skip_spaces s index) (l ++ [s % (i,index-1)])
	
				#! (found,index)
					= CharIndex s (i+1) '\"'
				| found
					= parse_command_line s (skip_spaces s (index+1)) (l ++ [s % (i+1,index-1)])
					
					= abort "parse_command_line: an error"
		
	skip_spaces :: String Int -> Int
	skip_spaces s i
		| (size s) == i
			= size s
			| s.[i] == ' '
				= skip_spaces s (inc i)		
				= i
