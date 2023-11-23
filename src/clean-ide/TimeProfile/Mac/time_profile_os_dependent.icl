implementation module time_profile_os_dependent

import StdEnv

PCorMac pc mac :== mac

clock_speed_and_profile_overhead :: (!Int,!Real,!Real)
clock_speed_and_profile_overhead = (0,0.0,0.0)

get_compute_time_function :: !*File -> (!(Int,Int,Int) -> Real,!*File)
get_compute_time_function file
	# (processor,processor_clock,bus_clock,file) = read_processor_information file
	= (compute_time processor processor_clock bus_clock,file)
where
	read_processor_information :: *File -> (Int,Int,Int,.File);
	read_processor_information file
		# (ok,processor,file)=freadi file
		| not ok
			= error file
		# (ok,processor_clock,file)=freadi file
		| not ok
			= error file
		# (ok,bus_clock,file)=freadi file
		| not ok
			= error file
		# (ok,c,file) = freadc file
		| not ok || c<>'\n'
			= error file
			= (processor,processor_clock,bus_clock,file)
	where
			error file = (0,1,1,file)

TwoPower32Real:==4294967296.0

PowerPC601GestaltNumber:==257
PowerPC750GestaltNumber:==264
PowerPC7400GestaltNumber:==268

PowerPC603604ProfileOverhead:==10.0
PowerPC750ProfileOverhead:==7.0

compute_time :: .Int a b -> .((c,.Int,d) -> Real) | toReal a & toReal b & toReal c & toReal d;
compute_time processor processor_clock bus_clock
	| processor==PowerPC601GestaltNumber
		= \ (time_hi,time_lo,n_profiler_calls)
			-> toReal time_hi + (toReal time_lo / 1E+9) - (toReal n_profiler_calls*16.0/toReal processor_clock)
	| processor>=PowerPC750GestaltNumber
		= \ (time_hi,time_lo,n_profiler_calls)
			-> ((toReal time_hi*TwoPower32Real + (if (time_lo>=0) (toReal time_lo) (TwoPower32Real+toReal time_lo)))*4.0)/toReal bus_clock
		 		- (toReal n_profiler_calls*PowerPC750ProfileOverhead/toReal processor_clock)
		= \ (time_hi,time_lo,n_profiler_calls)
			-> ((toReal time_hi*TwoPower32Real + (if (time_lo>=0) (toReal time_lo) (TwoPower32Real+toReal time_lo)))*4.0)/toReal bus_clock
		 		- (toReal n_profiler_calls*PowerPC603604ProfileOverhead/toReal processor_clock)
