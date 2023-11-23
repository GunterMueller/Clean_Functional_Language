definition module syncol

// provides preparsing for Clean syntax colouring.

import StdString
import StrictList

:: Info	=
	{comment_level::!Int	// comment nesting level at start of line
//	,!Bool					// in typedef at start of line
	,is_typedef::!Bool		// is typedef line
//	,!Bool					// in typedecl at start of line
	,is_typedecl::!Bool		// is typedecl line
	,offside_level::!Int	// context offside level
	,flush::!Bool			// flush accu
	}
// pack bools into bitfield?

firstParse :: !(StrictList String) -> StrictList (!Info,!String)
quickParse :: !Int !Int !(StrictList (!Info,!String)) -> (Int,Int,StrictList (!Info,!String))
