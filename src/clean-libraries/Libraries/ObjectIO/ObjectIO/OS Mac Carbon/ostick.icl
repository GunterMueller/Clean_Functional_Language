implementation module ostick

// to be placed in something bigger later

//import StdEnv
from events import TickCount,::Toolbox..

::	Tick	:== Int

pack_tick	::	!Int -> Tick
pack_tick i = i

unpack_tick	::	!Tick -> Int
unpack_tick tick = tick

os_getcurrenttick :: !*World -> (!Tick, !*World)
os_getcurrenttick world
	# (tc,_)	= TickCount 42
	= (tc, world)
