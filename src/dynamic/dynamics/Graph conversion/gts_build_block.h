
// The build_block and build_lazy_block-functions defined in DynamicGraphConversion are
// special because:
// - shared across libraries (this also may also be a disadvantage if there are
//   different versions of these functions).
// - recognised by the conversion functions:
//		* graph_to_string converts a build_block to a build_lazy_block. A build
//		  lazy block is stored in a special way in order to have a list of dynamics
//		  a dynamic depends upon.
//	    * string_to_graph convert build_lazy_blocks (from encoded dynamic) to
//        runtime build_lazy_blocks.

// arguments of build_dynamic (defined in DynamicGraphConversion)
#define BUILD_DYNAMIC_NODE__INDEX_PTR	4
#define BUILD_DYNAMIC_GDID__PTR			8

// arguments of build_lazy_dynamic 
#define BUILD_LAZY_DYNAMIC__NODE_INDEX			4
#define BUILD_LAZY_DYNAMIC__LAZY_DYNAMIC_INDEX	8

// arguments of build_lazy_dynamic (on disk, relative offsets from arg block of build_lazy_block)
#define BUILD_LAZY_DYNAMIC_ON_DISK__NODE_INDEX	0
#define BUILD_LAZY_DYNAMIC_ON_DISK__DYNAMIC_ID	4

#define BUILD_LAZY_DYNAMIC_ON_DISK__LAST_FIELD 	(BUILD_LAZY_DYNAMIC_ON_DISK__DYNAMIC_ID + 4)
#define BUILD_LAZY_DYNAMIC_ON_DISK__BSIZE		BUILD_LAZY_DYNAMIC_ON_DISK__LAST_FIELD
#define BUILD_LAZY_DYNAMIC_ON_DISK__WSIZE		(BUILD_LAZY_DYNAMIC_ON_DISK__LAST_FIELD / 4)
