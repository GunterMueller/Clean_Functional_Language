definition module asynclaunch;

import StdString;

:: *OS :== Int;
AsyncCallProcess :: !String !Int !OS -> (!Bool,!OS);
// void AsyncCallProcess (CleanString command,int slot,int* ok);
AsyncPollCompleted :: !OS -> (!Bool,!Int,!Int,!OS);
// void AsyncPollCompleted (int* ok,int* exitCode,int* slot);
