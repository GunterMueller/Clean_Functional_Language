implementation module colourclip

import StdArray, StdChar, StdClass, StdInt
import StdPictureDef

instance toString Colour
where
	toString (RGB {r,g,b})	= "RGB "+++toString r+++" :: "+++toString g+++" :: "+++toString b
	toString Black			= "0Black"
	toString White			= "1White"
	toString DarkGrey		= "2DarkGrey"
	toString Grey			= "3Grey"
	toString LightGrey		= "4LightGrey"
	toString Red			= "5Red"
	toString Green			= "6Green"
	toString Blue			= "7Blue"
	toString Cyan			= "8Cyan"
	toString Magenta		= "9Magenta"
	toString Yellow			= "Yellow"

instance fromString Colour
where
	fromString s
		| size s == 0 = Black
		= case s.[0] of
			'0' -> Black
			'1' -> White
			'2' -> DarkGrey
			'3' -> Grey
			'4' -> LightGrey
			'5' -> Red
			'6' -> Green
			'7' -> Blue
			'8' -> Cyan
			'9' -> Magenta
			'Y' -> Yellow
			'R' -> RGB {r = rrr, g = ggg, b = bbb}
			_   -> Black
	where
		(rgb,s1) = hasprefix "RGB " s
		rrr = StoInt s1
		(rok,s2) = hasprefix (toString rrr) s1
		(rol,s3) = hasprefix " :: " s2
		ggg = StoInt s3
		(gok,s4) = hasprefix (toString ggg) s3
		(gol,s5) = hasprefix " :: " s4
		bbb = StoInt s5

		StoInt s
			# i = findfirstnondigit 0
			# s` = s%(0,i-1)
			= toInt s`
		where
			findfirstnondigit i
				| i >= size s = i
				| isDigit s.[i] = findfirstnondigit (inc i)
				= i
		hasprefix p s
			# x = size p - 1
			| p == s%(0,x)
				= (True,s%(x+1,size s - 1))
			= (False,s)
