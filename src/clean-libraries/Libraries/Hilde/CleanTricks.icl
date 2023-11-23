implementation module CleanTricks

import StdInt, StdArray, StdEnum
import StdTuple, StdList, StdString

unsafeTypeAttrCast :: !.a -> .b
unsafeTypeAttrCast _ = code {
		pop_a		0
	}

unsafeTypeCast :: !u:a -> u:b
unsafeTypeCast x = unsafeTypeAttrCast x

matchConstructor :: !a !a -> Bool
matchConstructor x y = code {
		pushD_a		1
		pushD_a 	0
		pop_a		2
		eqI
	}

descriptorArity :: !a -> Int
descriptorArity _ = code {
		get_desc_arity	0
		pop_a			1
	}

unsafeSelect1of1 :: !a -> a1
unsafeSelect1of1 n = code {
		repl_args	1 1
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect1of1
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect1of1
		jmp_eval
	:1unsafeSelect1of1
		buildh		ARRAY 1
	}

unsafeSelect1of2 :: !a -> a1
unsafeSelect1of2 n = code {
		repl_args	2 2
		updatepop_a	0 1
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect1of2
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect1of2
		jmp_eval
	:1unsafeSelect1of2
		buildh		ARRAY 1
	}

unsafeSelect2of2 :: !a -> a2
unsafeSelect2of2 n = code {
		repl_args	2 2
		pop_a		1
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect2of2
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect2of2
		jmp_eval
	:1unsafeSelect2of2
		buildh		ARRAY 1
	}

unsafeSelect1of3 :: !a -> a1
unsafeSelect1of3 n = code {
		repl_args	3 3
		updatepop_a	0 2
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect1of3
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect1of3
		jmp_eval
	:1unsafeSelect1of3
		buildh		ARRAY 1
	}

unsafeSelect2of3 :: !a -> a2
unsafeSelect2of3 n = code {
		repl_args	3 3
		updatepop_a 1 2
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect2of3
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect2of3
		jmp_eval
	:1unsafeSelect2of3
		buildh		ARRAY 1
	}

unsafeSelect3of3 :: !a -> a3
unsafeSelect3of3 n = code {
		repl_args	3 3
		pop_a		2
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect3of3
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect3of3
		jmp_eval
	:1unsafeSelect3of3
		buildh		ARRAY 1
	}

unsafeSelect1of4 :: !a -> a1
unsafeSelect1of4 n = code {
		repl_args	4 4
		updatepop_a	0 3
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect1of4
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect1of4
		jmp_eval
	:1unsafeSelect1of4
		buildh		ARRAY 1
	}

unsafeSelect2of4 :: !a -> a2
unsafeSelect2of4 n = code {
		repl_args	4 4
		updatepop_a 1 3
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect2of4
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect2of4
		jmp_eval
	:1unsafeSelect2of4
		buildh		ARRAY 1
	}

unsafeSelect3of4 :: !a -> a3
unsafeSelect3of4 n = code {
		repl_args	4 4
		updatepop_a 2 3
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect3of4
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect3of4
		jmp_eval
	:1unsafeSelect3of4
		buildh		ARRAY 1
	}

unsafeSelect4of4 :: !a -> a4
unsafeSelect4of4 n = code {
		repl_args	4 4
		pop_a		3
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect4of4
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect4of4
		jmp_eval
	:1unsafeSelect4of4
		buildh		ARRAY 1
	}

unsafeSelect1of5 :: !a -> a1
unsafeSelect1of5 n = code {
		repl_args	5 5
		updatepop_a	0 4
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect1of5
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect1of5
		jmp_eval
	:1unsafeSelect1of5
		buildh		ARRAY 1
	}

unsafeSelect2of5 :: !a -> a2
unsafeSelect2of5 n = code {
		repl_args	5 5
		updatepop_a 1 4
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect2of5
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect2of5
		jmp_eval
	:1unsafeSelect2of5
		buildh		ARRAY 1
	}

unsafeSelect3of5 :: !a -> a3
unsafeSelect3of5 n = code {
		repl_args	5 5
		updatepop_a 2 4
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect3of5
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect3of5
		jmp_eval
	:1unsafeSelect3of5
		buildh		ARRAY 1
	}

unsafeSelect4of5 :: !a -> a4
unsafeSelect4of5 n = code {
		repl_args	5 5
		updatepop_a	3 4
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect4of5
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect4of5
		jmp_eval
	:1unsafeSelect4of5
		buildh		ARRAY 1
	}

unsafeSelect5of5 :: !a -> a5
unsafeSelect5of5 n = code {
		repl_args	5 5
		pop_a		4
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect5of5
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect5of5
		jmp_eval
	:1unsafeSelect5of5
		buildh		ARRAY 1
	}

unsafeSelect1of6 :: !a -> a1
unsafeSelect1of6 n = code {
		repl_args	6 6
		updatepop_a	0 5
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect1of6
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect1of6
		jmp_eval
	:1unsafeSelect1of6
		buildh		ARRAY 1
	}

unsafeSelect2of6 :: !a -> a2
unsafeSelect2of6 n = code {
		repl_args	6 6
		updatepop_a 1 5
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect2of6
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect2of6
		jmp_eval
	:1unsafeSelect2of6
		buildh		ARRAY 1
	}

unsafeSelect3of6 :: !a -> a3
unsafeSelect3of6 n = code {
		repl_args	6 6
		updatepop_a 2 5
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect3of6
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect3of6
		jmp_eval
	:1unsafeSelect3of6
		buildh		ARRAY 1
	}

unsafeSelect4of6 :: !a -> a4
unsafeSelect4of6 n = code {
		repl_args	6 6
		updatepop_a	3 5
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect4of6
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect4of6
		jmp_eval
	:1unsafeSelect4of6
		buildh		ARRAY 1
	}

unsafeSelect5of6 :: !a -> a5
unsafeSelect5of6 n = code {
		repl_args	6 6
		updatepop_a	4 5
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect5of6
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect5of6
		jmp_eval
	:1unsafeSelect5of6
		buildh		ARRAY 1
	}

unsafeSelect6of6 :: !a -> a6
unsafeSelect6of6 n = code {
		repl_args	6 6
		pop_a		5
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect6of6
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect6of6
		jmp_eval
	:1unsafeSelect6of6
		buildh		ARRAY 1
	}

unsafeSelect1of7 :: !a -> a1
unsafeSelect1of7 n = code {
		repl_args	7 7
		updatepop_a	0 6
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect1of7
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect1of7
		jmp_eval
	:1unsafeSelect1of7
		buildh		ARRAY 1
	}

unsafeSelect2of7 :: !a -> a2
unsafeSelect2of7 n = code {
		repl_args	7 7
		updatepop_a 1 6
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect2of7
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect2of7
		jmp_eval
	:1unsafeSelect2of7
		buildh		ARRAY 1
	}

unsafeSelect3of7 :: !a -> a3
unsafeSelect3of7 n = code {
		repl_args	7 7
		updatepop_a 2 6
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect3of7
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect3of7
		jmp_eval
	:1unsafeSelect3of7
		buildh		ARRAY 1
	}

unsafeSelect4of7 :: !a -> a4
unsafeSelect4of7 n = code {
		repl_args	7 7
		updatepop_a	3 6
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect4of7
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect4of7
		jmp_eval
	:1unsafeSelect4of7
		buildh		ARRAY 1
	}

unsafeSelect5of7 :: !a -> a5
unsafeSelect5of7 n = code {
		repl_args	7 7
		updatepop_a	4 6
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect5of7
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect5of7
		jmp_eval
	:1unsafeSelect5of7
		buildh		ARRAY 1
	}

unsafeSelect6of7 :: !a -> a6
unsafeSelect6of7 n = code {
		repl_args	7 7
		updatepop_a	5 6
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect6of7
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect6of7
		jmp_eval
	:1unsafeSelect6of7
		buildh		ARRAY 1
	}

unsafeSelect7of7 :: !a -> a7
unsafeSelect7of7 n = code {
		repl_args	7 7
		pop_a		6
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect7of7
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect7of7
		jmp_eval
	:1unsafeSelect7of7
		buildh		ARRAY 1
	}

unsafeSelect1of8 :: !a -> a1
unsafeSelect1of8 n = code {
		repl_args	8 8
		updatepop_a	0 7
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect1of8
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect1of8
		jmp_eval
	:1unsafeSelect1of8
		buildh		ARRAY 1
	}

unsafeSelect2of8 :: !a -> a2
unsafeSelect2of8 n = code {
		repl_args	8 8
		updatepop_a 1 7
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect2of8
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect2of8
		jmp_eval
	:1unsafeSelect2of8
		buildh		ARRAY 1
	}

unsafeSelect3of8 :: !a -> a3
unsafeSelect3of8 n = code {
		repl_args	8 8
		updatepop_a 2 7
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect3of8
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect3of8
		jmp_eval
	:1unsafeSelect3of8
		buildh		ARRAY 1
	}

unsafeSelect4of8 :: !a -> a4
unsafeSelect4of8 n = code {
		repl_args	8 8
		updatepop_a	3 7
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect4of8
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect4of8
		jmp_eval
	:1unsafeSelect4of8
		buildh		ARRAY 1
	}

unsafeSelect5of8 :: !a -> a5
unsafeSelect5of8 n = code {
		repl_args	8 8
		updatepop_a	4 7
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect5of8
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect5of8
		jmp_eval
	:1unsafeSelect5of8
		buildh		ARRAY 1
	}

unsafeSelect6of8 :: !a -> a6
unsafeSelect6of8 n = code {
		repl_args	8 8
		updatepop_a	5 7
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect6of8
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect6of8
		jmp_eval
	:1unsafeSelect6of8
		buildh		ARRAY 1
	}

unsafeSelect7of8 :: !a -> a7
unsafeSelect7of8 n = code {
		repl_args	8 8
		updatepop_a	6 7
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect7of8
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect7of8
		jmp_eval
	:1unsafeSelect7of8
		buildh		ARRAY 1
	}

unsafeSelect8of8 :: !a -> a8
unsafeSelect8of8 n = code {
		repl_args	8 8
		pop_a		7
		eq_desc		_STRING_ 0 0
		jmp_true	1unsafeSelect8of8
		eq_desc		_ARRAY_ 0 0
		jmp_true	1unsafeSelect8of8
		jmp_eval
	:1unsafeSelect8of8
		buildh		ARRAY 1
	}
