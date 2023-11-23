implementation module scrapaccess


import	StdInt, StdBool, StdString, StdArray, StdFunc, StdMisc, StdClass
import	pointer, memory, scrap, memoryaccess, commondef
import ospicture
//import	commondef, memoryaccess
from	quickdraw	import	:: PicHandle, QOpenPicture, QClosePicture, QKillPicture
//from	picture		import	Picture, 
//							PictureToToolbox, ToolboxToPicture, 
//							defaultpen, Pen, Origin, Colour, RGB, RGBColour, Font
import	StdIOCommon
import	StdMaybe


scrapaccessError :: String String -> .x
scrapaccessError rule error
	= abort (rule +++ " in module "+++"scrapaccess" +++" "+++error)


setScrapText :: !String !*OSToolbox -> (!Bool,!*OSToolbox)
setScrapText text tb
	=	(True,tb)
//	#	(_,tb)		= ZeroScrap tb
//		(error,tb)	= PutScrapText text tb
//	=	(error>=0,tb)

getScrapText :: !*OSToolbox -> (!Maybe String,!*OSToolbox)
getScrapText tb
	=	(Nothing,tb)
/*
	#	(hDest,rH,tb)	= NewHandle 0 tb
	|	rH<>0			= scrapaccessError "getScrapText" "Out of memory"
	#	(size,_,tb)		= GetScrap hDest TextResourceType tb
	|	size<=0			= (Nothing,tb1)
					with
						(_,tb1)		= DisposHandle hDest tb
	= (Just text,tb2)
					with
						(text,tb1)	= handle_to_string hDest size tb
						(_,tb2)		= DisposHandle hDest tb1
*/
scrapHasText :: !*OSToolbox -> (!Bool,!Int,!*OSToolbox)
scrapHasText tb
	=	(False,0,tb)
//	#	(size,offset,tb)	= GetScrap 0 TextResourceType tb
//	=	(size>0,offset,tb)

setScrapPict :: ![*Picture -> *Picture] !Rectangle !*OSToolbox -> (!Int,!*OSToolbox)
setScrapPict drawFs boundRect tb
//	| isEmptyRectangle boundRect
	=	(0,tb)
/*	#	(pictH,tb)		= QOpenPicture (OSRect2Rect (rectangleToRect boundRect)) tb
		picture			= packPicture {x=0,y=0} defaultPen False 0 tb
		picture			= strictSeq drawFs picture
		(_,_,_,_,tb)		= unpackPicture picture
		tb				= QClosePicture pictH tb
		(pictPtr,tb)	= LoadLong pictH tb
	//	(size,tb)		= LoadWord pictPtr tb
		(size,tb)		= GetHandleSize pictH tb
		(_,tb)			= ZeroScrap tb
		(error,tb)		= PutScrap size PictResourceType pictPtr tb
		tb				= QKillPicture pictH tb
	=	(error,tb)
*/
setScrapPictHandle :: !Handle !*OSToolbox -> (!Int,!*OSToolbox)
setScrapPictHandle pictH tb
	=	(0,tb)
/*	#	(pictPtr,tb)		= LoadLong pictH tb
	//	(size,tb)			= LoadWord pictPtr tb
		(size,tb)			= GetHandleSize pictH tb
		(_,tb)				= ZeroScrap tb
		(error,tb)			= PutScrap size PictResourceType pictPtr tb
	=	(error,tb)
*/
getScrapPictHandle :: !*OSToolbox -> (!Maybe Handle,!*OSToolbox)
getScrapPictHandle tb
	= (Nothing,tb)
/*	#	(hDest,rH,tb)	= NewHandle 0 tb
	|	rH<>0
	=	scrapaccessError "getScrapPictHandle" "Out of memory"
	#	(size,_,tb)		= GetScrap hDest PictResourceType tb
	|	size>0
	=	(Just hDest,tb)
	#	(_,tb)			= DisposHandle hDest tb
	=	(Nothing,tb)
*/
scrapHasPict :: !*OSToolbox -> (!Bool,!Int,!*OSToolbox)
scrapHasPict tb
	= (False,0,tb)
//	#	(size,offset,tb)	= GetScrap 0 PictResourceType tb
//	=	(size>0,offset,tb)
/*
getPictRectangle :: !Handle !*OSToolbox -> (!Rectangle,!*OSToolbox)
getPictRectangle pictH tb
	#	(pictPtr,tb)	= LoadLong pictH tb
		rectPtr			= 2+pictPtr					// picFrame offset
		((rleft,rtop, rright,rbottom),tb)	= LoadRect rectPtr tb
	=	({corner1={x=rleft,y=rtop},corner2={x=rright,y=rbottom}},tb)
*/
getScrapCount :: !*OSToolbox -> (!Int,!*OSToolbox)
//getScrapCount tb = LoadWord ScrapCount tb
getScrapCount tb = (42,tb)

getScrapPrefTypes :: !*OSToolbox -> (![Int],!*OSToolbox)
getScrapPrefTypes tb
	= ([],tb)
/*	#	(hasText,textOffset,tb)		= scrapHasText tb
		(hasPict,pictOffset,tb)		= scrapHasPict tb
	|	not hasText && not hasPict	= ([],tb)
	|	not hasText					= ([PictResourceType],tb)
	|	not hasPict					= ([TextResourceType],tb)
	|	textOffset<pictOffset		= ([TextResourceType,PictResourceType],tb)
									= ([PictResourceType,TextResourceType],tb)
*/
/*
LoadRect :: !Ptr !*OSToolbox -> (!Rect,!*OSToolbox)
LoadRect ptr tb
	#	(top,   tb)	= LoadWord ptr		tb
		(left,  tb)	= LoadWord (ptr+2)	tb
		(bottom,tb)	= LoadWord (ptr+4)	tb
		(right, tb)	= LoadWord (ptr+6)	tb
	=	((left,top,right,bottom),tb)
*/

//--
/*
OSRect2Rect r	:== (rleft,rtop,rright,rbottom)
where
	{rleft,rtop,rright,rbottom} = r
*/