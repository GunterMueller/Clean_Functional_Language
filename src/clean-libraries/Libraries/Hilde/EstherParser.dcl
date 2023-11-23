definition module EstherParser

import StdException, StdGeneric, StdMaybe
from StdParsComb import :: CParser, :: Parser, :: AltCont, :: XorCont, :: SucCont, :: ParsResult

//:: Src a = {parsed :: !a, pretty :: !a -> String}

:: ParseException
	= SyntaxError
	| AmbigiousParser
	| ParserRequired !String

:: NTstatements
	= Compound !NTstatement !Tsemicolon !NTstatements
	| Pipe !NTstatement !Tguard !NTstatements
	| Statement !NTstatement

:: NTstatement
	= Write !NTexpression !Twrite !NTnameDef
	| Function !(Scope NTfunction)
	| Expression !NTexpression

:: NTfunction = NTfunction !NTnameDef ![NTpattern] !Tis !NTexpression

:: NTexpression
	= Apply !NTexpression !NTterm
	| Term !NTterm

:: NTterm
	= Sugar !NTsugar
	| Plain !NTplain

:: NTsugar 
	= Tuple !Topen !NTexpression !Tcomma !(+- NTexpression Tcomma) !Tclose
	| List !(|-| TopenBracket NTlist TcloseBracket)

:: NTplain
	= Nested !(|-| Topen NTexpression Tclose)
	| Lambda !(Scope NTlambda)
	| Let !(Scope NTlet)
	| Case !NTcase
	| Dynamic !(Scope NTdynamic)
	| NameOrValue !NTnameOrValue 

:: NTdynamic = NTdynamic !Tdynamic !NTexpression

:: NTlist
	= ListComprehension !NTlistComprehension
	| Cons !(+- NTexpression Tcomma) !(Maybe (!Tcolon, !NTexpression))
	| Nil

:: NTlistComprehension
	= ZF !NTexpression !Tzf !(+- NTqualifier Tcomma) 
	| DotDot !NTexpression !(Maybe (!Tcomma, !NTexpression)) !Tdotdot !(Maybe NTexpression)

:: NTqualifier = Qualifier !(+- NTgenerator Tand) !(Maybe (!Tguard, !NTexpression))

:: NTgenerator = ListGenerator !NTpattern !TbackArrow !NTexpression
	
:: NTlambda = NTlambda !Tlambda !(+- NTpattern UNIT) !Tarrow !NTexpression

:: NTlet = NTlet !Tlet !(+- NTletDef Tsemicolon) !Tin !NTexpression

:: NTletDef = NTletDef !NTpattern !Tis !NTexpression

:: NTcase = NTcase !Tcase !NTexpression !Tof !(+- (Scope NTcaseAlt) Tsemicolon)

:: NTcaseAlt = NTcaseAlt !(+- NTpattern UNIT) !Tarrow !NTexpression

:: NTpattern
	= AnyPattern !Tunderscore
	| TuplePattern !Topen !NTpattern !Tcomma !(+- NTpattern Tcomma) !Tclose
	| ConsPattern !TopenBracket !NTpattern !(Maybe (Tcolon, NTpattern)) !TcloseBracket
	| NilPattern !TopenBracket !TcloseBracket
	| NestedPattern !Topen !(+- NTpattern UNIT) !Tclose
	| VariablePattern !NTvariable 
	| NameOrValuePattern !NTnameOrValue 

:: NTvariable = NTvariable !String !GenConsPrio

:: NTnameOrValue = NTname !String !GenConsPrio | NTvalue !Dynamic !GenConsPrio

:: NTnameDef = NTnameDef !String !GenConsPrio

:: Scope e = Scope !e

:: |-| l e r = |-| !e

:: +- e s = +- ![e]

//:: Src a = {node :: !a, src :: !String}

:: Topen = Topen
:: Tclose = Tclose
:: TopenBracket = TopenBracket
:: TcloseBracket = TcloseBracket
:: Tlambda = Tlambda
:: Tarrow = Tarrow
:: Tlet = Tlet
:: Tin = Tin
:: Tcase = Tcase
:: Tof = Tof
:: Tsemicolon = Tsemicolon
:: Tcolon = Tcolon
:: Tcomma = Tcomma
:: Tunderscore = Tunderscore
:: Tis = Tis
:: Tdotdot = Tdotdot
:: Tzf = Tzf
:: TbackArrow = TbackArrow
:: Tguard = Tguard
:: Tand = Tand
:: Twrite = Twrite
:: Tdynamic = Tdynamic

parseStatements :: !String -> /*Src*/ NTstatements
