implementation module colors;

import mac_types;

Index2Color :: !Int !*Toolbox -> (!Int,!Int,!Int,!*Toolbox);
Index2Color index t = code (index=R6D0,t=O0D1U)(red=W,green=W,blue=W,z=Z){
	call	.Index2Color
};