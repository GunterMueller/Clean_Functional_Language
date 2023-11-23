module read_dynamic_apply

import StdDynamic
import StdEnv
import RWSDebug
import StdDynamicFileIO
import path

:: X
	= {
		x_r1	:: Int
	,	x_r2	:: Int 
	};

Start world
	// build_lazy_blocks *not* at entry node
	# (ok,d,world)
		= readDynamic (p +++ "\\bool") world
	| not ok
		= abort " could not read";
		
	| size (get_real d) <> 0

	# (_,world)
		= writeDynamic (p +++ "\\bool2") d world
	= world
//	= (get_real /*,d*/ ,world)
//	= (get_real,d,world)

where
//	get_real (r :: Int)
//		= "detected Real"

	get_real (_ :: X) //Int)
		= "detected X"
	get_real _
		= "geen real"

// Onder de aanname dat de waardes van de dynamics ongeevalueerd bleven.
// geen dynamic pattern match  								OK
// falende dynamic pattern match							OK
// slagende pattern matches									OK
// slagende pattern matches	en (volledig) geevalueerd		OK
//
//
// waardes kunnen alleen opgebouwd worden na een *succesvolle* pattern match
// 
// Dus nu kunnen dynamics ongeacht de mate van geevalueerd zijn, worden
// weggeschreven.
// 
// Standaard, voor gedefinieerde types zoals INT, REAL, lijst, etc. worden
// speciaal behandeld..
	
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

