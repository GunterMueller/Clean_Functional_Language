definition module predefined_types;

:: PredefinedType
	= {
		pt_type_name			:: !String
	,	pt_constructor_names	:: [String]
	};
	
:: PredefinedTypes 
	:== [PredefinedType];

PredefinedTypes :: PredefinedTypes;	