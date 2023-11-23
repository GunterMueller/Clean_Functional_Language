definition module pointer;

import mac_types;

ClearLong :: !Ptr !*Toolbox -> *Toolbox;
LoadByte :: !Ptr !*Toolbox -> (!Int,!*Toolbox);
LoadLong :: !Ptr !*Toolbox -> (!Int, !*Toolbox);
LoadWord :: !Ptr !*Toolbox -> (!Int, !*Toolbox);
StoreLong :: !Ptr !Int !*Toolbox -> *Toolbox;
StoreWord :: !Ptr !Int !*Toolbox -> *Toolbox;
StoreByte :: !Ptr !Int !*Toolbox -> *Toolbox;
//	IsEvaluated :: node !*Toolbox -> (!Bool,!*Toolbox);
