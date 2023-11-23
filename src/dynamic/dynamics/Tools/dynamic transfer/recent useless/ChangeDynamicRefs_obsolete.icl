implementation module ChangeDynamicRefs

import DynID, StdDynamicLowLevelInterface

amap f array
	= { f element \\ element <-: array } 
/*	
	
func2 :: (a -> a) !*{#a} -> !*{#a}
func2 f uarray
	# (s_a,uarray2)
		= usize uarray
	= func2 0 s_a uarray2
where
	func2 i limit uarray
		| i == limit
			= uarray
			
		# (element,uarray)
			= uarray![i]
		= func2 (inc i) limit {uarray & [i] = f element}
			
*/		
 
Log :: String *World -> *World
Log st world 
	# ( console, world ) = stdio world
	#  console = fwrites st console
	# ( ok, world ) = fclose console world 
	= world


//???
ChangeDynamicReferences :: String (String -> String) *World -> (Bool, *World)
// ChangeDynamicReferences filename f w
// changes the references in filename that is stored on the disk. 
// it changes each x reference to f(x)
ChangeDynamicReferences filename f world  
	// read the header
	# ( ok, header, file, world ) = open_dynamic_as_binary filename world
	| not ok = ( False, world )
	// read rts info
	# ( ok, dyninfo, file ) = read_rts_info_from_dynamic header file
	| not ok = ( False, world ) 
	// use f to map through the table
	# ( ok, world ) = close_dynamic_as_binary file world
	| not ok = ( False, world ) 
	# newdyninfo = { dyninfo &
		di_library_index_to_library_name = amap f dyninfo.di_library_index_to_library_name,
		di_lazy_dynamics_a = amap f dyninfo.di_lazy_dynamics_a }
	// write the new rts info
	# ( ok, file, world ) = fopen filename FAppendData world
	| not ok = ( False, world ) 
	# ( ok, file, st ) = write_rts_info_to_dynamic newdyninfo header file
	| not ok = ( False, world )
	= fclose file world
/*	where
		g = toString o f o fromString
*/	

write_rts_info_to_dynamic :: DynamicInfo DynamicHeader *File -> (Bool, *File, String)
// writes the dynamic rts_info to the dynamic
// assumes that the dynamicinfo is at the end of the file
// this procedure just writes to the place of the old rts_info
write_rts_info_to_dynamic dyninfo header file
	// seek to the rts_info
	# ( ok, file ) = fseek file header.dynamic_rts_info_i FSeekSet
	| not ok = ( False, file, "" )
	// write the rts info
	# enc_dyninfo = encode dyninfo
	# file = fwrites enc_dyninfo file
	# ( ok, file ) = fseek file (DYNAMIC_RTS_INFO_SIZE - HEADER_SIZE_OFFSET + N_BYTES_BEFORE_HEADER_START) FSeekSet
	| not ok = ( False, file, "" )
	# file = fwritei (size enc_dyninfo) file
	= ( True, file, enc_dyninfo )
	

	

