implementation module palette;

import mac_types;

NewPalette :: !Int !Int !Int !Int !Toolbox -> Toolbox;
NewPalette entries srcColors srcUsage srcTolerance t
= code (entries=D0,srcColors=D1,srcUsage=D2,srcTolerance=D3,t=U)(z=Z){
	call	.NewPalette
};

DisposePalette :: !Int !Toolbox -> Toolbox;
DisposePalette srcPalette t = code (srcPalette=D0,t=U)(z=Z){
	call	.DisposePalette
};

ActivatePalette :: !WindowPtr !Toolbox -> Toolbox;
ActivatePalette srcWindow t = code (srcWindow=D0,t=U)(z=Z){
	call	.ActivatePalette
};

SetPalette :: !WindowPtr !Int !Bool !Toolbox -> Toolbox;
SetPalette dstWindow srcPalette cUpdates t = code (dstWindow=D0,srcPalette=D1,cUpdates=D2,t=U)(z=Z){
	call	.SetPalette
};

GetPalette :: !WindowPtr !Toolbox -> (!Int, !Toolbox);
GetPalette srcWindow t = code (srcWindow=D0,t=U)(palette=D0,z=Z){
	call	.GetPalette
};
	
SetEntryColor :: !Int !Int !(!Int,!Int,!Int) !Toolbox -> Toolbox;
SetEntryColor dstPalette dstEntry (red,green,blue) t
= code (blue=W,green=W,red=W,dstPalette=D0,dstEntry=D1,t=O0D2U)(z=I6Z){
	call	.SetEntryColor
};
