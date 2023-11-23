implementation module _SystemBigInt

import	StdOverloaded,ExtendedArithBasics

:: BigInt	= 	{	_sign_or_number	::	!Int
				,	_limbs			::	!.{#Int}
				}
// For efficiency this type is _not_ abstract.
// Don't try to access the fields of this record.

instance zero			BigInt
  where
	zero = code inline {
		pushI 0
		build _Nil 0 _hnf
		}	

instance one 			BigInt
  where
	one = code inline {
		pushI 1
		build _Nil 0 _hnf
		}	

instance EqInt BigInt
  where
	(==%) _ _ = code inline {
					.newlocallabel small_eqi
					.newlocallabel end_eqi
		
					eq_desc _Nil 0 0
					jmp_true small_eqi
					pop_a 1
					pop_b 2
					pushB FALSE
					jmp end_eqi
				:small_eqi
					pop_a 1
					eqI
				:end_eqi
		}

instance LessInt BigInt
  where
	(<%) _ _ = code inline {
					.newlocallabel small_lti
		
					eq_desc _Nil 0 0
					jmp_true small_lti
					pushI 0		|| the result only depends on the sign of the big BigInt
					update_b 0 2
					pop_b 1
				:small_lti
					pop_a 1
					ltI
		}
	
instance GreaterInt BigInt
  where
	(>%) _ _ = code inline {
					.newlocallabel small_gti
		
					eq_desc _Nil 0 0
					jmp_true small_gti
					pushI 0		|| the result only depends on the sign of the big BigInt
					update_b 0 2
					pop_b 1
				:small_gti
					pop_a 1
					gtI
		}

instance +% BigInt
  where
	(+%) _ _ = code inline {
					.newlocallabel is_small_addi
					.newlocallabel end_addi
		
					eq_desc _Nil 0 0
					jmp_true is_small_addi
				.d 1 2 ii
					jsr e_BigInt_saddBS
				.o 1 1 i
					jmp end_addi
				:is_small_addi
					addIo
					jmp_false end_addi
				.d 1 1 i
					jsr e_BigInt_shandle_add_overflow
				.o 1 1 i
				:end_addi
		}

instance -% BigInt
  where
	(-%) _ _ = code inline {
					.newlocallabel is_small_subi
					.newlocallabel end_subi
		
					eq_desc _Nil 0 0
					jmp_true is_small_subi
				.d 1 2 ii
					jsr bigInt_min_Int_entry2
				.o 1 1 i
					jmp end_subi
				:is_small_subi
					subIo
					jmp_false end_subi
				.d 1 1 i
					jsr e_BigInt_shandle_sub_overflow
				.o 1 1 i
				:end_subi
		}

instance %- BigInt
  where
	(%-) _ _ = code inline {
					.newlocallabel is_small_subi2
					.newlocallabel end_subi2
		
					eq_desc _Nil 0 0
					jmp_true is_small_subi2
				.d 1 2 ii
					jsr int_min_BigInt_entry
				.o 1 1 i
					jmp end_subi2
				:is_small_subi2
					subIo
					jmp_false end_subi2
				.d 1 1 i
					jsr e_BigInt_shandle_sub_overflow
				.o 1 1 i
				:end_subi2
		}


instance *% BigInt
  where
	(*%) _ _ = code inline {
					.newlocallabel is_small_muli
					.newlocallabel no_overflow_muli
					.newlocallabel end_muli
		
					eq_desc _Nil 0 0
					jmp_true is_small_muli
				.d 1 2 ii
					jsr e_BigInt_smulBS
				.o 1 1 i
					jmp end_muli
				:is_small_muli
					push_b 1
					push_b 1
					mulIo
					jmp_false no_overflow_muli
				 	pop_b 1
				.d 1 2 ii
					jsr e_BigInt_shandle_mult_overflow
				.o 1 1 i
					jmp end_muli
				:no_overflow_muli
					update_b 0 2
					pop_b 2
				:end_muli
		}

instance toBigInt Int
  where
	toBigInt _ = code inline {
		build _Nil 0 _hnf
		}	
