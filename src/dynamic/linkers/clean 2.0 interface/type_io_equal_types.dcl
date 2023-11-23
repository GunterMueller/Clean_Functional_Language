definition module type_io_equal_types

from type_io_read import :: TypeIOState, :: TIO_CommonDefs
from StdDynamicTypes import :: TIO_TypeReference
from BitSet import ::BitSet;

// converts a a type reference into an (unique) index
compute_index_in_type_cache :: !TIO_TypeReference !TIO_TypeReference !*TypeIOState -> (!Int,!*TypeIOState)

equal_types_TIO_TypeReference :: !TIO_TypeReference !TIO_TypeReference !*BitSet !*{#TIO_CommonDefs} !*TypeIOState
															 -> (!Bool,!*BitSet,!*{#TIO_CommonDefs},!*TypeIOState)
