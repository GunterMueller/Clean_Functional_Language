definition module dus_label;

from DefaultElem import class DefaultElem;
from UnknownModuleOrSymbol import :: ModuleOrSymbolUnknown;
from LinkerMessages import :: LinkerMessage;

:: DusLabel
	= {
		dusl_label_name				:: !String						// label name valid in dusl_library_instance_i
	,	dusl_library_instance_i		:: !Int							// if field below is False then library_instance_i contains/will contain the label_name, otherwise library_instance_i that contains actually contains the label.
	,	dusl_linked 				:: !Bool						// label representing a constructor of a type equivalence member *with* implementation for that class
	,	dusl_label_kind				:: !DusLabelKind
	,	dusl_ith_address			:: !Int
	,	dusl_address				:: !Int
	};

instance DefaultElem DusLabel;
	
:: DusLabelKind
	= DSL_EMPTY
	| DSL_RUNTIME_SYSTEM_LABEL
	| DSL_TYPE_EQUIVALENT_CLASS_WITH_IMPLEMENTATION
	| DSL_TYPE_EQUIVALENT_CLASS_IMPLEMENTATION
	| DSL_CLEAN_LABEL_BUT_NOT_A_TYPE
	;

:: DusImplementation
	= {
		dusi_descriptor_name		:: !String
	,	dusi_module_name			:: !String						
	,	dusi_library_instance_i		:: !Int							// if field below is False then library_instance_i contains/will contain the label_name, otherwise library_instance_i that contains actually contains the label.
	,	dusi_linked					:: !Bool						// label representing a constructor of a type equivalence member *with* implementation for that class
	,	dusi_label_kind				:: !DusLabelKind
	};

generate_dus_label :: !Char !DusImplementation -> (!DusLabel,DusImplementation);
	
produce_verbose_output :: ![ModuleOrSymbolUnknown] ![Int] [LinkerMessage] -> [LinkerMessage];
	
produce_verbose_output2 :: [LinkerMessage] !DusLabel !Int -> [LinkerMessage];
