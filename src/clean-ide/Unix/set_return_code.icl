implementation module set_return_code

import StdInt

set_return_code_world :: !Int !*World -> *World
set_return_code_world i world = IF_INT_64_OR_32 (set_return_code_world_64 i world) (set_return_code_world_32 i world)

set_return_code_world_64 :: !Int !*World -> *World
set_return_code_world_64 i world = code {
	pushI 0xffffffff
	and%
	pushLc return_code
	:xxx
| assume 4 byte aligned, little endian
| i<<32 if 8 byte misaligned
	pushI 3
	push_b 1
	pushI 4
	and%
	shiftl%
	push_b 2
	shiftl%
	update_b 0 2
	pop_b 1
| pointer and not 4
	pushI -5
	and%
| or 8 bytes
	pushI -8
	addI
	push_b_a 0
	pop_b 1
	pushI_a 0
	or%
	fill1_r _ 0 1 0 01
.keep 0 2
	fill_a 1 2
	pop_a 2
}

set_return_code_world_32 :: !Int !*World -> *World
set_return_code_world_32 i world = code {
	pushI -4
	pushLc return_code
	addI
	:xxx
	push_b_a 0
	pop_b 1
	fill1_r _ 0 1 0 01
.keep 0 2
	fill_a 1 2
	pop_a 2
}
