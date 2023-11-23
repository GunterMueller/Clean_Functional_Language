implementation module initialise;

import mac_types;
from textedit import TEInit;
from dialogs import InitDialogs,ProcPtr;

Initialise :: !*Toolbox -> *Toolbox;
Initialise tb = InitDialogs 0 (TEInit tb);
