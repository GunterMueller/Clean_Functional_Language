s/([ 	])extrn([ 	]+[a-zA-Z0-9_]+):near/\1.globl\2/
s/([ 	])extrn([ 	])/\1.globl\2/
s/([ 	])public([ 	])/\1.globl\2/
s/^([ 	]+)dq([ 	])/\1.quad\2/
s/([ 	]+)dq([ 	])/:\1.quad\2/
s/([ 	]+)dd([ 	])/\1.long\2/
s/([ 	]+)db([ 	]+".*")/\1.ascii\2/
s/([ 	]+)db([ 	])/\1.byte\2/
s/[ 	]+label ptr/:/
s/([ 	]+)comm([ 	]+[a-zA-Z0-9_]+):([0-9]+)/\1.comm\2,\3/
s/([ 	]+)comm([ 	]+[a-zA-Z0-9_]+):qword/\1.comm\2,8/
s/([ 	]+)comm([ 	])/\1.comm\2/
s/([ 	]+)align([ 	])/\1.align\2/
s/([ 	]+)align\(/\1.align	(/
s/\( *1 +shl +2 *\)/4/
s/\( *1 +shl +3 *\)/8/
s/([ 	])if([ 	])/\1.if\2/
s/([ 	])ife([ 	])/\1.if !\2/
s/ifdef/.ifdef/
s/ifndef/.ifndef/
s/else/.else/
s/endif/.endif/
s/([ 	]+)include([ 	]+)\.\.\\([a-zA-Z0-9._]*).asm/\1.include\2"\.\.\/\3.s"/
s/([ 	]+)include([ 	]+)([a-zA-Z0-9._]*).asm/\1.include\2"\3.s"/
s/([ 	]+)include([ 	]+)([a-zA-Z0-9._]*)/\1.include\2"\3"/
s/([ 	]+)_TEXT[ 	]+segment/\1.text/
s/([ 	]+)_DATA[ 	]+segment/\1.data/
s/_TEXT[ 	]+segment para 'CODE'//
s/_DATA[ 	]+segment para 'DATA'//
s/^_TEXT[ 	]+ends//
s/^_DATA[ 	]+ends//
s/([	,])([0-9])([0-9A-Fa-f]*)h([,+-])/\10x\2\3\4/
s/([	,])([0-9])([0-9A-Fa-f]*)h(,)/\10x\2\3\4/
s/([	,])([0-9])([0-9A-Fa-f]*)h(,)/\10x\2\3\4/
s/([	,])([0-9])([0-9A-Fa-f]*)h(,)/\10x\2\3\4/
s/([	,])([0-9])([0-9A-Fa-f]*)h$/\10x\2\3/
s/\(([0-9])([0-9A-Fa-f]*)h\)/(0x\1\2)/
s/(call[ 	])+near ptr[ 	]/\1/
s/^[ 	]+end[ 	]*//
s#^(.*[ 	])equ([ 	].*$)#/* \1=\2 */#
s#;(.*)$#/*\1 */#

s/,-\(4\*32\)$/,-4*32/
s/([[ 	,+])d2([] 	,+])/\1r10\2/
s/([[ 	,+])d2$/\1r10/
s/([ 	,+])d3([ 	,+])/\1r11\2/
s/([ 	,+])d3\]/\1r11]/
s/\[d3([ 	,+])/[r11\1/
s/\[d3\]/[r11]/
s/([[ 	,+])d3$/\1r11/
s/([[ 	,])d4([] 	,+$])/\1r12\2/
s/([ 	,])d5([ 	,+$])/\1r13\2/
s/\[d5\]/[r13]/
s/([ 	,])d3d([ 	,+]|$)/\1r11d\2/
s/([ 	,])d4d([ 	,+$])/\1r12d\2/
s/([ 	,])d2b([ 	,+$])/\1r10b\2/

