	.586
	.model flat

_TEXT	segment para 'CODE'

	align	(1 shl 4)
	public	_setjmp
	public	__setjmp3
_setjmp:
__setjmp3:
	mov		eax,dword ptr 4[esp]
	mov		dword ptr [eax],ebp
	mov		dword ptr 4[eax],ebx
	mov		dword ptr 8[eax],ecx
	mov		dword ptr 12[eax],edx
	mov		dword ptr 16[eax],esi
	mov		dword ptr 20[eax],edi
	mov		dword ptr 24[eax],esp
	mov		edx,dword ptr [esp]
	mov		dword ptr 28[eax],edx
	mov		edx,dword ptr 12[eax]
	sub		eax,eax
	ret
	align	(1 shl 4)

_TEXT	ends
	end
