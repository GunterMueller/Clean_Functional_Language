implementation module time_profile_os_dependent

import StdEnv

import code from "cpuspeed."
import code from "compute_profile_overhead."

PCorMac pc mac :== pc

define_fltused :: !Bool -> Bool
define_fltused n = code {
	.export _fltused
	:_fltused
	pop_b 0
	}

measure_clock_speed_and_profile_overhead :: (!Int,!Real,!Real)
measure_clock_speed_and_profile_overhead = code {
	ccall measure_clock_speed_and_profile_overhead ":IRR"
	}

clock_speed_and_profile_overhead :: (!Int,!Real,!Real)
clock_speed_and_profile_overhead
	=: clock_speed_and_profile_overhead
where
	clock_speed_and_profile_overhead
		| define_fltused True
			= measure_clock_speed_and_profile_overhead

get_compute_time_function :: !*File -> (!(Int,Int,Int) -> Real,!*File)
get_compute_time_function file
	# (_,clock_speed,overhead) = clock_speed_and_profile_overhead
	= (compute_time_x86 (clock_speed*1.0E6) overhead,file)

TwoPower32Real:==4294967296.0

compute_time_x86 :: a .Real -> .((b,.Int,c) -> Real) | toReal a & toReal b & toReal c;
compute_time_x86 processor_clock profile_overhead
	= \ (time_hi,time_lo,n_profiler_calls)
		-> (toReal time_hi*TwoPower32Real + (if (time_lo>=0) (toReal time_lo) (TwoPower32Real+toReal time_lo)))/toReal processor_clock
			- (toReal n_profiler_calls*profile_overhead/toReal processor_clock)
