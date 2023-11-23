definition module notification;

import mac_types;

::	NMRecPtr :== Int;

NMInstall :: !NMRecPtr !Toolbox -> (!Int,!Toolbox);
NMRemove :: !NMRecPtr !Toolbox -> (!Int,!Toolbox);
