definition module ExtList;

splitAtPred :: (.a -> (.Bool,.b)) ![.a] w:[.b] u:[.b] -> (x:[.b],v:[.b]), [u <= v, w <= x];

is_empty :: !u:[.a] -> (!.Bool,v:[.a]), [u <= v];		

mapSt f l s :== map_st l s;
	where {
		map_st [x : xs] s
		 	# (x, s) = f x s;
			  mapSt_result = map_st xs s;
			  (xs, _) = mapSt_result;
			#! s = second_of_2_tuple mapSt_result;
			= ([x : xs], s);
		map_st [] s
		 	= ([], s);
	};
	
second_of_2_tuple t :== e2;
	where {
		(_,e2) = t;
	};

isMemberP :: (.a -> .Bool) ![.a] -> .Bool;

anySt :: (.a -> .(.b -> (.Bool,.b))) ![.a] .b -> (.Bool,.b);

allSt	:: (.a -> .(.b -> (.Bool,.b))) ![.a] .b -> (.Bool,.b);
