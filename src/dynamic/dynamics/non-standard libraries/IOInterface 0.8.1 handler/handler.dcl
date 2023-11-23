definition module handler;

import deltaDialog, deltaIOState;
//import intrface, clCrossCall,ioTypes;

InstallDDEHandler :: (String *s -> *((IOState *s) -> (*s, IOState *s))) *s (IOState *s)
                             -> (*s, IOState *s);