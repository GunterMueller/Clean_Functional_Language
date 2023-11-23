implementation module SubServerUtil
import StdEnv, StdLib, StdMaybe

/****************************************************************************
	Set of handy http related functions for the end user
****************************************************************************/

/*1e method, 2e location, 3e get data, 4e http version*/
GetFirstLine :: String -> (String,String,[String],String)
GetFirstLine firstLine
| length data <>3 = ("","",[],"")
| otherwise
	# location=data!!1
	# location = case location % (0,6) == "http://" of
		True=location % ((FindIndexInString (location % (7,size location)) "/" 0)+7,size location)
		_=location
	# location = case location == "" of
		True="/"
		_=URLDecode (fromString location)
	# nr = FindIndexInString location "?" 0
	| nr==(-1) = (data!!0,location,[],data!!2)
	= (data!!0,location % (0,nr-1),(SplitToStringArray (location %(nr+1,size (location)))) "&",data!!2)
where
	data = SplitToStringArray firstLine " "

HexLineToInt :: [Char] -> Int
HexLineToInt [a] = toInt(hexToChar a)
HexLineToInt [a,b] = (16 * toInt(hexToChar a)) + HexLineToInt [b]
HexLineToInt [a,b,c] = (256 * toInt(hexToChar a)) + HexLineToInt [b,c]
HexLineToInt [a,b,c,d] = (4096 * toInt(hexToChar a)) + HexLineToInt [b,c,d]
HexLineToInt _ = 0

URLDecode :: [Char] -> String//URLDecode-functie (zet %?? om naar juiste characters, %20 naar spatie bijv.)
URLDecode [] = ""
URLDecode ['%',a,b:tail] = toString ((toChar (16 * toInt (hexToChar a))) + hexToChar b)+++ URLDecode tail
URLDecode ['+':tail]= " "+++URLDecode tail
URLDecode [head:tail] = toString head +++URLDecode tail

hexToChar :: Char -> Char//functie is onderdeel van removeEscapes
hexToChar a
	| a >= '0' && a <= '9' = a - '0'
	| a >= 'A' && a <= 'F' = a - 'A' + (toChar 10)
	| a >= 'a' && a <= 'f' = a - 'a' + (toChar 10)
	= toChar 0

GetHeaderData :: [String] *String -> String//ook een hulpfunctie, tevens interne functie
GetHeaderData [as:bs] header
	#string1 = ToUniqueString(as % (0,(size header)-1))
	# string = StringToUppercase 0 string1
	# header = StringToUppercase 0 header
	| string==header = TrimString (as % ((size header),size as))
	= GetHeaderData bs header
GetHeaderData _ _ = ""

getContentTypeGF :: String -> String//functie die Content-Type genereert aan de hand van de extensie
getContentTypeGF ".jpg" = "image/jpeg"
getContentTypeGF ".gif" = "image/gif"
getContentTypeGF ".bmp" = "image/x-ms-bmp"
getContentTypeGF ".htm" = "text/html"
getContentTypeGF ".txt" = "text/plain"
getContentTypeGF "" = "application/octet-stream\r\nContent-Disposition: attachment;"//forceer download (bij video's bijv., zodat deze niet meteen worden afgespeeld)
getContentTypeGF str = getContentTypeGF (str % (1,size str))

CheckLocation ::String -> String
CheckLocation location
# array = SplitToStringArray (location % (1,size location)) "/"
| hd array ==".." = ""
# array = FlattenLocation array
| hd array ==".." = ""
| (hd array) % (0,0)=="%" = ""
# countBack = CountStringInArray array ".." 0
# bool = StringArrayCount array - countBack > countBack
| not bool = ""
= StringArrayToString array "\\"

FlattenLocation :: [String] -> [String]
FlattenLocation array
# array1 = FlattenLocation1 array
| array == array1 = array1
= FlattenLocation array1
where
	FlattenLocation1 [as,bs:cs]
	| as==".." && bs==".." && cs<>[]= [as]++ FlattenLocation1 ([bs]++cs)
	| as==".." && bs<>".."&& cs<>[]= FlattenLocation1 cs
	| bs==".." && cs<>[] = FlattenLocation1 cs
	| cs<>[] = [as]++ FlattenLocation1 ([bs]++cs)
	FlattenLocation1 [as,bs] = [as,bs]
	FlattenLocation1 [as] = [as]

/****************************************************************************
	String handling utility functions
****************************************************************************/

CountStringInString :: String String -> Int
CountStringInString string token
# index = FindIndexInString string token 0
| index > -1 = 1 + CountStringInString (string % (index+size token,size string)) token
= 0

StringToUppercase :: Int *String  ->*String
StringToUppercase nr string
| nr < 0 = string
| size string > nr
	#! char = CharToUppercase string.[nr]
	# string = update string nr char
	= StringToUppercase (nr+1) string
| otherwise = string

CharToUppercase :: Char -> Char
CharToUppercase char
| int > 96 && int < 123 = toChar (int bitand (0xdf))
| otherwise = char
where 
	int = toInt char

TrimString::String -> String
TrimString string
| (FindIndexInString string "\t" 0)==0 = TrimString (string % (1,size string))
| string %(size string-1,size string)=="\t"= TrimString (string % (0,size string-2))
| (FindIndexInString string " " 0)==0 = TrimString (string % (1,size string))
| string %(size string-1,size string)==" "= TrimString (string % (0,size string-2))
| otherwise = string

SplitToStringArray :: String String -> [String]
SplitToStringArray string token
| string==""=[]
| nr <> -1 = [string % (0,(nr-1))]++SplitToStringArray (string % ((nr+(size token)),size string)) token
| otherwise = [string]
where
	nr = FindIndexInString string token 0

FindIndexInString ::String String Int -> Int
FindIndexInString string token nr
| nr>size string  || token==""= -1
| string %(nr,nr+(size token)-1)==token = nr
| ((size string) - 1)== nr = -1
| otherwise = FindIndexInString string token (nr+1)

StringArrayToTupple::[String] String -> [(String,String)]
StringArrayToTupple [as:bs] token
# index = FindIndexInString as token 0
| index== -1 = StringArrayToTupple bs token
| otherwise = [(as % (0,(index-1)),as%((index+size token),size as))]++ StringArrayToTupple bs token
StringArrayToTupple _ _ = []

ToUniqueString :: String -> *String
ToUniqueString c = {c.[i] \\ i <- [0..(size c-1)]}

CountStringInArray :: [String] String Int -> Int
CountStringInArray [as:bs] token nr
| as==token = CountStringInArray bs token nr+1
| otherwise = CountStringInArray bs token nr
CountStringInArray _ _ nr = nr

StringArrayCount :: [String] -> Int
StringArrayCount [as:bs] = 1 + StringArrayCount bs
StringArrayCount _ = 0

StringArrayToString :: [String] String-> String
StringArrayToString [as:bs] token= token+++as +++ StringArrayToString bs token
StringArrayToString _ _= ""

/****************************************************************************
	as -- bs removes all elements in bs from as
****************************************************************************/
(--) infixl 5 :: [a] [a] -> [a] | Eq a
(--) as bs = removeMembers as bs

/**********************************************************************
	General sorting and ordening of a list of elements	
***********************************************************************/
sortOn :: [(t t -> Bool)] [t] -> [t]
sortOn ps items
= sortBy (combined ps) items
where
	combined	:: [ (t t -> Bool) ] t t -> Bool
	combined [] x y			= True
	combined [p:ps] x y		= (p x y == p y x && combined ps x y) || p x y
	
groupOn :: [t -> a] [t] -> [[t]] | ==, < a
groupOn fs xs = (groupBy eqf o sortOn (map smf fs)) xs
where
	eqf a b		= [f a \\ f <- fs] == [f b \\ f <- fs]
	smf f a b	= f a <  f b

splitWith	:: (a -> Bool) 		[a]		-> ([a], [a])
splitWith _     []	=	([],[])
splitWith p [x:xs]
	| p x			=	([x:as],bs) 
	| otherwise		=	(as,[x:bs])
	where
		(as,bs)		= splitWith p xs



/**********************************************************************
	Some String utilities:
***********************************************************************/
words :: !a -> [String] | toString a
words a
	| size s == 0	= []
	| otherwise		= [s%(b,e-1) \\ (b,e) <- bes2]
where
	s = toString a
	bes1 = [i \\ i <- [1..(size s - 1)] | (isSpace s.[i]) <> (isSpace s.[i-1])]
	// alleen nog de vraag of je zo niet het laatste woord mist?
	// zo ja moeten we nog (size s - 1) aan de staart van bes1 toevoegen...
	// waarschijnlijk handigst in zip` met
	// zip` [b] = [(b,size s - 1)]
	bes2
		| isSpace s.[0]
			= zip` bes1
			= zip` [0:bes1]

	zip` [b] = [(b,size s)]
	zip` [b,e:r] = [(b,e):zip` r]
	zip` _ = []

wordsWith :: !.Char !String	-> [String]
wordsWith c s
	| s=="" && r==""	= []
	| r==""				= [s]
	| otherwise			= [f : wordsWith c r]
where
	(f,r)				= cSplit c s

splitAfter :: !.Char !String -> (!String,!String)
splitAfter c s = (s%(b1,e1),s%(b2,e2))
where
	sp = findPos c s 0 e2
	b1 = 0
	e1 = sp
	b2 = sp + 1
	e2 = size s

	findPos :: Char String Int Int -> Int
	findPos c s i end
		| i >= end		= end
		| s.[i] == c	= i
		| otherwise		= findPos c s (inc i) end

cSplit :: !.Char !String -> (!String,!String)
cSplit c s = (s%(b1,e1),s%(b2,e2))
where
	sp = findPos c s 0 e2
	b1 = 0
	e1 = sp - 1
	b2 = sp + 1
	e2 = size s

	findPos :: Char String Int Int -> Int
	findPos c s i end
		| i >= end		= end
		| s.[i] == c	= i
		| otherwise		= findPos c s (inc i) end

sSplit :: !String !String -> (!String,!String)
sSplit sep s = (s%(b1,e1),s%(b2,e2))
where
	sp = findPos sep s 0 e2
	b1 = 0
	e1 = sp - 1
	b2 = sp + ic + 1
	e2 = size s
	ic = size sep-1

	findPos :: String String Int Int -> Int
	findPos c s i end
		| i >= end			= end
		| s%(i,i+ic) == c	= i
		| otherwise			= findPos c s (inc i) end

unwords :: ![a] -> String | toString a
unwords ss		= flatWith " " ss

unlines :: ![a] -> String | toString a
unlines ss		= flatWith "\n" ss

/*flatWith :: !a ![b] -> String | toString a & toString b
flatWith s []    = ""
flatWith s [h]   = toString h
flatWith s [h:t] = toString h +++ toString s +++ flatWith s t
*/

flatWith :: !a ![b] -> String | toString a & toString b
flatWith sep items
= copyLines (createArray (sum (map size lines) + nrOfSep * (size ssep)) ' ') 0 lines
where
	nrOfSep
		| isEmpty items = 0
		| otherwise		= length items - 1
		
	lines	= map toString items
	ssep	= toString sep
	
	copyLines result n []	= result
	copyLines result n [l]
		# (_,result) = sup (size l) n 0 result l
		= result
		
	copyLines result n [l:ls]
		# (n,result) = sup (size l) n 0 result l
		# (n,result) = sup (size ssep) n 0 result ssep 
		= copyLines result n ls


endWith :: !a ![b] -> String | toString a & toString b
endWith suffix items
= copyLines (createArray (sum (map size lines) + nrOfSep * (size ssuffix)) ' ') 0 lines
where
	nrOfSep	= length items
		
	lines	= map toString items
	ssuffix	= toString suffix
	
	copyLines result n []	= result
		
	copyLines result n [l:ls]
		# (n,result) = sup (size l) n 0 result l
		# (n,result) = sup (size ssuffix) n 0 result ssuffix 
		= copyLines result n ls

sup :: !.Int Int !Int *String String -> (Int,.String)
sup l i j s h
	| j >= l	= (i,s)
	#! s		= {s & [i] = h.[j]}
	= sup l (inc i) (inc j) s h

substring :: String String -> Bool
substring s1 s2 = ss (fromString s1) (fromString s2)
where
	ss :: [Char] [Char] -> Bool
	ss p [] = p ==[]
	ss p xs = take (length p) xs == p || ss p (tl xs)

match :: String String -> Bool
match p s = match` (fromString p) (fromString s)
where
	match` :: [Char] [Char] 	-> Bool 
	match` p        []			=  all ((==) '*') p
	match` []       ss			=  ss == []
	match` ['*':ps] ss			=  match` ps ss
								|| match` ['*' : ps] (tl ss)
	match` ['?':ps] [s:ss]		=  match` ps ss 
	match` [p  :ps] [s:ss]		=  p==s 
								&& match` ps ss 



trim	:: String		-> String
trim s
	| s == ""			= ""
	| otherwise			= s % ((start 0),(end sizeS))
where		end n
				| not (isSpace s.[n]) || n <= 0		= n
				| otherwise 						= end (n-1)

			start n
				| not (isSpace s.[n]) || n >= sizeS	= n
				| otherwise 					= start (n+1)
			
			sizeS = size s - 1

trimQuotes	:: String		-> String
trimQuotes s
	| s == ""			= ""
	| otherwise			= s % ((start 0),(end sizeS))
where		end n
				| (s.[n] <> '\'' && s.[n] <> '\"')  || n <= 0		= n
				| otherwise 						= end (n-1)

			start n
				| (s.[n] <> '\'' && s.[n] <> '\"') || n >= sizeS	= n
				| otherwise 						= start (n+1)
			
			sizeS = size s - 1

stringToUpper :: String -> String
stringToUpper cs
= {toUpper c \\ c <-: cs}

stringToLower :: String -> String
stringToLower cs
= {toLower c \\ c <-: cs}

/**********************************************************************
	Instances on Maybe:
***********************************************************************/
instance < (Maybe a) | < a
where	(<) (Just a) (Just b)	= a < b
		(<) Nothing _			= True
		(<) _ Nothing			= False

instance toString (Maybe a) | toString a
where	toString (Just a) 	= toString a
		toString Nothing	= ""
	
	

/**********************************************************************
	To read all the characters from one File in one readacces
	returns: a String containing all characters in a file
***********************************************************************/
readFile :: *File -> (String, *File)
readFile file
	#	(ok,file)	= fseek file 0 FSeekEnd
	|	not ok		= abort "seek to end of file does not succeed\n"
	#	(pos,file)	= fposition	file
	#	(ok,file)	= fseek file (~pos) FSeekCur
	|	not ok		= abort "seek to begin of file does not succeed\n"
	#	(s, file)	= freads file pos
	=	(s, file)

/**********************************************************************
	To read all the lines from one File
	returns: a list of lines without the "\n"
***********************************************************************/
readStrings :: *File -> ([String], *File)
readStrings file
	# (eof, file)	= fend file
	|  eof			= ([], file)
	# (s, file)		= freadline file
	# s`			= s%(0,size s - 2)
	# (ss, file)	= readStrings file
	| otherwise		= ([s` : ss], file)
	
/**********************************************************************
	To save a list of files: [(fileName,fileContents)] 
	returns: a list of errors and a new fileenvironment
***********************************************************************/
exportFiles :: [(String,String)] *Files -> ([String],*Files)
exportFiles [] files
	= ([],files)
exportFiles [(fn,fc):htmls] files
	# (errors,files)			= exportFiles htmls files
	# (open,htmlfile,files)		= fopen fn FWriteText files
	| not open					= (["could not open: "+++fn+++"\n" : errors],files)
	# (close,files)				= (fclose (htmlfile <<< fc)) files
	| not close					= (["could not close: "+++fn+++"\n" : errors],files)
	| otherwise					= (errors,files)

/**********************************************************************
	Some funtion from the Haskell prelude:
***********************************************************************/
// from the Haskell prelude:
(hseq) infixr 0 ::  !.a .b -> .b
(hseq) a b = b

($)    infixr 0  
($) f  x   :== f x

instance == (Either a b) | == a & == b
 where
   (==) (Left x) (Left y) = y==x
   (==) (Right x) (Right y) = y==x
   (==) _ _ = False

lookup :: a [(a,.b)] -> Maybe .b | == a;
lookup k []       = Nothing
lookup k [(x,y):xys]
      | k==x      = Just y
      | otherwise = 	lookup k xys

foldr1 :: (.a -> .(.a -> .a)) ![.a] -> .a;
foldr1 f [x]      = x
foldr1 f [x:xs]   = f x (foldr1 f xs)

concatMap :: (.a -> [w:b]) -> u:([.a] -> v:[w:b]), [u <= v, u <= w]
concatMap f       = flatten o map f

fromMaybe              :: a (Maybe a) -> a
fromMaybe d Nothing    =  d
fromMaybe d (Just a)   =  a


