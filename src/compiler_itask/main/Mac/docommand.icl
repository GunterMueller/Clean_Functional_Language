implementation module docommand;

//1.3
from StdString import String;
//3.1

:: *DoCommandEnvironment :== Int;

DoCommandNullTerminated :: !String !DoCommandEnvironment -> (!Int,!DoCommandEnvironment);
DoCommandNullTerminated a0 a1 = code {
	ccall DoCommandNullTerminated "S:I:I"
}
// int DoCommandNullTerminated(CleanString);
