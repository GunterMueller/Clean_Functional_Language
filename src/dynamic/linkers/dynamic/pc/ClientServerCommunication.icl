implementation module ClientServerCommunication;

class SendAddressToClient a
where {
	SendAddressToClient :: a !*f -> !*f
};

instance SendAddressToClient !Int
where {
//	SendAddressToClient :: !Int !(IOState *s) -> !(IOState *s);
	SendAddressToClient start_addr io
		| ReplyReq start_addr
			= io;
};

instance SendAddressToClient !{#Char}
where {
//	SendAddressToClient :: !String !(IOState *s) -> !(IOState *s);
	SendAddressToClient s_symbol_addresses io
		| ReplyReqS s_symbol_addresses
			= io;
};