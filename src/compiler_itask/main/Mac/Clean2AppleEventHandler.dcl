definition module Clean2AppleEventHandler;

//1.3
from StdString import String;
from StdFile import Files;
from events import Event;
//3.1
/*2.0
from StdFile import :: Files;
from events import :: Event;
0.2*/

install_apple_event_handlers :: Int;
HandleAppleEvent :: !Event ({#Char} *Files -> (!Int,!*Files)) !*Files -> (!Bool,!Bool,!*Files);

get_apple_event_string :: !Int !String -> Int;
