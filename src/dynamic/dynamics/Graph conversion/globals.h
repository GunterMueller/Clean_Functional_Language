
#include "clean_labels.h"

#define VERSION_NUMBER	0x00010101

#define GDI
#ifdef GDI
	// eax	= graph_i (Int)
	// edx  = descP (String)
	// ecx	= gdi
	/*
	:: GlobalDynamicInfo = {
		,	graph			:: !String
			file_name		:: !String
		}
	*/
	//#define GDI_FILE_NAME		4
# define GDI_GRAPH			4 //8	
# define gdi				%ecx	// GDI ptr

#endif // GDI
 
#define STACK_CHECKS
	// #define SHARING_ACROSS_CONVERSIONS
	// REMOVE
	//#define TEST_COLOUR_GRAPH

	/*	
		Changes:
		1) gts_delete.c; restore indirection and entry nodeP is stored in the EN-table.
		2) intermediate descriptor table has a pointer for each descriptor to its usage
	*/

	/*
		doel:
		to_string:
		- block en hun entry knopen vastleggen
		- indirecties herstellen
		- extend descriptor prefix table
		
		from_string:
		- decoding it
		
		1. nested dynamics
			- copying dynamics (doen; heeft ook te maken met versie management)
			<- garbage collection and dynamics>
		
		< 2. data dynamics
			- hyper strict evaluation of graph
			- new syntax plus checks for frontend>
		
		3. type correctness of dynamics
			- external type is specification
			
		4. version management 
		
		// compile time
		5. frontend problems
			- overloading (small)
			- polymorphy (representatie van types) (small)
			- uniquness (huge project) (run-time interessant)
			
		6. Bugs

		Doel: type correct dynamics and nested dynamics

		7. Optimizations
			- Clean compiler frontend; sharing of type information
			- graph_to_string: sharing in SN-nodes
			- 
			
		8. Network dynamics
			- ABC libraries
			- MAC port
			
		The copy_graph_to_string algorithm:
		
		pass 1: colouring the graph
		
		pass 2: copying graph & creating descriptor usage sets
		
		pass 3: delete indirections and SN/EN-nodes & copying label/module names
		
		pass 4: adjusting encoded descriptors

	*/
