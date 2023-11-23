definition module flexbar

import StdEnv, StdIO

:: FlexBarControl ls ps =
	{ flexbarState	:: FlexBarState
	, flexbarAtts	:: [ControlAttribute *(ls,ps)]
	}

:: FlexBarState

FlexBarControl :: Id [(String, Maybe Int)] [ControlAttribute *(.ls,.ps)] !*env
				-> (!FlexBarControl .ls .ps,!*env) | Ids env

instance Controls FlexBarControl

//--

power :: !String -> [String]
