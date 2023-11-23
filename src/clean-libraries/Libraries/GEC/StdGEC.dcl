definition module StdGEC

import StdEnv

import
// GEC Arrow related

	StdArrow,			// standard arrow definitions like >>>, loop, arr
	GecArrow,			// additional arrow definitions for editors (i.e. GEC's) defined on circuits
	StdCircuits,		// frequently used editor circuit definitions

// AGEC related

	StdAGEC,			// functions for making Abstract Editors (i.e. AGEC's)
	basicAGEC,			// frequently used AGEC's
	dynamicAGEC,		// enables editing of higher order types (i.e. functions)
	
// Types that have special editors defined on it:

	layoutGEC,			// layout types such as <->, <|>
	buttonGEC,			// button types such as Button, Checkbox, Text, UpDown 
	modeGEC,			// types to make data not-editable (display), invisable, plain editable
	noObjectGEC,		// type to make only the data constructors invisable
	timedGEC			// starts a timer ! 
	
	
	