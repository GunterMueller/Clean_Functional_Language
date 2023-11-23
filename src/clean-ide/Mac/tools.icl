implementation module tools

import StdBool, StdFunc, StdFile, StdPStClass, StdSystem, StdInt
import ExtNotice, StdPathname, PmPath
import IdeState, UtilIO

//-- call out to supporting applications...

timepsuf	=: " Time Profile"
timeparg	=: " -h 4M "

heappsuf	=: " Heap Profile0"
heapparg	=: " -h 4M "

proofsuf	=: ".prj"
proofarg	=: " "

TimeProfileCode	:== 0x50525449	// 'PRTI'
HeapProfileCode	:== 0x50524850	// 'PRHP'
SparkleCode		:== 0x50505050	// 'PPPP'	FIXME: Maarten should register a creator code...

shoprofun :: !*(PSt General) -> *PSt General
shoprofun ps
	# (prj,ps)		= getProject ps
	# execpath		= PR_GetExecPath prj
	# ({reg_prefs={tp_path,tp_name}},ps) = getPrefs ps
	# (app_path,ps) = accFiles GetFullApplicationPath ps
	# apppath = fulAppPath app_path tp_path+++tp_name
	# docpath		= execpath +++ timepsuf
	# (err,ps)		= LaunchTheDocument
						docpath
						apppath
						TimeProfileCode
						ps
	| err <> 0
		= openNotice (Notice ["Unable to launch " +++  apppath +++ ".",docpath,toString err] (NoticeButton "OK" id) []) ps
	= ps
/*
	# (prj,ps)		= getProject ps
	# execpath		= PR_GetExecPath prj
	// approximate name mangling done by RTE
	// should still take into account max filename length
	# profpath		= quoted_string (RemoveSuffix` execpath +++ timepsuf)
	# (prefs,ps)	= getPrefs ps
	# timepapp		= quoted_string (prefs.reg_prefs.tp_path +++ prefs.reg_prefs.tp_name)
	# sp			= timepapp +++ timeparg +++ profpath
	# stup			= RemoveFilename execpath
	# (ok,ps)		= accFiles (FExists stup) ps
	# stup			= if ok (stup +++ "\\") (applicationpath "")
	# (ok,ps)		= accFiles (LaunchApplication sp stup False) ps
	| not ok
		= openNotice (Notice ["Unable to launch " +++  sp +++ ".",stup] (NoticeButton "OK" id) []) ps
	= ps
*/

shoheapfun :: !*(PSt General) -> *PSt General
shoheapfun ps
	# (prj,ps)		= getProject ps
	# execpath		= PR_GetExecPath prj
	# ({reg_prefs={hp_path,hp_name}},ps) = getPrefs ps
	# (app_path,ps) = accFiles GetFullApplicationPath ps
	# apppath = fulAppPath app_path hp_path+++hp_name
	# docpath		= execpath +++ heappsuf
	# (err,ps)		= LaunchTheDocument
						docpath
						apppath
						HeapProfileCode
						ps
	| err <> 0
		= openNotice (Notice ["Unable to launch " +++  apppath +++ ".",docpath,toString err] (NoticeButton "OK" id) []) ps
	= ps
/*
	# (prj,ps)		= getProject ps
	# execpath		= PR_GetExecPath prj
	// approximate name mangling done by RTE
	// should still take into account max filename length
	# profpath		= quoted_string (RemoveSuffix` execpath +++ heappsuf)
	# (prefs,ps)	= getPrefs ps
	# heappapp		= quoted_string (prefs.reg_prefs.hp_path +++ prefs.reg_prefs.hp_name)
	# sp			= heappapp +++  heapparg +++  profpath
	# stup			= RemoveFilename execpath
	# (ok,ps)		= accFiles (FExists stup) ps
	# stup			= if ok (stup +++ "\\") (applicationpath "")
	# (ok,ps)		= accFiles (LaunchApplication sp stup False) ps
	| not ok
		= openNotice (Notice ["Unable to launch " +++  sp +++ ".",stup] (NoticeButton "OK" id) []) ps
	= ps
*/
provefun :: !*(PSt General) -> *PSt General
provefun ps
	# (pathname,ps) = getPath ps
	# ({reg_prefs={pr_path,pr_name}},ps) = getPrefs ps
	# (app_path,ps) = accFiles GetFullApplicationPath ps
	# apppath = fulAppPath app_path pr_path+++pr_name
	# docpath		= RemoveSuffix` pathname +++ proofsuf
	# (err,ps)		= LaunchTheDocument
						docpath
						apppath
						SparkleCode
						ps
	| err <> 0
		= openNotice (Notice ["Unable to launch " +++  apppath +++ ".",docpath,toString err] (NoticeButton "OK" id) []) ps
	= ps
/*
	# (pathname,ps) = getPath ps
	# pr_path		= quoted_string (RemoveSuffix` pathname +++. proofsuf)
	# (prefs,ps)	= getPrefs ps
	# proofapp		= quoted_string (prefs.reg_prefs.pr_path +++ prefs.reg_prefs.pr_name)
	# cps			= proofapp +++ proofarg +++ pr_path
	# stup			= RemoveFilename pathname
	# (ok,ps)		= accFiles (FExists stup) ps
	# stup			= if ok (stup +++ "\\") (applicationpath "")
	# (ok,ps)		= accFiles (LaunchApplication cps stup False) ps
	| not ok
		= openNotice (Notice ["Unable to launch " +++  cps +++ "."] (NoticeButton "OK" id) []) ps
	= ps
*/

:: ToolInfo = ToolInfo

toolData :: !.Prefs !*(PSt General) -> *(!.ToolInfo,!*PSt General)
toolData prefs ps
	= (ToolInfo,ps)
toolOptions :: !.ToolInfo -> NilLS .a *(PSt General)
toolOptions ti
	= NilLS
