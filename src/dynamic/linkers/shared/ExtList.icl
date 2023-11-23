implementation module ExtList;

from StdBool import ||,&&;

// splitAtPred; order not preserved
splitAtPred :: (.a -> (.Bool,.b)) ![.a] w:[.b] u:[.b] -> (x:[.b],v:[.b]), [u <= v, w <= x];
splitAtPred f [] l r
	= (l,r);
splitAtPred f [h:t] l r
	#! (move_h_to_the_left,h)
		= f h;
	| move_h_to_the_left
		= splitAtPred f t [h:l] r;
		= splitAtPred f t l [h:r];
		
is_empty :: !u:[.a] -> (!.Bool,v:[.a]), [u <= v];		
is_empty []
	= (True,[]);
is_empty l 
	= (False,l);
	
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
isMemberP x [hd:tl] = x hd || isMemberP x tl;
isMemberP x []	= False;

anySt :: (.a -> .(.b -> (.Bool,.b))) ![.a] .b -> (.Bool,.b);
anySt p [] s
	= (False,s);
anySt p [x : xs] s
	# (ok,s)
		= p x s;
	| ok
		= (True,s);
		= anySt p xs s;

allSt	:: (.a -> .(.b -> (.Bool,.b))) ![.a] .b -> (.Bool,.b);
allSt p [] s
	= (True,s);
allSt p [b : tl] s
	# (ok,s)
		= p b s;
	| ok
		= allSt p tl s;
		= (False,s);
