definition module PmCallBack

from IdeState import ::General,::PSt
from StdFile import class FileEnv,class FileSystem
from StdPStClass import instance FileEnv (PSt .a),instance FileSystem (PSt .a)

IF_BATCHBUILD_OR_IDE batchbuild ide:==ide

:: *GeneralSt :== PSt General

start :: !.a !(.Bool -> .(.a -> .(*GeneralSt -> *(.a,*GeneralSt)))) !*GeneralSt -> *GeneralSt
cont :: !*(.a,!*GeneralSt) -> *(.a,!*GeneralSt);
stop :: !*(.a,!*GeneralSt) -> *(.a,!*GeneralSt);
