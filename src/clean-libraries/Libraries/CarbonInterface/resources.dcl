definition module resources;

from mac_types import ::Handle,::Toolbox;

HOpenResFile :: !Int !Int !{#Char} !Int !*Toolbox -> (!Int,!*Toolbox);
HCreateResFile :: !Int !Int !{#Char} !*Toolbox -> *Toolbox;
CloseResFile :: !Int !*Toolbox -> *Toolbox;
AddResource :: !Handle !{#Char} !Int !{#Char} !*Toolbox -> *Toolbox;
ResError :: !*Toolbox -> (!Int,!*Toolbox);
Get1Resource :: !{#Char} !Int !*Toolbox -> (!Handle,!*Toolbox);
RemoveResource :: !Handle !*Toolbox -> *Toolbox;
