definition module docommand;

//1.3
from StdString import String;
//3.1

:: *DoCommandEnvironment :== Int;
DoCommandNullTerminated :: !String !DoCommandEnvironment -> (!Int,!DoCommandEnvironment);
