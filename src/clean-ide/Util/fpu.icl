implementation module fpu;

import StdEnv;

f :: !Int -> Int;
f _ = code {
	instruction 155 | 9b
	instruction 217 | d9
	instruction 124 | 7c
	instruction 36 | 24
	instruction 252 | fc
	|	 fstcw	 TBYTE PTR [esp-4]
	instruction 15 | 0f
	instruction 183 | b7
	instruction 68 | 44
	instruction 36 | 24
	instruction 252 | fc
	|	 movzx	 eax, WORD PTR [esp-4]
	};

//test_fpu :: !(PSt .l) -> (!Bool,!PSt .l);
test_fpu :: !.a -> (!Bool,!.a);
test_fpu ps
	| (f 0) bitand 31<>31
//		= 1/0==0;
		= (False,ps);
		= (True,ps);

h :: !Bool -> Bool;
h _ = code {
	instruction 155 | 9b
	instruction 219 | db
	instruction 227 | e3
	|	 finit
	};

fix_fpu :: !.a -> .a;
fix_fpu env
	| h False
		= abort "fpu:fix_fpu failed to restore fpu flag.";
	= env;
