module isDynamicExample

import StdEnv

isDynamic :: String -> Bool
isDynamic s = not (hasExtension s)

hasExtension :: String -> Bool
hasExtension ""= False
hasExtension x= x.[0]=='.' || hasExtension ((%) x (1,(size x)-1))


dynname = "c:\\windows\\function.typ"

Start world
	| isDynamic dynname = "DYNAMIC\n"
	| otherwise = "not DYNAMIC\n"
