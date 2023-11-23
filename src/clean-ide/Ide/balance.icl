implementation module balance

import StdArray, StdBool, StdList, StdString
import EdPosition, EdSelection, EdText
import StrictList

IsOpenBracket c		:== c == '(' || c == '{' || c == '['
IsCloseBracket c	:== c == ')' || c == '}' || c == ']'
Corresponds a b		:== a == '(' && b == ')' || a == '[' && b == ']' ||
						a == '{' && b == '}'
							

//
//	Text_Balance returns the Selection of the smallest piece of balanced text surrounding
//	the cursor or the current selection.
//

Text_Balance :: !LineNr !Int !LineNr !Int !Text -> (!Bool,!Selection)
Text_Balance bln bcn eln ecn text
	#	(down,ld,cd,downb)= BalanceDownText eln ecn text
		(up  ,lu,cu,upb  )= BalanceUpText   bln bcn text
	| not down || not up || not (Corresponds upb downb)
		= (False,	{start={row=0,col=0},end={row=0,col=0}})
		= (True, 	{start={row=lu,col=cu},end={row=ld,col=inc cd}})


//BalanceDownText	:: !Int !Int !Text -> (!Bool,!Int,!Int,Char)
BalanceDownText ln cn text
	#	(line,text) = getLine ln text
	=  BalanceDown [] ln cn line text

//BalanceDown	:: ![Char] !Int !Int !TLine !Block !Text -> (!Bool,!Int,!Int,Char)
BalanceDown ps ln cn "" text
	| ln == lastLineNr text = (False,0,0,' ')
	#	ln			= inc ln
		cn			= 0
		(line,text) = getLine ln text
	=  BalanceDown ps ln cn line text
BalanceDown ps ln cn line text
	#	len					= size line
		(fnd,ps`,ci,brak)	= BalanceDownString ps cn len line
	| fnd			= (True,ln,ci,brak)
	| ci >= len 	= BalanceDown ps` ln cn "" text
	= BalanceDown ps` ln ci line text

//BalanceDownString :: ![Char] !Int !Int !String -> (!Bool,![Char],!Int,Char)
BalanceDownString ps ci len str
	| ci >= len			=  (False,ps,len,' ')
	#	char	= str.[ci]
		close	= IsCloseBracket char
	| close && ps == []	=  (True,[],ci,char)
	| close	&& Corresponds (hd ps) char
				=  BalanceDownString (tl ps) (inc ci) len str
	| close		=  (False,ps,len,' ')
	| IsOpenBracket char=  BalanceDownString [char:ps] (inc ci) len str
						=  BalanceDownString ps       (inc ci) len str

//BalanceUpText :: !Int !Int !Text -> (!Bool,!Int,!Int,Char)
BalanceUpText ln cn text
	#	(line,text) = getLine ln text
		(fnd,ps,ci,brak)= BalanceUpLine [] 0 (TakeChars cn line)
	| fnd	= (True,ln,dec (cn - ci),brak)
			= BalanceUp ps (dec ln) text

//BalanceUp :: ![Char] !Int !Text -> (!Bool,!Int,!Int,Char)
BalanceUp ps ln text
	| ln < 0	= (False,0,0,' ')
	#	(line,text)				= getLine ln text
		len						= size line
		(fnd,ps`,ci,brak)		= BalanceUpString ps (dec len) line//(Reverse line)
	| fnd
		# cn				= ci	//dec len  - ci
		= (True,ln,cn,brak)
	= BalanceUp ps` (dec ln) text


//BalanceUpLine :: ![Char] !Int !(StrictList String) -> (!Bool,![Char],!Int,Char)
BalanceUpLine ps ci "" =  (False,ps,ci,' ')
BalanceUpLine ps ci line
	#	len					= size line
		(fnd,ps`,ci`,brak)	= BalanceUpString ps (dec len) line
	| fnd	= (True,[],dec ((len - ci`)),brak)
			= (False,ps`,(len),brak)

BalanceUpString	:: ![Char] !Int !String -> (!Bool,![Char],!Int,Char)
BalanceUpString ps ci str
	| ci < 0				= (False,ps,0,' ')
	#	char	= str.[ci]
		open	= IsOpenBracket char
	| open && ps == []		= (True,[],ci,char)
	| open	&& Corresponds char (hd ps)
							= BalanceUpString (tl ps)	(dec ci) str
	| open					= (False,ps,0,' ')
	| IsCloseBracket char	= BalanceUpString [char:ps]	(dec ci) str
							= BalanceUpString ps		(dec ci) str
/*
Reverse :: String -> String 
Reverse str
	# cl = fromString str
	  rv = turn cl
	  rt = toString rv
	= rt
where
	turn :: [Char] -> [Char]
	turn l = reverse l

//RemoveChars	:: !Int !TLine -> TLine
RemoveChars 0 line	= line
RemoveChars i line	= line % (i, dec len)
where
	len= size line
*/
//TakeChars :: !Int !TLine !TLine -> TLine   // Returns the TLine reversed!!!
TakeChars 0 line	=  ""
TakeChars i line	= (line % (0, dec i))
	
//--- better balance [under development...]
/*
Text_Balance` :: .LineNr .Int !.LineNr .Int !.Text -> (.Bool,.Selection)
Text_Balance` bln bcn eln ecn text
	#	(down,ld,cd,downb)= BalanceDownText eln ecn text
		(up  ,lu,cu,upb  )= BalanceUpText   bln bcn text
	| not down || not up || not (Corresponds upb downb)
		= (False,	{start={row=0,col=0},end={row=0,col=0}})
		= (True, 	{start={row=lu,col=cu},end={row=ld,col=inc cd}})

balanceLine bln bcn eln ecn text
	# ((level,line),text)	= getLineC bln text
	# (bStack,bEnv)			= beforeParse level line bln bcn text
	# ((level,line),text)	= getLineC eln text
	# (eStack,eEnv)			= afterParse level line eln ecn text
	// dan uitbreiden tot je zowel iets op bStack en eStack heb en bEnv == eEnv
	| bEnv <> eEnv || isEmpty bStack || isEmpty eStack
		= (False,	{start={row=0,col=0},end={row=0,col=0}})
	| top bStack <> top eStack
		= (False,	{start={row=0,col=0},end={row=0,col=0}})
	= (True, {start = place bStack, end = place eStack})

:: BalnceEnv
	= Comment Int
	| LineComment
	| StringLit
	| CharLit
	| Pa
top [(i,r,c):_] = i

place [(i,r,c):_] = {row=r,col=c}

beforeParse level line bln bcn text
	// parseer tot bcn...
	// geeft bEnv
	// als open iets op top of stack dan klaar...?
	// zo niet dan terugwerken tot open iets op stack of begin of text

afterParse level line eln ecn text
*/
/*
sl_balance cl string sel_begin sel_end
 = inComment

where
	inComment = cl <> 0
	before = parse_upto sel_begin
	after = parse_from sel_end
	inside = balance_sel string sel_begin sel_end

chrparse i m s b e x y z
	= (x,y,z)

strparse i m s b e x y z
	= (x,y,z)

comparse i m s b e x y z
	= (x,y,z)

balparse i m s b e x y z
	| i >= m = (x,y,z)
	= case char of
		'('		-> balparse (inc i) m s b e x` y` z`
		')'		-> balparse (inc i) m s b e x` y` z`
		'['		-> balparse (inc i) m s b e x` y` z`
		']'		-> balparse (inc i) m s b e x` y` z`
		'{'		-> balparse (inc i) m s b e x` y` z`
		'}'		-> balparse (inc i) m s b e x` y` z`
		'\''	-> chrparse (inc i) m s b e x y z
		'\"'	-> strparse (inc i) m s b e x y z
		'/'		-> comparse (inc i) m s b e x y z
		c		-> if (funnyChar c)
					(balparse (scanFunny i) m s b e x y z)
					(balparse (inc i) m s b e x y z)
where
	char = s.[i]
	x` | before = [char:x]
		= x
	y` | inside = [char:y]
		= y
	z` | after = [char:z]
		= z
	before = i < b
	inside = i >= b && i < e
	after = i >= e
	
	funnyChar c = isStringMember c (dec funnySize) funnyChars

	//isStringMember:: a !.[a] -> .Bool | Eq a
	isStringMember x i s
		| i < 0 = False
		| s.[i] == x = True
		= isStringMember x (dec i) s

	funnyChars =: "~@#$%^?!+-*<>\\/|&=:."
	funnySize = 20

	scanFunny i
		| i >= m = i
		| funnyChar s.[i] = scanFunny (inc i)
		= i
*/