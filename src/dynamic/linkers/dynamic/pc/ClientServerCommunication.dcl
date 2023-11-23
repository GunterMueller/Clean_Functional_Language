definition module ClientServerCommunication

class SendAddressToClient a
where {
	SendAddressToClient :: a !*f -> !*f
};

instance SendAddressToClient !Int;
instance SendAddressToClient !{#Char};