definition module type_io_equal_type_defs

from typetable import :: TypeTable
from type_io_read import :: TypeTableTypeReference
		
:: OrderedTypeRef
	= {	otr_type_ref1	:: TypeTableTypeReference
	,	otr_type_ref2	:: TypeTableTypeReference
	};

:: *EqTypesState
default_eq_types_state :: *EqTypesState;

class EqTypesExtended a
where
	equal_type_defs :: !a !a !{#*TypeTable} !*EqTypesState -> (!Bool,!{#*TypeTable},!*EqTypesState)
	
instance EqTypesExtended TypeTableTypeReference;
