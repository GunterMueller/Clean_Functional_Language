Clean (:: *OS :== Int ;)

void AsyncCallProcess (CleanString command, int slot, int *ok);
Clean (AsyncCallProcess :: String Int OS -> (Bool, OS))
void AsyncPollCompleted (int *ok, int *exitCode, int *slot);
Clean (AsyncPollCompleted :: OS -> (Bool, Int, Int, OS))
