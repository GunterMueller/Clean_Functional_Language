implementation module fonts;

import StdInt;
import mac_types;

GetFontName :: !Int !{#Char} !*Toolbox -> (!{#Char},!*Toolbox);
GetFontName fontNum string256 tb = (GetFontName1 fontNum string256 tb, NewToolbox);

GetFontName1 :: !Int !{#Char} !*Toolbox -> {#Char};
GetFontName1 fontNum string256 t = code (fontNum=D0,string256=U,t=U)(theName=A0){
	instruction 0x3AA00000	|	li		r21,0
	instruction 0x92B70004	|	stw		r21,4(r23)
	instruction 0x38970007	|	addi	r4,r23,7
	call	.GetFontName
};

GetFNum :: !{#Char} !*Toolbox -> (!Int,!*Toolbox);
GetFNum fontName t = code (fontName=R4SD0,t=O0D1U)(theNum=W,z=I2Z){
	call	.GetFNum
};

RealFont :: !Int !Int !*Toolbox -> (!Bool,!*Toolbox);
RealFont fontNum size t = code (fontNum=D0,size=D1,t=U)(is_real_font=B0,z=Z){
	call	.RealFont
};

LMGetApFontID :: !*Toolbox -> (!Int,!*Toolbox);
LMGetApFontID t
	# (s,t) = LMGetApFontID16 t;
	= ((s<<16)>>16,t);

LMGetApFontID16 :: !*Toolbox -> (!Int,!*Toolbox);
LMGetApFontID16 t = code (t=U)(n=D0,z=Z){
	call .LMGetApFontID
};

LMGetSysFontFam :: !*Toolbox -> (!Int,!*Toolbox);
LMGetSysFontFam t
	# (s,t) = LMGetSysFontFam16 t;
	= ((s<<16)>>16,t);
	
LMGetSysFontFam16 :: !*Toolbox -> (!Int,!*Toolbox);
LMGetSysFontFam16 t = code (t=U)(n=D0,z=Z){
	call .LMGetSysFontFam
};

LMGetSysFontSize :: !*Toolbox -> (!Int,!*Toolbox);
LMGetSysFontSize t
	# (s,t) = LMGetSysFontSize16 t;
	= ((s<<16)>>16,t);

LMGetSysFontSize16 :: !*Toolbox -> (!Int,!*Toolbox);
LMGetSysFontSize16 t = code (t=U)(n=D0,z=Z){
	call .LMGetSysFontSize
};
