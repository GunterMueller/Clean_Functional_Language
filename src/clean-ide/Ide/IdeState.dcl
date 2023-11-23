definition module IdeState

import	StdPSt, StdPrint
import	ExtListBox, FilteredListBox
import	fbi, clipboard, typewin
import	EdState
import	PmProject
import	PmPrefs
import	flextextcontrol
from	PmAbcMagic	import :: ABCCache
from	PmFileInfo	import :: FileInfoCache
import	PmEnvironment
import	conswin
from PmCleanSystem import ::CompilerProcessIds

from iostate import ioStGetWorld,ioStSetWorld

app_world_instead_of_ps f ps
	:== appPIO app_world_instead_of_io ps
where
	app_world_instead_of_io io
		# (w,io) = ioStGetWorld io
		# w = f w
		= ioStSetWorld w io

:: *General

instance Editor		General		// Editor
instance Clipper	General		// Clipboard
instance Typer		General		// Types
instance Consoler	General		// Console

getProject :: !*(PSt *General) -> (Project,*PSt *General)
setProject :: !Project !*(PSt *General) -> *PSt *General
appProject :: (Project -> Project) !*(PSt *General) -> *PSt *General
getFromProject :: (Project -> .a) !*(PSt *General) -> (!.a,!*PSt *General)

getCompilerProcessIds :: !*(PSt *General) -> (!CompilerProcessIds,!*(PSt *General))
setCompilerProcessIds :: !CompilerProcessIds !*(PSt *General) -> *(PSt *General)

:: EditMenuLS l =	// local state for the Edit menu
	{ zfun :: (PSt l) -> PSt l	// undo-function
	, xfun :: (PSt l) -> PSt l	// cut-function
	, cfun :: (PSt l) -> PSt l	// copy-function
	, vfun :: (PSt l) -> PSt l	// paste-function
	}

:: MIn l = MGet | MSet (EditMenuLS l)	// message type for the Edit menu

:: ErrorInfo p =
	{ errorId		:: !Id
	, infoId		:: !FilteredListBoxId 	// id for w&e listbox
	, err_offset	:: !Vector2				// errwin offset
	, err_font		:: !Font				// errwin font
	, err_size		:: !Size				// errwin listbox size
	, err_forg		:: !Colour				// errwin listbox text colour
	, err_back		:: !Colour				// errwin listbox background colour
	, err_buttonId	:: !Id
	, err_countId	:: !Id
	, err_count		:: !Int
	, err			:: !Bool
	, wrn_buttonId	:: !Id
	, wrn_countId	:: !Id
	, wrn_count		:: !Int
	, wrn			:: !Bool
	, inf_buttonId	:: !Id
	, inf_countId	:: !Id
	, inf_count		:: !Int
	, inf			:: !Bool
	}

:: FindInfo =
	{ fi_find	:: ![String]		// find...
	, fi_repl	:: ![String]		// replace by
	, fi_ic		:: !Bool			// ignore case
	, fi_wa		:: !Bool			// wrap around
	, fi_bw		:: !Bool			// backward
	, fi_mw		:: !Bool			// match words
	, fi_re		:: !Bool			// temp: use regexp
	}

:: MenuIds =
	{ mn_sav	:: !Id											// File:Save id
	, mn_sva	:: !Id											// File:Save As id
	, mn_rev	:: !Id											// File:Revert id
	, mn_clo	:: !Id											// File:Close id
	, mn_oth	:: !Id											// File:Open Other id
	, mn_odm	:: !Id											// File:Open Definition id
	, mn_oim	:: !Id											// File:Open Implementation id
	, mn_prt	:: !Id											// File:Print id
	, mn_prs	:: !Id											// File:PrintSetup id
	, mn_und	:: !Id											// Edit:Undo id
	, mn_cut	:: !Id											// Edit:Cut id
	, mn_cpy	:: !Id											// Edit:Copy id
	, mn_pst	:: !Id											// Edit:Paste id
	, mn_clr	:: !Id											// Edit:Clear id
	, mg_edt	:: ![Id]										// Edit:tools ids
	, searchIds	:: !SearchMenuIds								// Search: ids
	, pm_menuid	:: !Id											// id of project menu
	, projIds	:: ![Id]										// Project: ids for disabling when no project...
	, pm_listid	:: !Id											// id of project list (in project menu)
	, pm_mrecid :: !R2Id PLMMessage PLMReply					// id of project menu receiver
	, ed_mrecid :: !R2Id (MIn *General) (EditMenuLS *General)	// id of edit menu receiver
	, fh_rid	:: !R2Id String [String]						// file history id
	, ph_rid	:: !R2Id String [String]						// project history id
	, moduleIds	:: ![Id]										// ids in module menu
	, md_cmp	:: !Id											// Module:Compile
	, md_chk	:: !Id											// Module:Check syntax
	, md_gen	:: !Id											// Module:Generate assembly
	, md_cst	:: !Id											// Module:Compiler settings
	, md_est	:: !Id											// Module:Editor settings
	}

:: SearchMenuIds =
	{ srchIds	:: ![Id]
	, findIds	:: ![Id]
	, gotoIds	:: ![Id]
	, nextIds	:: ![Id]
	}

//---

iniGeneral :: !Prefs !.Pathname
				Bool *File
				!Id !Id !.(ExtListBoxId *(PSt *General)) !EditorState !.FindInfo 
				!.(FindBoxInfo *(PSt *General)) !Id !Id !TypeWinInfo !ConsWinInfo !.[.Target] !Id !Id !(R2Id PLMMessage PLMReply) !*World//*env
				-> *(!ClipInfo,!*General,!*World)

//---

getEditRecId :: !*(PSt *General) -> *(R2Id (MIn *General) (EditMenuLS *General),*PSt *General)

getABCCache :: !*(PSt *General) -> (*ABCCache,*PSt *General)
setABCCache :: !*ABCCache !*(PSt *General) -> *PSt *General

getFICache :: !*(PSt *General) -> (FileInfoCache,*PSt *General)
setFICache :: !FileInfoCache !*(PSt *General) -> *PSt *General

getCallback :: !*(PSt *General) -> *(.Bool -> *(PSt *General) -> *(PSt *General),*PSt *General);
setCallback :: (Bool -> *(PSt *General) -> *(PSt *General)) !*(PSt *General) -> *PSt *General;

getFHI :: !*(PSt *General) -> (R2Id String [String],*PSt *General)
getPHI :: !*(PSt *General) -> (R2Id String [String],*PSt *General)

getMenuIds :: !*(PSt *General) -> (MenuIds,*PSt *General)
setModuleIds :: ![Id] !*(PSt *General) -> *PSt *General

setPrefs :: Prefs !*(PSt *General) -> *PSt *General
getPrefs :: !*(PSt *General) -> (Prefs,*PSt *General)

//-- project menu stuff

getPMI :: !*(PSt *General) -> ((Id,Id),*PSt *General)

:: PLMMessage
	= Add {#Char}
	| Rem {#Char}
	| Get

:: PLMReply
	:== [{#Char}]

getPMR :: !*(PSt *General) -> (R2Id PLMMessage PLMReply,*PSt *General)

//-- environment menu stuff

getTargetIds :: !*(PSt *General) -> ((!Id,!Id),!*PSt *General)

getTargets :: !*(PSt *General) -> (![Target],!*PSt *General)
setTargets :: ![Target] !*(PSt *General) -> *PSt *General

getCurrentTarget :: !*(PSt *General) -> (!Int,!*PSt *General)
setCurrentTarget :: !Int !*(PSt *General) -> *PSt *General

getCurrentPaths :: !*(PSt *General) -> (!(List Pathname),!*PSt *General)
getCurrentDlibs :: !*(PSt *General) -> (!(List String),!*PSt *General)
getCurrentSlibs :: !*(PSt *General) -> (!(List String),!*PSt *General)
getCurrentObjts :: !*(PSt *General) -> (!(List String),!*PSt *General)

getCurrentComp :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentCgen :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentAbcOpt :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentBCgen :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentBClink :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentBCstrip :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentBCprelink :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentLink :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentDynl :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentVers :: !*(PSt *General) -> (!Int,!*PSt *General)
getCurrentRedc :: !*(PSt *General) -> (!Bool,!*PSt *General)
getCurrent64BitProcessor :: !*(PSt *General) -> (!Bool,!*PSt *General)
getCurrentProc :: !*(PSt *General) -> (!Processor,!*PSt *General)
getCurrentMeth :: !*(PSt *General) -> (!CompileMethod,!*PSt *General)

//-- error window stuff

setErrInfo :: !(ErrorInfo (PSt *General)) !*(PSt *General) -> *PSt *General
getErrInfo :: !*(PSt *General) -> (!ErrorInfo (PSt *General),!*PSt *General)

//-- project window stuff

getPWI :: !*(PSt *General) -> (!ExtListBoxId (PSt General),!*PSt *General)
setPWI :: !(ExtListBoxId (PSt General)) !*(PSt *General) -> *PSt *General
getPWW :: !*(PSt *General) -> (!Id,!*PSt *General)
getPWX :: !*(PSt *General) -> (!FlexId,!*PSt *General)
getPWM :: !*(PSt *General) -> (!FlexId,!*PSt *General)

//-- search stuff

getFBI :: !*(PSt *General) -> (!FindBoxInfo *(PSt *General),!*PSt *General)
setFBI :: !(FindBoxInfo *(PSt *General)) !*(PSt *General) -> *PSt *General

//-- find stuff

getFI :: !*(PSt *General) -> (!FindInfo,!*PSt *General)
setFI :: !FindInfo !*(PSt *General) -> *PSt *General

//-- project path

getProjectFilePath :: !*(PSt *General) -> (!Pathname,!*PSt *General)
setProjectFilePath :: !Pathname !*(PSt *General) -> *PSt *General

//-- startup path

getStup :: !*(PSt *General) -> (!Pathname,!*PSt *General)

//--

getInterrupt :: !*(PSt *General) -> (!(Id,Id),!*PSt *General)
getInterText :: !*(PSt *General) -> (!(Id,Id,[Id]),!*PSt *General)

//-- print setup stuff

getPrintSetup  :: !*(PSt *General) -> (!PrintSetup,!*PSt *General)
setPrintSetup :: !PrintSetup !*(PSt *General) -> *PSt *General

//-- flexible prefixes

getPrefix  :: !*(PSt *General) -> (![String],!*PSt *General)
setPrefix :: !String !*(PSt *General) -> *PSt *General

//-- boolean that indicates if user interaction is allowed

getInteract  :: !*(PSt *General) -> (!Bool,!*PSt *General)
setInteract :: !Bool !*(PSt *General) -> *PSt *General

//-- log functions for batch build

writeLog :: !String !*(PSt *General) -> *PSt *General
abortLog :: !Bool !String !*(PSt *General) -> *PSt *General

getFstate :: !*(PSt *General) -> ([(!Bool,!String)],*(PSt *General))
setFstate :: ![(!Bool,!String)] !*(PSt *General) -> *(PSt *General)
