implementation module deltaIOState;

//
// Version 0.84sp
//
// Global operations on the IOState.
//


import deltaEventIO;
from misc    import UEvaluate_2;
from xwindow import set_dd_distance;
import ioState;
 
// RWS ...

import StdFile;

/*	IOState is an instance of the FileEnv class (see StdFile):	*/
instance FileEnv (IOState s) where {
	accFiles :: !.(*Files -> (.x,*Files)) !(IOState s) -> (!.x,!IOState s);
	accFiles accfun io
		# (w,io)	= IOStateGetWorld io;
		  (x,w)		= accFiles accfun w;
		  io		= IOStateSetWorld w io;
		= (x,io);
	
	appFiles :: !.(*Files -> *Files) !(IOState s) -> IOState s;
	appFiles appfun io
		# (w,io)	= IOStateGetWorld io;
		  w			= appFiles appfun w;
		  io		= IOStateSetWorld w io;
		= io;
	};

// ... RWS

/* There is no way to obscure the cursor under X Windows */
ObscureCursor :: !(IOState s) -> IOState s;
ObscureCursor io           =  io;

SetDoubleDownDistance :: !Int !(IOState s) -> IOState s;
SetDoubleDownDistance dist io           =  UEvaluate_2 io (set_dd_distance dist);
