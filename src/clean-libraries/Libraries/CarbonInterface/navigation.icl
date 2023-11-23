implementation module navigation;

from mac_types import ::Toolbox,::Ptr;
from appleevents import ::AEDescPtr;

import memory;

NavReplyRecordSize:==256;

NavReplyValidRecordOffset:==2;
NavReplySelectionOffset:==6;

NavChooseFolder :: !AEDescPtr !Ptr !Ptr !Ptr !Ptr !Int !*Toolbox -> (!Int,!*Toolbox);
NavChooseFolder defaultLocation reply dialogOptions eventProc filterProc callBackUD t
	= code (defaultLocation=D0,reply=D1,dialogOptions=D2,eventProc=D3,filterProc=D4,callBackUD=D5,t=U)(r=D0,z=Z){
		call .NavChooseFolder
	};

NavGetFile :: !AEDescPtr !Ptr !Ptr !Ptr !Ptr !Ptr !Ptr !Int !*Toolbox -> (!Int,!*Toolbox);
NavGetFile defaultLocation reply dialogOptions eventProc previewProc filterProc typeList callBackUD t
	= code (defaultLocation=D0,reply=D1,dialogOptions=D2,eventProc=D3,previewProc=D4,filterProc=D5,typeList=D6,callBackUD=D7,t=U)(r=D0,z=Z){
		call .NavGetFile
	};

NavPutFile :: !AEDescPtr !Ptr !Ptr !Ptr !Ptr !Int !Int !*Toolbox -> (!Int,!*Toolbox);
NavPutFile defaultLocation reply dialogOptions eventProc fileType fileCreator callBackUD t
	= code (defaultLocation=D0,reply=D1,dialogOptions=D2,eventProc=D3,fileType=D4,fileCreator=D5,callBackUD=D6,t=U)(r=D0,z=Z){
		call .NavPutFile
	};

NavDialogOptionFlagsOffset:==2;
NavDialogOptionSavedFileNameOffset:==1034;

kNavNoTypePopup:==1;

NavGetDefaultDialogOptions :: !*Toolbox -> (!Int,!Int,!*Toolbox);
NavGetDefaultDialogOptions t
	# (options,_,t) = NewPtr 2048 t;
	# (e,t) = navGetDefaultDialogOptions options t;
	= (e,options,t);
{
	navGetDefaultDialogOptions :: !Int !*Toolbox -> (!Int,!*Toolbox);
	navGetDefaultDialogOptions options t = code (options=D0,t=U)(r=D0,z=Z){
		call .NavGetDefaultDialogOptions
	}
}

NavDisposeReply :: !Ptr !*Toolbox -> (!Int,!*Toolbox);
NavDisposeReply reply_record t
	= code (reply_record=D0,t=U)(r=D0,z=Z){
		call .NavDisposeReply
	};
