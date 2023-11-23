
#ifdef G_POWER
# define FMADD
#endif

#if defined (I486) && !defined (G_AI64)
# define FP_STACK_OPTIMIZATIONS
#endif

#define IBHS IBGEU

enum {
	IADD,		IAND,		IASR,		IBEQ,		IBGE,		IBGEU,		IBGT,
	IBGTU,		IBLE,		IBLEU,		IBLT,		IBLTU,		IBNE,		IBNO,
	IBO,		ICMP,		IDIV,		IEOR,
#ifndef ARM
	IEXG,
#endif
	IEXT,		IFADD,
#if ! (defined (I486) && !defined (G_A64))
	IFBEQ,		IFBGE,		IFBGT,		IFBLE,		IFBLT,		IFBNE,
	IFBNEQ,		IFBNGE,		IFBNGT,		IFBNLE,		IFBNLT,		IFBNNE,
#endif
	IFABS,		IFCMP,		IFDIV,		IFMUL,		IFNEG,		IFREM,
	IFSEQ,		IFSGE,		IFSGT,		IFSLE,		IFSLT,		IFSNE,		IFSUB,
	IFTAN,		IFTST,		IFMOVE,		IFMOVEL,	IJMP,		IJSR,		ILEA,
	ILSL,		ILSR,		IREM,		IMOVE,		IMOVEB,		IMOVEDB,	IMUL,
	INEG,		IOR,		IRTS,		ISCHEDULE,	ISEQ,		ISGE,		ISGEU,
	ISGT,		ISGTU,		ISLE,		ISLEU,		ISLT,		ISLTU,		ISNE,
	ISNO,		ISO,		ISUB,		ITST,		IWORD
#ifndef ARM
	,IFCOS,		IFSIN
#endif
#if !defined (G_POWER)
	,IFSQRT
#endif
#ifdef M68000
	,ICMPW
	,IFACOS,	IFASIN,		IFATAN,		IFEXP,		IFLN,		IFLOG10
	,IBMI,		IBMOVE,		ITSTB
#endif
#if defined (M68000) || defined (ARM)
	,IMOVEM
#endif
#if defined (M68000) || defined (G_POWER)
	,IEXTB
#endif
#ifndef M68000
	,IBTST
#endif
#ifdef sparc
	,IFMOVEHI,	IFMOVELO
#endif
#ifdef G_POWER
	,IBNEP,IMTCTR
#endif
#if defined (G_POWER) || defined (sparc) || defined (ARM)
	,IADDI,	ILSLI
	,IADDO,	ISUBO
#endif
#ifdef I486
	,IASR_S,ILSL_S,ILSR_S
	,IROTL,IROTL_S,IROTR_S
#endif
#if defined (I486) || defined (ARM)
	,IROTR
#endif
#if defined (I486) && !defined (G_A64)
	,IFCEQ,	IFCGE, IFCGT, IFCLE, IFCLT, IFCNE
	,IFSINCOS
#endif
#ifdef G_POWER
	,ICMPLW
	,IMULO
#endif
#if defined (G_POWER) || defined (I486) || defined (ARM)
	,IJMPP	,IRTSP, INOT
#endif
#if defined (I486) && defined (FP_STACK_OPTIMIZATIONS)
	,IFEXG
#endif
#if defined (I486) || defined (ARM)
	,IADC, ISBB, IRTSI
#endif
#if defined (I486) || defined (ARM)
	,IDIVI, IREMI, IREMU, IFLOORDIV, IMOD
	,IFLOADS, IFMOVES
#endif
#if defined (I486) || (defined (ARM) && !defined (G_A64))
	,IMULUD
#endif
#if defined (I486)
	,IDIVDU
#endif
#if defined (I486) || defined (ARM) || defined (G_POWER)
	,IDIVU
#endif
#if defined (G_POWER) || (defined (ARM) && defined (G_A64))
	,IUMULH
#endif
#ifdef G_A64
	,ILOADSQB,	IMOVEQB
 #ifdef G_AI64
	,IFCVT2S
# endif
#endif
#if defined (THREAD32) || defined (THREAD64)
	,ILDTLSP
#endif
#ifdef THUMB
	,IANDI,	IORI
#endif
#if defined (I486) || defined (ARM)
	,ICLZB
#endif
};

enum {
	P_REGISTER,			P_LABEL,			P_DESCRIPTOR_NUMBER,	P_INDIRECT,	
	P_IMMEDIATE,		P_F_IMMEDIATE,		P_F_REGISTER,			P_INDEXED
#if defined (M68000) || defined (I486) || defined (ARM)
	,P_POST_INCREMENT,	P_PRE_DECREMENT
#endif
#if defined (G_POWER) || defined (ARM)
	,P_INDIRECT_WITH_UPDATE
#endif
#if defined (G_POWER)
	,P_INDIRECT_HP,	P_STORE_HP_INSTRUCTION
#endif
#if defined (ARM)
	,P_INDIRECT_POST_ADD
# if defined (THUMB) || defined (G_A64)
	,P_INDIRECT_ANY_ADDRESS
# endif
#endif
};
