finished:
	// *******************************************************************************************
	cmpl	$0,free							// free >= 0
	jg		prepare_to_return

garbage_collection2:	
# ifdef DEBUG_GC
//	int3
	save_regs 
	
	pushl	$gc_message
	call	_w_print_string
	addl	$4,%esp
	
	pushl	$'\n'
	call	_w_print_char
	addl	$4,%esp

	restore_regs
# endif 

	movl	old_heap_pointer,heapP			// release string memory
	
# define usedCells	%eax
	movl	initfree,usedCells
	subl	free,usedCells
	
	leal	-32(heapP,usedCells,4),free		// reserve usedCells * 4 from old heap start, gebruik l-entry
	
	movl	ecx_backup,%ecx
	movl	esp_backup,%esp					// restore B/C stackpointer
	popl	%esi
	movl	esi_backup,%esi 
	
	call	collect_1l 

#undef usedCells
	movl	$1,retry_after_gc

	jmp		copy__graph__to__string__0x00010101	
		
	/*
	** string format:
	*/
prepare_to_return:
	movl	esp_backup,%esp
#define	temp	%eax
prepare_to_return2:

	_set_default_undo_handler

	// misschien vooraf alles tussen heapP en end_heap vrijgeven.

#define BK_BLOCK_N			0
#define BK_START_OFFSET		4		// offset (in bytes) from encoding start
#define BK_SIZE				8		// block size (in bytes)
#define BK_N_EN_NODES		12		// # EN-nodes in block

#define BK_BASIC_BSIZE		(BK_N_EN_NODES + 4)
#define BK_BASIC_WSIZE		(BK_BASIC_BSIZE / MACHINE_WORD_BSIZE) // in bytes
	// block table	
	
	// store # blocks
	call	MAKE_ID_FBI(lb_size)
#define n_blocks %ecx

	// create index array for quick block array access
	subl	n_blocks,free	
	js		undo_handler
	
	movl	n_blocks,temp
	shll	$2,temp	
	movl	temp,index_array_size		// size of index array (in bytes)
	
	movl	heapP,index_array_ptr		// backup index array_pointer
	leal	(heapP,n_blocks,4),heapP	// create index array for blocks
	
	// create block array
	movl	heapP,block_table_start		// backup block table start

	subl	$1,free
	js		undo_handler

	movl	n_blocks,(heapP)			// amount of blocks
#undef n_blocks

	addl	$4,heapP
	
	movl	$ create_block_table,%ecx	// create block table
	call	MAKE_ID_FBI(lb_map_array)
	
	movl	$ insert_en_nodes_in_block_table,%ecx
	call	MAKE_ID_FEN(lb_map_array)
	
	// overwrite index_array with block table
#define block_table_p nodeP
#define index_array_p	descP
#define block_table_end heapP
	movl	block_table_start,block_table_p	// load start address of block table
	movl	index_array_ptr,index_array_p	// load start address of index array
	
	movl	index_array_p,block_table_start	// new start address of block table
	
1:
	cmpl	block_table_end,block_table_p
	jae		0f								// block_table_p >= block_table_end
	
#define temp2 arity
	movl	(block_table_p),temp2
	movl	temp2,(index_array_p)
#undef temp2
	addl	$4,block_table_p
	addl	$4,index_array_p
	
	jmp		1b
0:
	subl	index_array_size,heapP				// free index array
	
	movl	heapP,block_table_end2

#undef block_table_end
#undef index_array_p
#undef block_table_p

	movl 	old_heap_pointer,%ecx

	movl 	heapP,%eax					
	subl 	%ecx,%eax		
	subl	$8,%eax			 
						
	movl 	%eax,4(%ecx)					// length (%eax) = heapP - old_heap_pointer - 8 
 
#define t2 descP
#define t3 stackP
	movl	old_heap_pointer,temp
	leal	8(temp),temp					// temp = ptr to string start

	// set header size
	movl	$ HEADER_SIZE,t3
	subl	$4,t3						
	movl	t3,HEADER_SIZE_OFFSET(%ecx)		// header size
	
	// set version number of encoding routine
	movl	$ VERSION_NUMBER,t2
	movl	t2,VERSION_NUMBER_OFFSET(%ecx)
	
	// set graph offset and size
	movl	graph_start,t2
	movl	graph_end,t3
	subl	t2,t3							// t3 = graph_end - graph_start
	movl	t3,GRAPH_SIZE(%ecx)
	subl	temp,t2							// t2 = graph_start - string start
	movl	t2,GRAPH_OFFSET(%ecx)
	
	// set block table offset and size
	movl	block_table_start,t2
	movl	block_table_end2,t3
	subl	t2,t3							// t3 = graph_end - graph_start
	movl	t3,BLOCK_TABLE_SIZE(%ecx)
	subl	temp,t2							// t2 = graph_start - string start
	movl	t2,BLOCK_TABLE_OFFSET(%ecx)
	
	movl	$0x0,DYNAMIC_RTS_INFO_OFFSET(%ecx)
	movl	$0x0,DYNAMIC_RTS_INFO_SIZE(%ecx)
// End sharing for StdDynamic.icl
	
	// set string table offset and size
	movl	string_table_start,t2
	movl	string_table_end,t3
	subl	t2,t3
	movl	t3,STRINGTABLE_SIZE(%ecx)
	subl	temp,t2
	movl	t2,STRINGTABLE_OFFSET(%ecx)
	
	// set descriptor usage set offset and size
	movl	dus_start,t2
	movl	dus_end,t3
	subl	t2,t3
	movl	t3,DESCADDRESSTABLE_SIZE(%ecx)
	subl	temp,t2
	movl	t2,DESCADDTRESTABLE_OFFSET(%ecx)
	
	// set nodes
	movl	n_nodes,t3
	movl	t3,N_NODES(%ecx)
	
#ifdef BUILD_DESCRIPTOR_BITSET
	// set descriptor bitset
	movl	descriptor_bitset_start,t2
	movl	descriptor_bitset_end,t3
	subl	t2,t3
	movl	t3,DESCRIPTOR_BITSET_SIZE(%ecx)
	subl	temp,t2
	movl	t2,DESCRIPTOR_BITSET_OFFSET(%ecx)
#endif 

#undef temp

#undef t2	
#undef t3
	popl	%esi

#ifdef DYNAMIC_STRINGS
	pushl	%ecx							// backup ptr to encoded dynamic

	call	MAKE_ID_FDS(lb_size)

	movl	%ecx,%eax						// %eax = n_elements to store 	
	addl	%eax,%ecx						
	addl	$3,%ecx

	pushl	%esi
	subl	%ecx,free						// reserve heap
	js		undo_handler
	popl	%esi
	
	movl	%eax,%ecx
	
	movl	%edi,backup_lazy_dynamic_index_array
	
	movl	$__ARRAY__+2,(%edi)				// fill array header
	movl	%ecx,4(%edi)
	movl	$ CLEAN_rLazyDynamicReference+2,8(%edi)
	addl	$12,%edi

	pushl	%esi
	movl	$ fill_dynamic_string,%ecx
	call	MAKE_ID_FDS(lb_map_array)
	popl	%esi
	
# ifdef CONVERT_LAZY_RUN_TIME_ID
	call 	MAKE_ID_FRTID(lb_size)
	
	movl	%ecx,%eax						// n_elements to store
	addl	%eax,%ecx
	addl	%eax,%ecx
	addl	$3,%ecx
	
	pushl	%esi
	subl	%ecx,free
	js		undo_handler
	popl	%esi
	
	movl	%eax,%ecx						// get n_elements back

	movl	%edi,backup_runtime_ids
	
	movl	$__ARRAY__+2,(%edi)
	movl	%ecx,4(%edi)
	movl	$ CLEAN_rRunTimeIDW+2,8(%edi)
	addl	$12,%edi

	pushl	%esi
	movl	$ fill_runtime_ids,%ecx
	call	MAKE_ID_FRTID(lb_map_array)
	popl	%esi
# endif

	popl	%ecx							// restore ptr to encoded dynamic

#else // not DYNAMIC_STRINGS
	// aanname: genoeg geheugen
	movl	$__ARRAY__+2,(%edi)
	movl	$0,4(%edi)
	movl	$0,8(%edi)

	movl	%edi,-8(%esi)
	
	addl	$12,%edi 

	subl	$4,%esi
#endif	

	subl	$ 12+CGTSR_ARG_BLOCK_SIZE,free
	js		undo_handler
	
	pushl	heapP
#define temp %eax
	// Node
	// (%edi)		: CopyGraphToStringResults-descriptor
	// 4(%edi)		: string containing encoded dynamic (%ecx)
	// 8(%edi)		: ptr to arg block
	movl	$ CLEAN_rCopyGraphToStringResults+2,(heapP)
	movl	%ecx,CGTSR_ENCODED_DYNAMIC(heapP)				// ptr to encoded dynamic
	leal	12(heapP),temp
	movl	temp,8(heapP)									// ptr to arg block

	addl	$12,heapP
	
	// Arg block
	// layout of argument block
#define cgtsa %ebx
	movl	ecx_backup,cgtsa
	movl	8(cgtsa),cgtsa				// ptr to arg block
	
	movl	CGTSA_CODE_LIBRARY_INSTANCES(cgtsa),temp
	movl	temp,CGTSR_CODE_LIBRARY_INSTANCES(heapP)
	
	movl	CGTSA_TYPE_LIBRARY_INSTANCES(cgtsa),temp
	movl	temp,CGTSR_TYPE_LIBRARY_INSTANCES(heapP)

	movl	backup_lazy_dynamic_index_array,temp
	movl	temp,CGTSR_LAZY_DYNAMIC_REFERENCES(heapP)
	
#ifdef CONVERT_LAZY_RUN_TIME_ID
	movl	backup_runtime_ids,temp
	movl	temp,CGTSR_RUNTIME_IDS(heapP)
#endif
	
	addl	$ CGTSR_ARG_BLOCK_SIZE,heapP	
#undef cgtsa

	popl	%ecx						// ptr to CGTSR-node
# undef temp
	ret
	
#ifdef DYNAMIC_STRINGS
fill_dynamic_string:
	movl	(%ecx),%eax
	movl	%eax,(heapP)

	movl	4(%ecx),%eax
	movl	%eax,4(heapP)
	
	addl	$8,heapP
	ret	
#endif

	// insert en-nodes in block table
	// Two tasks:
	// 1. fill variable sized part of block table
	// 2. min (BK_START_OFFSET,current offset) (en-nodes of a block are encoded succesive)
insert_en_nodes_in_block_table:
#define en_node %ecx

#define temp descP
	movl	EN_NODE_INDEX(en_node),temp	// get node index

	pushl	temp						// backup node index

	andl	$0x0000ffff,temp
	shrl	$2,temp						// temp = block index
		
#define block_table_entry nodeP
	movl	index_array_ptr,block_table_entry
	leal	(block_table_entry,temp,4),block_table_entry
	movl	(block_table_entry),block_table_entry
#undef temp
	
#define en_offset descP
	movl	EN_BLOCK_OFFSET(en_node),en_offset	// get offset in 
	subl	$ (HEADER_SIZE + 8),en_offset
#undef en_node

	// store minimum offset of EN-nodes in block table
#define current_block_offset arity
	movl	((- BK_BASIC_BSIZE) + BK_START_OFFSET)(block_table_entry),current_block_offset	// get current block offset
	cmpl	en_offset,current_block_offset
	jbe 	0f							// current_block_offset <= en_offset
	
	movl	en_offset,((- BK_BASIC_BSIZE) + BK_START_OFFSET)(block_table_entry)	// store smaller offset
#undef current_block_offset
0:
	
#define en_index arity
	popl	en_index					// restore node index
	
	cmpl	$0,((- BK_BASIC_BSIZE) + BK_N_EN_NODES)(block_table_entry)
	je		1f

	shrl	$16,en_index				// extract entry node index

	movl	en_offset,(block_table_entry,en_index,4)
#undef en_offset
1:

#undef block_table_entry
	ret
	
	// creates the block table
create_block_table:
#define bi_block %ecx
	subl	$ BK_BASIC_WSIZE,free		// allocate basic block
	js		undo_handler
	
	// get & store block number
#define block_n nodeP
	movl	BI_INFO(bi_block),block_n
	andl	$0x0000ffff,block_n
	shrl	$2,block_n
	movl	block_n,BK_BLOCK_N(heapP)
	
#define temp descP
	movl	index_array_ptr,temp
	leal	(temp,block_n,4),temp		// temp = address in index_array for block_n
	
	leal	BK_BASIC_BSIZE(heapP),block_n
	movl	block_n,(temp)				// store address to variable sized of block_n
#undef temp
	
#undef block_n
	movl	$0xffffffff,BK_START_OFFSET(heapP)	// minimum of start offsets of the block EN-nodes
		
	// extract & store block size
# define temp nodeP
//O	movl	BI_INFO(bi_block),temp		
//O	shrl	$16,temp
	movl	BI_SIZE(bi_block),temp
	movl	temp,BK_SIZE(heapP)
#undef temp

	// store amount of block entry nodes
#define n_en_nodes nodeP
	movl	BI_N_EN_NODES(bi_block),n_en_nodes
	
	cmpl	$1,n_en_nodes
	jne		0f
	
	decl	n_en_nodes					// n_en_nodes is zero
0:
	movl	n_en_nodes,BK_N_EN_NODES(heapP)

	addl	$ BK_BASIC_BSIZE,heapP

	// reserve heap memory for the block entry nodes
	subl	n_en_nodes,free				// reserve a machine word for each entry node
	js		undo_handler
	
	shll	$2,n_en_nodes
	addl	n_en_nodes,heapP
#undef n_en_nodes
#undef bi_block
	ret

#ifdef CONVERT_LAZY_RUN_TIME_ID
fill_runtime_ids:
# define temp %eax
	movl	RTID_TYPE_STRING(%ecx),temp
	movl	temp,RTID_TYPE_STRING(heapP)

	movl 	RTID_RUNTIME_ID(%ecx),temp
	movl	temp,RTID_RUNTIME_ID(heapP)
	
	movl	RTID_ASSIGNED_DISK_ID(%ecx),temp
	movl	temp,RTID_ASSIGNED_DISK_ID(heapP)

	addl	$ RTID_SIZE,heapP
	ret
# undef temp
#endif

	.data
	.align	4
index_array_ptr:
	.long	0
index_array_size:
	.long	0
	
	// general
graph_start:
	.long	0
graph_end:
	.long	0

block_table_start:
	.long 	0
block_table_end2:
	.long 	0
dus_start:
	.long	0
dus_end:
	.long 	0

usage_bit_set_size:
	.long	0
n_usage_entries:
	.long 	0

	.data
	.align	4
string_table_start:
string_table_base:
	.long 0
string_table_end:
	.long 0

backup_lazy_dynamic_index_array:
	.long 0
	
#ifdef CONVERT_LAZY_RUN_TIME_ID
backup_runtime_ids:
	.long	0
#endif
