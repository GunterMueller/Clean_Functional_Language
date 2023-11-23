implementation module handler;

import deltaDialog, deltaIOState;
import intrface, clCrossCall,ioTypes;

InstallDDEHandler :: (String *s -> *((IOState *s) -> (*s, IOState *s))) *s (IOState *s)
                             -> (*s, IOState *s);
InstallDDEHandler funct s iostate = (s,iostate`);
where
{   (adm, os) = UnpackIOStateWithCheck iostate;
    adm`      = { adm & io_ddehandler = funct };
    iostate`  = PackIOState adm` os;
}
