s/	cmp	rax,offset/	db 48h\
	cmp	eax,offset/
s/	cmp	rbx,offset/	db 48h\
	cmp	ebx,offset/
s/	cmp	rcx,offset/	db 48h\
	cmp	ecx,offset/
s/	cmp	rbp,offset/	db 48h\
	cmp	ebp,offset/
s/	sub	rax,offset/	db 48h\
	sub	eax,offset/
s/	add	rax,offset/	db 48h\
	add	eax,offset/
s/	add	rdx,offset/	db 48h\
	add	edx,offset/
s/	mov	qword ptr \[rcx\],offset/	db 48h,0C7h,01h\
	dd	/
s/	mov	qword ptr \[rdx\],offset/	db 48h,0C7h,02h\
	dd	/
s/	mov	qword ptr \[rbp\],offset/	db 48h,0C7h,45h,00h\
	dd	/
s/	mov	qword ptr \[rsi\],offset/	db 48h,0C7h,06h\
	dd	/
s/	mov	qword ptr \[rdi\],offset/	db 48h,0C7h,07h\
	dd	/
s/	mov	qword ptr ([0-9]+)\[rax\],offset/	db 48h,0C7h,40h,\1\
	dd	/
s/	mov	qword ptr ([0-9]+)\[rcx\],offset/	db 48h,0C7h,41h,\1\
	dd	/
s/	mov	qword ptr ([0-9]+)\[rdi\],offset/	db 48h,0C7h,47h,\1\
	dd	/
s/	mov	qword ptr \(\-([0-9]*)\)\[rcx\],offset/	db 48h,0C7h,41h,\-\1\
	dd	/
s/	mov	qword ptr \(\-([0-9]*)\)\[rdx\],offset/	db 48h,0C7h,42h,\-\1\
	dd	/
s/	mov	qword ptr \(0F8h\)\[rax\],offset/	db 48h,0C7h,80h\
	dd	0F8h,/
s/	mov	qw \[a6\],offset/	db 48h,0C7h,07h\
	dd	/
s/	mov	qword ptr ([a-z_]*)\+0,offset/	db 48h\
	mov	dword ptr \1\+0,offset/
