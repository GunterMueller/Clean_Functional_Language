implementation module scrap;

import StdArray;
import mac_types;

:: ScrapRef:==Int;
:: ScrapFlavorType:==Int;
:: ScrapFlavorFlags:==Int;

ScrapFlavorTypeText :== 0x54455854;		// 'TEXT'
ScrapFlavorTypePict :== 0x50494354;		// 'PICT'

ScrapFlavorMaskNone :== 0;
ScrapFlavorMaskSenderOnly :== 1;
ScrapFlavorMaskTranslated :== 2;
    
NoScrapErr	:==	-100;		// desk scrap isn't initialized
NoTypeErr	:==	-102;		// no data of the requested type

GetCurrentScrap :: !*Toolbox -> (!Int,!ScrapRef,!*Toolbox);
GetCurrentScrap tb = code (tb=R4O0D0U)(r=D0,scrap_ref=L,z=Z){
	call .GetCurrentScrap
 }

GetScrapFlavorFlags :: !ScrapRef !ScrapFlavorType !*Toolbox -> (!Int,!ScrapFlavorFlags,!*Toolbox);
GetScrapFlavorFlags scrap_ref flavor_type tb = code (scrap_ref=D0,flavor_type=D1,tb=R4O0D2U)(r=D0,flavor_flags=L,z=Z){
	call .GetScrapFlavorFlags
 }

GetScrapFlavorSize :: !ScrapRef !ScrapFlavorType !*Toolbox -> (!Int,!Int,!*Toolbox);
GetScrapFlavorSize scrap_ref flavor_type tb = code (scrap_ref=D0,flavor_type=D1,tb=R4O0D2U)(r=D0,size=L,z=Z){
	call .GetScrapFlavorSize
 }

GetScrapFlavorData :: !ScrapRef !ScrapFlavorType !Int !*Toolbox -> (!Int,!Int,!{#Char},!*Toolbox);
GetScrapFlavorData scrap_ref flavor_type size tb
	# data_string=createArray size '@';
	# (r,size_out,tb) = GetScrapFlavorData1 scrap_ref flavor_type size data_string tb;
	= (r,size_out,data_string,tb);

GetScrapFlavorData1 :: !ScrapRef !ScrapFlavorType !Int !{#Char} !*Toolbox -> (!Int,!Int,!*Toolbox);
GetScrapFlavorData1 scrap_ref flavor_type size data_string tb
 = code (scrap_ref=D0,flavor_type=D1,size=L,data_string=O0D2CD3,tb=U)(r=D0,size_out=L,z=Z){
	call .GetScrapFlavorData
 }

ClearCurrentScrap :: !*Toolbox -> (!Int,!*Toolbox);
ClearCurrentScrap tb = code (tb=U)(r=D0,z=Z){
	call .ClearCurrentScrap
 };

PutScrapFlavor :: !ScrapRef !ScrapFlavorType !ScrapFlavorFlags !{#Char} !*Toolbox -> (!Int,!*Toolbox);
PutScrapFlavor scrap_ref flavor_type flavor_flags data tb
 = code (scrap_ref=D0,flavor_type=D1,flavor_flags=D2,data=CD4S3,tb=U)(r=D0,z=Z){
 	call .PutScrapFlavor
 }
