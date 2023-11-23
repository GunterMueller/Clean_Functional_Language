implementation module set_return_code

import StdInt

set_return_code :: !Int !*World -> *World
set_return_code i world = IF_INT_64_OR_32 (set_return_code64 i world) (set_return_code32 i world)

set_return_code64 :: !Int !*World -> *World
set_return_code64 i world = code {
    pushI 0
    pushLc _return_code
    :xxx
    pop_b 3
|    mov dword ptr [rbx+r10],eax
    instruction 66
    instruction 137
    instruction 4
    instruction 19
    fill_a 0 1
    pop_a 1
}

set_return_code32 :: !Int !*World -> *World
set_return_code32 i world = code {
    fill_a 0 1
    pop_a 1
    pushI 0
    pushLc _return_code
    :xxx
    pop_b 3
|	mov    (%esp),%edx
	instruction	139
	instruction 20
	instruction 36
|	movl	%edx,(%eax,%ebx,1)
	instruction 137
	instruction 20
	instruction 24
}
