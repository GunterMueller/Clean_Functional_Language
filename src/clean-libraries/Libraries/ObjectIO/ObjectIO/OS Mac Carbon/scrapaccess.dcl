definition module scrapaccess


from	mac_types	import	:: Handle
from	ostoolbox	import	:: OSToolbox
from	StdPicture	import	:: Picture
from	StdIOCommon	import	:: Rectangle, :: Point2
import	StdMaybe

setScrapText		:: !String						!*OSToolbox -> (!Bool,		!*OSToolbox)
getScrapText		::								!*OSToolbox -> (!Maybe String,!*OSToolbox)
scrapHasText		::								!*OSToolbox -> (!Bool,!Int,	!*OSToolbox)
setScrapPict		:: ![*Picture -> *Picture] !Rectangle	!*OSToolbox -> (!Int,			!*OSToolbox)
setScrapPictHandle	:: !Handle						!*OSToolbox -> (!Int,			!*OSToolbox)
getScrapPictHandle	::								!*OSToolbox -> (!Maybe Handle,!*OSToolbox)
scrapHasPict		::								!*OSToolbox -> (!Bool,!Int,	!*OSToolbox)
//getPictRectangle	:: !Handle						!*OSToolbox -> (!Rectangle,	!*OSToolbox)

getScrapCount		::								!*OSToolbox -> (!Int,			!*OSToolbox)
getScrapPrefTypes	::								!*OSToolbox -> (![Int],		!*OSToolbox)
