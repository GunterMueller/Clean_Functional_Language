Clean (:: *Thread :== Int)
int start_caching_compiler (CleanCharArray compiler_path);
Clean (start_caching_compiler :: {#Char} Thread -> (Int, Thread))
int call_caching_compiler (CleanCharArray args);
Clean (call_caching_compiler :: {#Char} Thread -> (Int, Thread))
int stop_caching_compiler (void);
Clean (stop_caching_compiler :: Thread -> (Int, Thread))
