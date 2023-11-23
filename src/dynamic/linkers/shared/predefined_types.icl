implementation module predefined_types;

import StdEnv;

:: PredefinedType
	= {
		pt_type_name			:: !String
	,	pt_constructor_names	:: [String]
	};
	
:: PredefinedTypes 
	:== [PredefinedType];

// FIXME: this list is far from complete: is it actually used?
PredefinedTypes :: PredefinedTypes;		
PredefinedTypes
	=> [list_type,real_type,int_type,unboxed_array];
where {
	list_type
		= {
			pt_type_name			= "_List"
		,	pt_constructor_names	= ["_Cons","_Nil"]
		};
	real_type
		= {
			pt_type_name			= "Real"
		,	pt_constructor_names	= ["REAL"]
		};
		
	int_type
		= {
			pt_type_name			= "Int"
		,	pt_constructor_names	= ["INT"]
		};
		
	unboxed_array
		= {
			pt_type_name			= "_#Array"
		,	pt_constructor_names	= ["_ARRAY_"]
		};
	
		
};