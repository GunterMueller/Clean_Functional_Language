module share

import
	StdEnv;
	
is_first_instance :: !Bool;
is_first_instance 
	= code {
		ccall is_first_instance ":I"
	};

Start
	| is_first_instance
		= "eerste keer"
		= "later dan de eerste keer"