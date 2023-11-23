definition module memory;

import mac_types;

NewHandle :: !Int !*Toolbox -> (!Handle,!Int,!*Toolbox);
DisposHandle :: !Handle !*Toolbox -> (!Int,!*Toolbox);
NewPtr :: !Int !*Toolbox -> (!Ptr,!Int,!*Toolbox);
DisposePtr :: !Ptr !*Toolbox -> *Toolbox;
GetHandleSize :: !Handle !*Toolbox -> (!Int,!*Toolbox);
copy_handle_data_to_string :: !{#Char} !Handle !Int !*Toolbox -> *Toolbox;
copy_string_slice_to_memory :: !s:{#Char} !Int !Int !Int !*Toolbox -> (!s:{#Char},!*Toolbox);
copy_string_to_handle :: !{#Char} !Handle !Int !*Toolbox -> *Toolbox;
