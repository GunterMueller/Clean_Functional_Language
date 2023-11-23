definition module navigation;

from mac_types import :: Toolbox,:: Ptr;
from appleevents import :: AEDescPtr;

NavReplyRecordSize:==256;

NavReplyValidRecordOffset:==2;
NavReplySelectionOffset:==6;

NavDialogOptionFlagsOffset:==2;
NavDialogOptionSavedFileNameOffset:==1034;

kNavNoTypePopup:==1;

NavGetFile :: !AEDescPtr !Ptr !Ptr !Ptr !Ptr !Ptr !Ptr !Int !*Toolbox -> (!Int,!*Toolbox);
NavPutFile :: !AEDescPtr !Ptr !Ptr !Ptr !Ptr !Int !Int !*Toolbox -> (!Int,!*Toolbox);
NavGetDefaultDialogOptions :: !*Toolbox -> (!Int,!Int,!*Toolbox);
NavDisposeReply :: !Ptr !*Toolbox -> (!Int,!*Toolbox);
NavChooseFolder :: !AEDescPtr !Ptr !Ptr !Ptr !Ptr !Int !*Toolbox -> (!Int,!*Toolbox);
