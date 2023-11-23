implementation module cg_name_mangling;

import StdEnv;

unmangle_name s :== expand_special_chars s;

expand_special_chars :: !String -> String;
expand_special_chars s
	#! limit
		= size s;
	#! delta
		= count_length_of_expanded_string 0 limit s 0
	| delta == 0
		= s;
		
	#! expanded_label_name_limit
		= limit + delta;
	#! expanded_label_name
		= createArray expanded_label_name_limit ' ';
	= expand_name 0 limit s 0 expanded_label_name
where {
	expand_name :: !Int !Int !String !Int !*{#Char} -> *{#Char};
	expand_name i limit s j name
		| i == limit
			= name;
			
		#! (delta,name)
			= case s.[i] of {
				'.'		-> (2, { name & [j] = '_', [j+1] = 'P' });
				'_' 	-> (2, { name & [j] = '_', [j+1] = '_' });
				'*' 	-> (2, { name & [j] = '_', [j+1] = 'M' });
				'-' 	-> (2, { name & [j] = '_', [j+1] = 'S' });
				'+' 	-> (2, { name & [j] = '_', [j+1] = 'A' });
				'='		-> (2, { name & [j] = '_', [j+1] = 'E' });
				'~'		-> (2, { name & [j] = '_', [j+1] = 'T' });
				'<'		-> (2, { name & [j] = '_', [j+1] = 'L' });
				'>'		-> (2, { name & [j] = '_', [j+1] = 'G' });
				'/'		-> (2, { name & [j] = '_', [j+1] = 'D' });
				'?'		-> (2, { name & [j] = '_', [j+1] = 'Q' });
				'#'		-> (2, { name & [j] = '_', [j+1] = 'H' });
				':' 	-> (2, { name & [j] = '_', [j+1] = 'C' });
				'$' 	-> (3, { name & [j] = '_', [j+1] = 'N', [j+2] = 'D' });
				'^' 	-> (3, { name & [j] = '_', [j+1] = 'N', [j+2] = 'C' });
				'@' 	-> (3, { name & [j] = '_', [j+1] = 'N', [j+2] = 'T' });
				'&' 	-> (3, { name & [j] = '_', [j+1] = 'N', [j+2] = 'A' });
				'%' 	-> (3, { name & [j] = '_', [j+1] = 'N', [j+2] = 'P' });
				'\''	-> (3, { name & [j] = '_', [j+1] = 'N', [j+2] = 'S' });
				'\"'	-> (3, { name & [j] = '_', [j+1] = 'N', [j+2] = 'Q' });
				'|'		-> (2, { name & [j] = '_', [j+1] = 'O' });
				'\\'	-> (3, { name & [j] = '_', [j+1] = 'N', [j+2] = 'B' });
				'`'		-> (2, { name & [j] = '_', [j+1] = 'B' });
				'!'		-> (3, { name & [j] = '_', [j+1] = 'N', [j+2] = 'E' });
				';'		-> (2, { name & [j] = '_', [j+1] = 'I' });
				c		-> (1, { name & [j] = c });
			}
			
		= expand_name (inc i) limit s (j + delta) name;
}

mangled_name_length unmangled_name :== count_length_of_expanded_string 0 s_unmangled_name unmangled_name s_unmangled_name;
where {
	s_unmangled_name
		= size unmangled_name;
};

count_length_of_expanded_string :: !Int !Int !String !Int -> Int;
count_length_of_expanded_string i limit s l
	| i == limit
		= l;
	#! delta
		= case s.[i] of {
			'.'		-> 1;
			'_' 	-> 1;
			'*' 	-> 1;
			'-' 	-> 1;
			'+' 	-> 1;
			'='		-> 1;
			'~'		-> 1;
			'<'		-> 1;
			'>'		-> 1;
			'/'		-> 1;
			'?'		-> 1;
			'#'		-> 1;
			':' 	-> 1;
			'$' 	-> 2;
			'^' 	-> 2;
			'@' 	-> 2;
			'&' 	-> 2;
			'%' 	-> 2;
			'\''	-> 2;
			'\"'	-> 2;
			'|'		-> 1;
			'\\'	-> 2;		
			'`'		-> 1;
			'!'		-> 2;
			';'		-> 1;
			_		-> 0
		}
	= count_length_of_expanded_string (inc i) limit s (l + delta);

// Labels
// Layout:
// e__<mangled module_name>__<prefix><mangled {function,constructor} name}>

// Constants
mangled_module_name_prefix		:== "e__";
s_mangled_module_name_prefix	:== size mangled_module_name_prefix;

mangled_module_name_suffix		:== "__";
s_mangled_module_name_suffix	:== size mangled_module_name_suffix;

class get_label_prefix_from_label s :: !String !Bool !s -> Char;

instance get_label_prefix_from_label Int
where {
	get_label_prefix_from_label label True s_unmangled_name
		# prefix_start
			= s_mangled_module_name_prefix + s_unmangled_name + s_mangled_module_name_suffix;
		# prefix_end
			= inc prefix_start;
		= (label % (prefix_start,prefix_end)).[0];
};
			
demangle :: !String -> String;
demangle mangled_name 
	// compute size of unmangled name
	#! s_mangled_name 
		= size mangled_name;
	#! s_unmangled_name
		= compute_s_unmangled_name 0 s_mangled_name 0
		with {
			compute_s_unmangled_name :: !Int !Int !Int -> Int;
			compute_s_unmangled_name i limit s_unmangled_name
				| i == limit
					= s_unmangled_name;
				
				| mangled_name.[i] == '_'
					# is_mangling_of_three_characters
						= mangled_name.[inc i] == 'N';
					= compute_s_unmangled_name (i + (if is_mangling_of_three_characters 3 2)) limit (inc s_unmangled_name);
					= compute_s_unmangled_name (inc i) limit (inc s_unmangled_name);
		}
		
	| s_mangled_name == s_unmangled_name
		// not mangled because a mangled name becomes always shorter
		= mangled_name;
		
	// convert to unmangled name
	#! unmangled_name
		= compute_unmangled_name 0 s_unmangled_name 0 (createArray s_unmangled_name ' ')
		with {
			compute_unmangled_name :: !Int !Int !Int !*{#Char} -> *{#Char};
			compute_unmangled_name i limit j_mangled_name unmangled_name
				| i == limit
					= unmangled_name;
					
				| mangled_name.[j_mangled_name] == '_'
					# next_mangling_char
						= mangled_name.[inc j_mangled_name];
					# is_mangling_of_three_characters
						= next_mangling_char == 'N';
					| is_mangling_of_three_characters
						// length of mangling is 3
						# next_next_mangling_char
							= mangled_name.[inc j_mangled_name];
						| next_next_mangling_char == 'D'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 3) {unmangled_name & [i] = '$'};
						| next_next_mangling_char == 'C'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 3) {unmangled_name & [i] = '^'};
						| next_next_mangling_char == 'T'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 3) {unmangled_name & [i] = '@'};
						| next_next_mangling_char == 'A'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 3) {unmangled_name & [i] = '&'};
						| next_next_mangling_char == 'P'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 3) {unmangled_name & [i] = '%'};
						| next_next_mangling_char == 'S'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 3) {unmangled_name & [i] = '\''};
						| next_next_mangling_char == 'Q'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 3) {unmangled_name & [i] = '\"'};
						| next_next_mangling_char == 'B'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 3) {unmangled_name & [i] = '\\'};
						| next_next_mangling_char == 'E'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 3) {unmangled_name & [i] = '!'};
							= abort "compute_unmangled_name; cannot unmangle three characters";
						
						// length of mangling is 2
						| next_mangling_char == '_'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '_'};
						| next_mangling_char == 'P'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '.'};
						| next_mangling_char == 'M'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '*'};
						| next_mangling_char == 'S'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '-'};
						| next_mangling_char == 'A'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '+'};
						| next_mangling_char == 'E'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '='};
						| next_mangling_char == 'T'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '~'};
						| next_mangling_char == 'L'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '<'};
						| next_mangling_char == 'G'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '>'};
						| next_mangling_char == 'D'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '/'};
						| next_mangling_char == 'Q'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '?'};
						| next_mangling_char == 'H'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '#'};
						| next_mangling_char == 'C'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = ':'};
						| next_mangling_char == 'O'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '|'};
						| next_mangling_char == 'B'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = '`'};
						| next_mangling_char == 'I'
							= compute_unmangled_name (inc i) limit (j_mangled_name + 2) {unmangled_name & [i] = ';'};
							= abort "compute_unmangled_name; cannot unmangle two characters";
					
					// unmangled character			
					= compute_unmangled_name (inc i) limit (inc j_mangled_name) {unmangled_name & [i] = mangled_name.[j_mangled_name]};
		}
	= unmangled_name;
