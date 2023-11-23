definition module structure;

import mac_types;

::	Structure :== (!Handle,!Ptr);

DereferenceHandle		:: !Handle				!*Toolbox -> (!Ptr,		!*Toolbox);
Append_long				:: !Structure !Int		!*Toolbox -> (!Structure,!*Toolbox);
Append_word				:: !Structure !Int		!*Toolbox -> (!Structure,!*Toolbox);
Append_byte				:: !Structure !Int		!*Toolbox -> (!Structure,!*Toolbox);
Append_zero_and_rect	:: !Structure !Rect		!*Toolbox -> (!Structure,!*Toolbox);
Append_string_and_align	:: !Structure !{#Char}	!*Toolbox -> (!Structure,!*Toolbox);
Append_string			:: !Structure !{#Char}	!*Toolbox -> (!Structure,!*Toolbox);
HandleToStructure 		:: !Handle				-> Structure;
AppendLong				:: !Structure !Int		-> Structure;
AppendWord				:: !Structure !Int		-> Structure;
AppendByte				:: !Structure !Int		-> Structure;
AppendString			:: !Structure !{#Char}	-> Structure;
