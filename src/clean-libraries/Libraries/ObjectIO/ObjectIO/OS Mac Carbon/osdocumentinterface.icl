implementation module osdocumentinterface

import StdIOCommon, StdClass, StdBool
import ostoolbox,ostoolbar,osmenu,menus

//import StdDebug

osInitialiseDI :: !*OSToolbox -> *OSToolbox
osInitialiseDI tb = tb

:: OSDInfo =
	{ osinfo :: !Maybe OSInfo
	, osmenu :: !Maybe OSMenuBar
	, osdoci :: !DocumentInterface
	, oswint :: !WindowTable
	}

:: OSInfo =
	{ osFrame	:: !Int	// dummys to keep StdWindow happy...
	, osClient	:: !Int
	, osToolbar :: !Maybe OSToolbar
	}

//::OSToolbar = {toolbarHeight::!Int}

emptyOSDInfo :: !DocumentInterface -> OSDInfo
emptyOSDInfo di
//	#! di = trace_n ("emptyOSDInfo: "+++toString di) di
	# info = case di of
				MDI	-> Just emptyOSInfo
				SDI	-> Just emptyOSInfo
				_	-> Nothing
	= {osinfo = info,osmenu = Nothing,osdoci = di, oswint = WT_Empty}

emptyOSInfo =
	{ osFrame = 0
	, osClient = 0
	, osToolbar = Nothing
	}

getOSDInfoDocumentInterface :: !OSDInfo -> DocumentInterface
getOSDInfoDocumentInterface {osdoci}
//	#! osdoci = trace_n ("getOSDInfoDocumentInterface: "+++toString osdoci) osdoci
	= osdoci

getOSDInfoOSInfo ::  !OSDInfo -> Maybe OSInfo
getOSDInfoOSInfo {osinfo}
//	#! osinfo = trace_n "getOSDInfoOSInfo" osinfo
	= osinfo

setOSDInfoOSInfo :: !OSInfo !OSDInfo -> OSDInfo
setOSDInfoOSInfo osi osd
//	#! osd = trace_n "setOSDInfoOSInfo" osd
	= {osd & osinfo = Just osi}

getOSDInfoOSMenuBar ::  !OSDInfo -> Maybe OSMenuBar
getOSDInfoOSMenuBar {osmenu}
//	#! osmenu = trace_n ("getOSDInfoOSMenuBar: "+++ (if (isJust osmenu) (toString (fromJust osmenu).amHandle) "no osmenu")) osmenu
	= osmenu

setOSDInfoOSMenuBar :: !OSMenuBar !OSDInfo -> OSDInfo
setOSDInfoOSMenuBar osmenu osd
//	#! osd = trace_n ("setOSDInfoOSMenuBar: "+++toString osmenu.amHandle) osd
	= {osd & osmenu = Just osmenu}

//--

osOpenNDI :: !*OSToolbox -> (!OSDInfo,!*OSToolbox)
osOpenNDI tb
	# tb				= ClearMenuBar tb
	# (appleHandle,tb)	= AppleMenu tb
	# (mbHandle,tb)		= GetMenuBar tb
	= (
		{ osinfo = Nothing
		, osmenu = Just (mb_empty_menubar appleHandle mbHandle)
		, osdoci = NDI
		, oswint = WT_Empty
		},tb)

osOpenMDI :: !Bool !Bool !*OSToolbox -> (!OSDInfo,!*OSToolbox)
osOpenMDI showFrame acceptFileOpen tb
	# tb				= ClearMenuBar tb
	# (appleHandle,tb)	= AppleMenu tb
	# (mbHandle,tb)		= GetMenuBar tb
//	# tb				= trace_n "OSopenMDI" tb
	// add Window Menu...
	= (
		{ osinfo = Just emptyOSInfo
		, osmenu = Just (mb_empty_menubar appleHandle mbHandle)
		, osdoci = MDI
		, oswint = WT_Empty
		},tb)

osOpenSDI :: !Bool !*OSToolbox -> (!OSDInfo,!*OSToolbox)
osOpenSDI acceptFileOpen tb
	# tb				= ClearMenuBar tb
	# (appleHandle,tb)	= AppleMenu tb
	# (mbHandle,tb)		= GetMenuBar tb
//	# tb				= trace_n ("OSopenSDI "+++toString appleHandle) tb
	= (
		{ osinfo = Just emptyOSInfo
		, osmenu = Just (mb_empty_menubar appleHandle mbHandle)
		, osdoci = SDI
		, oswint = WT_Empty
		},tb)

osCloseOSDInfo:: !OSDInfo !*OSToolbox -> *OSToolbox
osCloseOSDInfo osd tb
	// dispose apple menu?
	// dispose menubar?
//	# tb = trace_n "OScloseOSDInfo" tb
	= tb

getOSDInfoOSToolbar :: !OSDInfo -> Maybe OSToolbar
getOSDInfoOSToolbar osd
	# ostb		= Nothing
//	#! ostb		= trace_n "getOSDInfoOSToolbar" ostb
	= ostb

/*	osOSDInfoIsActive tests if the given OSDInfo represents the interactive process with the
	active menu system. (Always True on Windows; use menu bar on Mac.)
*/
osOSDInfoIsActive :: !OSDInfo !*OSToolbox -> (!Bool, !*OSToolbox)
osOSDInfoIsActive osdinfo tb
	# maybeOSMenuBar		= getOSDInfoOSMenuBar osdinfo
	| isNothing maybeOSMenuBar	// is NDI process
		= (True,tb)
	| otherwise
		# {amHandle}		= fromJust maybeOSMenuBar
		# (globalHandle,tb)	= GetMHandle AppleMenuId tb
		= (amHandle == globalHandle, tb)

getOSDInfoWindowTable :: !OSDInfo -> WindowTable
getOSDInfoWindowTable {oswint} = oswint

setOSDInfoWindowTable :: !WindowTable !OSDInfo -> OSDInfo
setOSDInfoWindowTable wt osd = {osd & oswint = wt}

getOSDInfoOffset :: !OSDInfo !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
getOSDInfoOffset _ tb
	= ((0,0),tb)

//-- menubar stuff...

import StdList

:: OSMenuBar =
	{ mbHandle	:: !Int		// handle to the menubar
	, amHandle	:: !Int		// handle to the apple menu
	, mbInfo	:: [Int]	// zIndex -> menuId association table
	}

mb_empty_menubar amHandle mbHandle =
	{ mbHandle = mbHandle
	, amHandle = amHandle
	, mbInfo = []
	}

mb_lookup :: !Int !OSMenuBar -> Int
mb_lookup z {mbInfo=mb}
	| z < 0 || z >= (length mb)
		= 0
	= mb!!z

mb_insert :: !Int !Int !OSMenuBar -> OSMenuBar
mb_insert z i mb=:{mbInfo}
	= {mb & mbInfo = insertAt z i mbInfo}

mb_remove :: !Int !OSMenuBar -> OSMenuBar
mb_remove i mb=:{mbInfo}
	= {mb & mbInfo = mb_remove i mbInfo}
where
	mb_remove i [] = []
	mb_remove i [h:t]
		| i == h = t
		= [h:mb_remove i t]

//-- window menu support...

import id, commondef, StdMisc, StdTuple

:: WindowTable :== [(Id,Id)]

WT_Empty :: WindowTable
WT_Empty = []

WT_Add :: !Id !Id !u:WindowTable -> u:WindowTable			// wId rId wt
WT_Add wId rId wt = [(wId,rId):wt]

WT_Rem :: !Id !.WindowTable -> .WindowTable				// wId wt
WT_Rem wId wt = filter (\(wId`,_)->wId<>wId`) wt

WT_LookupW :: !Id !u:WindowTable -> (!Maybe Id,!u:WindowTable)		// wId wt -> (rId,wt)
WT_LookupW wId wt
	# (found,entry,wt)	= ucselect (\(wId`,_)->wId==wId`) undef wt
	| found = (Just (snd entry),wt)
	= (Nothing,wt)

WT_LookupR :: !Id !u:WindowTable -> (!Maybe Id,!u:WindowTable)		// rId wt -> (wId,wt)
WT_LookupR rId wt
	# (found,entry,wt)	= ucselect (\(_,rId`)->rId==rId`) undef wt
	| found = (Just (fst entry),wt)
	= (Nothing,wt)
