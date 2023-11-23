/*
	Wrap Clean nodes (for debugging purposes).

	Version 1.0.4
	Ronny Wichers Schreur
	ronny@cs.kun.nl
*/
definition module Wrap

from StdOverloaded import class toString (..)

::	WrappedDescriptorId

instance toString WrappedDescriptorId

::	WrappedDescriptor
    =   WrappedDescriptorCons
    |   WrappedDescriptorNil
    |   WrappedDescriptorTuple
    |   WrappedDescriptorOther !WrappedDescriptorId

::  WrappedNode
	//	basic types
    =   WrappedInt !Int
    |   WrappedChar !Char
    |   WrappedBool !Bool
    |   WrappedReal !Real
    |   WrappedFile !File

	// unboxed arrays of basic types
    |   WrappedString !{#Char}
    |   WrappedIntArray !{#Int}
    |   WrappedBoolArray !{#Bool}
    |   WrappedRealArray !{#Real}

	// other arrays
    |   WrappedArray !{WrappedNode}

	// records
    |   WrappedRecord !WrappedDescriptor !{WrappedNode}

	// unboxed lists
    |   WrappedUnboxedList !WrappedDescriptor !{WrappedNode}

	// unboxed lists of records
    |   WrappedUnboxedRecordList !WrappedDescriptor !{WrappedNode}

	// other nodes
    |   WrappedOther !WrappedDescriptor !{WrappedNode}

wrapNode :: !.a -> WrappedNode