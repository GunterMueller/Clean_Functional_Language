implementation module htmlTrivial

import StdMaybe, StdGeneric, StdArray, StdClass, StdInt, StdList, StdString

derive bimap Maybe, (,)

// converting strings to lists and backwards

mkString	:: ![Char] -> *String
mkString	listofchar				= {c \\ c <- listofchar }

mkList		:: !String -> [Char]
mkList		string					= [c \\ c <-: string ]

FindSubstr	:: .[a] !.[a] -> (!Bool,!Int) | == a
FindSubstr substr list				= FindSubstr` list 0 
where
	lsubstr							= length substr
	
	FindSubstr` list=:[] _			= (False,0)
	FindSubstr` list=:[x:xs] index
	| substr == take lsubstr list	= (True,index)
	| otherwise						= FindSubstr` xs (index + 1)


stl			:: !u:[.a] -> v:[.a], [u <= v]
stl []					= []
stl [x:xs]				= xs 

//	Useful string concatenation function
(<+++) infixl :: !String !a -> String | toString a
(<+++) str x = str +++ toString x

(+++>) infixr :: !a !String -> String | toString a
(+++>) x str = toString x +++ str

(??) infixl 9 :: ![a] !a -> Int | == a
(??) [a:as] b
	| a==b		= 0
	| otherwise	= 1 + as??b
(??) [] _
	= -1

const2 :: .a !.b -> .b
const2 _ x = x
