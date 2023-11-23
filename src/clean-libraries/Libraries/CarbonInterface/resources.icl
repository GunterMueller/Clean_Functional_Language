implementation module resources;

from mac_types import ::Handle,::Toolbox;

HOpenResFile :: !Int !Int !{#Char} !Int !*Toolbox -> (!Int,!*Toolbox);
HOpenResFile vRefNum dirID fileName permission t
= code (vRefNum=D0,dirID=D1,fileName=SD2,permission=D3,t=U)(refNum=D0,t2=Z){
	call	.HOpenResFile
}

HCreateResFile :: !Int !Int !{#Char} !*Toolbox -> *Toolbox;
HCreateResFile vRefNum dirID fileName t = code (vRefNum=D0,dirID=D1,fileName=SD2,t=U)(t2=Z){
	call	.HCreateResFile
}

CloseResFile :: !Int !*Toolbox -> *Toolbox;
CloseResFile refNum t = code (refNum=D0,t=U)(t2=Z){
	call	.CloseResFile
}

AddResource :: !Handle !{#Char} !Int !{#Char} !*Toolbox -> *Toolbox;
AddResource theData theType theID name t = code (theData=D0,theType=U,theID=D2,name=SD3,t=U)(t2=Z){
	instruction 0x80960008	|	lwz	r4,8(r22)
	call	.AddResource
}

ResError :: !*Toolbox -> (!Int,!*Toolbox);
ResError t = code (t=U)(res_error=D0,t2=Z){
	call	.ResError
}

Get1Resource :: !{#Char} !Int !*Toolbox -> (!Handle,!*Toolbox);
Get1Resource theType index t = code (theType=U,index=D1,t=U)(handle=D0,t2=Z){
	instruction 0x80770008	|	lwz	r3,8(r23)
	call	.Get1Resource
}

RemoveResource :: !Handle !*Toolbox -> *Toolbox;
RemoveResource handle t = code (handle=D0,t=U)(t2=Z){
	call	.RemoveResource
}
