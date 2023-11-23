definition module deltaEventIO;

//	Version 0.8.3b

/*
==
==	Definition of IOState: the environment parameter on which all
==									I/O functions operate.
==	Definition of EVENTS : the environment parameter to start I/O.
==
==	The operations on the IOState to create interactions.
==


ABSTYPE

::	UNQ EVENTS;
::	UNQ IOState UNQ s;


RULE

::	OpenEvents !UNQ WORLD -> (!EVENTS, !UNQ WORLD);

<<	OpenEvents retrieves the event stream from the world. >>

::	CloseEvents !EVENTS !UNQ WORLD -> UNQ WORLD;

<<	CloseEvents replaces the event stream in the world. Event streams that
	have been retrieved from the world, must be closed before they can be
	opened again, otherwise a run-time error will occur. >>
*/


    

::	InitialIO *s	:== [s -> *((IOState s) -> *(s, IOState s))];


    

/*	Starting an interaction:
*/

StartIO	:: !(IOSystem *s (IOState *s)) !*s !(InitialIO *s) !*World -> (!*s, !*World);

/*	StartIO starts a new interaction specified by the IOSystem argument.
	Of each device only the first occurrence is taken into account. The
	program state argument serves as initial program state. The first
	functions to be evaluated are given in InitialIO from left-to-right.
	StartIO returns the final program state and the resulting events.
	In this version the program state must be unique. */

NestIO	:: !(IOSystem *t (IOState *t)) !*t !(InitialIO *t) !(IOState *s) -> (!*t, !IOState *s);

/*	NestIO starts a new interaction. It replaces the current interaction
	(specified by the IOState argument) with a completely new one
	(specified by the IOSystem argument). It hides the devices of the
	current interaction (if any) and fills the IOState with the devices
	that are specified in the IOSystem argument. Of each device only the
	first occurrence is taken into account. The program state argument
	serves as initial program state. The first functions to be evaluated
	are given in InitialIO from left-to-right.
	NestIO returns the final program state and the original IOState such
	that the original interaction re-appears. In this version the program
	state must be unique. */

QuitIO	:: !(IOState s) -> IOState s;

/*	QuitIO closes all devices that are held in the IOState argument.
	The resulting (empty) IOState will cause StartIO to terminate. QuitIO
	is the only function which terminates StartIO. */

ChangeIOState	:: ![(IOState s) ->  IOState s ] !(IOState s) -> IOState s;

/*	ChangeIOState applies the functions in its first argument in
	consecutive order to the second (IOState) argument. */



import deltaIOSystem;
from ioState import :: IOState; // RWS , EVENTS, OpenEvents, CloseEvents;
