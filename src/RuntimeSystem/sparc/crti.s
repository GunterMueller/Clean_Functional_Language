	.seg	".init"
	.globl	_init
	.type	_init,#function
_init:
	save	%sp,-96,%sp

	.seg	".fini"
	.globl	_fini
	.type	_fini,#function
_fini:
	save	%sp,-96,%sp
