// LinkedBlock.c

// FIXED and UNFIXED at the same time
#ifdef BOTH_FIXEDNESS
# define FIXED
# define UNFIXED
# undef BOTH_FIXEDNESS
#endif

// sanity checks
#ifndef FIXED
# ifndef UNFIXED
#  error  "LinkedBlock.c: FIXED or UNFIXED must be defined"
# endif
#endif

// include unfixed stack implementation
#ifdef UNFIXED
# define MAKE_IDP(l) MAKE_ID(l##_unfixed)
# define APPEND_P(l) l##_unfixed
# include "LinkedBlock2.c"
# undef APPEND_P
# undef MAKE_IDP
#endif

// include fixed stack implementation
#ifdef FIXED
# define MAKE_IDP(l) MAKE_ID(l##_fixed)
# define APPEND_P(l) l##_fixed
# include "LinkedBlock2.c"
# undef APPEND_P
# undef MAKE_IDP
#endif

// undo
#ifdef FIXED
# undef FIXED
#endif

#ifdef UNFIXED
# undef UNFIXED
#endif

	// shared among FIXED and UNFIXED stack sizes
	.data
	.align 	4
MAKE_ID(lb_root):
	.long	0							// address of root block
MAKE_ID(lb_current_block):						
	.long	0							// address of current block
MAKE_ID(lb_entry):
	.long	0							// number of next entry to be allocated
MAKE_ID(lb_n_blocks):
	.long	0							// amount of allocated blocks
MAKE_ID(lb_map_array_user_defined_function):
	.long	0							// temp used by lb_map_array
	
	.text
// from original LinkedBlock.c
#undef LB_BLOCK_BSIZE
#undef LB_BLOCK_WSIZE
// undef user defined macros
#undef N_LB_ENTRIES
#undef N_LB_ENTRIES_EXP
#undef LB_ENTRY_BSIZE
#ifdef NOT_A_POWER_OF_TWO_ENTRY_SIZE
# undef LB_ENTRY_WSIZE
# undef NOT_A_POWER_OF_TWO_ENTRY_SIZE
#else
# undef LB_ENTRY_BSIZE_EXP
#endif
#undef MAKE_ID
