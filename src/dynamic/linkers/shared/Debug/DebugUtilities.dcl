definition module DebugUtilities;

//from StdString import String;
import StdString;

E :: !a .b -> .b;
F :: !String .b -> .b;
FL :: [!String] .b -> .b;
FB :: !Bool !String .b -> .b;
FNONL :: !String .b -> .b;

/*
E a b :== b;
F s a :== a;
FL s b :== b;
FB b s b2 :== b2;
FNONL s b :== b;
*/