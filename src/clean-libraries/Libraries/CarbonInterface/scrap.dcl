definition module scrap;

import mac_types;

:: ScrapRef:==Int;
:: ScrapFlavorType:==Int;
:: ScrapFlavorFlags:==Int;

ScrapFlavorTypeText :== 0x54455854;		// 'TEXT'
ScrapFlavorTypePict :== 0x50494354;		// 'PICT'

ScrapFlavorMaskNone :== 0;
ScrapFlavorMaskSenderOnly :== 1;
ScrapFlavorMaskTranslated :== 2;

NoScrapErr			:==	-100;			// desk scrap isn't initialized
NoTypeErr			:==	-102;			// no data of the requested type
NoMemErr			:== -108;			// not enough memory

GetCurrentScrap :: !*Toolbox -> (!Int,!ScrapRef,!*Toolbox);
GetScrapFlavorFlags :: !ScrapRef !ScrapFlavorType !*Toolbox -> (!Int,!ScrapFlavorFlags,!*Toolbox);
GetScrapFlavorSize :: !ScrapRef !ScrapFlavorType !*Toolbox -> (!Int,!Int,!*Toolbox);
GetScrapFlavorData :: !ScrapRef !ScrapFlavorType !Int !*Toolbox -> (!Int,!Int,!{#Char},!*Toolbox);
ClearCurrentScrap :: !*Toolbox -> (!Int,!*Toolbox);
PutScrapFlavor :: !ScrapRef !ScrapFlavorType !ScrapFlavorFlags !{#Char} !*Toolbox -> (!Int,!*Toolbox);
