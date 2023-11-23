implementation module _SystemDrup

import StdArray, StdFile
import code from "fastreopen.o"
import StdInt, StdEnum, StdClass

fromArray :: !v:(a u:e) -> *[u:e] | Array a e, [v <= u]
//fromArray :: !v:(a e) -> *[e] | Array a e
fromArray array //= [x \\ x <-: array]
= code {
			||	Match code, stacksizes A: 9 B: 0
			||	Node definition _x: AP (shared or annotated)
			||	usize
	push_a 7
			||	array
	push_a 9
	push_a 1
	update_a 1 2
	update_a 0 1
	pop_a 1
			||	Remove unused stack elements
			||	array
	buildh _Nil 0
	update_a 0 11
	pop_a 1
	jsr_ap 1
			||	Building the contractum, Stacksizes A: 10 B: 0
			||	_Select
	push_arg 0 2 2
			||	-;7
			||	_Select
	push_arg 1 2 1
	jsr_eval 0
	pushI_a 0
	pop_a 1
			||	1
	pushI 1
	push_b 1
	update_b 1 2
	update_b 0 1
	pop_b 1
	subI
			||	0
	pushI 0
			||	_vArray
	push_a 9
	push_a 9
	push_a 9
	push_a 9
	push_a 9
	push_a 9
	push_a 9
	push_a 9
	update_a 8 18
	update_a 7 17
	update_a 6 16
	update_a 5 15
	update_a 4 14
	update_a 3 13
	update_a 2 12
	update_a 1 11
	updatepop_a 0 10
.d 10 2 ii
	jmp fromArray1
.o 10 2 ii
:fromArray1
			||	Match code, stacksizes A: 9 B: 2
			||	<;17
			||	g_i;10;27
	push_b 0
			||	g_s;10;27
	push_b 2
	ltI
	notB
	jmp_false fromArray2
			||	Node definition _x: AP (shared or annotated)
			||	g_i;10;27
	buildI_b 0
			||	uselect
	push_a 7
			||	g_a;10;27
	push_a 10
	push_a 1
	update_a 1 2
	update_a 0 1
	pop_a 1
			||	Remove unused stack elements
			||	g_a;10;27
	buildh _Nil 0
	update_a 0 12
	pop_a 1
	jsr_ap 2
			||	Node definition g_a;10;27: _Select (shared or annotated)
	push_arg 0 2 2
	jsr_eval 0
			||	Building the contractum, Stacksizes A: 11 B: 2
			||	_f0
			||	_vArray
	build_r e__SystemArray_rArray; 8 0 2 0
			||	g_a;10;27: _Select
	push_a 1
			||	g_s;10;27
	push_b 1
			||	g_i;10;27
	push_b 1
	push_a 1
	update_a 1 2
	update_a 0 1
	pop_a 1
	build_u _ 2 2 fromArray3
			||	_Select
	push_arg 2 2 1
	fillh _Cons 2 13
	pop_a 11
	pop_b 2
.d 1 0
	rtn
.nu 2 2 _ _
.o 1 0
:fromArray3
	push_node_u _cycle_in_spine 2 2
.o 3 2 ii
:fromArray4
.o 3 2 ii
:fromArray5
			||	Match code, stacksizes A: 2 B: 2
			||	Building the contractum, Stacksizes A: 2 B: 2
			||	+;6
			||	one;11
	pushI 1
			||	_
	push_b 1
	addI
			||	_
	push_r_args 0 8 0
			||	_
	push_a 9
			||	_
	push_b 2
	push_a 8
	update_a 1 9
	update_a 2 1
	update_a 3 2
	update_a 4 3
	update_a 5 4
	update_a 6 5
	update_a 7 6
	update_a 8 7
	update_a 0 8
	pop_a 1
	push_b 1
	update_b 1 2
	update_b 0 1
	pop_b 1
	update_a 8 10
	update_a 7 9
	update_a 6 8
	update_a 5 7
	update_a 4 6
	update_a 3 5
	update_a 2 4
	update_a 1 3
	updatepop_a 0 2
	update_b 1 3
	updatepop_b 0 2
.d 10 2 ii
	jmp fromArray1
:fromArray2
			||	Building the contractum, Stacksizes A: 9 B: 2
	fillh _Nil 0 9
	pop_a 9
	pop_b 2
}

unsafeCreateArray :: !Int -> *(a .e) | Array a e
unsafeCreateArray n = _createArray n

unsafeTypeCast :: !.a -> .b
unsafeTypeCast x = code {	|A| x
		pop_a		0		|A| x
	}

unsafeReopen :: !*File !Int -> (!Bool, !*File)
unsafeReopen f m = code {	|B| f1 f2 m
		push_b		0		|B| f1 f1 f2 m
		update_b	3 1		|B| f1 m f2 m
		update_b	2 3		|B| f1 m f2 f2
		update_b	0 2		|B| f1 m f1 f2
		ccall 		fast_re_open_file "II:I:II"	|B| b f1 f2
	}
