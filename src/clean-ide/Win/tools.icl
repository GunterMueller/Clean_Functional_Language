implementation module tools

import StdBool, StdFunc, StdFile, StdPStClass, StdSystem
import ExtNotice, StdPathname
import IdeState, UtilIO, UtilObjectIO, PmPath, projwin

//-- call out to supporting applications...

timepsuf	=: " Time Profile.pcl"
timeparg	=: " "

heappsuf	=: " Heap Profile0.hcl"
heapparg	=: " "

proofsuf	=: ".prj"
proofarg	=: " "

shoprofun :: !*(PSt General) -> *PSt General
shoprofun ps
	# (prj,ps)		= getProject ps
	# execpath		= PR_GetExecPath prj
	// approximate name mangling done by RTE
	// should still take into account max filename length
	# profpath		= quoted_string (RemoveSuffix` execpath +++ timepsuf)
	# (prefs,ps)	= getPrefs ps

	# pcl_path				= prefs.reg_prefs.tp_path
	# (app_path,ps)			= accFiles GetFullApplicationPath ps
	# app_path				= GetLongPathName app_path
	# pcl_path				= fulAppPath app_path pcl_path
	# pcl_path				= case GetShortPathName pcl_path of
								(True,pcl_path)	-> pcl_path
								_				-> pcl_path

	# timepapp		= quoted_string (pcl_path +++ prefs.reg_prefs.tp_name)
	# sp			= timepapp +++ timeparg +++ profpath
	# stup			= RemoveFilename execpath
	# (ok,ps)		= accFiles (FExists stup) ps
	# stup			= if ok (stup +++ "\\") (applicationpath "")
	# (ok,ps)		= accFiles (LaunchApplication sp stup False) ps
	| not ok
		= openNotice (Notice ["Unable to launch " +++  sp +++ ".",stup] (NoticeButton "OK" id) []) ps
	= ps

shoheapfun :: !*(PSt General) -> *PSt General
shoheapfun ps
	# (prj,ps)		= getProject ps
	# execpath		= PR_GetExecPath prj
	// approximate name mangling done by RTE
	// should still take into account max filename length
	# profpath		= quoted_string (RemoveSuffix` execpath +++ heappsuf)
	# (prefs,ps)	= getPrefs ps

	# pcl_path				= prefs.reg_prefs.hp_path
	# (app_path,ps)			= accFiles GetFullApplicationPath ps
	# app_path				= GetLongPathName app_path
	# pcl_path				= fulAppPath app_path pcl_path
	# pcl_path				= case GetShortPathName pcl_path of
								(True,pcl_path)	-> pcl_path
								_				-> pcl_path

	# heappapp		= quoted_string (pcl_path +++ prefs.reg_prefs.hp_name)
	# sp			= heappapp +++  heapparg +++  profpath
	# stup			= RemoveFilename execpath
	# (ok,ps)		= accFiles (FExists stup) ps
	# stup			= if ok (stup +++ "\\") (applicationpath "")
	# (ok,ps)		= accFiles (LaunchApplication sp stup False) ps
	| not ok
		= openNotice (Notice ["Unable to launch " +++  sp +++ ".",stup] (NoticeButton "OK" id) []) ps
	= ps

provefun :: !*(PSt General) -> *PSt General
provefun ps
	# ps			= pm_save ps	// ensure project file is recent...
	
	# (pathname,ps) = getProjectFilePath ps
	# pr_path		= quoted_string (RemoveSuffix` pathname +++. proofsuf)
	# (prefs,ps)	= getPrefs ps

	# pcl_path				= prefs.reg_prefs.pr_path
	# (app_path,ps)			= accFiles GetFullApplicationPath ps
	# app_path				= GetLongPathName app_path
	# pcl_path				= fulAppPath app_path pcl_path
	# pcl_path				= case GetShortPathName pcl_path of
								(True,pcl_path)	-> pcl_path
								_				-> pcl_path

	# proofapp		= quoted_string (pcl_path +++ prefs.reg_prefs.pr_name)
	# cps			= proofapp +++ proofarg +++ pr_path
	# stup			= RemoveFilename pathname
	# (ok,ps)		= accFiles (FExists stup) ps
	# stup			= if ok (stup +++ "\\") (applicationpath "")
	# (ok,ps)		= accFiles (LaunchApplication cps stup False) ps
	| not ok
		= openNotice (Notice ["Unable to launch " +++  cps +++ "."] (NoticeButton "OK" id) []) ps
	= ps

:: ToolInfo =
	{ tpId			:: !Id
	, tpString		:: !String
	, hpId			:: !Id
	, hpString		:: !String
	, prId			:: !Id
	, prString		:: !String
	}

toolData :: !.Prefs !*(PSt General) -> *(!.ToolInfo,!*PSt General)
toolData prefs ps
	# (tpId,ps)		= openId ps
	# (hpId,ps)		= openId ps
	# (prId,ps)		= openId ps
	# iniTPString	= prefs.reg_prefs.tp_path +++ prefs.reg_prefs.tp_name
	# iniHPString	= prefs.reg_prefs.hp_path +++ prefs.reg_prefs.hp_name
	# iniPRString	= prefs.reg_prefs.pr_path +++ prefs.reg_prefs.pr_name
	# ti			=
						{ tpId			= tpId
						, tpString		= iniTPString
						, hpId			= hpId
						, hpString		= iniHPString
						, prId			= prId
						, prString		= iniPRString
						}
	= (ti,ps)


toolOptions :: !.ToolInfo -> (:+: .TextControl (:+: .EditControl (:+: .ButtonControl (:+: .TextControl (:+: .EditControl (:+: .ButtonControl (:+: .TextControl (:+: .EditControl (:+: .ButtonControl .ButtonControl)))))))) .a *(PSt *General))
toolOptions ti=:{tpId,tpString,hpId,hpString,prId,prString} 
	=	TextControl "Time Profiler:" [ControlPos (Left,zero),ControlWidth (ContentWidth "Theorem Prover:")]
	:+: EditControl tpString (PixelWidth 300) 1 [ControlId tpId,ControlSelectState Unable]
	:+: ButtonControl "Select..." [ControlFunction (noLS (setTP tpId))]
	:+: TextControl "Heap Profiler:" [ControlPos (Left,zero),ControlWidth (ContentWidth "Theorem Prover:")]
	:+: EditControl hpString (PixelWidth 300) 1 [ControlId hpId,ControlSelectState Unable]
	:+: ButtonControl "Select..." [ControlFunction (noLS (setHP hpId))]
	:+: TextControl "Theorem Prover:" [ControlPos (Left,zero),ControlWidth (ContentWidth "Theorem Prover:")]
	:+: EditControl prString (PixelWidth 300) 1 [ControlId prId,ControlSelectState Unable]
	:+: ButtonControl "Select..." [ControlFunction (noLS (setPR prId))]
	:+: ButtonControl "Clear Registry" [ControlPos (Left,zero),ControlFunction (noLS clearRegistry)]


//import dodebug
import first_run, PmPath, StdList

setTP tpId ps
	# (prefs,ps)	= getPrefs ps
	# (result,ps)	= selectOutputFile` "Select time profiler" "*.exe" "Set" ps
	| isNothing result = ps
	# full			= fromJust result
	# name			= GetFileName full
	# short			= case GetShortPathName full of
						(True,short)	-> short
						_				-> full
	# rpath			= GetFilePath short
	# (app_path,ps)	= getStup ps
	# spath			= symAppPath app_path (GetFilePath full)
	# ps			= appPIO (setControlText tpId (spath +++ name)) ps
	# prefs			= {prefs & reg_prefs.tp_name = name, reg_prefs.tp_path = spath}
	# ps			= setPrefs prefs ps
	# (ide_name,ide_path,errs)
					= get_ide_from_registry
	| not (isEmpty errs) || ide_name == "" || ide_path == "" = ps
	# errs			= change_pcl_registry_fun ide_name ide_path name rpath
	| errs == []	= ps
	= ps

setHP hpId ps
	# (prefs,ps)	= getPrefs ps
	# (result,ps)	= selectOutputFile` "Select heap profiler" "*.exe" "Set" ps
	| isNothing result = ps
	# full			= fromJust result
	# name			= GetFileName full
	# short			= case GetShortPathName full of
						(True,short)	-> short
						_				-> full
	# rpath			= GetFilePath short
	# (app_path,ps)	= getStup ps
	# spath			= symAppPath app_path (GetFilePath full)
	# ps			= appPIO (setControlText hpId (spath +++ name)) ps
	# prefs			= {prefs & reg_prefs.hp_name = name, reg_prefs.hp_path = spath}
	# ps			= setPrefs prefs ps
	# (ide_name,ide_path,errs)
					= get_ide_from_registry
	| not (isEmpty errs) || ide_name == "" || ide_path == "" = ps
	# errs			= change_hcl_registry_fun ide_name ide_path name rpath
	| errs == []	= ps
	= ps

setPR prId ps
	# (prefs,ps)	= getPrefs ps
	# (result,ps)	= selectOutputFile` "Select theorem prover" "*.exe" "Set" ps
	| isNothing result = ps
	# full			= fromJust result
	# name			= GetFileName full
	# short			= case GetShortPathName full of
						(True,short)	-> short
						_				-> full
	# rpath			= GetFilePath short
	# (app_path,ps)	= getStup ps
	# spath			= symAppPath app_path (GetFilePath full)
	# ps			= appPIO (setControlText prId (spath +++ name)) ps
	# prefs			= {prefs & reg_prefs.pr_name = name, reg_prefs.pr_path = spath}
	= setPrefs prefs ps

clearRegistry ps
	# (errs,ps)		= uninstall ps
	| errs == [] = ps
	# (okId,ps)		= openId ps
	# (dlogId,ps)	= openId ps
	# (_,ps)		= openModalDialog Void (Dialog "Clear Registry errors"
						(	TextControl "Clear Registry produced an error:"	[]
						:+:	TextControl (hd errs) [ControlPos (Left,zero)]
						:+: ButtonControl "OK" [ControlId okId,ControlFunction (noLS (closeWindow dlogId))]) 
						[WindowOk okId,WindowId dlogId]) ps
	= ps
