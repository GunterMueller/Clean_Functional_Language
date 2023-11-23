
/*	The maximum arity of tuples is defined by MaxTupleArity */

#define MaxNodeArity	32

/*
	Compsupport
*/

/*	The compiler uses its own storage administration. When some storage is required
	it is checked whether or not this storage is available. If not, a new memory
	block of size MemBlockSize is allocated. Keeping the size large will slightly
	increase the performance of the memory allocator.
*/

#ifdef __MWERKS__
# define MemBlockSize ((SizeT) (16*KBYTE))
#else
# define MemBlockSize ((SizeT) (32*KBYTE))
#endif

/*	Code Generator */

/* The size of objects expressed in amounts of stack entries are given below */

#define SizeOfInt			1
#define SizeOfBool			1
#define SizeOfChar			1
#define SizeOfReal			2 /*1*/
#define SizeOfFile			2
#define SizeOfVoid			1
#define SizeOfProcId		1
#define SizeOfAStackElem 	1

#define NrOfGlobalSelectors	6
