definition module htmlMonad

import htmlHandler

::	HStM a :== *HSt -> *(a, *HSt)

//	The standard definition of the bind operator
(>>=) infixr 5 :: (HStM .a) (.a -> HStM .b) -> HStM .b


//	Strange experiment to mimic do-notation order
//(>>=) :: .(.a -> .(HStM .a,HStM .b)) -> HStM .b

mkHtmlM :: String [BodyTag] -> HStM Html	// string is used for the title of the page
