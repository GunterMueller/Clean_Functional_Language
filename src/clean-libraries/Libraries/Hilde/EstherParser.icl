implementation module EstherParser

import StdException, StdGeneric, StdMaybe
import StdParsComb, StdBool, StdList, StdEnum, StdFunc

:: TryWant = Try | Want

parseStatements :: !String -> /*Src*/ NTstatements
parseStatements input 
	= case begin (sp (parser{|*|} Want) <& sp eof) (fromString input) of
		[([], syntax)] -> syntax
		[] -> raise SyntaxError
		_ -> raise AmbigiousParser

generic parser a :: !TryWant -> CParser Char a b

parser{|UNIT|} _ = sp (yield UNIT)

parser{|PAIR|} gl gr t = gl t <&> \l -> sp (gr t) <@ PAIR l

parser{|EITHER|} gl gr t = gl Try <@ LEFT <!> gr t <@ RIGHT

parser{|CONS of {gcd_type_def={gtd_name}}|} gx t=:Want = gx Try <@ CONS <!> raise (ParserRequired gtd_name)
parser{|CONS|} gx t = gx t <@ CONS

parser{|FIELD|} gx t = gx t <@ FIELD

parser{|OBJECT|} gx t = gx t <@ OBJECT
//parser{|OBJECT|} gx t=:Try = gx t <@ OBJECT
//parser{|OBJECT of {gtd_name}|} gx t=:Want = gx t <@ OBJECT <!> raise (ParserRequired gtd_name)

parser{|Bool|} b
	= token ['True'] &> yield True 
	<!> token ['False'] &> yield False

parser{|Char|} b = symbol '\'' &> character ['\''] <& symbol '\''

parser{|Int|} b 
	= <?> (symbol '+') &> nat 
	<!> symbol '-' &> nat <@ ~
where
	nat 
		= token ['0x'] &> number_ 16
		<!> symbol '0' &> number_ 8
		<!> number_ 10
	
parser{|Real|} b = (realWithExp <!> realWithoutExp) <@ toReal o toString
where
	realWithoutExp = int <?= ['0'] <++> symbol '.' <:&> numberList_ 10
	realWithExp = int <++> (symbol '.' <:&> numberList_ 10) <?= ['0'] <++> symbol 'E' <:&> int
	int = symbol '-' <:&> numberList_ 10 <!> <?> (symbol '+') &> numberList_ 10 

parser{|String|} b = symbol '"' &> <*> (character ['"']) <& symbol '"' <@ toString
/*
parser{|Src|} ge = p
where
	p sc xc ac ss = ge sc` xc ac ss
	where
		sc` x xc` ac` ss` = sc {node = x, src = toString (take (length ss - length ss`) ss)} xc` ac` ss`
*/
parser{|NTexpression|} Try = (parser{|*|} Try <@ Term) <&> p 
where
	p x = (sp (parser{|*|} Try) <&> \y -> p (Apply x y)) <!> yield x
parser{|NTexpression|} Want = parser{|*|} Try <!> raise (ParserRequired "NTexpression")

parser{|NTvariable|} t = variableIdentifier <@ \n -> NTvariable n GenConsNoPrio
/*
parser{|NTnameOrValue|}
	= parser{|*|} <@ (\x -> NTvalue (dynamic x :: String) GenConsNoPrio)
	<!> <+> (character (spacechars ++ symbolchars)) <&> \cs -> case begin p cs of [([], parser)] -> parser
where
	p 
		= parser{|*|} <& eof <@ (\x -> yield (NTvalue (dynamic x :: Real) GenConsNoPrio))
		<!> parser{|*|} <& eof <@ (\x -> yield (NTvalue (dynamic x :: Int) GenConsNoPrio))
		<!> parser{|*|} <& eof <@ (\x -> yield (NTvalue (dynamic x :: Char) GenConsNoPrio))
		<!> parser{|*|} <& eof <@ (\x -> yield (NTvalue (dynamic x :: Bool) GenConsNoPrio))
		<!> (lowercaseIdentifier <!> uppercaseIdentifier <!> funnyIdentifier) <& eof <@ (\n -> if (isMember n keywords) fail (yield (NTname n)))
		<!> <+> (satisfy (const True)) <@ (\n -> yield (NTname (toString n)))
*/
parser{|NTnameOrValue|} Try
	= parser{|*|} Try <@ (\x -> NTvalue (dynamic x :: String) GenConsNoPrio)
	<!> parser{|*|} Try <@ (\x -> NTvalue (dynamic x :: Real) GenConsNoPrio)
	<!> parser{|*|} Try <@ (\x -> NTvalue (dynamic x :: Int) GenConsNoPrio)
	<!> parser{|*|} Try <@ (\x -> NTvalue (dynamic x :: Char) GenConsNoPrio)
	<!> parser{|*|} Try <@ (\x -> NTvalue (dynamic x :: Bool) GenConsNoPrio)
	<!> functionIdentifier <@ (\x -> NTname x GenConsNoPrio)
parser{|NTnameOrValue|} Want = parser{|*|} Try <!> raise (ParserRequired "NTnameOrValue")

parser{|NTnameDef|} t = fixity functionIdentifier <@ \(n, p) -> NTnameDef n p

fixity p = (symbol '(' &> sp p <&> \n -> spsymbol ')' &> sp f <@ \p -> (n, p))
	<!> (p <@ \n -> (n, GenConsNoPrio))
where
	f = (assoc <&> \f -> sp (number 1 10 <!> yield 9) <@ GenConsPrio f)
			<!> yield (GenConsPrio GenConsAssocLeft 9)
	where
		assoc = keyword "infixr" &> yield GenConsAssocRight
			<!> keyword "infixl" &> yield GenConsAssocLeft
			<!> keyword "infix" &> yield GenConsAssocNone

functionIdentifier = constructorIdentifier <!> variableIdentifier

constructorIdentifier 
	= (uppercaseIdentifier <!> funnyIdentifier) <&> (\n -> if (isMember n keywords) fail (yield n)) 
	<!> fileIdentifier

variableIdentifier = lowercaseIdentifier <&> (\n -> if (isMember n keywords) fail (yield n))

fileIdentifier = symbol '`' &> <*> (character ['`']) <& symbol '`' <@ toString

parser{|(|-|)|} ga ge gb t = ga t &> sp (ge t) <& sp (gb t) <@ |-|

//parser{|(+-)|} ge gs t = parseSequence (sp (ge t)) (sp (gs Try)) <@ \[x:xs] -> +- [x:xs]
parser{|(+-)|} ge gs t = p t
where
	p t
		= (ge t <&> \x -> sp (gs t) &> sp (p t) <@ \(+- xs) -> +- [x:xs])
		<!> (ge t <@ \x -> +- [x])
		<!> (case t of Want -> raise (ParserRequired "+-"); _ -> fail)

parser{|[]|} ge t = p t
where
	p t
		= (ge t <&> \x -> sp (p t) <@ \xs -> [x:xs])
		<!> (ge t <@ \x -> [x])
		<!> yield []

parser{|Maybe|} ge t
	= ge Try <@ Just
	<!> yield Nothing

want :: !TryWant !String -> CParser a b c
want Try _ = fail
want Want s = raise (ParserRequired s)

parser{|Topen|} t = symbol '(' &> yield Topen <!> want t "("
parser{|Tclose|} t = symbol ')' &> yield Tclose <!> want t ")"
parser{|TopenBracket|} b = symbol '[' &> yield TopenBracket
parser{|TcloseBracket|} b = symbol ']' &> yield TcloseBracket
parser{|Tlambda|} b = keyword "\\" &> yield Tlambda
parser{|Tarrow|} b = keyword "->" &> yield Tarrow
parser{|Tlet|} b = keyword "let" &> yield Tlet
parser{|Tin|} b = keyword "in" &> yield Tin
parser{|Tcase|} b = keyword "case" &> yield Tcase
parser{|Tof|} b = keyword "of" &> yield Tof
parser{|Tsemicolon|} b = symbol ';' &> yield Tsemicolon
parser{|Tcolon|} b = keyword ":" &> yield Tcolon
parser{|Tcomma|} b = symbol ',' &> yield Tcomma
parser{|Tunderscore|} b = keyword "_" &> yield Tunderscore
parser{|Tis|} b = keyword "=" &> yield Tis
parser{|Tdotdot|} b = keyword ".." &> yield Tdotdot
parser{|Tzf|} b = keyword "\\\\" &> yield Tzf
parser{|TbackArrow|} b = keyword "<-" &> yield TbackArrow
parser{|Tguard|} b = keyword "|" &> yield Tguard
parser{|Tand|} b = keyword "&" &> yield Tand
parser{|Twrite|} b = keyword ">>>" &> yield Twrite
parser{|Tdynamic|} b = keyword "dynamic" &> yield Tdynamic

derive parser NTstatements, NTstatement, NTfunction, NTplain, NTterm, NTsugar, NTlist, NTlistComprehension, NTqualifier, NTgenerator, NTdynamic, NTlambda, NTpattern, NTlet, NTletDef, NTcase, NTcaseAlt
derive parser Scope, (,)

character :: ![Char] -> CParser Char Char t
character delimiters
	= symbol '\\' &> escaped
	<!> satisfy (\c -> not (isMember c delimiters))
where
	escaped
		= symbol 'n' <@ const '\n'
		<!> symbol 'r' <@ const '\r'
		<!> symbol 'f' <@ const '\f'
		<!> symbol 'b' <@ const '\b'
		<!> symbol 't' <@ const '\t'
		<!> symbol 'v' <@ const '\v'
		<!> symbol 'x' &> number 2 16 <@ toChar
		<!> symbol 'X' &> number 2 16 <@ toChar
		<!> symbol 'd' &> number 3 10 <@ toChar
		<!> symbol 'D' &> number 3 10 <@ toChar
		<!> number 3 8 <@ toChar
		<!> satisfy (\_ -> True)

number_ :: Int -> CParser Char Int t
number_ base = number (1 << 31 - 1) base

number :: Int Int -> CParser Char Int t
number n base = numberList n base <@ convert 0
where
	convert x [] = x
	convert x [c:cs] = convert (x * base + (numberchars ?? c)) cs

numberList_ :: Int -> CParser Char [Char] t
numberList_ base = numberList (1 << 31 - 1) base

numberList :: Int Int -> CParser Char [Char] t
numberList n base 
	| n < 1 = fail
	| n == 1 = satisfy (\c -> isMember (toUpper c) (take base numberchars)) <@ \c -> [toUpper c]
	= numberList 1 base <&> \[c] -> numberList (n - 1) base <?= [] <@ \cs -> [c:cs]

keyword c = (lowercaseIdentifier <!> uppercaseIdentifier <!> funnyIdentifier) <&> \n -> if (n == c && isMember n keywords) (yield n) fail 

lowercaseIdentifier = satisfy (\c -> isMember c lowerchars) <:&> <*> (satisfy (\c -> isMember c alphachars)) <@ toString
uppercaseIdentifier = satisfy (\c -> isMember c upperchars) <:&> <*> (satisfy (\c -> isMember c alphachars)) <@ toString
funnyIdentifier = <+> (satisfy (\c -> isMember c funnychars)) <@ toString

keywords =: ["=", "->", "let", "in", "case", "of", "\\", "_", ":", "..", "\\\\", "<-", "|", "&", ">>>", "dynamic", "infix", "infixl", "infixr"]
//symbolchars =: ['\',();[]{}"']
//spacechars =: ['\t\n\r\v ']
funnychars =: ['\\?.=:$!@#%^&*+-<>/|~']
lowerchars =: ['a'..'z'] ++ ['_']
upperchars =: ['A'..'Z']
digitchars =: ['0'..'9']
numberchars =: digitchars ++ upperchars
alphachars =: numberchars ++ lowerchars

(??) infix 9
(??) xs y :== find xs 0
where
	find [] _ = raise "??: not found in list?!"
	find [x:xs] i
		| x == y = i
		= find xs (i + 1)

(<?=) infix 7
(<?=) p def :== <?> p <@ \l -> case l of [x] -> x; _ -> def
/*
generic pretty e :: !Bool e -> String
pretty{|UNIT|} _ _ = ""
pretty{|EITHER|} gl gr p (LEFT l) = gl p l
pretty{|EITHER|} gl gr p (RIGHT r) = gr p r
pretty{|CONS|} gx p (CONS x) = gx p x
pretty{|OBJECT|} gx p (OBJECT x) = gx p x
pretty{|FIELD|} gx p (FIELD x) = gx p x
pretty{|PAIR|} gl gr p (PAIR l r) = gl p l +++ " " +++ gr p r

pretty{|NTexpression|} p (Term x) = pretty{|*|} p x
pretty{|NTexpression|} False (Apply f _ x) = pretty{|*|} True f +++ " " +++ pretty{|*|} True x
pretty{|NTexpression|} True (Apply f _ x) = "(" +++ pretty{|*|} True f +++ " " +++ pretty{|*|} True x +++ ")"

pretty{|NTnameOrValue|} _ (NTvalue d p) = fst (prettyDynamic d)
pretty{|NTnameOrValue|} _ (NTname n) = n

pretty{|NTvariable|} _ (NTvariable n) = n

pretty{|Src|} gx p {node} = gx p node
pretty{|(+-)|} ga gb _ (+- [a]) = ga False a
pretty{|(+-)|} ga gb _ (+- [a:as]) = ga False a +++ gb False (raise "pretty") +++ pretty{|*->*->*|} ga gb False (+- as)

pretty{|Tsemicolon|} _ _ = ";"
pretty{|Tclose|} _ _ = ")"
pretty{|Topen|} _ _ = "("
pretty{|TcloseBracket|} _ _ = "]"
pretty{|TopenBracket|} _ _ = "["
pretty{|Tof|} _ _ = "of"
pretty{|Tcase|} _ _ = "case"
pretty{|Tcomma|} _ _ = ","
pretty{|Tarrow|} _ _ = "->"
pretty{|Tlambda|} _ _ = "\\"
pretty{|Tlet|} _ _ = "let"
pretty{|Tin|} _ _ = "in"
pretty{|Tis|} _ _ = "="
pretty{|Tcolon|} _ _ = ":"
pretty{|Tunderscore|} _ _ = "_"
pretty{|Tdotdot|} _ _ = ".."

derive pretty NTstatement, NTterm, NTsugar, NTlambda, NTlet, NTletDef, NTcase, NTcaseAlt, NTpattern, NTlist, NTlistComprehension
derive pretty Scope, Maybe, (,), |-|
*/