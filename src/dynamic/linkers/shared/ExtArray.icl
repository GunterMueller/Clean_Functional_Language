implementation module ExtArray;

import DefaultElem;
import StdArray;
import StdMaybe;
import StdEnv;

foldlNonUniqueArraySt f a s :== mapASt f a s;

mapASt f a s :== map_a_st 0 (size a) f a s
where {
	map_a_st i limit f a s
		| i == limit
			= s;
			= map_a_st (inc i) limit f a (f a.[i] s);
}; 

// S = for start
mapAiStS f a s start :== map_a_st start (size a) f a s
where {
	map_a_st i limit f a s
		| i == limit
			= s;
			= map_a_st (inc i) limit f a (f i a.[i] s);
}; 

// A = array, i = index, St = state
mapAiSt f a s :== map_a_st 0 (size a) f a s
where {
	map_a_st i limit f a s
		| i == limit
			= s;
			= map_a_st (inc i) limit f a (f i a.[i] s);
}; 

// A = array, i = index, St = state
map2AiSt f a1 a2 s :== map2_a_st 0 (size a1) f a1 a2 s
where {
	map2_a_st i limit f a1 a2 s
		| size a1 <> size a2
			= abort "map2AiSt: arrays not of same size";
			= map_a_st i limit f a1 a2 s;
	where {
		map_a_st i limit f a1 a2 s
			| i == limit
				= s;
				= map_a_st (inc i) limit f a1 a2 (f i a1.[i] a2.[i] s);
	};
}; 

findAiSt2 p a s :== map_a_st 0 (size a) p a s
where {
	map_a_st i limit p a s
		| i == limit
			= (Nothing,s);
			# (ok,s)
				= (p i a.[i] s)
			| isJust ok
				= (ok,s)
				= map_a_st (i + 1) limit p a s;
}; 

findAiSt p a s :== map_a_st 0 (size a) p a s
where {
	map_a_st i limit p a s
		| i == limit
			= s;
			# (ok,s)
				= (p i a.[i] s)
			| ok
				= s
				= map_a_st (inc i) limit p a s;
}; 

findAi p a :== map_a_st 0 (size a) p a
where {
	map_a_st i limit p a
		| i == limit
			= Nothing;
			# r
				= p i a.[i]
			| isNothing r
				= map_a_st (inc i) limit p a;
				= r
}; 
 
findAieu p a :== map_a_st2 p a
where {
	map_a_st2 p a
		#! (s_a,a)
			= usize a;
		= map_a_st 0 s_a p a;
	
	map_a_st i limit p a
		| i == limit
			= (Nothing,a);
			# (elem,a)
				= a![i];
			# r
				= p i elem
			| isNothing r
				= map_a_st (inc i) limit p a;
				= (r,a);
}; 

findAieuSt p a st :== map_a_st2 p a st
where {
	map_a_st2 p a st
		#! (s_a,a)
			= usize a;
		= map_a_st 0 s_a p a st;
	
	map_a_st i limit p a st
		| i == limit
			= (Nothing,a,st);
			
			# (elem,a)
				= a![i];
			# (r,st)
				= p i elem st
			| isNothing r
				= map_a_st (inc i) limit p a st;
				= (r,a,st);
}; 

findAieuSE p start end a :== map_a_st2 p a
where {
	map_a_st2 p a
		= map_a_st start end p a;
	
	map_a_st i limit p a
		| i == limit
			= (Nothing,a);
			# (elem,a)
				= a![i];
			# r
				= p i elem
			| isNothing r
				= map_a_st (inc i) limit p a;
				= (r,a);
}; 

loopA f a s :== loop2 f s a
where
{
	loop2 f s a
		#! (s_a,a)
			= usize a;
		= loop 0 s_a a s f;
		 
	loop i limit a s f
		| i == limit
			= (a,s)
			#! (e,a)
				= a![i];
			#! s
				= f e s;
			= loop (inc i) limit a s f;
}

class ExtArrayDefaultElem .e
where
{
	ExtArrayDefaultElem :: .e
};

instance ExtArrayDefaultElem Bool
where {
	ExtArrayDefaultElem = False
};

instance ExtArrayDefaultElem Int
where {
	ExtArrayDefaultElem :: .Int;
	ExtArrayDefaultElem = 0
};

// class array uitbreiden met default element
loopAur f a s :== loop2 f s a
where {
	loop2 f s a
		#! (s_a,a)
			= usize a;
		= loopQ 0 s_a a s f;
	
	loopQ i limit a s f
		| i == limit
			= (a,s);
			#! (e,a)
				= replace a i ExtArrayDefaultElem;
			#! (e,s)
				= f e s;
			#! a
				= { a & [i] = e};
			= loopQ (inc i) limit a s f;
}

loopAfill f a s:== loop2 f a s
where {
	loop2 f a s
		#! (s_a,a)
			= usize a;
		= loop 0 s_a a s f;
		 
	loop i limit a s f
		| i == limit
			= (a,s)
			#! (a,s)
				= f i a s;
			= loop (inc i) limit a s f;
}	

loopAst f s limit :== loopAst 0 limit f s 
where {
	loopAst i limit f s
		| i == limit
			= s;
			#! s
				= f i s;
			= loopAst (inc i) limit f s;
}

loopbAst f s start limit :== loopAst start limit f s 
where {
	loopAst i limit f s
		| i == limit
			= s;
			#! s
				= f i s;
			= loopAst (inc i) limit f s;
}

findAst f s limit :== loopAst 0 limit f s 
where {
	loopAst i limit f s
		| i == limit
			= (Nothing,s);
			
			#! (result,s)
				= f i s;
			| isNothing result
				= loopAst (inc i) limit f s;
				= (result,s);
}

// map
// A = on arrays
// e = f gets as first argument element at index i
// i = f gets as 2nd arg current array index
// a = f gets as 3rd arg the array
// u = assumes array unique but its elements not
mapAeiauSt f a s:== loop2 f a s
where {
	loop2 f a s
		#! (s_a,a)
			= usize a;
		= loop 0 s_a a s f;
		 
	loop i limit a s f
		| i == limit
			= (a,s)
			
			#! (element,a)
				= a![i];
			#! (a,s)
				= f element i a s;
			= loop (inc i) limit a s f;
}

// extend array with non-unique elements
extend_array_nu :: .Int .(a b) -> (Int,.(c b)) | Array c b & Array a b & DefaultElem b;
extend_array_nu n_new_elements a 
	# (s_a,a)
		= usize a;
	# s_new_a
		= s_a + n_new_elements;
	# new_a
		= createArray s_new_a default_elem;
	# new_a
		= { new_a & [i] = a.[i]  \\ i <- [0..dec s_a] };
	= (dec s_new_a,new_a);

real_mapASt f a s	
	:== real_mapAiSt (\i element s -> f element s) s;

real_mapAiSt f a s
	:== real_mapAiSt f a s
where {
	real_mapAiSt f a s
		# s_a
			= size a
		# new_a
			= createArray s_a default_elem
		= real_mapASt 0 s_a new_a s
	where {
		real_mapASt i limit new_a s
			| i == limit
				= (new_a,s);
				
				# (new_element,s)
					= f i a.[i] s;
				= real_mapASt (inc i) limit {new_a & [i] = new_element} s;
	};
};

extend_array :: .Int .(a b) -> (Int,.(c b)) | Array c b & Array a b & DefaultElem b;
extend_array n_new_elements a 
	# (s_a,a)
		= usize a;
	# s_new_a
		= s_a + n_new_elements;
	# new_a
		= createArray s_new_a default_elem;
	# new_a
		= { new_a & [i] = a.[i] \\ i <- [0..dec s_a] };
	= (dec s_new_a,new_a);
