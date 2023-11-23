definition module EdTab

// functions that deal with those annoying tab characters

from StdIOCommon	import :: Point2
from StdPicture		import :: Picture
from EdMonad		import :: FontInfo
from syncol			import :: Info

splitAtTabs	   :: !String -> .[String]
// splitAtTabs:	   splits a string into several strings that were
//				   separated by tabs in the orginal string.
//				   e.g. "monkey\tcow\t" --> ["monkey","cow",""]

tabTake		   :: !Int [String] -> [String]
// tabTake:		   takes a number of characters of a string that
//				   is split at tabs. e.g. tabTake 4 ["abc","def"] =
//				   ["abc",""]

tabDrawString  :: !Point2 !String !FontInfo !*Picture -> *Picture
tabDrawStringC :: !Point2 !(!Info,!String) !FontInfo !*Picture -> *Picture
// tabDrawString:	draws a string containing tabs properly.
// tabDrawStringC:	draws a string containing tabs properly with syntax colours.
