implementation module asynclaunch;

import StdString;

import code from "asynclaunch.obj";

:: *OS :== Int;

AsyncCallProcess :: !String !Int !OS -> (!Bool,!OS);
AsyncCallProcess a0 a1 a2 = code {
	ccall AsyncCallProcess "SI:VI:I"
};
// void AsyncCallProcess (CleanString command,int slot,int* ok);

AsyncPollCompleted :: !OS -> (!Bool,!Int,!Int,!OS);
AsyncPollCompleted a0 = code {
	ccall AsyncPollCompleted ":VIII:I"
};
// void AsyncPollCompleted (int* ok,int* exitCode,int* slot);
