implementation module System._Pointer

import StdOverloaded, StdClass, StdArray, StdInt, StdChar, StdString

readInt :: !Pointer !Offset -> Int
readInt pointer offset = IF_INT_64_OR_32 (readInt_64 pointer offset) (readInt_32 pointer offset)

readInt_64 :: !Pointer !Offset -> Int
readInt_64 pointer offset = code {
	pop_b 1
|	ldr     x6, [x5, x6]
	instruction 0xf86668a6
}

readInt_32 :: !Pointer !Offset -> Int
readInt_32 pointer offset = code {
	pop_b 1
|	ldr     r4, [r3, r4]
	instruction 0xe7934004
}

readIntP :: !Pointer !Offset -> (!Int,!Pointer)
readIntP pointer offset = IF_INT_64_OR_32 (readIntP_64 pointer offset) (readIntP_32 pointer offset)

readIntP_64 :: !Pointer !Offset -> (!Int,!Pointer)
readIntP_64 pointer offset = code {
|	mov     x4, x5
	instruction 0xaa0503e4
|	ldr     x5, [x5, x6]
	instruction 0xf86668a5
|	mov     x6, x4
	instruction 0xaa0403e6
}

readIntP_32 :: !Pointer !Offset -> (!Int,!Pointer)
readIntP_32 pointer offset = code {
|	mov     r2, r3
	instruction 0xe1a02003
|	ldr     r3, [r3, r4]
	instruction 0xe7933004
|	mov     r4, r2
	instruction 0xe1a04002
}

readIntElemOffset :: !Pointer !Offset -> Int
readIntElemOffset pointer offset = IF_INT_64_OR_32 (readIntElemOffset_64 pointer offset) (readIntElemOffset_32 pointer offset)

readIntElemOffset_64 :: !Pointer !Offset -> Int
readIntElemOffset_64 pointer offset = code {
	pop_b 1
|	ldr     x6, [x5, x6, lsl #3]
	instruction 0xf86678a6
}

readIntElemOffset_32 :: !Pointer !Offset -> Int
readIntElemOffset_32 pointer offset = code {
	pop_b 1
|	ldr     r4, [r3, r4, lsl #2]
	instruction 0xe7934104
}

readIntElemOffsetP :: !Pointer !Offset -> (!Int,!Pointer)
readIntElemOffsetP pointer offset = IF_INT_64_OR_32 (readIntElemOffsetP_64 pointer offset) (readIntElemOffsetP_32 pointer offset)

readIntElemOffsetP_64 :: !Pointer !Offset -> (!Int,!Pointer)
readIntElemOffsetP_64 pointer offset = code {
|	mov     x4, x5
	instruction 0xaa0503e4
|	ldr     x5, [x5, x6, lsl #3]
	instruction 0xf86678a5
|	mov     x6, x4
	instruction 0xaa0403e6
}

readIntElemOffsetP_32 :: !Pointer !Offset -> (!Int,!Pointer)
readIntElemOffsetP_32 pointer offset = code {
|	mov     r2, r3
	instruction 0xe1a02003
|	ldr     r3, [r3, r4, lsl #2]
	instruction 0xe7933104
|	mov     r4, r2
	instruction 0xe1a04002
}

readInt4Z :: !Pointer !Offset -> Int
readInt4Z pointer offset = IF_INT_64_OR_32 (readInt4Z_64 pointer offset) (readInt4Z_32 pointer offset)

readInt4Z_64 :: !Pointer !Offset -> Int
readInt4Z_64 pointer offset = code {
	pop_b 1
|	ldr     w6, [x5, x6]
	instruction 0xb86668a6
}

readInt4Z_32 :: !Pointer !Offset -> Int
readInt4Z_32 pointer offset = code {
	pop_b 1
|	ldr     r4, [r3, r4]
	instruction 0xe7934004
}

readInt4S :: !Pointer !Offset -> Int
readInt4S pointer offset = IF_INT_64_OR_32 (readInt4S_64 pointer offset) (readInt4S_32 pointer offset)

readInt4S_64 :: !Pointer !Offset -> Int
readInt4S_64 pointer offset = code {
	pop_b 1
|	ldrsw     x6, [x5, x6]
	instruction 0xb8a668a6
}

readInt4S_32 :: !Pointer !Offset -> Int
readInt4S_32 pointer offset = code {
	pop_b 1
|	ldr     r4, [r3, r4]
	instruction 0xe7934004
}

readInt2Z :: !Pointer !Offset -> Int
readInt2Z pointer offset = IF_INT_64_OR_32 (readInt2Z_64 pointer offset) (readInt2Z_32 pointer offset)

readInt2Z_64 :: !Pointer !Offset -> Int
readInt2Z_64 pointer offset = code {
	pop_b 1
|	ldrh    w6, [x5, x6]
	instruction 0x786668a6
}

readInt2Z_32 :: !Pointer !Offset -> Int
readInt2Z_32 pointer offset = code {
	pop_b 1
|	ldrh    r4, [r3, r4]
	instruction 0xe19340b4
}

readInt2S :: !Pointer !Offset -> Int
readInt2S pointer offset = IF_INT_64_OR_32 (readInt2S_64 pointer offset) (readInt2S_32 pointer offset)

readInt2S_64 :: !Pointer !Offset -> Int
readInt2S_64 pointer offset = code {
	pop_b 1
|	ldrsh   w6, [x5, x6]
	instruction 0x78e668a6
}

readInt2S_32 :: !Pointer !Offset -> Int
readInt2S_32 pointer offset = code {
	pop_b 1
|	ldrsh   r4, [r3, r4]
	instruction 0xe19340f4
}

readInt1Z :: !Pointer !Offset -> Int
readInt1Z pointer offset = IF_INT_64_OR_32 (readInt1Z_64 pointer offset) (readInt1Z_32 pointer offset)

readInt1Z_64 :: !Pointer !Offset -> Int
readInt1Z_64 pointer offset = code {
	pop_b 1
|	ldrb    w6, [x5, x6]
	instruction 0x386668a6
}

readInt1Z_32 :: !Pointer !Offset -> Int
readInt1Z_32 pointer offset = code {
	pop_b 1
|	ldrb    r4, [r3, r4]
	instruction 0xe7d34004
}

readInt1S :: !Pointer !Offset -> Int
readInt1S pointer offset = IF_INT_64_OR_32 (readInt1S_64 pointer offset) (readInt1S_32 pointer offset)

readInt1S_64 :: !Pointer !Offset -> Int
readInt1S_64 pointer offset = code {
	pop_b 1
|	ldrsb   w6, [x5, x6]
	instruction 0x38e668a6
}

readInt1S_32 :: !Pointer !Offset -> Int
readInt1S_32 pointer offset = code {
	pop_b 1
|	ldrsb   r4, [r3, r4]
	instruction 0xe19340d4
}

readChar :: !Pointer !Offset -> Char
readChar pointer offset = IF_INT_64_OR_32 (readChar_64 pointer offset) (readChar_32 pointer offset)

readChar_64 :: !Pointer !Offset -> Char
readChar_64 pointer offset = code {
	pop_b 1
|	ldrsb   w6, [x5, x6]
	instruction 0x38e668a6
}

readChar_32 :: !Pointer !Offset -> Char
readChar_32 pointer offset = code {
	pop_b 1
|	ldrb    r4, [r3, r4]
	instruction 0xe7d34004
}

readReal8 :: !Pointer !Offset -> Real
readReal8 pointer offset = IF_INT_64_OR_32 (readReal8_64 pointer offset) (readReal8_32 pointer offset)

readReal8_64 :: !Pointer !Offset -> Real
readReal8_64 pointer offset = code {
	pushR 0.0
	updatepop_b 0 2
	jmp read_f8_p_64
	:read_f8_p_64
|	ldr d0, [x5, x6]
	instruction 0xfc6668a0
}

readReal8_32 :: !Pointer !Offset -> Real
readReal8_32 pointer offset = code {
	pushR 0.0
	update_b 1 3
	updatepop_b 0 2
	jmp read_f8_p_32
	:read_f8_p_32
|	add     r4, r3, r4
	instruction 0xe0834004
|	vldr    d0, [r4]
	instruction 0xed940b00
}


readReal4 :: !Pointer !Offset -> Real
readReal4 pointer offset = IF_INT_64_OR_32 (readReal4_64 pointer offset) (readReal4_32 pointer offset)

readReal4_64 :: !Pointer !Offset -> Real
readReal4_64 pointer offset = code {
        pushR 0.0
        updatepop_b 0 2
        jmp read_f4_p_64
        :read_f4_p_64
|	ldr s0, [x5, x6]
	instruction 0xbc6668a0
|	fcvt d0, s0
	instruction 0x1e22c000
}

readReal4_32 :: !Pointer !Offset -> Real
readReal4_32 pointer offset = code {
	pushR 0.0
	update_b 1 3
	updatepop_b 0 2
	jmp read_f4_p_32
	:read_f4_p_32
|	add     r4, r3, r4
	instruction 0xe0834004
|	vldr    s0, [r4]
	instruction 0xed940a00
|	vcvt.f64.f32    d0, s0
	instruction 0xeeb70ac0
}

writeInt :: !Pointer !Offset !Int -> Pointer
writeInt pointer offset i = IF_INT_64_OR_32 (writeInt_64 pointer offset i) (writeInt_32 pointer offset i)

writeInt_32 :: !Pointer !Offset !Int -> Pointer
writeInt_32 pointer offset i = code {
|	str     r4, [r2, r3]
	instruction 0xe7824003
	updatepop_b 0 2
}

writeInt_64 :: !Pointer !Offset !Int -> Pointer
writeInt_64 pointer offset i = code {
|	str     x6, [x4, x5]
	instruction 0xf8256886
	updatepop_b 0 2
}

writeIntElemOffset :: !Pointer !Offset !Int -> Pointer
writeIntElemOffset pointer offset i = IF_INT_64_OR_32 (writeIntElemOffset_64 pointer offset i) (writeIntElemOffset_32 pointer offset i)

writeIntElemOffset_64 :: !Pointer !Offset !Int -> Pointer
writeIntElemOffset_64 pointer offset i = code {
|	str     x6, [x4, x5, lsl #3]
	instruction 0xf8257886
	updatepop_b 0 2
}

writeIntElemOffset_32 :: !Pointer !Offset !Int -> Pointer
writeIntElemOffset_32 pointer offset i = code {
|	str     r4, [r2, r3, lsl #2]
	instruction 0xe7824103
	updatepop_b 0 2
}

writeInt4 :: !Pointer !Offset !Int -> Pointer
writeInt4 pointer offset i = IF_INT_64_OR_32 (writeInt4_64 pointer offset i) (writeInt4_32 pointer offset i)

writeInt4_64 :: !Pointer !Offset !Int -> Pointer
writeInt4_64 pointer offset i = code {
|	str     w6, [x4, x5]
	instruction 0xb8256886
	updatepop_b 0 2
}

writeInt4_32 :: !Pointer !Offset !Int -> Pointer
writeInt4_32 pointer offset i = code {
|	str     r4, [r2, r3]
	instruction 0xe7824003
	updatepop_b 0 2
}

writeInt2 :: !Pointer !Offset !Int -> Pointer
writeInt2 pointer offset i = IF_INT_64_OR_32 (writeInt2_64 pointer offset i) (writeInt2_32 pointer offset i)

writeInt2_64 :: !Pointer !Offset !Int -> Pointer
writeInt2_64 pointer offset i = code {
|	strh    w6, [x4, x5]
	instruction 0x78256886
	updatepop_b 0 2
}

writeInt2_32 :: !Pointer !Offset !Int -> Pointer
writeInt2_32 pointer offset i = code {
|	strh    r4, [r2, r3]
	instruction 0xe18240b3
	updatepop_b 0 2
}

writeInt1 :: !Pointer !Offset !Int -> Pointer
writeInt1 pointer offset i = IF_INT_64_OR_32 (writeInt1_64 pointer offset i) (writeInt1_32 pointer offset i)

writeInt1_64 :: !Pointer !Offset !Int -> Pointer
writeInt1_64 pointer offset i = code {
|	strb    w6, [x4, x5]
	instruction 0x38256886
	updatepop_b 0 2
}

writeInt1_32 :: !Pointer !Offset !Int -> Pointer
writeInt1_32 pointer offset i = code {
|	strb    r4, [r2, r3]
	instruction 0xe7c24003
	updatepop_b 0 2
}

writeChar :: !Pointer !Offset !Char -> Pointer
writeChar pointer offset i = IF_INT_64_OR_32 (writeChar_64 pointer offset i) (writeChar_32 pointer offset i)

writeChar_64 :: !Pointer !Offset !Char -> Pointer
writeChar_64 pointer offset i = code {
|	strb    w6, [x4, x5]
	instruction 0x38256886
	updatepop_b 0 2
}

writeChar_32 :: !Pointer !Offset !Char -> Pointer
writeChar_32 pointer offset i = code {
|	strb    r4, [r2, r3]
	instruction 0xe7c24003
	updatepop_b 0 2
}

writeReal8 :: !Pointer !Offset !Real -> Pointer
writeReal8 pointer offset double = IF_INT_64_OR_32 (writeReal8_64 pointer offset double) (writeReal8_32 pointer offset double)

writeReal8_64 :: !Pointer !Offset !Real -> Pointer
writeReal8_64 pointer offset double = code {
|	str    d0, [x5, x6]
	instruction 0xfc2668a0
	updatepop_b 0 2
}

writeReal8_32 :: !Pointer !Offset !Real -> Pointer
writeReal8_32 pointer offset double = code {
|	add     r4, r3, r4
	instruction 0xe0834004
|	vstr    d0, [r4]
	instruction 0xed840b00
	updatepop_b 0 3
}

writeReal4 :: !Pointer !Offset !Real -> Pointer
writeReal4 pointer offset double = IF_INT_64_OR_32 (writeReal4_64 pointer offset double) (writeReal4_32 pointer offset double)

writeReal4_64 :: !Pointer !Offset !Real -> Pointer
writeReal4_64 pointer offset double = code {
	updatepop_b 0 2
|	fcvt s0, d0
	instruction 0x1e624000
|	str s0, [x5, x6]
	instruction 0xbc2668a0
}

writeReal4_32 :: !Pointer !Offset !Real -> Pointer
writeReal4_32 pointer offset double = code {
|	add     r4, r3, r4
	instruction 0xe0834004
|	vcvt.f32.f64    s0, d0
	instruction 0xeeb70bc0
|	vstr    s0, [r4]
	instruction 0xed840a00
	updatepop_b 0 3
}

derefInt :: !Pointer -> Int
derefInt ptr = code {
	load_i 0
}

derefString :: !Pointer -> String
derefString ptr = copy ptr 0 (createArray len '\0')
where
	len = skip_to_zero ptr - ptr

	skip_to_zero ptr
		| load_char ptr <> '\0'	= skip_to_zero (ptr+1)
								= ptr

	copy :: !Pointer !Offset *{#Char} -> *{#Char}
	copy ptr off arr
		# char = load_char (ptr+off)
		| char <> '\0'	= copy ptr (off + 1) {arr & [off] = char}
						= arr
	
derefCharArray :: !Pointer !Int -> {#Char}
derefCharArray ptr len = copy 0 (createArray len '\0')
where
	copy :: !Offset *{#Char} -> *{#Char}
	copy off arr
		# char = load_char (ptr+off)
		| off < len	= copy (inc off) {arr & [off] = char}
					= arr

load_char :: !Pointer -> Char
load_char ptr = code inline {
		load_ui8 0
	}
	
writeCharArray :: !Pointer !{#Char} -> Pointer
writeCharArray ptr array = copy ptr 0
where
	len = size array
	
	copy :: !Pointer !Offset -> Pointer
	copy ptr off
		# char = array.[off]
		| off < len	= copy (writeChar ptr off char) (inc off)
					= ptr

packInt :: !Int -> {#Int}
packInt i = {i}

packString :: !String -> {#Char}
packString s = s +++ "\0"

unpackString :: !{#Char} -> String
unpackString s = unpack 0
where
	unpack :: Int -> String
	unpack off	| s.[off] == '\0' = s % (0, off - 1)
				| otherwise       = unpack (off + 1)

unpackInt2Z :: !{#Char} !Offset -> Int
unpackInt2Z s off
	= 		(toInt s.[off])
	bitor	(toInt s.[off + 1] << 8)

unpackInt2S :: !{#Char} !Offset -> Int
unpackInt2S s off
	= ((unpackInt2Z s off) bitxor 0x8000) - 0x8000
//	= ((unpackInt2Z s off) << 16) >> 16

unpackInt4Z :: !{#Char} !Offset -> Int
unpackInt4Z s off
	= 		(toInt s.[off])
	bitor	(toInt s.[off + 1] << 8)
	bitor	(toInt s.[off + 2] << 16)
	bitor	(toInt s.[off + 3] << 24)

unpackInt4S :: !{#Char} !Offset -> Int
unpackInt4S s off = unpackInt4Z s off

unpackInt8 :: !{#Char} !Offset -> Int
unpackInt8 s off = unpackInt4Z s off

unpackBool :: !{#Char} !Offset -> Bool
unpackBool s off = unpackInt4Z s off <> 0

forceEval :: !a !*env -> *env
forceEval _ world = world

forceEvalPointer :: !Pointer !*env -> *env
forceEvalPointer _ world = world

readP :: !.(Pointer -> .a) !Pointer -> (!.a, !Pointer)
readP f ptr = (f ptr, ptr)
