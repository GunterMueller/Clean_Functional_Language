// WARNING:
// consistency required with StdDynamicLowInterface!

// ModuleIDs can only occur in the main library instance. 
#include "gts_code_and_type_runtime_ids.h"

#define RID_N_RANGE_ENTRIES_OFFSET		0
#define RID_N_TYPE_TABLES_OFFSET		4
#define RID_HEADER_SIZE					(RID_N_TYPE_TABLES_OFFSET + 4)

#define RIDE_BEGIN_ADDRESS_OFFSET		0
#define RIDE_END_ADDRESS_OFFSET			4
#define RIDE_RUNTIME_ID_LIB_NUMBER		8
#define RIDE_SIZE						(RIDE_RUNTIME_ID_LIB_NUMBER + 4)

#define TTUT_UNUSED						0xffffffff

	.data
type_module_list:
	.long 	0
disk_type_id:
	.long 	0
type_ref_id:
	.long	0
current_module_id:
	.long	0

#ifdef CONVERT_LAZY_RUN_TIME_ID
found_runtime_id_entry: 
	.long 	0
searched_runtime_id_entry:
	.long	0
#endif
	
	.align	4
unknown_address:
	.long	__STRING__+2
	.long	116
	//       012345678901234567890123456789012345678901234567890123456789012345
	//		 0         1         2         3         4         5
	.ascii  "find_address_in_range_id in gts_range_id; unknown address; the add"
	.ascii	"ress does not seem to be allocated to code or data"
	.byte 	0
	.byte 	0
	.byte 	0
	.byte	0
	
	.text

init_range_id:
	movl	$0,type_module_list
	movl	$1,disk_type_id
	
// see StdDynamicLowLevelInterface.icl
#define INITIAL_TYPE_REFERENCE_NUMBER 0
	movl	$ INITIAL_TYPE_REFERENCE_NUMBER,type_ref_id
	movl	$80000000,current_module_id					// uninitialized
	ret

	// -------------------------------------------------------------------------------------
	// Shared

	// input:
	// - %ebx = address to find
	// 
	// output:
	// - %eax = library instance number (on disk)
	//
	// destroys:
	// - %eax, %ecx
find_code_library_instance_nr:
	call	find_address_in_range_id				// %ecx = ride_ptr
	movl	RIDE_RUNTIME_ID_LIB_NUMBER(%ecx),%eax	// %eax = run-time id number
	call	convert_code_rt_to_disk_id					// %ecx = corresponding disk id
	movl	%ecx,%eax								// disk id in output register
	ret

	// input:
	// - %ebx = address to find
	// 
	// output:
	// - %ecx = ptr to range_id_entry
	//
	// destroys:
	// - %eax, %ecx
find_address_in_range_id:
#define temp %edx
	pushl	temp
	
#define ride_ptr arity
#define rid_end_ptr nodeP
	movl	range_table,ride_ptr				// load base address of range_id table
	leal	8(ride_ptr),ride_ptr				// skip Clean STRING descriptor and length
	
	movl	RID_N_RANGE_ENTRIES_OFFSET(ride_ptr),rid_end_ptr
	movl	$ RIDE_SIZE,temp
	mull	temp		
	
	leal	RID_HEADER_SIZE(ride_ptr),ride_ptr	// ride_ptr = range_table + RID_HEADER_SIZE
	addl	ride_ptr,rid_end_ptr				// rid_end_ptr = ride_ptr + RID_N_RANGE_ENTRIES_OFFSET * RIDE_SIZE

1:
	// comparison i.e. start =< descP =< end
	cmpl 	RIDE_BEGIN_ADDRESS_OFFSET(ride_ptr),descP
	jb		2f
	cmpl	RIDE_END_ADDRESS_OFFSET(ride_ptr),descP
	jbe		3f
	
2:	
	addl	$ RIDE_SIZE,ride_ptr			
	cmpl	ride_ptr,rid_end_ptr
	jne 	1b

	popl	temp
	
	int3
	movl	$ unknown_address,%ecx	
	jmp		abort	
3:
	// address found
#undef rid_end_ptr
#undef ride_ptr
	popl	temp
#undef temp
	ret
	
	// 
	// input:
	// - %eax = run-time type id
	//
	// output:
	// - %ecx = disk type id
	//
	// destroys:
	// - %eax, %ecx
convert_code_rt_to_disk_id:
#define temp nodeP
#define temp2 arity
	leal	12(,temp,4),temp				// skip ARRAY, INT and length information
	addl	type_table_usage,temp
	movl	(temp),temp2				// get temp-th array element

	cmpl	$ TTUT_UNUSED,temp2
	jne		1f							

	
	movl	disk_type_id,temp2
	movl	temp2,(temp)				// update type_table_usage
	
	incl	disk_type_id				// increment type_table_usage ptr	
1:
	orl		$ CODE_LIBRARY_INSTANCE,(temp)	// mark library instance as used by a code reference

	andl	$ LIBRARY_INSTANCE_MASK,%ecx

	ret
#undef temp2	
#undef temp
	
	// -------------------------------------------------------------------------------------
	// External functions
	// dummy
restore__Module_descriptors:					// dummy
	ret

	pushl	nodeP
#define temp %ecx
	movl	TOT_TCS_TYPE_NAME(nodeP),temp	// fetch type string
	movl	temp,type_string_ptr	
#define arg_blockP nodeP
	movl	12(nodeP),arg_blockP
#undef temp
	popl	nodeP
