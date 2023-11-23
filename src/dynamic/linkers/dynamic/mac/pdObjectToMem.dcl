definition module pdObjectToMem;

import DLState;
generate_options_file :: !*DLClientState !*DLServerState !*Files -> *(*(!String,*DLClientState,*DLServerState),*Files);

// Client <-> Server communication
class SendAddressToClient a
where {
	SendAddressToClient :: !ProcessSerialNumber a !(IOState *s) -> !(IOState *s)
};

instance SendAddressToClient !Int;
instance SendAddressToClient !{#Char};

//write_image :: !*State !*Files -> !(!*State,!*Files);
write_image :: !*State (!*IOState s) -> !(!Int,!*State,!*IOState s);

objects_and_libraries :: (![!String],![!String],!String);

