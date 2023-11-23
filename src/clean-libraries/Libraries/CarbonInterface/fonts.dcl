definition module fonts;

import mac_types;

GetFontName :: !Int !{#Char} !*Toolbox -> (!{#Char},!*Toolbox);
GetFNum		:: !{#Char} !*Toolbox -> (!Int,!*Toolbox);
RealFont	:: !Int !Int !*Toolbox -> (!Bool,!*Toolbox);
LMGetApFontID :: !*Toolbox -> (!Int,!*Toolbox);
LMGetSysFontFam :: !*Toolbox -> (!Int,!*Toolbox);
LMGetSysFontSize :: !*Toolbox -> (!Int,!*Toolbox);
