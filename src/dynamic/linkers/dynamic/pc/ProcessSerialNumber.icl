implementation module ProcessSerialNumber;

// winos
import	StdEnv;

:: ProcessSerialNumber = {
		client_id	:: !Int
	};

DefaultProcessSerialNumber :: ProcessSerialNumber;
DefaultProcessSerialNumber	= { client_id = 0};
	
CreateProcessSerialNumber :: !Int -> ProcessSerialNumber;
CreateProcessSerialNumber client_id
	= { client_id = client_id};
	
GetOSProcessSerialNumber :: !ProcessSerialNumber -> Int;
GetOSProcessSerialNumber {client_id}
	= client_id;
	
instance == ProcessSerialNumber
where {
	(==) {client_id=client_id1} {client_id=client_id2}
		= client_id1 == client_id2;
};

KillClient2 :: !ProcessSerialNumber !*f ->  *f;
KillClient2 {client_id} io
	= abort "KillClient2";

instance toString ProcessSerialNumber
where {
	toString {client_id}
		= "PID: " +++ toString client_id;
};