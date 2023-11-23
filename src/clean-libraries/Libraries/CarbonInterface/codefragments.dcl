definition module codefragments;

kPowerPCArch :== 0x70777063; // 'pwpc'

kLoadLib:==1;
kFindLib:==2;
kLoadNewCopy:==3;

kTVectorCFragSymbol :== 2;

GetSharedLibrary :: !{#Char} !Int !Int !{#Char} -> (!Int,!Int,!Int);
FindSymbol :: !Int !{#Char} -> (!Int,!Int,!Int);
