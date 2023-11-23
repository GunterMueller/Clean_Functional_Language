implementation module DebugUtilities;

//from StdString import /*String,*/ +++;
import StdString;
from StdFile import fwrites, stderr;


// Auxillary functions
E :: !a .b -> .b;
E a b 
	= b;

F :: !String .b -> .b;
F s b
	= E (fwrites (s +++ "\n") stderr) b;
	
FL :: [!String] .b -> .b;
FL l b
	#! s_l
		= loop l;
	= F ("---\n" +++ s_l) b;
where {
	loop []
		= "";
	loop [s:ss]
		= s +++ "\n" +++ (loop ss);
}
	

	
FNONL :: !String .b -> .b;
FNONL s b
	= b;//E (fwrites s stderr) b;
	
FB :: !Bool !String .b -> .b;
FB cond s b
	| cond
		= F s b;
		= b;

/*

E a b :== b;
F s a :== a;
FL s b :== b;
FB b s b2 :== b2;
FNONL s b :== b;
*/