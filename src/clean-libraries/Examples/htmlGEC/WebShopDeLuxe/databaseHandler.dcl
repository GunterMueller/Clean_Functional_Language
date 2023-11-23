definition module databaseHandler

import StdFile
import StdMaybe

::	ItemData d
 = 	{	item	:: !Item
 	,	data	:: d
 	}
::	Item
 =	{	itemnr	:: !Int
 	,	instock	:: !Int
 	,	prize	:: !Int
 	}
::	SearchOptions o
 =	{	options	:: [(String,o)]
 	}
::	Headers d
 =	{	headers	:: [(Maybe Int,String)]
 	,	fields	:: d -> [String]
 	}
::	ExtendedInfo d
 =	{	extKey	:: d -> [[String]]
 	,	extVal	:: d -> [[String]]
 	}

class readDB          d :: !*env -> (![ItemData d],!*env) | FileSystem env
class searchDB option d :: !option !String ![ItemData d] -> (!Bool,![ItemData d])
class searchOptions option :: SearchOptions option
class headersDB       d :: Headers d
class extendedInfoDB  d :: ExtendedInfo d

showPrize :: Int -> String
