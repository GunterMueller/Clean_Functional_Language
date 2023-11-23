definition module pp

import transform, syntax

showComponents3 :: !*{! Group} !Int !Bool !*{# FunDef} !*File  -> (!*{! Group}, !*{# FunDef},!*File)
showComponents3U :: !*{! Group} !Int !Bool !*{# FunDef} !*File  -> (!*{! Group}, !*{# FunDef},!*File)


class (<#<) infixl a :: *PPState !a -> *PPState

instance <#< Bool


instance <#< (a,b) | <#< a & <#< b
instance <#< (a,b,c) | <#< a & <#< b & <#< c
instance <#< (a,b,c,d) | <#< a & <#< b & <#< c & <#< d
instance <#< (a,b,c,d,e) | <#< a & <#< b & <#< c & <#< d & <#< e

instance <#< (a,b,c,d,e,f,g) | <#< a & <#< b & <#< c & <#< d & <#< e & <#< f & <#< g

instance <#< [a] | <#< a


instance <#< Expression
instance <#< Position
instance <#< {#Char}
//instance <#< Optional a | <#< a
//instance <#< FunctionBody
instance <#< TypeCodeExpression
instance <#< VarInfo
//:: PPState

:: PPState = {
		file							:: !.File
	,	indent_level					:: !Int
	,	last_character_written_was_nl	:: !Bool
	,	write_indent					:: !Bool
	}
(-#->) infix :: .a !b -> .a | <#< b


//
instance <#< FunDef
InitPPState :: !*File -> *PPState

//instance <#< (a,b,c) | <#< a & <#< b & <#< c

//1.3
instance <#< {!a} | select_u, size_u, <#< a
//3.1
instance <#< Type
instance <#< TypeContext
instance <#< DynamicPattern
instance <#< ATypeVar
instance <#< AType
instance <#< (Ptr v) | <#< v
instance <#< TypeVar
instance <#< DynamicType
instance <#< AttributeVar

// TempLocalVar

do_print_chain :: ![Ptr ExprInfo] !*(Heap ExprInfo) -> *(Heap ExprInfo)
