implementation module dus_label;

import DefaultElem;
import UnknownModuleOrSymbol;
import LinkerMessages;
import dynamics;
import StdEnv;
import pdExtInt;
import _SystemDynamic;

:: DusLabel
	= {
		dusl_label_name				:: !String						// label name valid in dusl_library_instance_i
	,	dusl_library_instance_i		:: !Int							// if field below is False then library_instance_i contains/will contain the label_name, otherwise library_instance_i that contains actually contains the label.
	,	dusl_linked 				:: !Bool						// label representing a constructor of a type equivalence member *with* implementation for that class
	,	dusl_label_kind				:: !DusLabelKind
	,	dusl_ith_address			:: !Int
	,	dusl_address				:: !Int
	};

instance DefaultElem DusLabel
where {
	default_elem
		= {
			dusl_label_name				= ""
		,	dusl_library_instance_i		= 0
		,	dusl_linked					= False
		,	dusl_label_kind				= DSL_EMPTY
		,	dusl_ith_address			= -999
		,	dusl_address				= -1

		};
};
	
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

produce_verbose_output :: ![ModuleOrSymbolUnknown] ![Int] [LinkerMessage] -> [LinkerMessage];
produce_verbose_output [] [] labels
	= labels;
produce_verbose_output [ModuleUnknown module_name label_name:unknown_modules] [label_address:label_addresses] labels
	#! label = Verbose ("label " +++ label_name +++ " at " +++ (hex_int label_address));
	= produce_verbose_output unknown_modules label_addresses [label:labels];
produce_verbose_output [SymbolUnknown module_name label_name:unknown_modules] [label_address:label_addresses] labels
	#! label = Verbose ("label " +++ label_name +++ " at " +++ (hex_int label_address));
	= produce_verbose_output unknown_modules label_addresses [label:labels];
produce_verbose_output _ [] _
	= abort "!produce_verbose_output; no addresses";
	
produce_verbose_output2 :: [LinkerMessage] !DusLabel !Int -> [LinkerMessage];
produce_verbose_output2 messages {dusl_label_name,dusl_library_instance_i,dusl_linked,dusl_label_kind} address
	#! linked
		= if dusl_linked "linked " "";
	#! label_kind
		= case dusl_label_kind of {
			DSL_RUNTIME_SYSTEM_LABEL
				-> "RTS";
			DSL_TYPE_EQUIVALENT_CLASS_WITH_IMPLEMENTATION
				-> "LINKED TYPE";
			DSL_TYPE_EQUIVALENT_CLASS_IMPLEMENTATION
				-> "UNLINKED TYPE";
			DSL_CLEAN_LABEL_BUT_NOT_A_TYPE
				-> "NON CLEAN TYPE";
			DSL_EMPTY
				-> "EMPTY";
		};
	#! label
		= Verbose (linked +++ "label " +++ dusl_label_name +++ "<" +++ toString dusl_library_instance_i +++ "," +++ label_kind +++ "> at " +++ (hex_int address));
	= [label:messages];

generate_dus_label :: !Char !DusImplementation -> (!DusLabel,DusImplementation);
generate_dus_label prefix dusi=:{dusi_descriptor_name,dusi_module_name,dusi_library_instance_i,dusi_linked,dusi_label_kind}
	#! label_name
		= gen_label_name True (dusi_descriptor_name,dusi_module_name) prefix;
	#! dus_label
		= { default_elem &
			dusl_label_name				= label_name
		,	dusl_library_instance_i		= dusi_library_instance_i
		,	dusl_linked					= dusi_linked
		,	dusl_label_kind				= dusi_label_kind
		};
	= (dus_label,dusi);
