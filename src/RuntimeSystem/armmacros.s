
.ifdef PIC

.macro lao r a i
	ldr	\r,\a\()__o\i
.endm

.macro otoa r a i
\a\()__u\i:
	add	\r,\r,pc
.endm

.macro ldo rd ra a i
\a\()__u\i:
	ldr	\rd,[pc,\ra]	
.endm

.macro ldosb rd ra a i
\a\()__u\i:
	ldrsb	\rd,[pc,\ra]	
.endm

.macro sto rd ra a i
\a\()__u\i:
	str	\rd,[pc,\ra]	
.endm

.macro stob rd ra a i
\a\()__u\i:
	strb	\rd,[pc,\ra]	
.endm

.macro lto a i
\a\()__o\i:
	.long	\a\()-(\a\()__u\i\()+8)
.endm

.macro laol r a l i
	ldr	\r,\l\()__o\i
.endm

.macro ltol a l i
\l\()__o\i:
	.long	\a\()-(\l\()__u\i\()+8)
.endm

.else

.macro lao r a i
	ldr	\r,=\a
.endm

.macro otoa r a i
.endm

.macro ldo rd ra a i
	ldr	\rd,[\ra]	
.endm

.macro ldosb rd ra a i
	ldrsb	\rd,[\ra]	
.endm

.macro sto rd ra a i
	str	\rd,[\ra]	
.endm

.macro stob rd ra a i
	strb	\rd,[\ra]	
.endm

.macro laol r a l i
	ldr	\r,=\a
.endm

.endif
