implementation module commonWriteState;

invert_marked_bool_a :: !*State -> (!*{#Bool},!*State);
invert_marked_bool_a state 
	#! (marked_bool_a, state)
		= select_marked_bool_a state;
	#! (size, marked_bool_a)
		= usize marked_bool_a;
	#! inverted_marked_bool_a
		= { False \\ i <- [1..size] };
	#! (inverted_marked_bool_a, marked_bool_a)
		= invert 0 size inverted_marked_bool_a marked_bool_a;
	= (inverted_marked_bool_a,{state & marked_bool_a = marked_bool_a});	
where
{
		invert :: !Int !Int !*{#Bool} !*{#Bool} -> (!*{#Bool},!*{#Bool});
		invert i limit inverted_marked_bool_a marked_bool_a
			| i == limit
				= (inverted_marked_bool_a,marked_bool_a);
				
			#! (element,marked_bool_a)
				= marked_bool_a![i];
			= invert (inc i) limit {inverted_marked_bool_a & [i] = not element} marked_bool_a;
				
}