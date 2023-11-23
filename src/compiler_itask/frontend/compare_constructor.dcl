system module compare_constructor;

equal_constructor a b :== equal_constructor a b;
{
	equal_constructor :: !a !a ->Bool;
	equal_constructor _ _ = code inline {
		pushD_a 1
		pushD_a 0
		pop_a 2
		eqI
	};
}

less_constructor a b :== less_constructor a b;
{
	less_constructor :: !a !a ->Bool;
	less_constructor _ _ = code inline {
		pushD_a 1
		pushD_a 0
		pop_a 2
		ltI
	};
}

greater_constructor a b :== greater_constructor a b;
{
	greater_constructor :: !a !a ->Bool;
	greater_constructor _ _ = code inline {
		pushD_a 1
		pushD_a 0
		pop_a 2
		gtI
	};
}
