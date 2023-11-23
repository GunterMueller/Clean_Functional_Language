implementation module DynamicID;

import StdEnv;
	
:: DynamicID 
	= { 
		did_counter		:: !Int		// points to next free id
	,	did_freed_ids	:: [Int]	// collection of free ids to be reused
	};
	
default_dynamic_id :: *DynamicID;
default_dynamic_id
	= { DynamicID |
		did_counter		= 	1
	,	did_freed_ids	= 	[]
	};
	
class DynamicIDs a
where {
	new_dynamic_id :: *a -> (!Int,*a);
	free_dynamic_id :: !Int *a -> *a;
	is_valid_id :: !Int *a -> *a;
	is_valid_id2 :: !Int *a -> (!Bool,*a)
};

instance DynamicIDs DynamicID
where {
	new_dynamic_id dynamic_id=:{did_counter,did_freed_ids=[]}
		= (did_counter,{dynamic_id & did_counter = inc did_counter});
	new_dynamic_id dynamic_id=:{did_counter,did_freed_ids}
		= (hd did_freed_ids,{dynamic_id & did_freed_ids = tl did_freed_ids});	
		
	free_dynamic_id id dynamic_id=:{did_counter,did_freed_ids}
		| isMember id did_freed_ids
			= abort "free_dynamic_id: internal error id cannot already been unused";
		= {dynamic_id & did_freed_ids = [id:did_freed_ids]};
		
	is_valid_id id dynamic_id=:{did_counter,did_freed_ids}
		| isMember id did_freed_ids || id >= did_counter
			= abort ("invalid dynamic id: " +++ toString id);
			= dynamic_id;

	is_valid_id2 id dynamic_id=:{did_counter,did_freed_ids}
		| isMember id did_freed_ids || id >= did_counter
			= (False,dynamic_id);
			= (True,dynamic_id);
};
