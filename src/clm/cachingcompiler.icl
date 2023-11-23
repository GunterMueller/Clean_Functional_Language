implementation module cachingcompiler;

//1.3
from StdString import String;
//3.1

:: *Thread :== Int;

start_caching_compiler :: !{#Char} !Thread -> (!Int,!Thread);
start_caching_compiler a0 a1 = code {
	ccall start_caching_compiler "s:I:I"
}
// int start_caching_compiler (CleanCharArray compiler_path);

call_caching_compiler :: !{#Char} !Thread -> (!Int,!Thread);
call_caching_compiler a0 a1 = code {
	ccall call_caching_compiler "s:I:I"
}
// int call_caching_compiler (CleanCharArray args);

stop_caching_compiler :: !Thread -> (!Int,!Thread);
stop_caching_compiler a0 = code {
	ccall stop_caching_compiler ":I:I"
}
// int stop_caching_compiler ();
