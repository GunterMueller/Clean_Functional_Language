definition module DynamicID;

:: DynamicID 
	= { 
		did_counter		:: !Int			// points to next free id
	,	did_freed_ids	:: [Int]		// collection of free ids to be reused
	};

default_dynamic_id :: *DynamicID;

class DynamicIDs a
where {
	new_dynamic_id :: *a -> (!Int,*a);
	free_dynamic_id :: !Int *a -> *a;
	is_valid_id :: !Int *a -> *a;
	is_valid_id2 :: !Int *a -> (!Bool,*a)
};

instance DynamicIDs DynamicID;
	