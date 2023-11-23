
ZERO_ARITY_DESCRIPTOR_OFFSET = -8
COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP = 1

	str	x26,[sp,#-16]!

	adrp	x16,heap_p2
	ldr	x26,[x16,#:lo12:heap_p2]
	adrp	x4,heap_size_257
	ldr	x4,[x4,#:lo12:heap_size_257]
	lsl	x4,x4,#7

	adrp	x16,semi_space_size
	str	x4,[x16,#:lo12:semi_space_size]

	add	x27,x26,x4

# x0 = INT+2
# x1 = CHAR+2
	adrp	x0,INT+2
	add	x0,x0,#:lo12:INT+2
	adrp	x1,CHAR+2
	add	x1,x1,#:lo12:CHAR+2
	adrp	x6,semi_space_size
	ldr	x6,[x6,#:lo12:semi_space_size]
	adrp	x11,heap_copied_vector
	ldr	x11,[x11,#:lo12:heap_copied_vector]
	adrp	x12,heap_p1
	ldr	x12,[x12,#:lo12:heap_p1]
	adrp	x13,small_integers
	add	x13,x13,#:lo12:small_integers
	adrp	x14,static_characters
	add	x14,x14,#:lo12:static_characters
	adrp	x15,__STRING__+2
	add	x15,x15,#:lo12:__STRING__+2

.if WRITE_HEAP
	adrp	x16,heap2_begin_and_end+4
	str	x27,[x16,#:lo12:heap2_begin_and_end+4]
.endif

	sub	sp,sp,#32

	adrp	x16,caf_list
	ldr	x4,[x16,#:lo12:caf_list]
	cbz	x4,end_copy_cafs

copy_cafs_lp:
	ldr	x16,[x4,#-8]
	str	x16,[sp,#-16]!

	add	x10,x4,#8
	ldr	x3,[x4]
	mov	x2,#-2
	bl	copy_lp2

	ldr	x4,[sp],#16
	cbnz	x4,copy_cafs_lp

end_copy_cafs:
	ldr	x3,[sp,#32]
	adrp	x16,stack_p
	ldr	x10,[x16,#:lo12:stack_p]
	sub	x3,x3,x10
	lsr	x3,x3,#3

	cbz	x3,end_copy0
	mov	x2,#-2
	bl	copy_lp2
end_copy0:
	adrp	x16,heap_p2
	ldr	x10,[x16,#:lo12:heap_p2]

	bl	copy_lp1

	add	sp,sp,#32

	adrp	x16,heap_end_after_gc
	str	x27,[x16,#:lo12:heap_end_after_gc]

.ifdef FINALIZERS
	adrp	x8,finalizer_list
	add	x8,x8,#:lo12:finalizer_list
	adrp	x9,free_finalizer_list
	add	x9,x9,#:lo12:free_finalizer_list
	ldr	x10,[x8]

determine_free_finalizers_after_copy:
	ldr	x4,[x10]
	tbz	x4,#0,finalizer_not_used_after_copy

	ldr	x10,[x10,#8]
	sub	x4,x4,#1
	str	x4,[x8]
	add	x8,x4,#8
	b	determine_free_finalizers_after_copy

finalizer_not_used_after_copy:
	adrp	x16,__Nil-8
	add	x16,x16,#:lo12:__Nil-8
	cmp	x10,x16
	beq	end_finalizers_after_copy

	str	x10,[x9]
	add	x9,x10,#8
	ldr	x10,[x10,#8]
	b	determine_free_finalizers_after_copy	

end_finalizers_after_copy:
	str	x10,[x8]
	str	x10,[x9]
.endif

	b	skip_copy_gc

	.ltorg


#
#	Copy nodes to the other semi-space
#

copy_lp2_lp1_all_pointers:
	add	x2,x10,x3,lsl #3

copy_lp2_lp1:
copy_lp2:
	mov	x5,x10
	ldr	x9,[x10],#8

copy_lp2__lp1:
copy_lp2_:
# selectors:
continue_after_selector_2:
	ldr	x8,[x9]
	tbz	x8,#1,not_in_hnf_2

in_hnf_2:
	ldrh	w4,[x8,#-2]
	cbz	x4,copy_arity_0_node2

	cmp	x4,#256
	bhs	copy_record_2

	subs	x4,x4,#2
	str	x26,[x5]
	bhi	copy_hnf_node2_3

	str	x8,[x26],#1
	blo	copy_hnf_node2_1

	ldr	x8,[x9,#8]

	str	x26,[x9]
	ldr	x4,[x9,#16]

	subs	x3,x3,#1
	str	x8,[x26,#8-1]

	str	x4,[x26,#16-1]
	add	x26,x26,#24-1

	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

copy_hnf_node2_1:
	ldr	x4,[x9,#8]

	subs	x3,x3,#1
	str	x26,[x9]

	str	x4,[x26,#8-1]
	add	x26,x26,#16-1

	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

copy_hnf_node2_3:
	str	x8,[x26],#1

	str	x26,[x9]
	ldr	x8,[x9,#8]

	str	x8,[x26,#8-1]
	ldr	x8,[x9,#16]

	add	x26,x26,#24-1
	ldr	x9,[x8]

	tbnz	x9,#0,arguments_already_copied_2

	str	x26,[x26,#-8]

	str	x9,[x26],#1

	str	x26,[x8],#8
	add	x26,x26,#8-1

cp_hnf_arg_lp2:
	ldr	x9,[x8],#8
	subs	x4,x4,#1
	str	x9,[x26],#8
	bne	cp_hnf_arg_lp2

	subs	x3,x3,#1
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

arguments_already_copied_2:
	str	x9,[x26,#-8]

	subs	x3,x3,#1
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

copy_arity_0_node2:
	cmp	x8,x15 // __STRING__+2
	bls	copy_string_or_array_2

	cmp	x8,x1 // CHAR+2
	bhi	copy_normal_hnf_0_2

copy_int_bool_or_char_2:
	ldr	x4,[x9,#8]
	beq	copy_char_2

	cmp	x8,x0 // INT+2
	bne	no_small_int_or_char_2

copy_int_2:
	cmp	x4,#33
	bhs	no_small_int_or_char_2

	add	x4,x13,x4,lsl #4 // small_integers
	subs	x3,x3,#1

	str	x4,[x5]
	bne	copy_lp2

	mov	x10,x2
	b	copy_lp1

copy_char_2:
	subs	x3,x3,#1
	add	x4,x14,x4,uxtb #4 // static_characters

	str	x4,[x5]
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

no_small_int_or_char_2:
copy_record_node2_1_b:
	str	x8,[x27,#-16]

	str	x4,[x27,#-8]
	sub	x27,x27,#15

	str	x27,[x9]
	sub	x27,x27,#1

	str	x27,[x5]

	subs	x3,x3,#1
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

copy_normal_hnf_0_2:
	sub	x8,x8,#2-ZERO_ARITY_DESCRIPTOR_OFFSET
	subs	x3,x3,#1

	str	x8,[x5]
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

already_copied_2:
	sub	x8,x8,#1
	subs	x3,x3,#1

	str	x8,[x5]

	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

copy_record_2:
	ldrh	w16,[x8,#-2+2]
	subs	x4,x4,#258
	bhi	copy_record_node2_3
	blo	copy_record_node2_1

	cbz	x16,copy_record_2_bb

	str	x26,[x5]
	str	x8,[x26]

	add	x8,x26,#1
	ldr	x4,[x9,#8]

	str	x8,[x9]

	str	x4,[x26,#8]
	ldr	x4,[x9,#16]

	str	x4,[x26,#16]

	add	x26,x26,#24
	subs	x3,x3,#1
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

copy_record_node2_1:
	ldr	x4,[x9,#8]

	cbz	x16,copy_record_node2_1_b

	str	x26,[x5]
	str	x8,[x26]

	add	x8,x26,#1
	str	x4,[x26,#8]

	str	x8,[x9]

	add	x26,x26,#16
	subs	x3,x3,#1
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

copy_record_2_bb:
	str	x8,[x27,#-24]
	sub	x27,x27,#24-1

	str	x27,[x9]
	sub	x27,x27,#1

	ldr	x4,[x9,#8]
	ldr	x8,[x9,#16]

	str	x27,[x5]

	str	x4,[x27,#8]
	subs	x3,x3,#1

	str	x8,[x27,#16]

	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

copy_record_node2_3:
	cmp	x16,#1
	bls	copy_record_node2_3_ab_or_b

	add	x7,x26,#1

	str	x7,[x9]
	ldr	x7,[x9,#16]

	str	x8,[x26]
	ldr	x9,[x9,#8]

	str	x9,[x26,#8]
	str	x26,[x5]

	ldr	x16,[x7]
	mov	x8,x7
	tbnz	x16,#0,record_arguments_already_copied_2

	add	x9,x26,#24
	str	x9,[x26,#16]

	add	x26,x26,#25
	ldr	x9,[x8]

	str	x26,[x8],#8

	str	x9,[x26,#-1]
	add	x26,x26,#7

cp_record_arg_lp2:
	ldr	x9,[x8],#8
	subs	x4,x4,#1
	str	x9,[x26],#8
	bne	cp_record_arg_lp2

	subs	x3,x3,#1
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

record_arguments_already_copied_2:
	ldr	x9,[x8]

	str	x9,[x26,#16]
	add	x26,x26,#24

	subs	x3,x3,#1
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

copy_record_node2_3_ab_or_b:
	blo	copy_record_node2_3_b

copy_record_node2_3_ab:
	add	x7,x26,#1

	str	x7,[x9]
	ldr	x7,[x9,#16]

	str	x8,[x26]
	ldr	x9,[x9,#8]

	mov	x8,x7
	sub	x7,x7,x12 // heap_p1

	str	x9,[x26,#8]

	lsr	x9,x7,#9
	ubfx	x7,x7,#4,#5

	str	x26,[x5]

	mov	x16,#1
	lsl	x7,x16,x7

	ldr	w16,[x11,x9,lsl #2] // heap_copied_vector
	tst	x7,x16
	bne	record_arguments_already_copied_2

	lsl	x4,x4,#3
	orr	x16,x16,x7
	str	w16,[x11,x9,lsl #2] // heap_copied_vector

	sub	x27,x27,x4

	sub	x7,x27,#8
	sub	x27,x27,#8-1

	str	x27,[x26,#16]
	add	x26,x26,#24

	ldr	x9,[x8]
	b	cp_record_arg_lp3_c

copy_record_node2_3_b:
	add	x7,x27,#-24+1

	str	x7,[x9]
	ldr	x7,[x9,#16]

	str	x8,[x27,#-24]
	ldr	x9,[x9,#8]

	mov	x8,x7
	sub	x7,x7,x12 // heap_p1

	str	x9,[x27,#-16]

	lsr	x9,x7,#9
	sub	x27,x27,#24
	ubfx	x7,x7,#4,#5

	str	x27,[x5]

	mov	x16,#1
	lsl	x7,x16,x7

	ldr	w16,[x11,x9,lsl #2] // heap_copied_vector
	tst	x7,x16
	bne	record_arguments_already_copied_3_b

	lsl	x4,x4,#3
	orr	x16,x16,x7
	str	w16,[x11,x9,lsl #2] // heap_copied_vector

	sub	x7,x27,#8
	sub	x7,x7,x4
	str	x7,[x27,#16]

	ldr	x9,[x8]
	add	x27,x7,#1

cp_record_arg_lp3_c:
	str	x27,[x8],#8

	str	x9,[x27,#-1]
	add	x27,x27,#7

cp_record_arg_lp3:
	ldr	x9,[x8],#8
	subs	x4,x4,#8
	str	x9,[x27],#8
	bne	cp_record_arg_lp3

	mov	x27,x7

	subs	x3,x3,#1
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

record_arguments_already_copied_3_b:
	ldr	x9,[x8]

	subs	x3,x3,#1

	sub	x9,x9,#1
	str	x9,[x27,#16]

	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

not_in_hnf_2:
	tbnz	x8,#0,already_copied_2

	ldr	w4,[x8,#-4]
	cmp	w4,#0
	ble	copy_arity_0_node2_

copy_node2_1_:
	and	x4,x4,#255
	subs	x4,x4,#2
	blt	copy_arity_1_node2
copy_node2_3:
	str	x26,[x5]
	str	x8,[x26],#1
	ldr	x8,[x9,#8]
	str	x26,[x9],#16
	str	x8,[x26,#8-1]
	add	x26,x26,#16-1

cp_arg_lp2:
	ldr	x8,[x9],#8
	subs	x4,x4,#1
	str	x8,[x26],#8
	bhs	cp_arg_lp2

	subs	x3,x3,#1
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

copy_arity_1_node2__:
copy_arity_1_node2:
copy_arity_1_node2_:
	str	x26,[x5]
	str	x8,[x26],#1
	str	x26,[x9]
	ldr	x4,[x9,#8]
	str	x4,[x26,#8-1]
	add	x26,x26,#24-1

	subs	x3,x3,#1
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

copy_indirection_2:
	mov	x4,x9
	ldr	x9,[x9,#8]

	ldr	x8,[x9]
	tbnz	x8,#1,in_hnf_2

	tbnz	x8,#0,already_copied_2

	ldr	w16,[x8,#-4]
	cmp	w16,#-2
	beq	skip_indirections_2

	adds	w4,w16,#0
	ble	copy_arity_0_node2_
	b	copy_node2_1_

skip_indirections_2:
	ldr	x9,[x9,#8]

	ldr	x8,[x9]
	tbnz	x8,#1,update_indirection_list_2
	tbnz	x8,#0,update_indirection_list_2

	ldr	w16,[x8,#-4]
	cmp	w16,#-2
	beq	skip_indirections_2

update_indirection_list_2:
	add	x8,x4,#8
	ldr	x4,[x4,#8]
	str	x9,[x8]
	cmp	x9,x4
	bne	update_indirection_list_2

	b	continue_after_selector_2

copy_selector_2:
	cmp	w4,#-2
	beq	copy_indirection_2
	blt	copy_record_selector_2

	ldr	x4,[x9,#8]

	ldr	x7,[x4]
	tbz	x7,#1,copy_arity_1_node2__

	ldrh	w16,[x7,#-2]
	cmp	x16,#2
	bls	copy_selector_2_

	ldr	x7,[x4,#16]
	ldr	x16,[x7]
	tbnz	x16,#0,copy_arity_1_node2__

.ifdef PIC
	add	x17,x8,#-8+4
.endif
	ldr	w8,[x8,#-8]
	adrp	x16,e__system__nind
.ifdef PIC
	ldrh	w8,[x17,x8]
.else
	ldrh	w8,[x8,#4]
.endif
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x9]

	cmp	x8,#16
	blt	copy_selector_2_1
	beq	copy_selector_2_2

	sub	x7,x7,#24
	ldr	x8,[x8,x7]
	str	x8,[x9,#8]
	mov	x9,x8
	b	continue_after_selector_2

copy_selector_2_1:
	ldr	x8,[x4,#8]
	str	x8,[x9,#8]
	mov	x9,x8
	b	continue_after_selector_2

copy_selector_2_2:
	ldr	x8,[x7]
	str	x8,[x9,#8]
	mov	x9,x8
	b	continue_after_selector_2

copy_selector_2_:
.ifdef PIC
	add	x17,x8,#-8+4
.endif
	ldr	w8,[x8,#-8]

	adrp	x16,e__system__nind
.ifdef PIC
	ldrh	w8,[x17,x8]
.else
	ldrh	w8,[x8,#4]
.endif
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x9]

	ldr	x8,[x4,x8]
	str	x8,[x9,#8]
	mov	x9,x8
	b	continue_after_selector_2

copy_record_selector_2:
	cmp	w4,#-3
	ldr	x4,[x9,#8]
	ldr	x4,[x4]
	beq	copy_strict_record_selector_2

	tbz	x4,#1,copy_arity_1_node2_

	ldrh	w16,[x4,#-2]
	cmp	x16,#258
	bls	copy_record_selector_2_

	ldrh	w16,[x4,#-2+2]
	cmp	x16,#2
	bhs	copy_selector_2__

	ldr	x4,[x9,#8]

	ldr	x4,[x4,#16]

	sub	x4,x4,x12 // heap_p1

	lsr	x7,x4,#9
	ubfx	x4,x4,#4,#5

	mov	x16,#1
	lsl	x4,x16,x4

	ldr	w16,[x11,x7,lsl #2] // heap_copied_vector
	ands	x4,x4,x16
	beq	copy_record_selector_2_
	b	copy_arity_1_node2_
copy_selector_2__:
	ldr	x4,[x9,#8]
	ldr	x4,[x4,#16]
	ldrb	w16,[x4]
	tbnz	x16,#0,copy_arity_1_node2_
copy_record_selector_2_:
.ifdef PIC
	add	x17,x8,#-8+4
.endif
	ldr	w4,[x8,#-8]
	adrp	x16,e__system__nind
	ldr	x8,[x9,#8]
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x9]

.ifdef PIC
	ldrh	w4,[x17,x4]
.else
	ldrh	w4,[x4,#4]
.endif
	cmp	x4,#16
	ble	copy_record_selector_3
	ldr	x8,[x8,#16]
	sub	x4,x4,#24
copy_record_selector_3:
	ldr	x8,[x8,x4]

	str	x8,[x9,#8]
	mov	x9,x8
	b	continue_after_selector_2

copy_strict_record_selector_2:
	tbz	x4,#1,copy_arity_1_node2_

	ldrh	w16,[x4,#-2]
	cmp	x16,#258
	bls	copy_strict_record_selector_2_

	ldrh	w16,[x4,#-2+2]
	cmp	x16,#2
	blo	copy_strict_record_selector_2_b

 	ldr	x4,[x9,#8]
	ldr	x4,[x4,#16]
	ldrb	w16,[x4]
	tbnz	x16,#0,copy_arity_1_node2_

	b	copy_strict_record_selector_2_

copy_strict_record_selector_2_b:
 	ldr	x4,[x9,#8]

	ldr	x4,[x4,#16]

	sub	x4,x4,x12 // heap_p1

	lsr	x7,x4,#9
	ubfx	x4,x4,#4,#5

	mov	x16,#1
	lsl	x4,x16,x4

	ldr	w16,[x11,x7,lsl #2] // heap_copied_vector
	ands	x4,x4,x16
	bne	copy_arity_1_node2_

copy_strict_record_selector_2_:
.ifdef PIC
	add	x17,x8,#-8+4
.endif
	ldr	w4,[x8,#-8]

	ldr	x8,[x9,#8]

.ifdef PIC
	ldrh	w7,[x4,x17]!
.else
	ldrh	w7,[x4,#4]
.endif
	cmp	x7,#16
	ble	copy_strict_record_selector_3
	ldr	x16,[x8,#16]
	add	x7,x7,x16
	ldr	x7,[x7,#-24]
	b	copy_strict_record_selector_4
copy_strict_record_selector_3:
	ldr	x7,[x8,x7]
copy_strict_record_selector_4:
	str	x7,[x9,#8]

.ifdef PIC
	ldrh	w7,[x4,#6-4]
.else
	ldrh	w7,[x4,#6]
.endif
	cbz	x7,copy_strict_record_selector_6
	cmp	x3,#16
	ble	copy_strict_record_selector_5
	ldr	x8,[x8,#16]
	sub	x7,x7,#24
copy_strict_record_selector_5:
	ldr	x3,[x8,x7]
	str	x3,[x9,#16]
copy_strict_record_selector_6:

	ldr	x8,[x4,#-8]
	str	x8,[x9]
	tbnz	x8,#1,in_hnf_2
hlt:	b	hlt

copy_arity_0_node2_:
	blt	copy_selector_2

	str	x8,[x27,#-24]!
	str	x27,[x5]
	add	x4,x27,#1

	str	x4,[x9]

	subs	x3,x3,#1
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

copy_string_or_array_2:
.ifdef DLL
	beq	copy_string_2
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	cmp	x8,x16
	blo	copy_normal_hnf_0_2
	mov	x8,x9
	b	copy_array_2
copy_string_2:
	mov	x8,x9
.else
	mov	x8,x9
	bne	copy_array_2
.endif
	sub	x9,x9,x12 // heap_p1
	cmp	x9,x6 // semi_space_size
	bhs	copy_string_or_array_constant

	ldr	x9,[x8,#8]
	add	x9,x9,#7

	lsr	x4,x9,#3
	and	x9,x9,#-8

	sub	x27,x27,x9

	ldr	x7,[x8],#8

	str	x7,[x27,#-16]!

	str	x27,[x5]
	add	x9,x27,#1

	str	x9,[x8,#-8]
	add	x9,x27,#8

cp_s_arg_lp2:
	ldr	x7,[x8],#8
	subs	x4,x4,#1
	str	x7,[x9],#8
	bge	cp_s_arg_lp2

	subs	x3,x3,#1
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

copy_array_2:
	sub	x9,x9,x12 // heap_p1
	cmp	x9,x6 // semi_space_size
	bhs	copy_string_or_array_constant

	ldr	x4,[x8,#16]
	cmp	x4,#0
	beq	copy_array_a2

	ldrh	w7,[x4,#-2]
	cbz	x7,copy_strict_basic_array_2

	ldr	x16,[x8,#8]
	sub	x7,x7,#256
	mul	x7,x16,x7
	b	copy_array_a3

copy_array_a2:
	ldr	x7,[x8,#8]
copy_array_a3:
	mov	x9,x26

	add	x26,x26,#24
	add	x26,x26,x7,lsl #3

	str	x9,[x5]
	ldr	x4,[x8]

	str	x4,[x9]

	add	x4,x9,#1
	add	x9,x9,#8

	str	x4,[x8],#8

	add	x4,x7,#1
	b	cp_s_arg_lp2

copy_strict_basic_array_2:
	ldr	x7,[x8,#8]
	cmp	x4,x0 // INT+2
	ble	copy_int_or_real_array_2

	adrp	x16,BOOL+2
	add	x16,x16,#:lo12:BOOL+2
	cmp	x4,x16
	beq	copy_bool_array_2

copy_int32_or_real32_array_2:
	add	x7,x7,#1
	lsr	x7,x7,#1

copy_int_or_real_array_2:
	add	x9,x27,#-24

	sub	x9,x9,x7,lsl #3
	ldr	x4,[x8]

	str	x9,[x5]

	mov	x27,x9

	str	x4,[x9]
	add	x4,x9,#1

	add	x9,x9,#8
	str	x4,[x8],#8

	add	x4,x7,#1
	b	cp_s_arg_lp2

copy_bool_array_2:
	add	x7,x7,#7
	lsr	x7,x7,#3
	b	copy_int_or_real_array_2

copy_string_or_array_constant:
	str	x8,[x5]

	subs	x3,x3,#1
	bne	copy_lp2
	mov	x10,x2
	b	copy_lp1

#
#	Copy all referenced nodes to the other semi space
#

copy_lp1:
	cmp	x10,x26
	bhs	end_copy1

	ldr	x4,[x10],#8
	tbz	x4,#1,not_in_hnf_1
in_hnf_1:
	ldrh	w3,[x4,#-2]
	cbz	x3,copy_array_21

	cmp	x3,#2
	bls	copy_lp2_lp1_all_pointers

	cmp	x3,#256
	bhs	copy_record_21

	ldr	x16,[x10,#8]
	tbnz	x16,#0,node_without_arguments_part

	ldr	x9,[x10],#16
	sub	x2,x10,#8
	sub	x5,x10,#16
	add	x2,x2,x3,lsl #3
	b	copy_lp2__lp1

copy_record_21:
	sub	x3,x3,#256
	subs	x3,x3,#2
	bhi	copy_record_arguments_3

	ldrh	w3,[x4,#-2+2]
	blo	copy_record_arguments_1

	add	x2,x10,#16

	cmp	x3,#1
	bhi	copy_lp2_lp1
	b	copy_node_arity1

copy_record_arguments_1:
	add	x2,x10,#8
	b	copy_lp2_lp1

copy_record_arguments_3:
	ldr	x16,[x10,#8]
	tbnz	x16,#0,record_node_without_arguments_part

	ldrh	w9,[x4,#-2+2]

	add	x8,x10,x3,lsl #3
	add	x2,x8,#3*8
	mov	x3,x9

	ldr	x9,[x10],#16
	sub	x5,x10,#16
	b	copy_lp2__lp1

node_without_arguments_part:
record_node_without_arguments_part:
	ldr	x9,[x10],#16
	sub	x4,x16,#1

	mov	x3,#1
	sub	x5,x10,#16
	str	x4,[x10,#-8]
	mov	x2,x10
	b	copy_lp2__lp1

not_in_hnf_1:
	ldr	w3,[x4,#-4]
	cmp	w3,#256
	bgt	copy_unboxed_closure_arguments

	cmp	w3,#1
	bgt	copy_lp2_lp1_all_pointers

copy_node_arity1:
	ldr	x9,[x10],#16
	mov	x3,#1
	sub	x5,x10,#16
	mov	x2,x10
	b	copy_lp2__lp1

copy_unboxed_closure_arguments:
	cmp	x3,#257
	beq	copy_unboxed_closure_arguments1

	ubfx	x4,x3,#8,#8
	and	x2,x3,#255

	subs	x3,x2,x4
	add	x2,x10,x2,lsl #3
	bne	copy_lp2_lp1

copy_unboxed_closure_arguments_without_pointers:
	mov	x10,x2
	b	copy_lp1

copy_unboxed_closure_arguments1:
	add	x10,x10,#16
	b	copy_lp1

copy_array_21:
	ldr	x3,[x10,#8]
	add	x10,x10,#16
	cbz	x3,copy_array_21_a

	ldrh	w4,[x3,#-2]
	ldrh	w3,[x3,#-2+2]
	sub	x4,x4,#256
	cbz	x3,copy_array_21_b

	cmp	x3,x4
	bne	copy_array_21_ab

copy_array_21_r_a:
	ldr	x3,[x10,#-16]
	mul	x3,x4,x3
	cbz	x3,copy_lp1
	b	copy_lp2_lp1_all_pointers

copy_array_21_a:
	ldr	x3,[x10,#-16]
	cbz	x3,copy_lp1
	b	copy_lp2_lp1_all_pointers

copy_array_21_b:
	ldr	x3,[x10,#-16]
	mul	x3,x4,x3
	add	x10,x10,x3,lsl #3
	b	copy_lp1

copy_array_21_ab:
	ldr	x16,[x10,#-16]
	cbz	x16,copy_lp1

	str	x16,[sp,#0]
	lsl	x4,x4,#3
	str	x3,[sp,#16]
	str	x4,[sp,#8]

copy_array_21_lp_ab:
	add	x2,x10,x4
	str	x2,[sp,#24]
	mov	x2,#-1
	b	copy_lp2

end_copy1:
	cmp	x10,#-1
	beq	copy_array_21_lp_ab_next
	ret	x30

copy_array_21_lp_ab_next:
	ldr	x10,[sp,#24]
	ldr	x16,[sp]
	ldr	x3,[sp,#16]
	ldr	x4,[sp,#8]
	subs	x16,x16,#1
	str	x16,[sp]
	bne	copy_array_21_lp_ab

	b	copy_lp1

	.ltorg

skip_copy_gc:
