.model small
.code
        public _printStackNow
_printStackNow:
        movl 4(%esp),%eax
        pushl _stack_trace_depth
        movl %eax,_stack_trace_depth
        pushl %esi
        pushl %edi
        pushl %ebp
        call write_profile_stack
        popl %ebp
        popl %edi
        popl %esi
        popl %eax
        movl %eax,_stack_trace_depth
        ret
