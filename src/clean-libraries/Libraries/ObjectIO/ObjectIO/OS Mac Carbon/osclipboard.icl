implementation module osclipboard

//	Clean Object I/O library, version 1.2

//	Clipboard operations.

import StdInt, StdTuple, StdMisc, StdString
import scrap	//, scrapaccess
import ostoolbox

osInitialiseClipboard :: !*OSToolbox -> *OSToolbox
osInitialiseClipboard tb = tb

::	OSClipboardItemType
	:==	Int
	
OSClipboardText
	:==	ScrapFlavorTypeText

osHasClipboardText :: !*OSToolbox -> (!Bool,!*OSToolbox)
osHasClipboardText tb
// 	= WinHasClipboardText tb
//	# (has,_,tb)	= scrapHasText tb
	# (err,ref,tb)	= GetCurrentScrap tb
	| err <> 0		= abort ("osclipboard:osHasClipboardText(GetCurrentScrap): " +++ toString err +++ "\n")
	# (err,_,tb)	= GetScrapFlavorFlags ref ScrapFlavorTypeText tb
	# has			= case err of
						0			-> True
						NoTypeErr	-> False
						_			-> abort ("osclipboard:osHasClipboard(GetScrapFlavorFlags): " +++ toString err +++ "\n")
	= (has,tb)

osSetClipboardText :: !{#Char} !*OSToolbox -> *OSToolbox
osSetClipboardText text tb
//	= WinSetClipboardText text tb
//	= snd (setScrapText text tb)
	# (err,tb)		= ClearCurrentScrap tb
	| err <> 0		= abort ("osclipboard:osSetClipboardText(ClearCurrentScrap): " +++ toString err +++ "\n")
	# (err,ref,tb)	= GetCurrentScrap tb
	| err <> 0		= abort ("osclipboard:osSetClipboardText(GetCurrentScrap): " +++ toString err +++ "\n")
	# (err,tb)		= PutScrapFlavor ref ScrapFlavorTypeText ScrapFlavorMaskNone text tb
	| err <> 0		= abort ("osclipboard:osSetClipboardText(PutScrapFlavor): " +++ toString err +++ "\n")
	= tb

osGetClipboardText :: !*OSToolbox -> (!{#Char},!*OSToolbox)
osGetClipboardText tb
//	= WinGetClipboardText tb
//	# (opt_text,tb)	= getScrapText tb
//	| isNothing opt_text
//		= ("",tb)
//	= (fromJust opt_text,tb)
	# (err,ref,tb)	= GetCurrentScrap tb
	| err <> 0		= abort ("osclipboard:osGetClipboardText:GetCurrentScrap: "+++toString err)
	# (err,_,tb)	= GetScrapFlavorFlags ref ScrapFlavorTypeText tb
	| err == NoTypeErr	= ("",tb)
	| err <> 0		= abort ("osclipboard:osGetClipboardText:GetScrapFlavorFlags: "+++toString err)
	# (err,siz,tb)	= GetScrapFlavorSize ref ScrapFlavorTypeText tb
	| err == NoTypeErr	= ("",tb)	// shouldn't really occur but seems to anyway?!
	| err <> 0		= abort ("osclipboard:osGetClipboardText:GetScrapFlavorSize: "+++toString err)
	# (err,siz,dat,tb)	= GetScrapFlavorData ref ScrapFlavorTypeText siz tb
	| err == NoMemErr	= ("",tb)	// triggered when debugging with codewarrior debugger
	| err == NoTypeErr	= ("",tb)
	| err <> 0		= abort ("osclipboard:osGetClipboardText:GetScrapFlavorData: "+++toString err)
	= (dat,tb)

osGetClipboardContent :: !*OSToolbox -> (![OSClipboardItemType],!*OSToolbox)
osGetClipboardContent tb
//	# (hasText,tb)	= WinHasClipboardText tb
//	= (if hasText [OSClipboardText] [],tb)
//	= getScrapPrefTypes tb
	# (hastext,tb)	= osHasClipboardText tb
	= (if hastext [OSClipboardText] [], tb)
/*
Silly implementation as long as we only support text clippings...
Can later replace by:
GetScrapFlavorCount + GetScrapFlavorInfoList
*/

osGetClipboardVersion :: !Int !*OSToolbox -> (!Int,!*OSToolbox)
osGetClipboardVersion nr tb
//	= WinGetClipboardCount tb
//	= getScrapCount tb
	| nr == 1	= (0,tb)
	= (1,tb)
/*
Dummy implementation for now...
Can use the current scrap ref for this except that we need to reset it explicitly
a) on activate/deactivates... N.B. there is no valid clipboard for a background app...
b) after calling ClearCurrentScrap
*/

