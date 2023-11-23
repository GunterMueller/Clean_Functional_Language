definition module cg_name_mangling;

from StdArray import class Array (size);

unmangle_name s :== expand_special_chars s;

expand_special_chars :: !String -> String;

mangled_name_length unmangled_name :== count_length_of_expanded_string 0 s_unmangled_name unmangled_name s_unmangled_name;
where {
	s_unmangled_name
		= size unmangled_name;
};

count_length_of_expanded_string :: !Int !Int !String !Int -> Int;

// Labels
// Layout:
// e__<mangled module_name>__<prefix><mangled {function,constructor} name}>

// Constants
mangled_module_name_prefix		:== "e__";
s_mangled_module_name_prefix	:== size mangled_module_name_prefix;

mangled_module_name_suffix		:== "__";
s_mangled_module_name_suffix	:== size mangled_module_name_suffix;

class get_label_prefix_from_label s :: !String !Bool !s -> Char;

instance get_label_prefix_from_label Int;

demangle :: !String -> String;
