definition module cachingcompiler;

//1.3
from StdString import String;
//3.1

:: *Thread :== Int;
start_caching_compiler :: !{#Char} !Thread -> (!Int,!Thread);
// int start_caching_compiler (CleanCharArray compiler_path);
call_caching_compiler :: !{#Char} !Thread -> (!Int,!Thread);
// int call_caching_compiler (CleanCharArray args);
stop_caching_compiler :: !Thread -> (!Int,!Thread);
// int stop_caching_compiler ();
