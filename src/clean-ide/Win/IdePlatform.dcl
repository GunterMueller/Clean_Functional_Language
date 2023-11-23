definition module IdePlatform

import	StdPSt, StdString, StdFile
import	StdIOCommon
from	IdeState			import :: General

PlatformInteractiveInit		:: !*(PSt General)	-> *PSt General
PlatformProcessAttributes	:: [ProcessAttribute *(PSt General)]
RunProgram					:: !.String !*(PSt General) -> *PSt General

SetWindowIcon				:: !Id !Int !(PSt .l) -> PSt .l
SetProcessIcon				:: !Int !(PSt .l) -> PSt .l
GetBitmapResource			:: !Int !.env -> (!Maybe Bitmap,!.env)

winInitialiseTooltips		:: !*OSToolbox -> *OSToolbox

CleanIcon	:== 32512
ProjectIcon	:== 32513
AbcmodIcon	:== 32514
DefmodIcon	:== 32515
ImpmodIcon	:== 32516

toolIconFun :: !Int !(Maybe String) !(IdFun .st) ![(ToolbarItem .st)] !.env -> (![(ToolbarItem .st)],!.env)

getAboutBitmap :: !*env -> (!Maybe Bitmap, !*env) | FileEnv env

AboutBitmap	:== 32512
findBM		:== 32513
newfBM		:== 32514
openBM		:== 32515
prntBM		:== 32516
saveBM		:== 32517
srchBM		:== 32518
updtBM		:== 32519
urunBM		:== 32520

helpItems :: !Id !Id !*(PSt .a) -> *PSt .a
