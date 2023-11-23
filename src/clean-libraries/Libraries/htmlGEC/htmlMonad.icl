implementation module htmlMonad

import StdFunc
import htmlHandler, htmlFormlib

(>>=) infixr 5 :: (HStM .a) (.a -> HStM .b) -> HStM .b
(>>=) fM gM = \hSt -> let (a,hSt1) = fM hSt in gM a hSt1

mkHtmlM :: String [BodyTag] -> HStM Html	// string is used for the title of the page
mkHtmlM s tags = return (simpleHtml s [] tags)

// Experiment with more do-like notation.
(>>>=) :: u:(.a -> (.(.b -> (.a,.c)),.(.c -> .d))) -> v:(.b -> .d), [v <= u]
(>>>=) f = help f
where
	help :: !.(.a -> (.(.b -> (.a,.c)),.(.c -> .d))) .b -> .d
	help f hSt
		= gM hSt1
	where
		(a,hSt1)	= fM hSt
		(fM,gM)		= f a
