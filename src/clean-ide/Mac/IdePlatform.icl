implementation module IdePlatform

import StdPSt
import StdArray, StdEnum, StdList
import StdFunc, StdSystem
import PmCleanSystem
import errwin
from IdeState import :: General
import Platform
import Directory,StdMenu,StdBool,files,StdPStClass,memory


toolIconFun :: !String !(Maybe String) !(IdFun .st) ![(ToolbarItem .st)] !*env -> (![(ToolbarItem .st)],!*env) | FileSystem env
toolIconFun bitmapname tooltip toolfun itemlist world
/* Disable for now as toolbars are not implemented yet!
	# bitmappath	= MakeFullPathname BitmapDir bitmapname
	# (bmp,world)	= openBitmap bitmappath world
	# itemlist		= case bmp of
						Nothing		-> itemlist
						Just bmp	-> [ToolbarItem bmp tooltip toolfun:itemlist]
*/
	= (itemlist,world)

PlatformInteractiveInit		:: !*(PSt General) -> *PSt General
PlatformInteractiveInit ps
	= ps

PlatformProcessAttributes :: [ProcessAttribute *(PSt General)]
PlatformProcessAttributes = []

RunProgram :: !.String !*(PSt General) -> *PSt General
RunProgram path ps
	#	(project,ps)	= getProject ps
		ao				= PR_GetApplicationOptions project
		(ps,_)			= Execute updateErrorWindow path ao ps
	= ps

//-- Win only for now ?!

SetWindowIcon :: !Id !Int !(PSt .l) -> PSt .l
SetWindowIcon wId iId ps = ps

SetProcessIcon :: !Int !(PSt .l) -> PSt .l
SetProcessIcon iId ps = ps

ProjectIcon	:== 32513
ImpmodIcon	:== 32516
DefmodIcon	:== 32515
CleanIcon	:== 32512
AbcmodIcon	:== 32514

import osbitmap

getAboutBitmap :: !*env -> (!Maybe Bitmap, !*env) | FileEnv env
getAboutBitmap env
//	= accFiles (openBitmap AboutBitmap) env
	# (ok,osbm,tb)	= osOpenBitmap 128 OSNewToolbox
	| ok
		= (Just (toBitmap osbm), env)
		= (Nothing,env)

AboutBitmap	:== applicationpath "bitmaps:aboutIDE.pict"

findBM		:== "findBM.bmp"
newfBM		:== "newfBM.bmp"
openBM		:== "openBM.bmp"
prntBM		:== "prntBM.bmp"
saveBM		:== "saveBM.bmp"
srchBM		:== "srchBM.bmp"
updtBM		:== "updtBM.bmp"
urunBM		:== "urunBM.bmp"

helpItems :: !Id !Id !*(PSt .a) -> *PSt .a
helpItems wId mId ps
	| not onOSX
		= ps
	# path					= applicationpath "Help"
	# ((ok,path`),ps)		= pd_StringToPath path ps
	| not ok = ps
	# ((err,dir),ps)		= getDirectoryContents path` ps
	| err <> NoDirError = ps
	# items					= map getinfo dir
	= to_menu_items (path+++.{dirseparator}) items mId ps
where
	getinfo {fileName,fileInfo=fi=:{pi_fileInfo=dummyname=:{isDirectory}}}
		= (isDirectory,fileName)
	
	to_menu_items path [] mId ps = ps
	to_menu_items path [(is_dir,filename):rest] mId ps
		| not is_dir
			# item			= MenuItem filename [MenuFunction (noLS (help path filename wId))]
			# (err,ps)		= openSubMenuElements mId 32000 Void item ps
			= to_menu_items path rest mId ps
		| filename == "." || filename == ".."
			= to_menu_items path rest mId ps
		# ((ok,path`),ps)	= pd_StringToPath (path+++.filename) ps
		| not ok
			= to_menu_items path rest mId ps
		# ((err,dir),ps)	= getDirectoryContents path` ps
		| err <> NoDirError
			= to_menu_items path rest mId ps
		# items				= map getinfo dir		// only need common fileinfo...
		# (mId`,ps)			= openId ps
		# item				= SubMenu filename NilLS [MenuId mId`]
		# (err,ps)			= openSubMenuElements mId 32000 Void item ps
		# ps				= to_menu_items (path+++.filename+++.{dirseparator}) items mId` ps
		= to_menu_items path rest mId ps

help path file wId ps
	# path		= path +++. file
	# (error_n,pathSpec,tb)	= FSMakeFSSpec path OSNewToolbox
	| error_n <> 0 = ps
	# (pathRef,error_n,tb)	= NewPtr 80 tb
	| error_n <> 0 = ps
	# (error_n,tb)	= FSpMakeFSRef pathSpec pathRef tb
	| error_n <> 0 = ps
	# (error_n,tb)	= LSOpenFSRef pathRef 0 tb
	| error_n <> 0 = ps
	= ps
where
	FSpMakeFSRef :: !{#Char} !Int !*OSToolbox -> (!Int,!*OSToolbox)
	FSpMakeFSRef _ _ _ = code {
		ccall FSpMakeFSRef "sI:I:I"
		}
	LSOpenFSRef	:: !Int !Int !*OSToolbox -> (!Int,!*OSToolbox)
	LSOpenFSRef _ _ _ = code {
		ccall LSOpenFSRef "II:I:I"
		}

//-- Get EXE_VERSION from 'vers' resource

import pointer, resources, structure
import StdTuple

EXE_VERSION	:: String
EXE_VERSION
	=: fst (read_vers_resource 42)

read_vers_resource :: *Int -> (!String, !*Int);
read_vers_resource t
	# (handle,t)		=	Get1Resource "vers" 1 t
	| handle==0
		=	("no version resource", t);
	# (ptr, t)			=	DereferenceHandle handle t;
	# (size, t)			=	LoadByte (ptr+6) t;
	# (vers, _, t)		=	LoadString 0 size (createArray size '@') (ptr+7) t;
	=	(vers, t);

LoadString :: Int Int *{#Char} Ptr *Toolbox -> (!*{#Char}, Ptr, !*Toolbox);
LoadString n size string ptr t
	| n == size
		=	(string, ptr, t);
	# (char, t)
		=	LoadByte (ptr+n) t;
	=	LoadString (n+1) size {string & [n] = toChar char} ptr t;

