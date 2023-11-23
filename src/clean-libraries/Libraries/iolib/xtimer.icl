implementation module xtimer;

//1.3
from StdString import String;
//3.1


install_timer :: !Int -> Int;
install_timer a0 = code {
	ccall install_timer "I:I"
}
// int install_timer (int);

change_timer_interval :: !Int -> Int;
change_timer_interval a0 = code {
	ccall change_timer_interval "I:I"
}
// int change_timer_interval (int);

get_timer_count :: !Int -> Int;
get_timer_count a0 = code {
	ccall get_timer_count "I:I"
}
// int get_timer_count (int);

enable_timer :: !Int -> Int;
enable_timer a0 = code {
	ccall enable_timer "I:I"
}
// int enable_timer (int);

disable_timer :: !Int -> Int;
disable_timer a0 = code {
	ccall disable_timer "I:I"
}
// int disable_timer (int);

get_current_time :: !Int -> (!Int,!Int,!Int);
get_current_time a0 = code {
	ccall get_current_time "I:VIII"
}
// void get_current_time (int,int*,int*,int*);

get_current_date :: !Int -> (!Int,!Int,!Int,!Int);
get_current_date a0 = code {
	ccall get_current_date "I:VIIII"
}
// void get_current_date (int,int*,int*,int*,int*);

wait_mseconds :: !Int -> Int;
wait_mseconds a0 = code {
	ccall wait_mseconds "I:I"
}
// int wait_mseconds (int);
