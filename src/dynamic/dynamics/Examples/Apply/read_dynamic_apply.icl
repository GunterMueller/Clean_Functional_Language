module read_dynamic_apply

import StdDynamic
import DynamicFileIO
import StdEnv
import RWSDebug

Start world
	// build_lazy_blocks *not* at entry node
	# (ok,d,world)
		= readDynamic (p +++ "\\bool") world
	| not ok
		= abort " could not read";
		
	| size (get_real d) <> 0

	# (_,world)
		= writeDynamic (p +++ "\\bool2") d world
	= (get_real,world)
where
	p
		= "C:\\WINDOWS\\Desktop\\cvs\\Dynamics\\Examples\\Apply"

	get_real (r :: Int)
		= "detected Real"
	get_real _
		= "geen real"

	
	
/* ORIGINEEL	
	# s = get_real d
	| size s == 0
		= undef
		
	# (_,world)
		= writeDynamic (p +++ "\\bool2") DynamicDefaultOptions d world
		
//	= (d,get_real d,world)
//	= (get_real d,d,world)	// werkt niet
	= (get_real d,d,world)	// werkt ook niet
// writeDynamic file_name dynamic_options dynamic_value files
where
	get_real (r :: Real)
		= "detected Real"

	p
		= "C:\\WINDOWS\\Desktop\\cvs\\Dynamics\\Examples\\Apply"

*/





		
		
			

/*		
	// bool2 contains build_lazy_blocks as entry nodes
	# (ok,world)
		= writeDynamic (p +++ "\\bool2") DynamicDefaultOptions d world
	| not ok
		= abort " could not write";


	# (ok,d,world)
		= readDynamic (p +++ "\\bool2") world
	| not ok
		= abort " could not read";	
		
// Problems:
// - lazy dynamic which has already been registered
// - (superfluous build_blocks for entry nodes consisting of build_lazy_block)
// - converting already existing build_lazy_blocks to disk build_lazy_blocks
// - misc dynamics (met meerdere library instances)

	# (ok,world)
		= writeDynamic (p +++ "\\bool3") DynamicDefaultOptions d world
	| not ok
		= abort " could not write";

// TEST
	# (ok,d,world)
		= readDynamic (p +++ "\\bool3") world
	| not ok
		= abort " could not read";	
		
// Problems:
// - lazy dynamic which has already been registered
// - (superfluous build_blocks for entry nodes consisting of build_lazy_block)
// - converting already existing build_lazy_blocks to disk build_lazy_blocks
// - ?

	# (ok,world)
		= writeDynamic (p +++ "\\bool4") DynamicDefaultOptions d world
	| not ok
		= abort " could not write";
*/

