implementation module codefragments;

kPowerPCArch :== 0x70777063; // 'pwpc'

kLoadLib:==1;
kFindLib:==2;
kLoadNewCopy:==3;

kTVectorCFragSymbol :== 2;

import StdArray,StdInt;

/*
Start
	# error_string=createArray 255 ' ';
	# (connection_id,main_address,r)=GetSharedLibrary "InterfaceLib" kPowerPCArch kLoadLib error_string;
	= (connection_id,main_address,r,error_string,FindSymbol connection_id "GetSharedLibrary");
*/

GetSharedLibrary :: !{#Char} !Int !Int !{#Char} -> (!Int,!Int,!Int);
GetSharedLibrary libName archType loadFlags errMessage
	= code (libName=R8SD0,archType=D1,loadFlags=D2,errMessage=O0D3O4D4SD5)(connID=L,mainAddr=L,r=D0){
		call .GetSharedLibrary
	}

FindSymbol :: !Int !{#Char} -> (!Int,!Int,!Int);
FindSymbol cFragConnectionID symName
	# (symAddr,symClass,r) = FindSymbol cFragConnectionID symName;
	= (symAddr,(symClass>>24) bitand 255,r);
{
	FindSymbol :: !Int !{#Char} -> (!Int,!Int,!Int);
	FindSymbol cFragConnectionID symName
		= code (cFragConnectionID=R8D0,symName=O0D2O4D3SD1)(symAddr=L,symClass=L,r=D0){
			call .FindSymbol
		}
}
