/*
	Show Wrapped Node

	Version 1.0.4
	Ronny Wichers Schreur
	ronny@cs.kun.nl
*/
implementation module ShowWrapped

import StdEnv
import Wrap

ShowParentheses
	:==	True
Don`tShowParentheses
	:==	False

showWrapped :: WrappedNode -> [{#Char}]
showWrapped node
	=	show Don`tShowParentheses node

show :: Bool WrappedNode -> [{#Char}]
show _ (WrappedInt i)
	=	[toString i]
show _ (WrappedChar c)
	=	["\'" +++ toString c +++ "\'"]
show _ (WrappedBool b)
	=	[toString b]
show _ (WrappedReal r)
	=	[toString r]
show _ (WrappedFile _)
	=	["File"]
show _ (WrappedString s)
	=	["\"" +++ s +++ "\""]
show _ (WrappedIntArray a)
	=	showBasicArray a
show _ (WrappedBoolArray a)
	=	showBasicArray a
show _ (WrappedRealArray a)
	=	showBasicArray a
show _ (WrappedArray a)
	=	["{" : flatten (separate [", "] [show Don`tShowParentheses el \\ el <-: a])] ++ ["}"]
show _ (WrappedRecord descriptor args)
	=	["{" : flatten (separate [" "] [[showDescriptor descriptor] : [show ShowParentheses arg \\ arg <-: args]])] ++ ["}"]
show _ (WrappedUnboxedList _ args)
	| size args == 2
		=	["[#" : flatten [show Don`tShowParentheses args.[0] : showTail args.[1]]] ++ ["]"]
	where
		showTail :: WrappedNode -> [[{#Char}]]
		showTail (WrappedUnboxedList _ args)
			| size args == 2
				=	[[", "], show Don`tShowParentheses args.[0] : showTail args.[1]]
		showTail (WrappedOther WrappedDescriptorNil args)
			| size args == 0
				=	[]
		showTail node // abnormal list
			=	[[" : " : show Don`tShowParentheses node]]
show _ (WrappedUnboxedRecordList descriptor args)
	=	["[#" : flatten (showHeadTail descriptor args)] ++ ["]"]
	where
		showHeadTail :: WrappedDescriptor {WrappedNode} -> [[{#Char}]]
		showHeadTail descriptor args
			=	[show Don`tShowParentheses (WrappedRecord descriptor head) : showTail tail]
			where
				n
					=	size args
				head
					=	{arg \\ arg <-: args & _ <- [0..n-2]}
				tail
					=	args.[n-1]
			
		showTail :: WrappedNode -> [[{#Char}]]
		showTail (WrappedUnboxedRecordList descripctor args)
			| size args == 2
				=	[[", "] : showHeadTail descriptor args]
		showTail (WrappedOther WrappedDescriptorNil args)
			| size args == 0
				=	[]
		showTail node // abnormal list
			=	[[" : " : show Don`tShowParentheses node]]
show _ (WrappedOther WrappedDescriptorCons args)
	| size args == 2
		=	["[" : flatten [show Don`tShowParentheses args.[0] : showTail args.[1]]] ++ ["]"]
	where
		showTail :: WrappedNode -> [[{#Char}]]
		showTail (WrappedOther WrappedDescriptorCons args)
			| size args == 2
				=	[[", "], show Don`tShowParentheses args.[0] : showTail args.[1]]
		showTail (WrappedOther WrappedDescriptorNil args)
			| size args == 0
				=	[]
		showTail node // abnormal list
			=	[[" : " : show Don`tShowParentheses node]]
show _ (WrappedOther WrappedDescriptorTuple args)
	=	["(" : flatten (separate [", "] [show Don`tShowParentheses arg \\ arg <-: args])] ++ [")"]
show parentheses (WrappedOther descriptor args)
	| parentheses && size args > 0
		=	["(" : application] ++ [")"]
	// otherwise
		=	application
	where
		application
			=	flatten (separate [" "] [[showDescriptor descriptor] : [show ShowParentheses arg \\ arg <-: args]])

showDescriptor :: WrappedDescriptor -> {#Char}
showDescriptor (WrappedDescriptorOther id)
	=	toString id
showDescriptor WrappedDescriptorNil
	=	"[]"
showDescriptor WrappedDescriptorCons
	=	"[:]"
showDescriptor WrappedDescriptorTuple
	=	"(..)"

showBasicArray :: {#a} -> [{#Char}] | toString a & Array {#} a
showBasicArray a
	=	["{" : separate ", " [toString el \\ el <-: a]] ++ ["}"]

showWrappedArray :: {WrappedNode} -> [{#Char}]
showWrappedArray a
	=	["{" : flatten (separate [", "] [show Don`tShowParentheses el \\ el <-: a])] ++ ["}"]

separate :: a [a] -> [a]
separate separator [a : t=:[b : _]]
	=	[a, separator : separate separator t]
separate _ l
	=	l

instance toString File
where
	toString :: !File -> {#Char}
	toString _
		=	"File"
