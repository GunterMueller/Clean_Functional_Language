implementation module
	DynArray

import
	StdArray,
	StdInt,
	StdClass

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: *DynIntArray =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ dynArraySize			:: !Int
	, dynArray				:: *{#Int}
	, dynArrayDelta			:: !Int
	, dynArrayDefault		:: !Int
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------   
createDynIntArray :: !Int !Int !Int -> *DynIntArray
// -------------------------------------------------------------------------------------------------------------------------------------------------   
createDynIntArray size delta element
	= {dynArraySize = size, dynArray = createArray size element, dynArrayDelta = delta, dynArrayDefault = element}

// -------------------------------------------------------------------------------------------------------------------------------------------------   
computeNewSize :: !Int !Int !Int -> Int
// -------------------------------------------------------------------------------------------------------------------------------------------------   
computeNewSize size delta index
	| size > index			 	= size
	= computeNewSize (size+delta) delta index

// -------------------------------------------------------------------------------------------------------------------------------------------------   
selectDynIntArray :: !*DynIntArray !Int -> (!Int, !*DynIntArray)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
selectDynIntArray array index
	# (element, dynArray)			= uselect array.dynArray index
	= (element, {array & dynArray = dynArray})

// -------------------------------------------------------------------------------------------------------------------------------------------------   
updateDynIntArray :: !*DynIntArray !Int !Int -> *DynIntArray
// -------------------------------------------------------------------------------------------------------------------------------------------------   
updateDynIntArray array=:{dynArraySize, dynArrayDelta} index value
	| index < dynArraySize			= {array & dynArray = update array.dynArray index value}
	# newsize						= computeNewSize dynArraySize dynArrayDelta index
	# array							= enlargeDynIntArray array newsize
	= {array & dynArray = update array.dynArray index value}
	where
		enlargeDynIntArray :: !*DynIntArray !Int -> *DynIntArray
		enlargeDynIntArray array=:{dynArrayDelta,dynArrayDefault} new_size
			# newarray					= createDynIntArray new_size dynArrayDelta dynArrayDefault
			= updateElements array newarray
		
		updateElements :: !*DynIntArray !*DynIntArray -> *DynIntArray
		updateElements old_array=:{dynArraySize} new_array
			| dynArraySize == 0			= new_array
			# (element, old_array)		= selectDynIntArray old_array dynArraySize
			# new_array					= updateDynIntArray new_array dynArraySize element
			# old_array					= {old_array & dynArraySize = dynArraySize-1}
			= updateElements old_array new_array