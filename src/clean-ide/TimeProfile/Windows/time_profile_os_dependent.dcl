definition module time_profile_os_dependent

PCorMac pc mac :== pc

clock_speed_and_profile_overhead :: (!Int,!Real,!Real);
get_compute_time_function :: !*File -> (!(Int,Int,Int) -> Real,!*File)
