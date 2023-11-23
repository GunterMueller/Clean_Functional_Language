definition module filehist

import StdMenuElementClass

:: FileHistMenu ls pst
	= FileHistMenu String Int Id (R2Id String [String]) Id [String] (String pst -> pst)

instance MenuElements FileHistMenu
