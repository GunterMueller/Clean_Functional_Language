implementation module IdeState

import ExtListBox, FilteredListBox
import EdState
import PmPath, PmProject, PmPrefs, PmFileInfo
import clipboard, typewin, fbi, PmAbcMagic, errwin
import flextextcontrol, ioutil, UtilStrictLists
from PmCleanSystem import ::CompilerProcessIds,NoCompilerProcessIds
from StdPStClass import instance FileEnv (PSt .l)
//-- batch build support
from StdProcess import closeProcess
from StdPStClass import class FileSystem, instance FileSystem (PSt .l)
import logfile, PlatformObjectIO

:: InfoDialogInfo =
	{pr_info	:: !Id								// id for info dialog
	,pr_text1	:: !Id								// id for info dialog text
	,pr_text2	:: !Id								// id for info dialog text
	,pr_text3	:: ![Id]							// id for info dialog text
	,pr_trig	:: !Id								// id for interrupt trigger
	}
	
:: *General =
  ! {pr_path	:: !Pathname						// pathname current project
	,pr_stup	:: !Pathname						// startupdirectory

	,pr_idi		:: !InfoDialogInfo
	
	,pr_wwid	:: !Id								// id for proj window
	,pr_xxid	:: !FlexId							// id for exec path text control
	,pr_mmid	:: !FlexId							// id for main mod text control
	,pr_list	:: !ExtListBoxId (PSt General)		// listbox id

	,ed_stat	:: !EditorState						// om editor aan te hangen
	,ed_find	:: !FindInfo						// regular find info
	,fb_info	:: !(FindBoxInfo (PSt General))		// clean-savvy find info
	,er_info	:: !(ErrorInfo (PSt General)) 		// info for error window
	,ed_clip	:: !ClipInfo
	,tw_info	:: !TypeWinInfo
	,cons_info	:: !ConsWinInfo

	,pm_targets	:: ![Target]
	,tg_menuid	:: !Id
	,tg_radioid	:: !Id
	,pm_curtarg :: !Int
	,prefs		:: !Prefs

	,mn_ids		:: !MenuIds
	
	,callback	:: Bool (PSt General) -> (PSt General)
	,abc_cache	:: !*(Maybe ABCCache)
	,fi_cache	:: !(Maybe FileInfoCache)
	
	,print_setup :: !MaybePrintSetup
	
	,project	:: !Project
	,g_compiler_process_ids :: !CompilerProcessIds
	
	, prefix	:: ![String]						// prefixes for add/rem prefix
	, interact	:: Bool
	, logfile	:: *File
	
	, fstate	:: ![(!Bool,!String)]
	}

:: MaybePrintSetup = NoPrintSetup | PrintSetup !PrintSetup;

getFstate :: !*(PSt *General) -> ([(!Bool,!String)],*(PSt *General))
getFstate ps = accPLoc (\l=:{fstate}->(fstate,l)) ps

setFstate :: ![(!Bool,!String)] !*(PSt *General) -> *(PSt *General)
setFstate fs ps = appPLoc (\l->{l & fstate = fs}) ps

getProject :: !*(PSt *General) -> (Project,*(PSt *General))
getProject ps = accPLoc (\l=:{project}->(project,l)) ps

setProject :: !Project !*(PSt *General) -> *(PSt *General)
setProject prj ps = appPLoc (\l->{l & project = prj}) ps

appProject :: (Project -> Project) !*(PSt *General) -> *(PSt *General)
appProject f ps = appPLoc (\l=:{project}->{l & project = f project}) ps

getFromProject :: (Project -> .a) !*(PSt *General) -> (!.a,!*PSt *General)
getFromProject f ps=:{ls={project}}
	= (f project,ps)

getCompilerProcessIds :: !*(PSt *General) -> (!CompilerProcessIds,!*(PSt *General))
getCompilerProcessIds ps = accPLoc (\l -> l!g_compiler_process_ids) ps

setCompilerProcessIds :: !CompilerProcessIds !*(PSt *General) -> *(PSt *General)
setCompilerProcessIds compiler_project_ids ps = appPLoc (\l -> {l & g_compiler_process_ids = compiler_project_ids}) ps
	
::EditMenuLS l =
	{ zfun :: (PSt l) -> PSt l
	, xfun :: (PSt l) -> PSt l
	, cfun :: (PSt l) -> PSt l
	, vfun :: (PSt l) -> PSt l
	}
::MIn l = MGet | MSet (EditMenuLS l)

:: MenuIds =
	{ mn_sav	:: !Id		// File:Save id
	, mn_sva	:: !Id		// File:Save As id
	, mn_rev	:: !Id		// File:Revert id
	, mn_clo	:: !Id		// File:Close id
	, mn_oth	:: !Id		// File:Open Other id
	, mn_odm	:: !Id		// File:Open Definition id
	, mn_oim	:: !Id		// File:Open Implementation id
	, mn_prt	:: !Id		// File:Print id
	, mn_prs	:: !Id		// File:PrintSetup id
	, mn_und	:: !Id		// Edit:Undo id
	, mn_cut	:: !Id		// Edit:Cut id
	, mn_cpy	:: !Id		// Edit:Copy id
	, mn_pst	:: !Id		// Edit:Paste id
	, mn_clr	:: !Id		// Edit:Clear id
	, mg_edt	:: ![Id]	// Edit:tools ids
	, searchIds	:: !SearchMenuIds	// Search: ids
	, pm_menuid	:: !Id		// id of project menu
	, projIds	:: ![Id]	// Project: ids for disabling when no project...
	, pm_listid	:: !Id		// id of project list (in project menu)
	, pm_mrecid :: !R2Id PLMMessage PLMReply	// id of project menu receiver
	, ed_mrecid :: !R2Id (MIn *General) (EditMenuLS *General)	// id of edit menu receiver
	,fh_rid :: !R2Id String [String]	// file history id
	,ph_rid :: !R2Id String [String]	// project history id
	, moduleIds	:: ![Id]	// ids in module menu
	, md_cmp	:: !Id		// Module:Compile
	, md_chk	:: !Id		// Module:Check syntax
	, md_gen	:: !Id		// Module:Generate assembly
	, md_cst	:: !Id		// Module:Compiler settings
	, md_est	:: !Id		// Module:Editor settings
	}

:: SearchMenuIds =
	{ srchIds	:: ![Id]
	, findIds	:: ![Id]
	, gotoIds	:: ![Id]
	, nextIds	:: ![Id]
	}

:: ErrorInfo p =
	{ errorId		:: !Id
	, infoId		:: !FilteredListBoxId
	, err_offset	:: !Vector2
	, err_font		:: !Font
	, err_size		:: !Size
	, err_forg		:: !Colour
	, err_back		:: !Colour
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

//---

iniGeneral :: !Prefs !.Pathname
				Bool *File
				!Id !Id !.(ExtListBoxId *(PSt *General)) !EditorState !.FindInfo
				!.(FindBoxInfo *(PSt *General)) !Id !Id !TypeWinInfo !ConsWinInfo !.[.Target] !Id !Id !(R2Id PLMMessage PLMReply) !*World//*env
				-> *(!ClipInfo,!*General,!*World)
iniGeneral
	prefs stup interact logfile mTargetId eTargetId lbId initEditorState emptyFindInfo ffind
	mEdUndoId mMdEdOptId iniTwi iniCons iniTargets mProjMenuId mProjListId mProjRecId env
	#	(infoId,env)	= openId env
		(text1Id,env)	= openId env
		(text2Id,env)	= openId env
		(text3Ids,env)	= openIds 3 env
		(trigId,env)	= openId env
		(wwId,env)		= openId env
		(xxId,env)		= openFlexId env
		(mmId,env)		= openFlexId env
		(fhId,env)		= openR2Id env
		(phId,env)		= openR2Id env
		(saveId,env)	= openId env
		(saveAsId,env)	= openId env
		(revertId,env)	= openId env
		(closeId,env)	= openId env
		(otherId,env)	= openId env
		(odefId,env)	= openId env
		(oimpId,env)	= openId env
		(printId,env)	= openId env
		(printSetupId,env)	= openId env
		(mEdCutId,env)	= openId env
		(mEdCopyId,env)	= openId env
		(mEdPasteId,env)	= openId env
		(mEdClearId,env)	= openId env
		(edToolsIds,env)	= openIds 10 env
		(mdCmpId,env)	= openId env
		(mdChkId,env)	= openId env
		(mdGenId,env)	= openId env
		(mdCstId,env)	= openId env
		(edmrecid,env)	= openR2Id env
	#	(errinfo,env)	= err_init prefs.err_prefs env
	# (srchIds,env)		= openIds 3 env
	# (findIds,env)		= openIds 4 env
	# (gotoIds,env)		= openIds 3 env
	# (nextIds,env)		= openIds 2 env
	# searchIds =
		{ srchIds = srchIds
		, findIds = findIds
		, gotoIds = gotoIds
		, nextIds = nextIds
		}
	# (projIds,env)		= openIds 17 env
	#	(iniClip,env) 	= initClipInfo mEdUndoId [mEdUndoId, mEdCutId, mEdCopyId, mEdPasteId, mEdClearId: edToolsIds ++ searchIds.findIds ++ searchIds.gotoIds] env
	# idi = 
		{ pr_info = infoId
		, pr_text1 = text1Id
		, pr_text2 = text2Id
		, pr_text3 = text3Ids
		, pr_trig = trigId
		}
	# gen ={ pr_path = ""
		, pr_stup = stup
		, pr_idi  = idi
		, pr_wwid = wwId
		, pr_xxid = xxId
		, pr_mmid = mmId
		, pr_list = lbId
		, ed_stat = initEditorState
		, ed_find = emptyFindInfo
		, fb_info = ffind
		, er_info = errinfo
		, ed_clip = iniClip
		, tw_info = iniTwi
		, cons_info = iniCons
		, pm_targets = iniTargets
		, tg_menuid = mTargetId
		, tg_radioid = eTargetId
		, pm_curtarg = 0
		, prefs = prefs
		, mn_ids =
			{ mn_sav = saveId
			, mn_sva = saveAsId
			, mn_rev = revertId
			, mn_clo = closeId
			, mn_oth = otherId
			, mn_odm = odefId
			, mn_oim = oimpId
			, mn_prt = printId
			, mn_prs = printSetupId
			, mn_und = mEdUndoId
			, mn_cut = mEdCutId
			, mn_cpy = mEdCopyId
			, mn_pst = mEdPasteId
			, mn_clr = mEdClearId
			, mg_edt = edToolsIds
			, searchIds = searchIds
			, pm_menuid = mProjMenuId
			, projIds = projIds
			, pm_listid = mProjListId
			, pm_mrecid = mProjRecId
			, ed_mrecid = edmrecid
			, fh_rid = fhId
			, ph_rid = phId
			, moduleIds	= []			// initially none enabled
			, md_cmp	= mdCmpId		// Module:Compile
			, md_chk	= mdChkId		// Module:Check syntax
			, md_gen	= mdGenId		// Module:Generate assembly
			, md_cst	= mdCstId		// Module:Compiler settings
			, md_est	= mMdEdOptId		// Module:Editor settings
			}
		, callback = (\_ ps -> ps)
		, abc_cache = Just AC_Init
		, fi_cache = Just FI_EmptyCache
		, print_setup = NoPrintSetup
		, project = PR_InitProject
		, g_compiler_process_ids=NoCompilerProcessIds
		, prefix = ["//\t"]
		, interact = interact
		, logfile = logfile
		, fstate = []
		}
	= (iniClip,gen,env)

//---

getABCCache :: !*(PSt *General) -> (*ABCCache,*PSt *General)
getABCCache ps = accPLoc (\p=:{abc_cache = Just abc_cache}->(abc_cache,{p & abc_cache = Nothing})) ps

setABCCache :: !*ABCCache !*(PSt *General) -> *PSt *General
setABCCache ac ps = appPLoc (\p->{p & abc_cache = Just ac}) ps

getFICache :: !*(PSt *General) -> (FileInfoCache,*PSt *General)
getFICache ps = accPLoc (\p=:{fi_cache = Just fi_cache}->(fi_cache,{p & fi_cache = Nothing})) ps

setFICache :: !FileInfoCache !*(PSt *General) -> *PSt *General
setFICache ac ps = appPLoc (\p->{p & fi_cache = Just ac}) ps

getCallback :: !*(PSt *General) -> *(.Bool -> *(PSt *General) -> *(PSt *General),*PSt *General);
getCallback ps = accPLoc (\p=:{callback}->(callback,p)) ps

setCallback :: (Bool -> *(PSt *General) -> *(PSt *General)) !*(PSt *General) -> *PSt *General;
setCallback cb ps = appPLoc (\p->{p & callback = cb}) ps

getFHI :: !*(PSt *General) -> (R2Id String [String],*PSt *General)
getFHI ps = accPLoc (\p=:{mn_ids=mi=:{fh_rid}}->(fh_rid,p)) ps

getPHI :: !*(PSt *General) -> (R2Id String [String],*PSt *General)
getPHI ps = accPLoc (\p=:{mn_ids=mi=:{ph_rid}}->(ph_rid,p)) ps

getMenuIds :: !*(PSt *General) -> (MenuIds,*PSt *General)
getMenuIds ps = accPLoc (\p=:{mn_ids}->(mn_ids,p)) ps

setModuleIds :: ![Id] !*(PSt *General) -> *PSt *General
setModuleIds ids ps = appPLoc (\p=:{mn_ids}->{p & mn_ids = {mn_ids & moduleIds = ids}}) ps

getEditRecId :: !*(PSt *General) -> *(R2Id (MIn *General) (EditMenuLS *General),*PSt *General)
getEditRecId ps = accPLoc (\p=:{mn_ids=mi=:{ed_mrecid}}->(ed_mrecid,p)) ps

setPrefs :: Prefs !*(PSt *General) -> *PSt *General
setPrefs p ps = appPLoc (\l->{l&prefs=p}) ps

getPrefs :: !*(PSt *General) -> (Prefs,*PSt *General)
getPrefs ps = accPLoc (\l=:{prefs}->(prefs,l)) ps

::PLMMessage
	= Add {#Char}
	| Rem {#Char}
	| Get

::PLMReply
	:== [{#Char}]

getPMI :: !*(PSt *General) -> ((Id,Id),*PSt *General)
getPMI ps = accPLoc (\l=:{mn_ids=mi=:{pm_menuid,pm_listid}}->((pm_menuid,pm_listid),l)) ps

getPMR :: !*(PSt *General) -> (R2Id PLMMessage PLMReply,*PSt *General)
getPMR ps = accPLoc (\l=:{mn_ids=mi=:{pm_mrecid}}->(pm_mrecid,l)) ps

getTargetIds :: !*(PSt *General) -> ((!Id,!Id),!*PSt *General)
getTargetIds ps = accPLoc (\p=:{tg_menuid,tg_radioid}->((tg_menuid,tg_radioid),p)) ps

getFBI :: !*(PSt *General) -> (!FindBoxInfo *(PSt *General),!*PSt *General)
getFBI ps = accPLoc (\p=:{fb_info}->(fb_info,p)) ps

setFBI :: !(FindBoxInfo *(PSt *General)) !*(PSt *General) -> *PSt *General
setFBI ts ps = appPLoc (\p->{p & fb_info = ts}) ps

setErrInfo :: !(ErrorInfo (PSt *General)) !*(PSt *General) -> *PSt *General
setErrInfo ei ps = appPLoc (\p->{p & er_info = ei}) ps

getErrInfo :: !*(PSt *General) -> (!(ErrorInfo (PSt *General)),!*PSt *General)
getErrInfo ps = accPLoc (\p=:{er_info}->(er_info,p)) ps

getPWI :: !*(PSt *General) -> (!ExtListBoxId (PSt General),!*PSt *General)
getPWI ps = accPLoc (\p=:{pr_list}->(pr_list,p)) ps

setPWI :: !(ExtListBoxId (PSt General)) !*(PSt *General) -> *PSt *General
setPWI ei ps = appPLoc (\p->{p & pr_list = ei}) ps

getPWW :: !*(PSt *General) -> (!Id,!*PSt *General)
getPWW ps = accPLoc (\p=:{pr_wwid}->(pr_wwid,p)) ps

getPWX :: !*(PSt *General) -> (!FlexId,!*PSt *General)
getPWX ps = accPLoc (\p=:{pr_xxid}->(pr_xxid,p)) ps

getPWM :: !*(PSt *General) -> (!FlexId,!*PSt *General)
getPWM ps = accPLoc (\p=:{pr_mmid}->(pr_mmid,p)) ps

getFI :: !*(PSt *General) -> (!FindInfo,!*PSt *General)
getFI ps = accPLoc (\p=:{ed_find}->(ed_find,p)) ps

setFI :: !FindInfo !*(PSt *General) -> *PSt *General
setFI ei ps = appPLoc (\p->{p & ed_find = ei}) ps

getProjectFilePath :: !*(PSt *General) -> (!Pathname,!*PSt *General)
getProjectFilePath ps = accPLoc (\p=:{General | pr_path}->(pr_path,p)) ps

setProjectFilePath :: !Pathname !*(PSt *General) -> *PSt *General
setProjectFilePath ts ps = appPLoc (\p->{General | p & pr_path = ts}) ps

getStup :: !*(PSt *General) -> (!Pathname,!*PSt *General)
getStup ps = accPLoc (\p=:{pr_stup}->(pr_stup,p)) ps

getInterrupt :: !*(PSt *General) -> (!(Id,Id),!*PSt *General)
getInterrupt ps = accPLoc (\p=:{pr_idi}->((pr_idi.pr_info,pr_idi.pr_trig),p)) ps

getInterText :: !*(PSt *General) -> (!(Id,Id,[Id]),!*PSt *General)
getInterText ps = accPLoc (\p=:{pr_idi}->((pr_idi.pr_text1,pr_idi.pr_text2,pr_idi.pr_text3),p)) ps

getTargets :: !*(PSt *General) -> (![Target],!*PSt *General)
getTargets ps = accPLoc (\p=:{pm_targets}->(pm_targets,p)) ps

setTargets :: ![Target] !*(PSt *General) -> *PSt *General
setTargets ts ps = appPLoc (\p->{p & pm_targets = ts}) ps

getCurrentTarget :: !*(PSt *General) -> (!Int,!*PSt *General)
getCurrentTarget ps = accPLoc (\p=:{pm_curtarg}->(pm_curtarg,p)) ps

setCurrentTarget :: !Int !*(PSt *General) -> *PSt *General
setCurrentTarget tg ps
	= appPLoc (\p->{p & pm_curtarg = tg}) ps

getCurrentPaths :: !*(PSt *General) -> (!(List Pathname),!*PSt *General)
getCurrentPaths ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_path,ps)

getCurrentDlibs :: !*(PSt *General) -> (!(List String),!*PSt *General)
getCurrentDlibs ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_libs,ps)

getCurrentSlibs :: !*(PSt *General) -> (!(List String),!*PSt *General)
getCurrentSlibs ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_stat,ps)

getCurrentObjts :: !*(PSt *General) -> (!(List String),!*PSt *General)
getCurrentObjts ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_objs,ps)

getCurrentComp :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentComp ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_comp,ps)

getCurrentCgen :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentCgen ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_cgen,ps)

getCurrentAbcOpt :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentAbcOpt ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_abcopt,ps)

getCurrentBCgen :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentBCgen ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_bcgen,ps)

getCurrentBClink :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentBClink ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_bclink,ps)

getCurrentBCstrip :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentBCstrip ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_bcstrip,ps)

getCurrentBCprelink :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentBCprelink ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_bcprelink,ps)

getCurrentLink :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentLink ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_link,ps)

getCurrentDynl :: !*(PSt *General) -> (!String,!*PSt *General)
getCurrentDynl ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_dynl,ps)

getCurrentVers :: !*(PSt *General) -> (!Int,!*PSt *General)
getCurrentVers ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_vers,ps)

getCurrent64BitProcessor :: !*(PSt *General) -> (!Bool,!*PSt *General)
getCurrent64BitProcessor ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.env_64_bit_processor,ps)

getCurrentRedc :: !*(PSt *General) -> (!Bool,!*PSt *General)
getCurrentRedc ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_redc,ps)

getCurrentProc :: !*(PSt *General) -> (!Processor,!*PSt *General)
getCurrentProc ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_proc,ps)

getCurrentMeth :: !*(PSt *General) -> (!CompileMethod,!*PSt *General)
getCurrentMeth ps
	# (ct,ps) = accPLoc (\p=:{pm_targets,pm_curtarg}->(pm_targets!!pm_curtarg,p)) ps
	= (ct.target_meth,ps)

instance Editor General
where
	setEditorState es gen = {gen & ed_stat = es}
	getEditorState gen=:{ed_stat} = (ed_stat,gen)

instance Clipper General
where
	getClipInfo gen=:{ed_clip} = (ed_clip,gen)
	setClipInfo ci gen = {gen & ed_clip = ci}

instance Typer General
where
	getTypeWinInfo gen=:{tw_info} = (tw_info,gen)
	setTypeWinInfo ti gen = {gen & tw_info = ti}

//--

getPrintSetup  :: !*(PSt *General) -> (!PrintSetup,!*PSt *General)
getPrintSetup ps=:{ls={print_setup=PrintSetup print_setup}}
	= (print_setup,ps);
getPrintSetup ps=:{ls={print_setup=NoPrintSetup}}
	# (default_setup,ps) = defaultPrintSetup ps
	= (default_setup,{ps & ls.print_setup = PrintSetup default_setup});

setPrintSetup :: !PrintSetup !*(PSt *General) -> *PSt *General
setPrintSetup s ps = {ps & ls.print_setup = PrintSetup s};

getPrefix  :: !*(PSt *General) -> (![String],!*PSt *General)
getPrefix ps = accPLoc (\p=:{prefix}->(prefix,p)) ps

setPrefix :: !String !*(PSt *General) -> *PSt *General
setPrefix s ps = appPLoc (\p=:{prefix}->{p & prefix = removeDup [s:prefix]}) ps

getInteract  :: !*(PSt *General) -> (!Bool,!*PSt *General)
getInteract ps = accPLoc (\p=:{interact}->(interact,p)) ps 

setInteract :: !Bool !*(PSt *General) -> *PSt *General
setInteract interact ps = appPLoc (\p=:{interact}->{p & interact = interact}) ps


writeLog :: !String !*(PSt *General) -> *PSt *General
writeLog message ps
	= appPLoc (\ls=:{logfile} -> {ls & logfile = writeLogfile message logfile}) ps

abortLog :: !Bool !String !*(PSt *General) -> *PSt *General
abortLog flag message ps
	# ps		= case message of
					""	-> ps
					_	-> appPLoc (\ls=:{logfile} -> {ls & logfile = writeLogfile message logfile}) ps
	# (lf,ps)	= accPLoc (\ls=:{logfile} -> (logfile,{ls & logfile = stderr})) ps
	# (ok,ps)	= closeLogfile lf ps
//	| not ok ...
	# ps = case flag of
		True	-> pAbort ps
		_		-> ps
	= closeProcess ps

//-- Console support...

import conswin

instance Consoler General
where
	getConsWinInfo gen=:{cons_info} = (cons_info,gen)
	setConsWinInfo ti gen = {gen & cons_info = ti}
