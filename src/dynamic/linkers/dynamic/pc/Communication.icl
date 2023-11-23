implementation module Communication;

import StdEnv;

ReceiveReq :: !Bool !Int -> !String;
ReceiveReq static_application_as_client client_id
	= abort "ReceiveReq";
	