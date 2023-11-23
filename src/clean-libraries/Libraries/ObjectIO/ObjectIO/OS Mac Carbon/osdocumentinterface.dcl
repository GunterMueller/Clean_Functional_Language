definition module osdocumentinterface

//	Clean object I/O library, version 1.2

import StdIOCommon
import ostoolbar, ostoolbox

::	OSDInfo

::	OSInfo =
	{	osFrame		:: !Int	// dummys to keep StdWindow happy...
	,	osClient	:: !Int	// should both be equal to the window handle of a single sdi window...
	,	osToolbar	:: !Maybe OSToolbar
	}

//::OSToolbar = {toolbarHeight::!Int}

::	OSMenuBar =
	{	mbHandle	:: !Int
	,	amHandle	:: !Int
	,	mbInfo		:: [Int]
	}

/*	Before using osOpenMDI, osOpenSDI, or osCloseOSDInfo evaluate osInitialiseDI.
*/
osInitialiseDI :: !*OSToolbox -> *OSToolbox

/*	emptyOSDInfo creates a OSDInfo with dummy values for the argument document interface.
*/
emptyOSDInfo :: !DocumentInterface -> OSDInfo

/*	getOSDInfoDocumentInterface returns the DocumentInterface of the argument OSDInfo.
*/
getOSDInfoDocumentInterface :: !OSDInfo -> DocumentInterface

/*	getOSDInfoOSMenuBar returns the OSMenuBar info from the argument OSDInfo.
	setOSDInfoOSMenuBar sets the OSMenuBar info in the OSDInfo.
*/
getOSDInfoOSMenuBar ::            !OSDInfo -> Maybe OSMenuBar
setOSDInfoOSMenuBar :: !OSMenuBar !OSDInfo -> OSDInfo

/*	getOSDInfoOSInfo returns the OSInfo from the argument OSDInfo if present.
	setOSDInfoOSInfo sets the OSInfo in the OSDInfo.
*/
getOSDInfoOSInfo ::         !OSDInfo -> Maybe OSInfo
setOSDInfoOSInfo :: !OSInfo !OSDInfo -> OSDInfo

getOSDInfoOffset :: !OSDInfo !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)

/*	osOpenMDI  creates  the infrastructure of a MDI process.
		If the first Bool argument is True, then the frame window is shown, otherwise it is hidden.
		The second Bool indicates whether the process accepts file open events.
	osOpenSDI  creates the infrastructure of a SDI process.
		The Bool argument indicates whether the process accepts file open events.
	osOpenNDI  creates the infrastructure of a NDI process.
	osCloseOSDInfo destroys the infrastructure.
*/
osOpenMDI     :: !Bool !Bool !*OSToolbox -> (!OSDInfo,!*OSToolbox)
osOpenSDI     ::       !Bool !*OSToolbox -> (!OSDInfo,!*OSToolbox)
osOpenNDI     ::             !*OSToolbox -> (!OSDInfo,!*OSToolbox)
osCloseOSDInfo:: !OSDInfo    !*OSToolbox -> *OSToolbox

/*	getOSDInfoOSToolbar retrieves the OSToolbar, if any.
*/
getOSDInfoOSToolbar :: !OSDInfo -> Maybe OSToolbar

/*	osOSDInfoIsActive tests if the given OSDInfo represents the interactive process with the
	active menu system. (Always True on Windows; use menu bar on Mac.)
*/
osOSDInfoIsActive :: !OSDInfo !*OSToolbox -> (!Bool, !*OSToolbox)

//---

mb_lookup :: !Int/*zIndex*/ !OSMenuBar -> Int /*OSMenuNr*/
mb_insert :: !Int/*zIndex*/ !Int/*OSMenuNr*/ !OSMenuBar -> OSMenuBar
mb_remove :: !Int/*OSMenuNr*/ !OSMenuBar -> OSMenuBar

//---

:: WindowTable

getOSDInfoWindowTable :: !OSDInfo -> WindowTable
setOSDInfoWindowTable :: !WindowTable !OSDInfo -> OSDInfo

WT_Empty :: WindowTable
WT_Add :: !Id !Id !u:WindowTable -> u:WindowTable			// wId rId wt
WT_Rem :: !Id !.WindowTable -> .WindowTable				// wId wt
WT_LookupW :: !Id !u:WindowTable -> (!Maybe Id,!u:WindowTable)		// wId wt -> (rId,wt)
WT_LookupR :: !Id !u:WindowTable -> (!Maybe Id,!u:WindowTable)		// rId wt -> (wId,wt)
