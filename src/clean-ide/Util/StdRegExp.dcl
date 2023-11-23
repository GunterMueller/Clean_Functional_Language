definition module StdRegExp

import StdOverloaded, StdParsComb, StdMaybe

:: StrSlice 	:== (![Char],!(!Int,!Int))			// slice = found string with begin and end position 
													// which is relative to previous string found
:: StrResult	:== (!StrSlice,![StrSlice])		// found string + list of found substrings

:: Cparser a b	:== CParser Char a b

Beginmark		:== '\000'					// character reserved for marking begin of substring
Endmark			:== '\001'					// character reserved for marking end of substring

findParser		:: Parser Char (Parser Char StrSlice)
replaceOne_RE	:: [.Char] !.StrResult -> (.Maybe {#Char},Maybe .[Char]);
massageResult	:: ![Char] -> StrResult

// The string to search for is specified by using a Regular Expression:
//
// expr = beg exprs end	: search string indicated by regular expression
// beg	= ^ 			: search for an exprs at beginning of the string
//		| |				: search for exprs at the beginning of a word in the string
//		| 				: search for exprs starting anywhere
// end	= ^ 			: search for an exprs ending at the end of the string
//		| |				: search for exprs ending at a word
//		| 				: search for an exprs ending anywhere
// exprs= RE			: search for indicated expression
//		| RE expr		: search for sequence of indicated expressions
// exprs= {expr}		: search for expr and remember the corresponding matching expression as substring
// RE	= unit			: search for unit
//		| unit *		: search for zero or more occurrences of unit
//		| unit +		: search for one  or more occurrences of unit
// unit = c				: search for the indicated character
//		| (exprs)		: turn exprs into unit
// char	= c				: search for the specified character, if it is not used as special RE character
//		| #c			: search for the specified character, even if it is a special RE character: { } * + ( ) # . @ ~ [ ] 
//		| .				: search for any character
//		| @				: search for any letter
//		| ~				: search for any non-letter
//		| [alt]			: search for any of the specified characters
// alt	= c				: 	this character 
// 		| c1c2			: 	or any character in this sequence
//		| c1..c2		:	or any character in this interval

// The string by which the string found has to be replaced can be specified as follows:
//
// rexpr= exprs			: replace string found by exprs
//		| exprs rexpr	: replace string found by sequence of exprs
// exprs= c				: replace string found by the indicated character, if no control character
//		| #c			: replace string found by the specified character, even if it is a control character: & $ # 
//		| &				: replace string found by itself
//		| $n			: replace string found by the n-th substring indicated in the search expression, 0 <= n <= 9
//						: replaced by empty string if the n-th substring does not exist
