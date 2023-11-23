	.586
	.model flat

_TEXT	segment para 'CODE'

	align	(1 shl 4)
	public	_longjmp
_longjmp:
	mov		edi,dword ptr 4[esp]
	mov		eax,dword ptr 8[esp]

	mov		esp,dword ptr 24[edi]
	mov		esi,dword ptr 28[edi]

	mov		ebp,dword ptr [edi]
	mov		ebx,dword ptr 4[edi]
	mov		ecx,dword ptr 8[edi]
	mov		edx,dword ptr 12[edi]

	mov		dword ptr [esp],esi

	mov		esi,dword ptr 16[edi]
	mov		edi,dword ptr 20[edi]
	ret
	nop
	align	(1 shl 4)

_TEXT	ends
	end

