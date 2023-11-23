/*
	Debug functions.

	Version 1.0.4
	Ronny Wichers Schreur
	ronny@cs.kun.nl
*/
implementation module Debug

import StdEnv
import Wrap, ShowWrapped
import StdDebug

// abort and undef from StdMisc are recognised be the strictness analyser
// because we rely on the evaluation order in this module, we use our own abort

non_strict_abort :: !{#Char} -> .a;
non_strict_abort a = code  {
	.d 1 0
		jsr print_string_
	.o 0 0
		halt
	}

print :: ![{#Char}] .b -> .b
print debugStrings value
	| fst (ferror (stderr <<< debugStrings))
		=	non_strict_abort "Debug, print: couldn't write to stderr"
	// otherwise
		=	value

debugBefore :: !.a !(DebugShowFunction .a) .b -> .b
debugBefore debugValue show value
	=	print (show debugValue) value

debugAfter :: .a !(DebugShowFunction .a) !.b -> .b
debugAfter debugValue show value
	=	print (show debugValue) value

debugValue :: !(DebugShowFunction .a) !.a -> .a
debugValue show value
	// copying a unique reference is OK here, because after the show
	// reference1 is no longer in use and show shouldn't change anything
	=	print (show reference1) reference2
	where
		(reference1, reference2)
			=	copyUniqueReference value

		copyUniqueReference :: !.a -> (!.a, !.a)
		copyUniqueReference value
			=	code {
				.o 1 0
					push_a	0				
				.d 2 0
				}

:: DebugShowFunction a :== a -> [{#Char}]

:: DebugOptionRecord
	=	{maxDepth :: !Int, maxBreadth :: !Int, maxChars :: !Int, terminator :: !{#Char}}
DebugDefaultOptions
	:== {maxDepth = MaxInt, maxBreadth = MaxInt, maxChars = MaxInt, terminator = "\n"}

MaxInt
	:== (1<<31)-1

:: DebugShowOption 
	=	DebugMaxDepth !Int			// default MaxInt
	|	DebugMaxBreadth !Int		// default MaxInt
	|	DebugMaxChars !Int			// default MaxInt
	|	DebugTerminator !{#Char}	// default "\n"

(:-) infixl
(:-) a f
	:== f a

debugShowWithOptions :: [DebugShowOption] .a -> [{#Char}]
debugShowWithOptions debugOptions debugValue 
	=	debugValue
	:-	wrapNode
	:-	pruneWrappedNode maxDepth maxBreadth
	:-	showWrapped
	:-	chop maxChars
	:-	flip (++) [terminator]
	where
		{maxDepth, maxBreadth, maxChars, terminator}
			=	foldl set DebugDefaultOptions debugOptions
			where
				set options (DebugMaxDepth maxDepth)
					=	{options & maxDepth=maxDepth}
				set options (DebugMaxBreadth maxBreadth)
					=	{options & maxBreadth=maxBreadth}
				set options (DebugMaxChars maxChars)
					=	{options & maxChars=maxChars}
				set options (DebugTerminator terminator)
					=	{options & terminator=terminator}

:: Indicators
	=	@...
	|	.+.

MaxCharsString
	:== ".."
MaxBreadthString
	:== "..."
MaxBreadthIndicator
	:== wrapNode @...
MaxDepthIndicator
	:==	wrapNode .+.

pruneWrappedNode :: !Int !Int !WrappedNode -> WrappedNode
pruneWrappedNode maxDepth maxBreadth value
	=	prune 0 value
	where
		prune :: !Int WrappedNode -> WrappedNode
		prune depth value
			| depth == maxDepth
				=	MaxDepthIndicator
		prune depth (WrappedIntArray a)
			=	pruneBasicArray depth a
		prune depth (WrappedBoolArray a)
			=	pruneBasicArray depth a
		prune depth (WrappedRealArray a)
			=	pruneBasicArray depth a
		prune depth (WrappedString a)
			| size a > maxBreadth
				=	WrappedString ((a % (0, maxBreadth-1)) +++ MaxBreadthString)
		prune depth (WrappedArray a)
			=	WrappedArray (pruneArray depth a)
		prune depth (WrappedRecord descriptor args)
			=	WrappedRecord descriptor (pruneArray depth args)
		prune depth (WrappedOther WrappedDescriptorCons args)
			| size args == 2
				=	WrappedOther WrappedDescriptorCons
						{prune (depth+1) args.[0], prune depth args.[1]}
		prune depth (WrappedOther WrappedDescriptorTuple args)
			=	WrappedOther WrappedDescriptorTuple (pruneArray depth args)
		prune depth (WrappedOther descriptor args)
			=	WrappedOther descriptor (pruneArray depth args)
		prune _ a
			=	a

		pruneArray :: !Int !{WrappedNode} -> {WrappedNode}
		pruneArray depth a
			| size a > maxBreadth
				=	{{prune (depth+1) e \\ e <-: a & i <- [0 .. maxBreadth]}
						& [maxBreadth] = MaxBreadthIndicator}
			// otherwise
				=	{prune (depth+1) e \\ e <-: a}

		pruneBasicArray :: !Int !(a b) -> WrappedNode | Array a b
		pruneBasicArray depth a
			| size a > maxBreadth
				=	WrappedArray (pruneArray depth {wrapNode e \\ e <-: a & i <- [0 .. maxBreadth]})
			// otherwise
				=	WrappedArray {wrapNode e \\ e <-: a}

/* FIXME handle newlines in strings correctly */
chop :: !Int [{#Char}] -> [{#Char}]
chop _ []
	=	[]
chop maxChars list=:[string:strings]
	| maxChars < stringSize + sizeMaxCharsString
		| fits maxChars list
			=	list
		| stringSize > sizeMaxCharsString
			=	[string % (0, maxChars-sizeMaxCharsString-1), MaxCharsString]
		// otherwise
			=	[MaxCharsString]
	// otherwise
		=	[string : chop (maxChars - stringSize) strings]
	where
		stringSize
			=	size string
		sizeMaxCharsString
			=	size MaxCharsString

		fits :: !Int [{#Char}] -> Bool
		fits _ []
			=	True
		fits maxChars [h : t]
			=	maxChars >= size h && fits (maxChars - size h) t

instance <<< [a] | <<< a where
	(<<<) :: !*File ![a] -> *File | <<< a
	(<<<) file []
		=	file
	(<<<) file [h:t]
		=	file <<< h <<< t
