implementation module notification;

import mac_types;

::	NMRecPtr :== Int;

NMInstall :: !NMRecPtr !Toolbox -> (!Int,!Toolbox);
NMInstall nmReqPtr t = code (nmReqPtr=D0,t=U)(r=D0,z=Z){
	call	.NMInstall
};

NMRemove :: !NMRecPtr !Toolbox -> (!Int,!Toolbox);
NMRemove nmReqPtr t = code (nmReqPtr=D0,t=U)(r=D0,z=Z){
	call	.NMRemove
};
