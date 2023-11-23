implementation module palettes;

import mac_types;

PmForeColor :: !Int !Toolbox -> Toolbox;
PmForeColor dstEntry t = code (dstEntry=D0,t=U)(z=Z){
	call	.PmForeColor
};
