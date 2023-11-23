/*
	File:	cgopt.c
	Author:	John van Groningen
	At:		University of Nijmegen
*/

#include <stdio.h>
#if defined (LINUX) && defined (G_AI64)
# include <stdint.h>
#elif defined (__GNUC__) && defined (__SIZEOF_POINTER__)
# if __SIZEOF_POINTER__==8
#  include <stdint.h>
# endif
#endif

#include "cgport.h"
#include "cg.h"
#include "cgrconst.h"
#include "cgtypes.h"
#include "cgiconst.h"
#include "cglin.h"

#include "cgopt.h"

#if defined (I486) && !defined (G_AI64)
# define I486_USE_SCRATCH_REGISTER
#endif

#ifndef M68000
# define NEW_R_ALLOC
#endif

#ifdef G_POWER
# define IF_G_POWER(a) a
#else
# define IF_G_POWER(a)
#endif

#ifdef sparc
# define IF_G_SPARC(a) a
#else
# define IF_G_SPARC(a)
#endif

#if defined (G_POWER) || defined (sparc) || defined (ARM)
# define IF_G_RISC(a) a
#else
# define IF_G_RISC(a)
#endif

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

#if ! (defined (ARM) && defined (G_A64))
# define POWER_PC_A_STACK_OPTIMIZE
#endif
#if defined (I486) || defined (ARM)
# define OPTIMIZE_LOOPS
#endif

/* from cgcode.c : */

extern struct basic_block *first_block;

#ifdef OPTIMIZE_LOOPS
extern LABEL *new_local_label (int label_flags);
#endif

static void optimize_branch_jump (struct instruction *branch,LABEL *new_branch_label)
{
	branch->instruction_parameters[0].parameter_data.l=new_branch_label;
	
	switch (branch->instruction_icode){
		case IBEQ:	branch->instruction_icode=IBNE;		break;
		case IBGE:	branch->instruction_icode=IBLT;		break;
		case IBGT:	branch->instruction_icode=IBLE;		break;
		case IBLE:	branch->instruction_icode=IBGT;		break;
		case IBLT:	branch->instruction_icode=IBGE;		break;
		case IBNE:	branch->instruction_icode=IBEQ;		break;
		case IBGEU:	branch->instruction_icode=IBLTU;	break;
		case IBGTU:	branch->instruction_icode=IBLEU;	break;
		case IBLEU:	branch->instruction_icode=IBGTU;	break;
		case IBLTU:	branch->instruction_icode=IBGEU;	break;
#if !defined (I486_USE_SCRATCH_REGISTER) || defined (G_A64) || defined (ARM)
		case IFBEQ:	branch->instruction_icode=IFBNEQ;	break;
		case IFBGE:	branch->instruction_icode=IFBNGE;	break;
		case IFBGT:	branch->instruction_icode=IFBNGT;	break;
		case IFBLE:	branch->instruction_icode=IFBNLE;	break;
		case IFBLT:	branch->instruction_icode=IFBNLT;	break;
		case IFBNE:	branch->instruction_icode=IFBNNE;	break;
		case IFBNEQ:	branch->instruction_icode=IFBEQ;	break;
		case IFBNGE:	branch->instruction_icode=IFBGE;	break;
		case IFBNGT:	branch->instruction_icode=IFBGT;	break;
		case IFBNLE:	branch->instruction_icode=IFBLE;	break;
		case IFBNLT:	branch->instruction_icode=IFBLT;	break;
		case IFBNNE:	branch->instruction_icode=IFBNE;
#endif
	}
}

#ifdef OPTIMIZE_LOOPS
static LABEL *get_label_of_block (struct basic_block *block)
{
	if (block->block_labels!=NULL)
		return block->block_labels->block_label_label;
	else {
		struct block_label *new_block_label;
		LABEL *new_jmp_label;

		new_jmp_label=new_local_label (0);

		new_block_label=fast_memory_allocate_type (struct block_label);
		new_block_label->block_label_label=new_jmp_label;
		new_block_label->block_label_next=NULL;
		
		block->block_labels=new_block_label;

		return new_jmp_label;
	}
}
#endif

void optimize_jumps (void)
{
	struct basic_block *block;

	for_l (block,first_block,block_next){
		struct instruction *branch;
		
		if ((branch=block->block_last_instruction)!=NULL){
			switch (branch->instruction_icode){
				case IBEQ:	case IBGE:	case IBGT:	case IBLE:	case IBLT:
				case IBNE:	case IBGEU:	case IBGTU:	case IBLEU:	case IBLTU:
#if !defined (I486_USE_SCRATCH_REGISTER) || defined (G_A64) || defined (ARM)
				case IFBEQ:	case IFBGE:	case IFBGT:	case IFBLE:	case IFBLT:	case IFBNE:
				case IFBNEQ:	case IFBNGE:	case IFBNGT:	case IFBNLE:	case IFBNLT:	case IFBNNE:
#endif
				{
					struct basic_block *next_block;
					
					if ((next_block=block->block_next)!=NULL && next_block->block_labels==NULL){
						struct instruction *jump;
						
						if ((jump=next_block->block_instructions)!=NULL
							&& jump->instruction_icode==IJMP
							&& jump->instruction_parameters[0].parameter_type==P_LABEL
							&& jump->instruction_next==NULL )
						{
							struct basic_block *next_next_block;
							
							if ((next_next_block=next_block->block_next)!=NULL){
								struct block_label *block_labels;
								LABEL *branch_label;
								
								branch_label=branch->instruction_parameters[0].parameter_data.l;
								if ((branch_label->label_flags & LOCAL_LABEL) &&
									(jump->instruction_parameters[0].parameter_data.l->label_flags & LOCAL_LABEL)
#ifdef G_POWER
									&& !(jump->instruction_parameters[0].parameter_data.l->label_flags & DOT_O_BEFORE_LABEL)
#endif
									)
								{
									for_l (block_labels,next_next_block->block_labels,block_label_next)
										if (block_labels->block_label_label==branch_label){
											optimize_branch_jump (branch,jump->instruction_parameters[0].parameter_data.l);
											next_block->block_instructions=NULL;
#ifdef OPTIMIZE_LOOPS
											next_block->block_last_instruction=NULL;
#endif
											break;
										}
								}
							}
						}
					}

#ifdef OPTIMIZE_LOOPS
					{
					struct instruction *cmp_instruction;
					
					cmp_instruction=block->block_instructions;
					if (cmp_instruction->instruction_icode==ICMP && cmp_instruction->instruction_next==branch
						&& (cmp_instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE ||
							cmp_instruction->instruction_parameters[0].parameter_type==P_REGISTER ||
							(cmp_instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
							 cmp_instruction->instruction_parameters[1].parameter_type==P_REGISTER))
						&& (cmp_instruction->instruction_parameters[1].parameter_type==P_REGISTER ||
							cmp_instruction->instruction_parameters[1].parameter_type==P_INDIRECT)
						&& block->block_profile==0
					){
						struct block_label *block_label;
						
						for_l (block_label,block->block_labels,block_label_next){
							LABEL *label;

							label=block_label->block_label_label;
							label->label_flags |= CMP_BRANCH_BLOCK_LABEL;
							label->label_block = block;
						}
					}
					}
#endif
					break;
				}
				case IJMP:
				{
					struct basic_block *next_block;

					if (branch->instruction_parameters[0].parameter_type==P_LABEL
						&& (next_block=block->block_next)!=NULL)
					{
						struct block_label *labels;
						LABEL *jmp_label;
				
						jmp_label=branch->instruction_parameters[0].parameter_data.l;
						
						labels=next_block->block_labels;
						for (; labels!=NULL; labels=labels->block_label_next){
							if (labels->block_label_label==jmp_label){
								if (next_block->block_begin_module)
									next_block->block_link_module=1;

								/* remove branch */
								if (branch->instruction_prev!=NULL)
									branch->instruction_prev->instruction_next=NULL;
								else
#ifdef OPTIMIZE_LOOPS
								{
									block->block_instructions=NULL;
									block->block_last_instruction=NULL;
								}
#else
									block->block_instructions=NULL;
#endif
								break;
							}
						}
					}
					break;
				}
#if defined (G_POWER)
				case IJSR:
				{
					struct basic_block *next_block;
					struct instruction *next_block_last_instruction;

					if (block->block_n_new_heap_cells!=0 && !(branch->instruction_arity & NO_MFLR)){
						if (block->block_gc_kind==0){
							block->block_gc_kind=2;
							branch->instruction_arity |= NO_MFLR;
						} else if (block->block_gc_kind==1){
							block->block_gc_kind=3;
							branch->instruction_arity |= NO_MFLR;							
						}
					}

					if ((next_block=block->block_next)!=NULL && next_block->block_labels==NULL
						&& !next_block->block_begin_module && !(next_block->block_n_node_arguments>-100))
					{
						if (next_block->block_n_new_heap_cells!=0){
							branch->instruction_arity|=NO_MTLR;
							next_block->block_gc_kind=1;
						} else {
							if ((next_block_last_instruction=next_block->block_last_instruction)!=NULL
								&& next_block_last_instruction->instruction_icode==IJSR)
							{
								branch->instruction_arity|=NO_MTLR;
								next_block_last_instruction->instruction_arity|=NO_MFLR;
							}
						}
					}
				}
#endif
			}
		}
	}

#ifdef OPTIMIZE_LOOPS
	for_l (block,first_block,block_next){
		struct instruction *branch;
		
		if ((branch=block->block_last_instruction)!=NULL &&
			branch->instruction_icode==IJMP && branch->instruction_parameters[0].parameter_type==P_LABEL)
		{
			LABEL *jmp_label;
		
			jmp_label=branch->instruction_parameters[0].parameter_data.l;
			if (jmp_label->label_flags & CMP_BRANCH_BLOCK_LABEL){
				struct basic_block *jmp_block,*jmp_next_block;
				struct block_label *branch_block_label,*branch_next_block_label;
				struct instruction *old_cmp_instruction,*old_branch_instruction,*new_branch_instruction;
				LABEL *branch_label,*new_jmp_label;
# if defined (I486) || defined (ARM)
				struct instruction *previous_instruction;
# endif

				jmp_block=jmp_label->label_block;
				old_cmp_instruction=jmp_block->block_instructions;
				jmp_next_block=jmp_block->block_next;
				old_branch_instruction=old_cmp_instruction->instruction_next;

				branch_label=old_branch_instruction->instruction_parameters[0].parameter_data.l;

				branch_next_block_label=NULL;
				if (block->block_next!=NULL)
					for_l (branch_next_block_label,block->block_next->block_labels,block_label_next)
						if (branch_next_block_label->block_label_label==branch_label)
							break;

				branch_block_label=NULL;
				if (branch_next_block_label==NULL)
					for_l (branch_block_label,block->block_labels,block_label_next)
						if (branch_block_label->block_label_label==branch_label)
							break;

# if defined (I486) || defined (ARM)
				if (old_cmp_instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE &&
					old_cmp_instruction->instruction_parameters[0].parameter_data.i==0 &&
					old_cmp_instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
					(previous_instruction=branch->instruction_prev)!=NULL &&
					(previous_instruction->instruction_icode==ISUB || previous_instruction->instruction_icode==IADD) &&
					previous_instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
					old_cmp_instruction->instruction_parameters[1].parameter_data.reg.r==previous_instruction->instruction_parameters[1].parameter_data.reg.r)
				{
					new_jmp_label = get_label_of_block (jmp_next_block);

#  ifdef ARM
					if (previous_instruction->instruction_icode==ISUB)
						previous_instruction->instruction_icode=ISUBO;
					else if (previous_instruction->instruction_icode==IADD)
						previous_instruction->instruction_icode=IADDO;
#  endif

					if (branch_next_block_label!=NULL){
						branch->instruction_icode=old_branch_instruction->instruction_icode;
						branch->instruction_parameters[0]=old_branch_instruction->instruction_parameters[0];

						if (block->block_next->block_begin_module)
							block->block_next->block_link_module=1;

						optimize_branch_jump (branch,new_jmp_label);
					} else {
						new_branch_instruction=(struct instruction*)fast_memory_allocate (sizeof (struct instruction)+sizeof (struct parameter));
						
						new_branch_instruction->instruction_icode=old_branch_instruction->instruction_icode;
						new_branch_instruction->instruction_arity=1;
						new_branch_instruction->instruction_parameters[0]=old_branch_instruction->instruction_parameters[0];

						if (block->block_instructions==branch){
							block->block_instructions=new_branch_instruction;
							new_branch_instruction->instruction_prev=NULL;
						} else {
							struct instruction *previous_instruction;
							
							previous_instruction=branch->instruction_prev;
							previous_instruction->instruction_next=new_branch_instruction;
							new_branch_instruction->instruction_prev=previous_instruction;
						}
						new_branch_instruction->instruction_next=branch;
						
						branch->instruction_prev=new_branch_instruction;

						branch->instruction_parameters[0].parameter_data.l=new_jmp_label;
					}
				} else
# endif

				if (branch_next_block_label!=NULL || branch_block_label!=NULL){
					struct instruction *new_cmp_instruction;
					
					new_cmp_instruction=(struct instruction*)fast_memory_allocate (sizeof (struct instruction)+2*sizeof (struct parameter));

					new_cmp_instruction->instruction_icode=ICMP;
					new_cmp_instruction->instruction_arity=2;
					new_cmp_instruction->instruction_parameters[0]=old_cmp_instruction->instruction_parameters[0];
					new_cmp_instruction->instruction_parameters[1]=old_cmp_instruction->instruction_parameters[1];

					if (block->block_instructions==branch){
						block->block_instructions=new_cmp_instruction;
						new_cmp_instruction->instruction_prev=NULL;
					} else {
						struct instruction *previous_instruction;
							
						previous_instruction=branch->instruction_prev;
						previous_instruction->instruction_next=new_cmp_instruction;
						new_cmp_instruction->instruction_prev=previous_instruction;
					}
					
					new_jmp_label = get_label_of_block (jmp_next_block);

					if (branch_next_block_label!=NULL){
						branch->instruction_icode=old_branch_instruction->instruction_icode;
						branch->instruction_parameters[0]=old_branch_instruction->instruction_parameters[0];

						if (block->block_next->block_begin_module)
							block->block_next->block_link_module=1;

						optimize_branch_jump (branch,new_jmp_label);

						new_cmp_instruction->instruction_next=branch;
						
						branch->instruction_prev=new_cmp_instruction;
					} else {
						new_branch_instruction=(struct instruction*)fast_memory_allocate (sizeof (struct instruction)+sizeof (struct parameter));
						
						new_branch_instruction->instruction_icode=old_branch_instruction->instruction_icode;
						new_branch_instruction->instruction_arity=1;
						new_branch_instruction->instruction_parameters[0]=old_branch_instruction->instruction_parameters[0];

						new_cmp_instruction->instruction_next=new_branch_instruction;
						
						new_branch_instruction->instruction_prev=new_cmp_instruction;
						new_branch_instruction->instruction_next=branch;
						
						branch->instruction_prev=new_branch_instruction;

						branch->instruction_parameters[0].parameter_data.l=new_jmp_label;
					}
				}
			}
		}
	}
#endif
}

#if defined (M68000) || defined (I486) || defined (ARM)

#	ifdef M68000
static struct parameter *previous_a_parameter;
static int previous_a_icode;
static int a_offset;
#	endif

static int b_offset;

#	ifdef M68000
static int get_argument_size (int instruction_code)
{
	switch (instruction_code){
		case IADD:		case IAND:		case IASR:		case ICMP:		case IDIV:
		case IEOR:		case ILSL:		case ILSR:		case IREM:		case IMOVE:
		case IMUL:		case IOR:		case ISUB:
#ifndef I486
		case ITST:
#endif
IF_G_RISC (case IADDI: case ILSLI:)
#if defined (sparc) || defined (ARM)
		case IADDO:		case ISUBO:
#endif
#if defined (I486) || defined (ARM)
		case IDIVI:		case IREMI:		case IREMU:
		case IFLOORDIV:	case IMOD:
#endif
#if defined (I486) || (defined (ARM) && !defined (G_A64))
		case IMULUD:
#endif
#ifdef I486
		case IDIVDU:
#endif
#if ((defined (I486) || defined (ARM)) && !defined (I486_USE_SCRATCH_REGISTER)) || defined (G_POWER)
		case IDIVU:
#endif
#if defined (G_POWER) || defined (ARM)
		case IUMULH:
#endif
			return 4;
		case IFADD:		case IFCMP:		case IFDIV:		case IFMUL:
		case IFREM:		case IFSUB:		case IFTST:		case IFMOVE:
		case IFACOS:	case IFASIN:	case IFATAN:	case IFCOS:
		case IFEXP:		case IFLN:		case IFLOG10:	case IFSIN:
		case IFTAN:		case IFNEG:
#if !defined (G_POWER)
		case IFSQRT:
#endif
		case IFABS:
			return 8;
		default:
			return 0;
	}
}

static void optimize_a_stack_access (struct parameter *parameter,int instruction_code)
{
	int	previous_argument_size;
	
	if (previous_a_parameter!=NULL){
		previous_argument_size=get_argument_size (previous_a_icode);
		
		if (previous_argument_size!=0){
			if (previous_a_parameter->parameter_offset==0){
				if (parameter->parameter_offset-a_offset==previous_argument_size){
					a_offset+=previous_argument_size;
					previous_a_parameter->parameter_type=P_POST_INCREMENT;
				}  else {
					int argument_size=get_argument_size (instruction_code);
		
					if (argument_size!=0 && argument_size!=previous_argument_size
						&& parameter->parameter_offset-a_offset
						==previous_argument_size-argument_size)
					{
						a_offset+=previous_argument_size;
						previous_a_parameter->parameter_type=P_POST_INCREMENT;	
					}
				}
			} else 
			if (previous_a_parameter->parameter_offset==-previous_argument_size
				&& parameter->parameter_offset-a_offset!=0)
			{
				a_offset-=previous_argument_size;
				previous_a_parameter->parameter_type=P_PRE_DECREMENT;
			}
		}
	}
	
	parameter->parameter_offset-=a_offset;
	previous_a_parameter=parameter;
	previous_a_icode=instruction_code;
}
#	endif

extern struct basic_block *last_block;
extern struct instruction *last_instruction;

#if defined (ARM) && (defined (G_A64) || defined (THUMB))
static void insert_decrement_a_stack_pointer (struct instruction *next_instruction,int offset)
{
	struct instruction *previous_instruction,*instruction;
				
	instruction=(struct instruction*)fast_memory_allocate (sizeof (struct instruction)+2*sizeof (struct parameter));

	instruction->instruction_arity=2;
	instruction->instruction_icode=ILEA;

	instruction->instruction_parameters[0].parameter_type=P_INDIRECT;
	instruction->instruction_parameters[0].parameter_offset=-offset;
	instruction->instruction_parameters[0].parameter_data.reg.r=A_STACK_POINTER;

	instruction->instruction_parameters[1].parameter_type=P_REGISTER;
	instruction->instruction_parameters[1].parameter_data.i=A_STACK_POINTER;

	previous_instruction=next_instruction->instruction_prev;
	if (previous_instruction==NULL)
		last_block->block_instructions=instruction;
	else
		previous_instruction->instruction_next=instruction;
	
	instruction->instruction_next=next_instruction;
	instruction->instruction_prev=previous_instruction;

	if (next_instruction!=NULL)
		next_instruction->instruction_prev=instruction;
}
#endif

#if defined (M68000) || defined (I486) || defined (ARM)
static void insert_decrement_b_stack_pointer (struct instruction *next_instruction,int offset)
{
	struct instruction *previous_instruction,*instruction;
				
	instruction=(struct instruction*)fast_memory_allocate (sizeof (struct instruction)+2*sizeof (struct parameter));

	instruction->instruction_arity=2;
# ifdef M68000
	instruction->instruction_icode=ISUB;

	instruction->instruction_parameters[0].parameter_type=P_IMMEDIATE;
	instruction->instruction_parameters[0].parameter_data.i=offset;
# else
	instruction->instruction_icode=ILEA;

	instruction->instruction_parameters[0].parameter_type=P_INDIRECT;
	instruction->instruction_parameters[0].parameter_offset=-offset;
	instruction->instruction_parameters[0].parameter_data.reg.r=B_STACK_POINTER;
# endif

	instruction->instruction_parameters[1].parameter_type=P_REGISTER;
	instruction->instruction_parameters[1].parameter_data.i=B_STACK_POINTER;

	previous_instruction=next_instruction->instruction_prev;
	if (previous_instruction==NULL)
		last_block->block_instructions=instruction;
	else
		previous_instruction->instruction_next=instruction;
	
	instruction->instruction_next=next_instruction;
	instruction->instruction_prev=previous_instruction;

	if (next_instruction!=NULL)
		next_instruction->instruction_prev=instruction;
}
#endif

#if defined (I486) || defined (ARM)
static void optimize_b_stack_access (struct parameter *parameter,struct instruction *instruction)
{
	if (parameter->parameter_offset<b_offset){
		insert_decrement_b_stack_pointer (instruction,b_offset-parameter->parameter_offset);
		b_offset=parameter->parameter_offset;
	}

	parameter->parameter_offset-=b_offset;
}

static void optimize_b_stack_access2 (struct instruction *instruction)
{
	struct parameter *parameter0,*parameter1;
	
	parameter0=&instruction->instruction_parameters[0];
	parameter1=&instruction->instruction_parameters[1];
	
	if (parameter1->parameter_offset<b_offset && parameter1->parameter_offset < parameter0->parameter_offset){
		insert_decrement_b_stack_pointer (instruction,b_offset-parameter1->parameter_offset);

		b_offset=parameter1->parameter_offset;
		parameter0->parameter_offset-=b_offset;
		parameter1->parameter_offset=0;
		return;
	}
	
	if (parameter0->parameter_offset<b_offset){
		insert_decrement_b_stack_pointer (instruction,b_offset-parameter0->parameter_offset);
		b_offset=parameter0->parameter_offset;
		parameter0->parameter_offset=0;
	} else
		parameter0->parameter_offset-=b_offset;

	if (parameter1->parameter_offset<b_offset)
		internal_error_in_function ("optimize_b_stack_access2");
		
	parameter1->parameter_offset-=b_offset;
}
#endif

#ifdef M68000
static void optimize_b_stack_access (struct parameter *parameter,struct instruction *instruction)
{
	int argument_size;
	
	if (parameter->parameter_offset<b_offset){
		argument_size=get_argument_size (instruction->instruction_icode);
		
		if (argument_size!=0 && parameter->parameter_offset==b_offset-argument_size){
			b_offset-=argument_size;
			parameter->parameter_type=P_PRE_DECREMENT;
			return;	
		} else {
			insert_decrement_b_stack_pointer (instruction,b_offset-parameter->parameter_offset);
			b_offset=parameter->parameter_offset;
		}
	} else 
		if (parameter->parameter_offset==b_offset
			&& b_offset<((WORD)parameter->parameter_data.reg.u))
		{
			argument_size=get_argument_size (instruction->instruction_icode);
			
			if (argument_size!=0 && b_offset+argument_size<=((WORD)parameter->parameter_data.reg.u)){
				b_offset+=argument_size;
				parameter->parameter_type=P_POST_INCREMENT;	
				return;
			}
		}
		
	parameter->parameter_offset-=b_offset;
}

static void optimize_b_stack_access2 (struct instruction *instruction)
{
	int argument_size;
	struct parameter *parameter0,*parameter1;
	
	parameter0=&instruction->instruction_parameters[0];
	parameter1=&instruction->instruction_parameters[1];

	argument_size=get_argument_size (instruction->instruction_icode);
	
	if (parameter1->parameter_offset<b_offset
		&&	!(argument_size!=0 && parameter1->parameter_offset==b_offset-argument_size))
	{
		insert_decrement_b_stack_pointer (instruction,b_offset-parameter1->parameter_offset);

		b_offset=parameter1->parameter_offset;
		parameter0->parameter_offset-=b_offset;
		parameter1->parameter_offset=0;
		return;
	}
	
	if (parameter0->parameter_offset<b_offset){
		if (argument_size!=0 && parameter0->parameter_offset==b_offset-argument_size){
			b_offset-=argument_size;
			parameter0->parameter_type=P_PRE_DECREMENT;
		} else {
			insert_decrement_b_stack_pointer (instruction,b_offset-parameter0->parameter_offset);
			b_offset=parameter0->parameter_offset;
			parameter0->parameter_offset=0;
		}
	} else {
		if (parameter0->parameter_offset==b_offset
			&& b_offset<((WORD)parameter0->parameter_data.reg.u))
		{
			if (argument_size!=0 && b_offset+argument_size<=((WORD)parameter0->parameter_data.reg.u)){
				b_offset+=argument_size;
				parameter0->parameter_type=P_POST_INCREMENT;	
			} else
				parameter0->parameter_offset-=b_offset;
		} else
			parameter0->parameter_offset-=b_offset;
	}

	if (parameter1->parameter_offset<b_offset){
		if (argument_size!=0 && parameter1->parameter_offset==b_offset-argument_size){
			b_offset-=argument_size;
			parameter1->parameter_type=P_PRE_DECREMENT;
			return;	
		} else
			internal_error_in_function ("optimize_b_stack_access2");
	} else 
		if (parameter1->parameter_offset==b_offset
			&& b_offset<((WORD)parameter1->parameter_data.reg.u))
		{
			if (argument_size!=0 && b_offset+argument_size<=((WORD)parameter1->parameter_data.reg.u)){
				b_offset+=argument_size;
				parameter1->parameter_type=P_POST_INCREMENT;	
				return;
			}
		}
		
	parameter1->parameter_offset-=b_offset;
}
#	endif

static void compute_maximum_b_stack_offsets (int b_offset)
{
	struct instruction *instruction;
	
	for_l (instruction,last_instruction,instruction_prev){
		switch (instruction->instruction_arity){
			default:
				if (
#ifdef M68000
					instruction->instruction_icode!=IMOVEM &&
#endif
#ifdef ARM
					instruction->instruction_icode!=IADDI &&
					instruction->instruction_icode!=ILSLI &&
#endif
#if defined (I486) || defined (ARM)
# ifdef THREAD32
					instruction->instruction_icode!=IDIV &&
					instruction->instruction_icode!=IDIVU &&
					instruction->instruction_icode!=IMULUD &&
# endif
					instruction->instruction_icode!=IDIVI &&
					instruction->instruction_icode!=IREMI &&
					instruction->instruction_icode!=IREMU &&
# ifndef ARM
					instruction->instruction_icode!=IDIVDU &&
					instruction->instruction_icode!=IASR_S &&
					instruction->instruction_icode!=ILSL_S &&
					instruction->instruction_icode!=ILSR_S &&
# endif
					instruction->instruction_icode!=IFLOORDIV &&
					instruction->instruction_icode!=IMOD &&
# ifndef ARM
					instruction->instruction_icode!=IROTL_S &&
					instruction->instruction_icode!=IROTR_S &&
# endif
#endif
					instruction->instruction_icode!=IREM)
#ifdef M68000
						if (instruction->instruction_icode==IBMOVE)
							break;
						else
#endif
							internal_error_in_function ("compute_maximum_b_stack_offsets");
					/* only first argument of movem or mod might be register indirect */
					/* no break ! */
			case 1:
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
					&& instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER)
				{
					instruction->instruction_parameters[0].parameter_data.reg.u=b_offset;
					if (instruction->instruction_parameters[0].parameter_offset<b_offset)
						b_offset=instruction->instruction_parameters[0].parameter_offset;
				}
				break;
			case 2:
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
					&& instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER)
				{
					instruction->instruction_parameters[0].parameter_data.reg.u=b_offset;
					if (instruction->instruction_parameters[0].parameter_offset<b_offset)
						b_offset=instruction->instruction_parameters[0].parameter_offset;
				}
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT
					&& instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER)
				{
					instruction->instruction_parameters[1].parameter_data.reg.u=b_offset;
					if (instruction->instruction_parameters[1].parameter_offset<b_offset)
						b_offset=instruction->instruction_parameters[1].parameter_offset;
				}
		}
	}
}

#ifdef ARM
static int is_int_instruction (int icode)
{
	switch (icode){
		case IMOVE:
		case IADD: case ISUB:  case ICMP:  case ITST:  case INEG: /* case IADDI: */
		case IAND: case IOR:   case IEOR:  case INOT:
		case ILSL: case ILSR:  case IASR:  case IROTR: /* case ILSLI: */
		case IMUL:
# ifdef G_A64
		case IUMULH:
# endif
		case IDIV: case IDIVI: case IFLOORDIV: case IDIVU:
		case IREM: case IREMI: case IREMU:  case IMOD:
		case IADC: case ISBB:  case IADDO:  case ISUBO:
			return 1;
		default:
			return 0;
	}
}

# if defined (G_A64) || defined (THUMB)
static void adjust_a_stack_pointer_in_previous_instructions (struct instruction *current_instruction,int smallest_a_offset)
{
	struct instruction *instruction;

	for (instruction=current_instruction->instruction_prev; ; instruction=instruction->instruction_prev)
		switch (instruction->instruction_arity){
			default:
				if (
					instruction->instruction_icode!=IADDI &&
					instruction->instruction_icode!=ILSLI &&
# ifdef THREAD32
					instruction->instruction_icode!=IDIV &&
					instruction->instruction_icode!=IDIVU &&
					instruction->instruction_icode!=IMULUD &&
# endif
					instruction->instruction_icode!=IDIVI &&
					instruction->instruction_icode!=IREMI &&
					instruction->instruction_icode!=IREMU &&
					instruction->instruction_icode!=IFLOORDIV &&
					instruction->instruction_icode!=IMOD &&
					instruction->instruction_icode!=IREM)
						internal_error_in_function ("adjust_a_stack_pointer_in_previous_instructions");
					/* only first argument might be register indirect */
					/* no break ! */
			case 1:
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
					instruction->instruction_parameters[0].parameter_data.reg.r==A_STACK_POINTER)
				{
					if (instruction->instruction_parameters[0].parameter_offset==smallest_a_offset){
						instruction->instruction_parameters[0].parameter_type=P_INDIRECT_WITH_UPDATE;
						return;
					}
					instruction->instruction_parameters[0].parameter_offset -= smallest_a_offset;
				}
				break;
			case 2:
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
					instruction->instruction_parameters[1].parameter_data.reg.r==A_STACK_POINTER)
				{
					if (instruction->instruction_parameters[1].parameter_offset==smallest_a_offset){
						instruction->instruction_parameters[1].parameter_type=P_INDIRECT_WITH_UPDATE;
						return;
					}
					instruction->instruction_parameters[1].parameter_offset -= smallest_a_offset;
				}
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
					instruction->instruction_parameters[0].parameter_data.reg.r==A_STACK_POINTER)
				{
					if (instruction->instruction_parameters[0].parameter_offset==smallest_a_offset){
						instruction->instruction_parameters[0].parameter_type=P_INDIRECT_WITH_UPDATE;
						return;
					}
					instruction->instruction_parameters[0].parameter_offset -= smallest_a_offset;
				}
		}
}
# endif
#endif

void optimize_stack_access (struct basic_block *block,int *a_offset_p,int *b_offset_p
# ifdef ARM
	,int try_adjust_b_stack_pointer
# endif
	)
{
	struct instruction *instruction;

# ifdef M68000	
	a_offset=0;
	previous_a_parameter=NULL;
# endif
# ifdef ARM
	struct parameter *previous_a_stack_parameter,*previous_b_stack_parameter;
	int previous_a_stack_parameter_icode,previous_b_stack_parameter_icode;
#  if defined (G_A64) || defined (THUMB)
	int smallest_a_offset,a_offset;
#  endif

	previous_a_stack_parameter=NULL;
	previous_b_stack_parameter=NULL;
# endif

	b_offset=0;
	
	compute_maximum_b_stack_offsets (*b_offset_p);

# ifdef M68000
	for_l (instruction,block->block_instructions,instruction_next){
		switch (instruction->instruction_arity){
			default:
				if (
					instruction->instruction_icode!=IMOVEM &&
					instruction->instruction_icode!=IREM)
						if (instruction->instruction_icode==IBMOVE)
							break;
						else
							internal_error_in_function ("optimize_stack_access");
					/* only first argument of movem or mod might be register indirect */
					/* no break ! */
			case 1:
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					switch (instruction->instruction_parameters[0].parameter_data.reg.r){
						case A_STACK_POINTER:
							optimize_a_stack_access (&instruction->instruction_parameters[0],
													 instruction->instruction_icode);
							break;
						case B_STACK_POINTER:
							optimize_b_stack_access (&instruction->instruction_parameters[0],instruction);
					}
				}
				break;
			case 2:
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					if (instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER
						&&	instruction->instruction_parameters[1].parameter_type==P_INDIRECT
						&&	instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER)
					{
						optimize_b_stack_access2 (instruction);
						break;
					}

					switch (instruction->instruction_parameters[0].parameter_data.reg.r){
						case A_STACK_POINTER:
							optimize_a_stack_access (&instruction->instruction_parameters[0],
													 instruction->instruction_icode);
							break;
						case B_STACK_POINTER:
							optimize_b_stack_access (&instruction->instruction_parameters[0],instruction);
					}
				}
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT){
					switch (instruction->instruction_parameters[1].parameter_data.reg.r){
						case A_STACK_POINTER:
							optimize_a_stack_access (&instruction->instruction_parameters[1],
													 instruction->instruction_icode);
							break;
						case B_STACK_POINTER:
							optimize_b_stack_access (&instruction->instruction_parameters[1],instruction);
					}
				}
		}
	}
	
	if (previous_a_parameter!=NULL){
		int previous_argument_size;
		
		previous_argument_size=get_argument_size (previous_a_icode);
		if (previous_argument_size!=0){
			if (previous_a_parameter->parameter_offset==0){
				if (*a_offset_p-a_offset==previous_argument_size){
					a_offset+=previous_argument_size;
					previous_a_parameter->parameter_type=P_POST_INCREMENT;
				}
			} else if (previous_a_parameter->parameter_offset==-previous_argument_size){
				if (*a_offset_p-a_offset!=0){
					a_offset-=previous_argument_size;
					previous_a_parameter->parameter_type=P_PRE_DECREMENT;
				}
			}
		}
	}

	*a_offset_p-=a_offset;
# endif

# if defined (ARM) && (defined (G_A64) || defined (THUMB))
	smallest_a_offset=0;
	a_offset=0;
# endif

# if defined (I486) || defined (ARM)
	for_l (instruction,block->block_instructions,instruction_next){
		if (instruction->instruction_icode==IMOVE){
# ifdef ARM
			if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
				instruction->instruction_parameters[1].parameter_data.reg.r==A_STACK_POINTER)
			{
				previous_a_stack_parameter=&instruction->instruction_parameters[1];
				previous_a_stack_parameter_icode=IMOVE;
#  if defined (G_A64) || defined (THUMB)
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
					instruction->instruction_parameters[0].parameter_data.reg.r==A_STACK_POINTER)
				{
					int new_a_offset;
					
					new_a_offset = (instruction->instruction_parameters[0].parameter_offset -= a_offset);
					if (new_a_offset<smallest_a_offset){
#   ifdef THUMB
						if (new_a_offset < -255){
							if (new_a_offset - smallest_a_offset >= -255){
#   else
						if (new_a_offset < -256){
							if (new_a_offset - smallest_a_offset >= -256){
#   endif
								adjust_a_stack_pointer_in_previous_instructions (instruction,smallest_a_offset);
								a_offset+=smallest_a_offset;
								new_a_offset-=smallest_a_offset;
							} else {
								insert_decrement_a_stack_pointer (instruction,-new_a_offset);
								a_offset+=new_a_offset;
								new_a_offset=0;
							}
							instruction->instruction_parameters[0].parameter_offset = new_a_offset;
						}
						smallest_a_offset=new_a_offset;
					}
					
					new_a_offset = (instruction->instruction_parameters[1].parameter_offset -= a_offset);
					if (new_a_offset<smallest_a_offset){
#   ifdef THUMB
						if (new_a_offset < -255){
							if (new_a_offset - smallest_a_offset >= -255){
#   else
						if (new_a_offset < -256){
							if (new_a_offset - smallest_a_offset >= -256){
#   endif
								if (instruction->instruction_parameters[0].parameter_offset==smallest_a_offset){
									instruction->instruction_parameters[0].parameter_type=P_INDIRECT_WITH_UPDATE;
								} else {
									instruction->instruction_parameters[0].parameter_offset -= smallest_a_offset;
									adjust_a_stack_pointer_in_previous_instructions (instruction,smallest_a_offset);
								}
								a_offset+=smallest_a_offset;
								new_a_offset-=smallest_a_offset;
							} else {
								insert_decrement_a_stack_pointer (instruction,-new_a_offset);
								instruction->instruction_parameters[0].parameter_offset -= new_a_offset;							
								a_offset+=new_a_offset;
								new_a_offset=0;
							}
							instruction->instruction_parameters[1].parameter_offset = new_a_offset;
						}
						smallest_a_offset=new_a_offset;
					}
				} else {
					int new_a_offset;
					
					new_a_offset = (instruction->instruction_parameters[1].parameter_offset -= a_offset);
					if (new_a_offset<smallest_a_offset){
#   ifdef THUMB
						if (new_a_offset < -255){
							if (new_a_offset - smallest_a_offset >= -255){
#   else
						if (new_a_offset < -256){
							if (new_a_offset - smallest_a_offset >= -256){
#   endif
								adjust_a_stack_pointer_in_previous_instructions (instruction,smallest_a_offset);
								a_offset+=smallest_a_offset;
								new_a_offset-=smallest_a_offset;
							} else {
								insert_decrement_a_stack_pointer (instruction,-new_a_offset);
								a_offset+=new_a_offset;
								new_a_offset=0;
							}
							instruction->instruction_parameters[1].parameter_offset = new_a_offset;
						}
						smallest_a_offset=new_a_offset;
					}
				}
#  endif
			} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
					   instruction->instruction_parameters[0].parameter_data.reg.r==A_STACK_POINTER)
			{
				previous_a_stack_parameter=&instruction->instruction_parameters[0];
				previous_a_stack_parameter_icode=IMOVE;
#  if defined (G_A64) || defined (THUMB)
				{
					int new_a_offset;
					
					new_a_offset = (instruction->instruction_parameters[0].parameter_offset -= a_offset);
					if (new_a_offset<smallest_a_offset){
#   ifdef THUMB
						if (new_a_offset < -255){
							if (new_a_offset - smallest_a_offset >= -255){
#   else
						if (new_a_offset < -256){
							if (new_a_offset - smallest_a_offset >= -256){
#   endif
								adjust_a_stack_pointer_in_previous_instructions (instruction,smallest_a_offset);
								a_offset+=smallest_a_offset;
								new_a_offset-=smallest_a_offset;
							} else {
								insert_decrement_a_stack_pointer (instruction,-new_a_offset);
								a_offset+=new_a_offset;
								new_a_offset=0;
							}
							instruction->instruction_parameters[0].parameter_offset = new_a_offset;
						}
						smallest_a_offset=new_a_offset;
					}
				}
#  endif
			}
# endif
			if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
				instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER)
			{
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
					instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER)
				{
					struct parameter *parameter0,*parameter1;
					
					parameter0=&instruction->instruction_parameters[0];
					parameter1=&instruction->instruction_parameters[1];
# ifdef ARM
					previous_b_stack_parameter=parameter1;
					previous_b_stack_parameter_icode=IMOVE;
# endif
					if (parameter1->parameter_offset<b_offset && parameter1->parameter_offset!=b_offset-STACK_ELEMENT_SIZE){
# ifdef ARM
#  ifdef G_A64
						if (parameter1->parameter_offset-b_offset>=-256){
#  endif
						int offset;

						parameter0->parameter_offset-=b_offset;
						parameter1->parameter_type=P_INDIRECT_WITH_UPDATE;
						offset=parameter1->parameter_offset;
						parameter1->parameter_offset=offset-b_offset;
						b_offset=offset;
						continue;
#  ifdef G_A64
						} else {
							insert_decrement_b_stack_pointer (instruction,b_offset-parameter1->parameter_offset);

							b_offset=parameter1->parameter_offset;
							parameter0->parameter_offset-=b_offset;
							parameter1->parameter_offset=0;
							continue;
						}
#  endif
# else
						insert_decrement_b_stack_pointer (instruction,b_offset-parameter1->parameter_offset);
				
						b_offset=parameter1->parameter_offset;
						parameter0->parameter_offset-=b_offset;
						parameter1->parameter_offset=0;
						continue;
# endif
					}
					
					if (parameter0->parameter_offset<b_offset){
						insert_decrement_b_stack_pointer (instruction,b_offset-parameter0->parameter_offset);
						b_offset=parameter0->parameter_offset;
						parameter0->parameter_offset=0;
					} else {
						if (parameter0->parameter_offset==b_offset
							&& b_offset<((WORD)parameter0->parameter_data.reg.u))
						{
							if (b_offset+STACK_ELEMENT_SIZE<=((WORD)parameter0->parameter_data.reg.u)){
								b_offset+=STACK_ELEMENT_SIZE;
								parameter0->parameter_type=P_POST_INCREMENT;
							} else
								parameter0->parameter_offset-=b_offset;
						} else
							parameter0->parameter_offset-=b_offset;
					}
					
					if (parameter1->parameter_offset<b_offset){
						if (parameter1->parameter_offset==b_offset-STACK_ELEMENT_SIZE){
							b_offset-=STACK_ELEMENT_SIZE;
							parameter1->parameter_type=P_PRE_DECREMENT;
							continue;
						} else
							internal_error_in_function ("optimize_stack_access");
					}
						
					parameter1->parameter_offset-=b_offset;
				} else {
					struct parameter *parameter;
		
					parameter=&instruction->instruction_parameters[0];
# ifdef ARM
					previous_b_stack_parameter=parameter;
					previous_b_stack_parameter_icode=IMOVE;
# endif

					if (parameter->parameter_offset<b_offset){
# ifdef ARM
#  ifdef G_A64
						if (parameter->parameter_offset-b_offset>=-256){
#  endif
						int offset;

						parameter->parameter_type=P_INDIRECT_WITH_UPDATE;
						offset=parameter->parameter_offset;
						parameter->parameter_offset=offset-b_offset;
						b_offset=offset;
						continue;
#  ifdef G_A64
						} else {
							insert_decrement_b_stack_pointer (instruction,b_offset-parameter->parameter_offset);
							b_offset=parameter->parameter_offset;
						}
#  endif
# else
						insert_decrement_b_stack_pointer (instruction,b_offset-parameter->parameter_offset);
						b_offset=parameter->parameter_offset;
# endif
					} else 
						if (parameter->parameter_offset==b_offset
							&& b_offset<((WORD)parameter->parameter_data.reg.u))
						{							
							if (b_offset+STACK_ELEMENT_SIZE<=((WORD)parameter->parameter_data.reg.u)){
								b_offset+=STACK_ELEMENT_SIZE;
								parameter->parameter_type=P_POST_INCREMENT;
								continue;
							}
						}
					
					parameter->parameter_offset-=b_offset;
				}
			} else {
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
					instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER)
				{
					struct parameter *parameter;
		
					parameter=&instruction->instruction_parameters[1];
# ifdef ARM
					previous_b_stack_parameter=parameter;
					previous_b_stack_parameter_icode=IMOVE;
# endif
					if (parameter->parameter_offset<b_offset){
						if (parameter->parameter_offset==b_offset-STACK_ELEMENT_SIZE){
							b_offset-=STACK_ELEMENT_SIZE;
							parameter->parameter_type=P_PRE_DECREMENT;
							continue;
						} else {
# ifdef ARM
#  ifdef G_A64
							if (parameter->parameter_offset-b_offset>=-256){
#  endif
							int offset;

							parameter->parameter_type=P_INDIRECT_WITH_UPDATE;
							offset=parameter->parameter_offset;
							parameter->parameter_offset=offset-b_offset;
							b_offset=offset;
							continue;
#  ifdef G_A64
							} else {
								insert_decrement_b_stack_pointer (instruction,b_offset-parameter->parameter_offset);
								b_offset=parameter->parameter_offset;
							}
#  endif
# else
							insert_decrement_b_stack_pointer (instruction,b_offset-parameter->parameter_offset);
							b_offset=parameter->parameter_offset;
# endif
						}
					}
						
					parameter->parameter_offset-=b_offset;
				}
			}
		} else
	
		switch (instruction->instruction_arity){
			default:
				if (
#ifdef ARM
					instruction->instruction_icode!=IADDI &&
					instruction->instruction_icode!=ILSLI &&
#endif
# ifdef THREAD32
					instruction->instruction_icode!=IDIV &&
					instruction->instruction_icode!=IDIVU &&
					instruction->instruction_icode!=IMULUD &&
# endif
					instruction->instruction_icode!=IDIVI &&
					instruction->instruction_icode!=IREMI &&
					instruction->instruction_icode!=IREMU &&
# ifndef ARM
					instruction->instruction_icode!=IDIVDU &&
					instruction->instruction_icode!=IASR_S &&
					instruction->instruction_icode!=ILSL_S &&
					instruction->instruction_icode!=ILSR_S &&
# endif
					instruction->instruction_icode!=IFLOORDIV &&
					instruction->instruction_icode!=IMOD &&
					instruction->instruction_icode!=IREM
# ifndef ARM
					&& instruction->instruction_icode!=IROTL_S
					&& instruction->instruction_icode!=IROTR_S
# endif
					)
					internal_error_in_function ("optimize_stack_access");
				/* only first argument of mod might be register indirect */
				/* no break ! */
			case 1:
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					if (instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER){
						optimize_b_stack_access (&instruction->instruction_parameters[0],instruction);
# ifdef ARM
						previous_b_stack_parameter=&instruction->instruction_parameters[0];
						previous_b_stack_parameter_icode=instruction->instruction_icode;
					} else if (instruction->instruction_parameters[0].parameter_data.reg.r==A_STACK_POINTER){
#  if defined (G_A64) || defined (THUMB)
						int new_a_offset;
#  endif
						previous_a_stack_parameter=&instruction->instruction_parameters[0];
						previous_a_stack_parameter_icode=instruction->instruction_icode;
#  if defined (G_A64) || defined (THUMB)
						new_a_offset = (instruction->instruction_parameters[0].parameter_offset -= a_offset);
						if (new_a_offset<smallest_a_offset){
#   ifdef THUMB
							if (new_a_offset < -255){
								if (new_a_offset - smallest_a_offset >= -255){
#   else
							if (new_a_offset < -256){
								if (new_a_offset - smallest_a_offset >= -256){
#   endif
									adjust_a_stack_pointer_in_previous_instructions (instruction,smallest_a_offset);
									a_offset+=smallest_a_offset;
									new_a_offset-=smallest_a_offset;
								} else {
									insert_decrement_a_stack_pointer (instruction,-new_a_offset);
									a_offset+=new_a_offset;
									new_a_offset=0;
								}
								instruction->instruction_parameters[0].parameter_offset = new_a_offset;
							}
							smallest_a_offset=new_a_offset;
						}
#  endif
# endif
					}
				}
				break;
			case 2:
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
					instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER)
				{
					if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
						instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER)
					{
						optimize_b_stack_access2 (instruction);
# ifdef ARM
						previous_b_stack_parameter=&instruction->instruction_parameters[1];
						previous_b_stack_parameter_icode=instruction->instruction_icode;
# endif
					} else {
						optimize_b_stack_access (&instruction->instruction_parameters[0],instruction);
# ifdef ARM
						previous_b_stack_parameter=&instruction->instruction_parameters[0];
						previous_b_stack_parameter_icode=instruction->instruction_icode;
# endif
					}
				} else if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
						   instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER)
				{
					optimize_b_stack_access (&instruction->instruction_parameters[1],instruction);
# ifdef ARM
					previous_b_stack_parameter=&instruction->instruction_parameters[1];
					previous_b_stack_parameter_icode=instruction->instruction_icode;
# endif
				}
# ifdef ARM
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
					instruction->instruction_parameters[1].parameter_data.reg.r==A_STACK_POINTER)
				{
#  if defined (G_A64) || defined (THUMB)
					int new_a_offset;
#  endif
					previous_a_stack_parameter=&instruction->instruction_parameters[1];
					previous_a_stack_parameter_icode=instruction->instruction_icode;
#  if defined (G_A64) || defined (THUMB)
					new_a_offset = (instruction->instruction_parameters[1].parameter_offset -= a_offset);
					if (new_a_offset<smallest_a_offset){
#   ifdef THUMB
						if (new_a_offset < -255){
							if (new_a_offset - smallest_a_offset >= -255){
#   else
						if (new_a_offset < -256){
							if (new_a_offset - smallest_a_offset >= -256){
#   endif
								adjust_a_stack_pointer_in_previous_instructions (instruction,smallest_a_offset);
								a_offset+=smallest_a_offset;
								new_a_offset-=smallest_a_offset;
							} else {
								insert_decrement_a_stack_pointer (instruction,-new_a_offset);
								a_offset+=new_a_offset;
								new_a_offset=0;
							}
							instruction->instruction_parameters[1].parameter_offset = new_a_offset;
						}
						smallest_a_offset=new_a_offset;
					}

					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
						instruction->instruction_parameters[0].parameter_data.reg.r==A_STACK_POINTER)
					{
						internal_error_in_function ("optimize_stack_access");
					}
#  endif
				} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
						   instruction->instruction_parameters[0].parameter_data.reg.r==A_STACK_POINTER)
				{
#  if defined (G_A64) || defined (THUMB)
					int new_a_offset;
#  endif
					previous_a_stack_parameter=&instruction->instruction_parameters[0];
					previous_a_stack_parameter_icode=instruction->instruction_icode;
#  if defined (G_A64) || defined (THUMB)
					new_a_offset = (instruction->instruction_parameters[0].parameter_offset -= a_offset);
					if (new_a_offset<smallest_a_offset){
#   ifdef THUMB
						if (new_a_offset < -255){
							if (new_a_offset - smallest_a_offset >= -255){
#   else
						if (new_a_offset < -256){
							if (new_a_offset - smallest_a_offset >= -256){
#   endif
								adjust_a_stack_pointer_in_previous_instructions (instruction,smallest_a_offset);
								a_offset+=smallest_a_offset;
								new_a_offset-=smallest_a_offset;
							} else {
								insert_decrement_a_stack_pointer (instruction,-new_a_offset);
								a_offset+=new_a_offset;
								new_a_offset=0;
							}
							instruction->instruction_parameters[0].parameter_offset = new_a_offset;
						}
						smallest_a_offset=new_a_offset;
					}
#  endif
				}
# endif
		}
	}
# endif

# ifdef ARM
#  if defined (G_A64) || defined (THUMB)
	*a_offset_p-=a_offset;
#  endif
	{
		int offset;
		
		offset=*b_offset_p-b_offset;
		if (previous_b_stack_parameter!=NULL && offset!=0 && is_int_instruction (previous_b_stack_parameter_icode)){
			if (previous_b_stack_parameter->parameter_type==P_INDIRECT && try_adjust_b_stack_pointer
#  if defined (G_A64)
				&& offset>=-256 && offset<256
#  endif
			){
				if (previous_b_stack_parameter->parameter_offset==0){
					if (offset==STACK_ELEMENT_SIZE){
						previous_b_stack_parameter->parameter_type=P_POST_INCREMENT;
					} else {
						previous_b_stack_parameter->parameter_type=P_INDIRECT_POST_ADD;
						previous_b_stack_parameter->parameter_offset=offset;
					}
					b_offset = *b_offset_p;
				} else if (previous_b_stack_parameter->parameter_offset==offset){
					previous_b_stack_parameter->parameter_type=P_INDIRECT_WITH_UPDATE;
					b_offset = *b_offset_p;
				}
			} else if (previous_b_stack_parameter->parameter_type==P_POST_INCREMENT
#  if defined (G_A64)
				&& STACK_ELEMENT_SIZE+offset>=-256 && STACK_ELEMENT_SIZE+offset<256
#  endif
			){
				previous_b_stack_parameter->parameter_type=P_INDIRECT_POST_ADD;
				previous_b_stack_parameter->parameter_offset=STACK_ELEMENT_SIZE+offset;				
				b_offset = *b_offset_p;
			}
		}

		if (previous_a_stack_parameter!=NULL && *a_offset_p!=0 &&
#  ifdef G_A64
			*a_offset_p>=-256 && *a_offset_p<256 &&
#  endif
#  ifdef THUMB
			*a_offset_p>=-255 && *a_offset_p<256 &&
#  endif
			is_int_instruction (previous_a_stack_parameter_icode))
		{
			if (previous_a_stack_parameter->parameter_type==P_INDIRECT){
				if (previous_a_stack_parameter->parameter_offset==0){
					previous_a_stack_parameter->parameter_type=P_INDIRECT_POST_ADD;
					previous_a_stack_parameter->parameter_offset=*a_offset_p;
					*a_offset_p=0;
				} else if (previous_a_stack_parameter->parameter_offset==*a_offset_p){
					previous_a_stack_parameter->parameter_type=P_INDIRECT_WITH_UPDATE;
					*a_offset_p = 0;
				}
			}
		}
	}
# endif

# ifdef OLDI486
	for_l (instruction,block->block_instructions,instruction_next){
		if (instruction->instruction_icode==IMOVE){
			if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&	
				instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER &&
				instruction->instruction_parameters[0].parameter_offset==b_offset &&
				b_offset+STACK_ELEMENT_SIZE<=((WORD)instruction->instruction_parameters[0].parameter_data.reg.u)
			){
				instruction->instruction_parameters[0].parameter_type=P_POST_INCREMENT;

				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
					instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER
				){
					instruction->instruction_parameters[1].parameter_offset-=b_offset;
				}
				b_offset+=STACK_ELEMENT_SIZE;
				continue;
			}
			if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
				instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER &&
				instruction->instruction_parameters[1].parameter_offset==b_offset-STACK_ELEMENT_SIZE
			){
				instruction->instruction_parameters[1].parameter_type=P_PRE_DECREMENT;

				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
					instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER
				){
					instruction->instruction_parameters[0].parameter_offset-=b_offset;
				}
				b_offset-=STACK_ELEMENT_SIZE;
				continue;				
			}
		}
			
		switch (instruction->instruction_arity){
			default:
				if (instruction->instruction_icode!=IREM)
					internal_error_in_function ("optimize_stack_access");
					/* only first argument of movem or mod might be register indirect */
					/* no break ! */
			case 1:
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&	
					instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER
				){
					instruction->instruction_parameters[0].parameter_offset-=b_offset;
				}
				break;
			case 2:
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
					instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER
				){
					instruction->instruction_parameters[0].parameter_offset-=b_offset;
				}
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
					instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER
				){
					instruction->instruction_parameters[1].parameter_offset-=b_offset;
				}
		}
	}
# endif

	*b_offset_p-=b_offset;
}
#endif

#ifdef G_POWER

# ifdef POWER_PC_A_STACK_OPTIMIZE
void optimize_stack_access (struct basic_block *block,int *a_offset_p,int *b_offset_p)
{
	struct instruction *instruction;
	int a_offset;
	
	a_offset=*a_offset_p;

	if (a_offset==0)
		return;

	for_l (instruction,block->block_instructions,instruction_next){
		if (instruction->instruction_icode==IMOVE){
			if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&			
				instruction->instruction_parameters[0].parameter_data.reg.r==A_STACK_POINTER &&
				instruction->instruction_parameters[0].parameter_offset==a_offset)
			{
				instruction->instruction_parameters[0].parameter_type=P_INDIRECT_WITH_UPDATE;
								
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
					instruction->instruction_parameters[1].parameter_data.reg.r==A_STACK_POINTER)
				{
					instruction->instruction_parameters[1].parameter_offset -= a_offset;
				}				
				break;
			}
			if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
				instruction->instruction_parameters[1].parameter_data.reg.r==A_STACK_POINTER &&
				instruction->instruction_parameters[1].parameter_offset==a_offset)
			{
				instruction->instruction_parameters[1].parameter_type=P_INDIRECT_WITH_UPDATE;
				break;
			}
		}
	}

	if (instruction!=NULL){
		while ((instruction=instruction->instruction_next)!=NULL){
			switch (instruction->instruction_arity){
				default:
					break;
				case 1:
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT && 
						instruction->instruction_parameters[0].parameter_data.reg.r==A_STACK_POINTER)
					{
						instruction->instruction_parameters[0].parameter_offset -= a_offset;
					}
					break;
				case 2:
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
						instruction->instruction_parameters[0].parameter_data.reg.r==A_STACK_POINTER)
					{
						instruction->instruction_parameters[0].parameter_offset -= a_offset;
					}
					if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
						instruction->instruction_parameters[1].parameter_data.reg.r==A_STACK_POINTER)
					{
						instruction->instruction_parameters[1].parameter_offset -= a_offset;
					}
					break;
			}
		}
	
		*a_offset_p=0;
	}
}
# endif

extern struct instruction *last_heap_pointer_update;

void optimize_heap_pointer_increment (struct basic_block *block,int offset_from_heap_register)
{
	struct instruction *instruction;

	instruction=last_heap_pointer_update;

	if (instruction!=NULL && instruction->instruction_icode==IMOVE
		&& instruction->instruction_parameters[1].parameter_type==P_INDIRECT_HP
		&& instruction->instruction_parameters[1].parameter_data.i==offset_from_heap_register)
	{
		instruction->instruction_parameters[1].parameter_type=P_INDIRECT_WITH_UPDATE;
		instruction->instruction_parameters[1].parameter_data.reg.r=HEAP_POINTER;
		instruction->instruction_parameters[1].parameter_offset=offset_from_heap_register;
	} else {
		if (instruction!=NULL){
			instruction=instruction->instruction_next;
		} else
			instruction=block->block_instructions;

		for (; instruction!=NULL; instruction=instruction->instruction_next){
			switch (instruction->instruction_icode){
				case IADD:
					if (instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
						instruction->instruction_parameters[1].parameter_data.reg.r==HEAP_POINTER)
					{
						internal_error_in_function ("optimize_heap_pointer_increment");
					}
					continue;
				case ILEA:
					/* can be optimized, not yet implemented
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
						instruction->instruction_parameters[0].parameter_data.reg.r==HEAP_POINTER &&
						instruction->instruction_parameters[0].parameter_offset==offset_from_heap_register)
					{
						break;
					}
					*/	
					continue;
				case IMOVE:
					if (instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
						instruction->instruction_parameters[0].parameter_data.reg.r==HEAP_POINTER)
					{
						if (instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
							instruction->instruction_parameters[1].parameter_data.reg.r!=HEAP_POINTER)
						{
						} else {
							internal_error_in_function ("optimize_heap_pointer_increment");
						}
					} else {
						if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
							instruction->instruction_parameters[1].parameter_data.reg.r==HEAP_POINTER)
						{
							if (instruction->instruction_parameters[1].parameter_offset==offset_from_heap_register){
								instruction->instruction_parameters[1].parameter_type=P_INDIRECT_WITH_UPDATE;
								break;
							}
						} else if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE
								|| instruction->instruction_parameters[1].parameter_type==P_INDIRECT_HP){
							internal_error_in_function ("optimize_heap_pointer_increment");
						}
					}
					continue;
				case IFMOVE:
					/* can be optimized, not yet implemented
					if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
						instruction->instruction_parameters[1].parameter_data.reg.r==HEAP_POINTER &&
						instruction->instruction_parameters[1].parameter_offset==offset_from_heap_register)
					{
						break;
					}
					*/
					continue;
				default:
					continue;
			}
			break;
		}
	}

	if (instruction!=NULL){
		while ((instruction=instruction->instruction_next)!=NULL){
			switch (instruction->instruction_icode){
				case IADD:
					if (instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
						instruction->instruction_parameters[1].parameter_data.reg.r==HEAP_POINTER)
					{
						internal_error_in_function ("optimize_heap_pointer_increment");
					}
					break;
				case ILEA:
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
						instruction->instruction_parameters[0].parameter_data.reg.r==HEAP_POINTER)
					{
						instruction->instruction_parameters[0].parameter_offset -= offset_from_heap_register;
					}	
					break;
				case IMOVE:
					if (instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
						instruction->instruction_parameters[0].parameter_data.reg.r==HEAP_POINTER)
					{
						if (instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
							instruction->instruction_parameters[1].parameter_data.reg.r!=HEAP_POINTER)
						{
							instruction->instruction_icode=ILEA;
							instruction->instruction_parameters[0].parameter_type=P_INDIRECT;
							instruction->instruction_parameters[0].parameter_offset = -offset_from_heap_register;
						} else {
							internal_error_in_function ("optimize_heap_pointer_increment");
						}
					} else {
						if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
							instruction->instruction_parameters[1].parameter_data.reg.r==HEAP_POINTER)
						{
							instruction->instruction_parameters[1].parameter_offset -= offset_from_heap_register;
						} else if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE
								|| instruction->instruction_parameters[1].parameter_type==P_INDIRECT_HP){
							internal_error_in_function ("optimize_heap_pointer_increment");
						}
					}
					break;
				case IFMOVE:
					if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
						instruction->instruction_parameters[1].parameter_data.reg.r==HEAP_POINTER)
					{
						instruction->instruction_parameters[1].parameter_offset -= offset_from_heap_register;
					}
			}
		}
	} else
		i_add_i_r (offset_from_heap_register,HEAP_POINTER);

	last_heap_pointer_update=NULL;
}
#endif

struct register_use {
	int instruction_n;
	int value_used;
	int offset;
	int reg;
};

struct register_allocation {
	int instruction_n;
	int value_used;
	int reg;
	int altered;
};

#ifdef NEW_R_ALLOC
struct register_use *r_reg_uses;
#else
struct register_use *a_reg_uses,*d_reg_uses;
#endif
struct register_use *f_reg_uses;

#ifdef NEW_R_ALLOC
#define N_REAL_REGISTERS (N_REAL_A_REGISTERS+8)
struct register_allocation r_reg_alloc[N_REAL_REGISTERS];
#else
struct register_allocation a_reg_alloc[8],d_reg_alloc[8];
#endif

#if defined (NEW_R_ALLOC) && (defined (sparc) || defined (G_POWER) || defined (G_AI64))
# define F_REG_15
#endif

#ifdef F_REG_15
	struct register_allocation f_reg_alloc[15];
#else
	struct register_allocation f_reg_alloc[8];
#endif

static void initialize_register_uses (struct register_use *reg_uses,int highest_register,unsigned end_registers)
{
	int n;
	struct register_use *reg_use;
	
	for (n=0,reg_use=reg_uses; n<highest_register; ++n,++reg_use){
		reg_use->instruction_n=0;
		reg_use->value_used=0;
		reg_use->reg=-1;
		reg_use->offset=0;
	}
		
	for (n=0; n<8; ++n)
		if (end_registers & ((unsigned)1<<n)){
			reg_uses[n].instruction_n=1;
			reg_uses[n].value_used=1;
		}
}

#ifdef NEW_R_ALLOC
static void initialize_a_register_uses (struct register_use *reg_uses,int highest_register,unsigned end_registers)
{
	int n;
	struct register_use *reg_use;
		
	for (n=0,reg_use=reg_uses; --reg_use,n<highest_register; ++n){
		reg_use->instruction_n=0;
		reg_use->value_used=0;
		reg_use->reg=-1;
		reg_use->offset=0;
	}
	
	for (n=0; n<N_REAL_A_REGISTERS; ++n)
		if (end_registers & ((unsigned)1<<n)){
			reg_uses[-(n+1)].instruction_n=1;
			reg_uses[-(n+1)].value_used=1;
		}
}
#endif

unsigned int end_a_registers,end_d_registers,end_f_registers;

static int instruction_number;

static void use_parameter (struct parameter *parameter)
{
	struct register_use *r_use_p;
	int reg;
	
	switch (parameter->parameter_type){
		case P_REGISTER:
		case P_INDIRECT:
#if defined (M68000) || defined (I486) || defined (ARM)
		case P_POST_INCREMENT:
		case P_PRE_DECREMENT:
#endif
			reg=parameter->parameter_data.reg.r;

#ifdef MORE_PARAMETER_REGISTERS
			if ((unsigned)(num_to_d_reg (reg)-N_DATA_PARAMETER_REGISTERS)<(unsigned)N_ADDRESS_PARAMETER_REGISTERS){
				reg = a_reg_num ((N_ADDRESS_PARAMETER_REGISTERS-1)-(num_to_d_reg (reg)-N_DATA_PARAMETER_REGISTERS));
				parameter->parameter_data.reg.r = reg;
			}
#endif

#ifdef NEW_R_ALLOC
			r_use_p=&r_reg_uses[reg];
#else
			if (is_d_register (reg))
				r_use_p=&d_reg_uses[d_reg_num (reg)];
			else 
				r_use_p=&a_reg_uses[a_reg_num (reg)];
#endif
			parameter->parameter_data.reg.u=(r_use_p->instruction_n<<1)+(r_use_p->value_used & 1);
			r_use_p->instruction_n=instruction_number;
			r_use_p->value_used=1;
			break;
		case P_F_REGISTER:
			reg=parameter->parameter_data.reg.r;
	
			r_use_p=&f_reg_uses[reg];
	
			parameter->parameter_data.reg.u=(r_use_p->instruction_n<<1)+(r_use_p->value_used & 1);
			r_use_p->instruction_n=instruction_number;
			r_use_p->value_used=1;
			break;
		case P_INDEXED:
		{
			struct index_registers *index_registers;
			
			index_registers=parameter->parameter_data.ir;

#ifdef MORE_PARAMETER_REGISTERS
			if ((unsigned)(num_to_d_reg (index_registers->a_reg.r)-N_DATA_PARAMETER_REGISTERS)<(unsigned)N_ADDRESS_PARAMETER_REGISTERS)
				index_registers->a_reg.r = a_reg_num ((N_ADDRESS_PARAMETER_REGISTERS-1)-(num_to_d_reg (index_registers->a_reg.r)-N_DATA_PARAMETER_REGISTERS));

			if ((unsigned)(num_to_d_reg (index_registers->d_reg.r)-N_DATA_PARAMETER_REGISTERS)<(unsigned)N_ADDRESS_PARAMETER_REGISTERS)
				index_registers->d_reg.r = a_reg_num ((N_ADDRESS_PARAMETER_REGISTERS-1)-(num_to_d_reg (index_registers->d_reg.r)-N_DATA_PARAMETER_REGISTERS));
#endif

#ifdef NEW_R_ALLOC
			r_use_p=&r_reg_uses[index_registers->a_reg.r];
#else
			r_use_p=&a_reg_uses[a_reg_num (index_registers->a_reg.r)];
#endif
			index_registers->a_reg.u=(r_use_p->instruction_n<<1)+(r_use_p->value_used & 1);
			r_use_p->instruction_n=instruction_number;
			r_use_p->value_used=1;

#ifdef NEW_R_ALLOC
			r_use_p=&r_reg_uses[index_registers->d_reg.r];
#else
			r_use_p=&d_reg_uses[d_reg_num (index_registers->d_reg.r)];
#endif
			index_registers->d_reg.u=(r_use_p->instruction_n<<1)+(r_use_p->value_used & 1);
			r_use_p->instruction_n=instruction_number;
			r_use_p->value_used=1;
		}
	}
}

static void define_parameter (struct parameter *parameter)
{
	struct register_use *r_use_p;
	int reg,reg_num;
	
	switch (parameter->parameter_type){
		case P_REGISTER:
			reg=parameter->parameter_data.reg.r;

#ifdef MORE_PARAMETER_REGISTERS
			if ((unsigned)(num_to_d_reg (reg)-N_DATA_PARAMETER_REGISTERS)<(unsigned)N_ADDRESS_PARAMETER_REGISTERS){
				reg = a_reg_num ((N_ADDRESS_PARAMETER_REGISTERS-1)-(num_to_d_reg (reg)-N_DATA_PARAMETER_REGISTERS));
				parameter->parameter_data.reg.r = reg;
			}
#endif

#ifdef NEW_R_ALLOC
			reg_num=reg;
			r_use_p=&r_reg_uses[reg_num];			
#else
			if (is_d_register (reg)){
				reg_num=d_reg_num (reg);
				r_use_p=&d_reg_uses[reg_num];
			} else {
				reg_num=a_reg_num (reg);
				r_use_p=&a_reg_uses[reg_num];
			}
#endif
			parameter->parameter_data.reg.u=(r_use_p->instruction_n<<1)+(r_use_p->value_used & 1);
#ifdef NEW_R_ALLOC
			if ((unsigned)(reg_num+N_REAL_A_REGISTERS)<(unsigned)N_REAL_REGISTERS)
#else
			if (reg_num<8)
#endif
				r_use_p->instruction_n=instruction_number;
			else
				r_use_p->instruction_n=0;
			r_use_p->value_used=0;
			break;
		case P_INDIRECT:
#if defined (M68000) || defined (I486) || defined (ARM)
		case P_POST_INCREMENT:
		case P_PRE_DECREMENT:
#endif
			reg=parameter->parameter_data.reg.r;

#ifdef MORE_PARAMETER_REGISTERS
			if ((unsigned)(num_to_d_reg (reg)-N_DATA_PARAMETER_REGISTERS)<(unsigned)N_ADDRESS_PARAMETER_REGISTERS){
				reg = a_reg_num ((N_ADDRESS_PARAMETER_REGISTERS-1)-(num_to_d_reg (reg)-N_DATA_PARAMETER_REGISTERS));
				parameter->parameter_data.reg.r = reg;
			}
#endif

#ifdef NEW_R_ALLOC
			r_use_p=&r_reg_uses[reg];
#else
			if (is_d_register (reg))
				r_use_p=&d_reg_uses[d_reg_num (reg)];
			else 
				r_use_p=&a_reg_uses[a_reg_num (reg)];
#endif
			parameter->parameter_data.reg.u=(r_use_p->instruction_n<<1)+(r_use_p->value_used & 1);
			r_use_p->instruction_n=instruction_number;
			r_use_p->value_used=1;
			break;
		case P_F_REGISTER:
			reg_num=parameter->parameter_data.reg.r;
			
			r_use_p=&f_reg_uses[reg_num];
	
			parameter->parameter_data.reg.u=(r_use_p->instruction_n<<1)+(r_use_p->value_used & 1);
			if (reg_num<8)
				r_use_p->instruction_n=instruction_number;
			else
				r_use_p->instruction_n=0;
			r_use_p->value_used=0;
			break;
		case P_INDEXED:
		{
			struct index_registers *index_registers;
			
			index_registers=parameter->parameter_data.ir;

#ifdef MORE_PARAMETER_REGISTERS
			if ((unsigned)(num_to_d_reg (index_registers->a_reg.r)-N_DATA_PARAMETER_REGISTERS)<(unsigned)N_ADDRESS_PARAMETER_REGISTERS)
				index_registers->a_reg.r = a_reg_num ((N_ADDRESS_PARAMETER_REGISTERS-1)-(num_to_d_reg (index_registers->a_reg.r)-N_DATA_PARAMETER_REGISTERS));

			if ((unsigned)(num_to_d_reg (index_registers->d_reg.r)-N_DATA_PARAMETER_REGISTERS)<(unsigned)N_ADDRESS_PARAMETER_REGISTERS)
				index_registers->d_reg.r = a_reg_num ((N_ADDRESS_PARAMETER_REGISTERS-1)-(num_to_d_reg (index_registers->d_reg.r)-N_DATA_PARAMETER_REGISTERS));
#endif

#ifdef NEW_R_ALLOC
			r_use_p=&r_reg_uses[index_registers->a_reg.r];
#else
			r_use_p=&a_reg_uses[a_reg_num (index_registers->a_reg.r)];
#endif
			index_registers->a_reg.u=(r_use_p->instruction_n<<1)+(r_use_p->value_used & 1);
			r_use_p->instruction_n=instruction_number;
			r_use_p->value_used=1;
#ifdef NEW_R_ALLOC
			r_use_p=&r_reg_uses[index_registers->d_reg.r];
#else
			r_use_p=&d_reg_uses[d_reg_num (index_registers->d_reg.r)];
#endif
			index_registers->d_reg.u=(r_use_p->instruction_n<<1)+(r_use_p->value_used & 1);
			r_use_p->instruction_n=instruction_number;
			r_use_p->value_used=1;
		}
	}
}

#ifdef I486_USE_SCRATCH_REGISTER
struct scratch_register_next_uses {
	unsigned int scratch_register_u;
	struct scratch_register_next_uses *scratch_register_next;
};

static struct scratch_register_next_uses *scratch_register_next_uses,*scratch_register_free_list=NULL;

static int allocate_scratch_register=1;

static void define_scratch_register (void)
{
	struct register_use *r_use_p;
	struct scratch_register_next_uses *scratch_register_next_use;
	
	if (scratch_register_free_list!=NULL){
		scratch_register_next_use=scratch_register_free_list;
		scratch_register_free_list=scratch_register_next_use->scratch_register_next;
	} else
		scratch_register_next_use=(struct scratch_register_next_uses*)fast_memory_allocate (sizeof (struct scratch_register_next_uses));

	scratch_register_next_use->scratch_register_next=scratch_register_next_uses;	
	scratch_register_next_uses=scratch_register_next_use;

	r_use_p=&r_reg_uses[-3];

	scratch_register_next_use->scratch_register_u=(r_use_p->instruction_n<<1)+(r_use_p->value_used & 1);

	r_use_p->instruction_n=instruction_number;
	r_use_p->value_used=0;
}
#endif

static void store_next_uses (struct instruction *instruction)
{
	instruction_number=2;
	while (instruction!=NULL){
		switch (instruction->instruction_icode){
			case IADD:	case IAND:
#ifndef I486_USE_SCRATCH_REGISTER
			case IASR:	case ILSL:	case ILSR:
			case IDIV:
# if defined (I486) || defined (ARM)
#  ifndef ARM
			case IROTL:
#  endif
			case IROTR:
# endif
#endif
#if (defined (I486) && !defined (I486_USE_SCRATCH_REGISTER)) || (defined (ARM) && !defined (G_A64))
			case IMULUD:
#endif
#if ((defined (I486) || defined (ARM)) && !defined (I486_USE_SCRATCH_REGISTER)) || defined (G_POWER)
			case IDIVU:
#endif
			case IEOR:	case IFADD:	
			case IFCMP:	case IFDIV:	case IFMUL:	case IFREM:	case IFSUB:
			case IMUL:	case IOR:	case ISUB:	case ICMP:
#ifdef I486
			case ITST:
#endif
#ifndef ARM
			case IEXG:
#endif
IF_G_POWER (case ICMPLW:)
#if defined (sparc) || defined (ARM)
			case IADDO:	case ISUBO:
#endif
#if defined (I486) && defined (FP_STACK_OPTIMIZATIONS)
			case IFEXG:
#endif
#if defined (G_POWER) || (defined (ARM) && defined (G_A64))
			case IUMULH:
#endif
#if defined (I486) || defined (ARM)
			case IADC:	case ISBB:
#endif
#ifdef M68000
			case ICMPW:
#endif
				use_parameter (&instruction->instruction_parameters[1]);
				use_parameter (&instruction->instruction_parameters[0]);
				break;
#ifdef I486_USE_SCRATCH_REGISTER
			case IASR:	case ILSL:	case ILSR:	case IROTR:
# ifndef ARM
			case IROTL:
# endif
				if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE)
					define_scratch_register();
				use_parameter (&instruction->instruction_parameters[1]);
				use_parameter (&instruction->instruction_parameters[0]);
				break;
			case IDIV:	case IREM:	case IDIVU:	case IREMU: case IMULUD:
# ifdef THREAD32
				use_parameter (&instruction->instruction_parameters[1]);
				use_parameter (&instruction->instruction_parameters[0]);
				define_parameter (&instruction->instruction_parameters[2]);
# else
				define_scratch_register();
				use_parameter (&instruction->instruction_parameters[1]);
				use_parameter (&instruction->instruction_parameters[0]);
# endif
				break;
			case IMOVE:
				if ((instruction->instruction_parameters[0].parameter_type==P_INDIRECT ||
					 instruction->instruction_parameters[0].parameter_type==P_INDEXED) &&
					(instruction->instruction_parameters[1].parameter_type==P_INDIRECT ||
					 instruction->instruction_parameters[1].parameter_type==P_INDEXED))
					define_scratch_register();
				define_parameter (&instruction->instruction_parameters[1]);
				use_parameter (&instruction->instruction_parameters[0]);
				break;
#endif
#if defined (I486) || defined (ARM)
			case IDIVI:		case IREMI:
# if defined (I486_USE_SCRATCH_REGISTER) && !defined (THREAD32)
				define_scratch_register();
# endif
				use_parameter (&instruction->instruction_parameters[1]);
				define_parameter (&instruction->instruction_parameters[2]);
# ifdef THREAD32
				define_parameter (&instruction->instruction_parameters[3]);
# endif
				break;
#endif
			case IFMOVE:	case IFMOVEL:	case ILEA:		
#ifndef I486_USE_SCRATCH_REGISTER
			case IMOVE:
#endif
			case IMOVEB:	case IMOVEDB:
#ifdef G_A64
			case IMOVEQB:
#endif
#ifndef ARM
			case IFCOS:		case IFSIN:
#endif
			case IFTAN:
#ifdef M68000
			case IFACOS:	case IFASIN:	case IFATAN:	case IFEXP:		case IFLN:		case IFLOG10:
#endif
			case IFNEG:
#if !defined (G_POWER)
			case IFSQRT:
#endif
			case IFABS:
IF_G_SPARC (case IFMOVEHI:	case IFMOVELO:)
IF_G_RISC (case IADDI: case ILSLI:)
#ifdef G_A64
			case ILOADSQB:
#endif
#ifdef G_AI64
			case IFCVT2S:
#endif
#if defined (I486) || defined (ARM)
			case IFLOADS:	case IFMOVES:
#endif
#if defined (I486) && !defined (G_A64)
			case IFSINCOS:
#endif
				define_parameter (&instruction->instruction_parameters[1]);
				use_parameter (&instruction->instruction_parameters[0]);
				break;
			case IFTST:
#ifndef I486
			case ITST:
#endif
			case IEXT:
#if defined (M68000) || defined (G_POWER)
			case IEXTB:
#endif
			case INEG:
#if defined (I486) || defined (ARM) || defined (G_POWER)
			case INOT:
#endif
			/* case IJMP:	case IJSR: */
				use_parameter (&instruction->instruction_parameters[0]);
				break;
			case ISEQ:	case ISGE:	case ISGT:	case ISLE:	case ISLT:	case ISNE:
			case ISO:	case ISGEU:	case ISGTU:	case ISLEU:	case ISLTU:	case ISNO:
			case IFSEQ:	case IFSGE:	case IFSGT:	case IFSLE:	case IFSLT:	case IFSNE:
#if defined (I486) && !defined (G_A64)
			case IFCEQ:	case IFCGE:	case IFCGT:	case IFCLE:	case IFCLT:	case IFCNE:
#endif
				define_parameter (&instruction->instruction_parameters[0]);
				break;
#ifndef I486_USE_SCRATCH_REGISTER
			case IREM:
# if defined (I486) || defined (ARM) || defined (G_POWER)
				use_parameter (&instruction->instruction_parameters[1]);
#  if defined (I486) || defined (ARM)
			case IREMU:
#  endif
				use_parameter (&instruction->instruction_parameters[0]);
				break;
# else
				define_parameter (&instruction->instruction_parameters[1]);
				use_parameter (&instruction->instruction_parameters[2]);
				use_parameter (&instruction->instruction_parameters[0]);
				break;
# endif
#endif
#ifdef I486
			case IASR_S: case ILSL_S: case ILSR_S: case IROTL_S: case IROTR_S:
				define_parameter (&instruction->instruction_parameters[2]);
				use_parameter (&instruction->instruction_parameters[1]);
				use_parameter (&instruction->instruction_parameters[0]);
				break;
#endif
#ifdef M68000
			case IMOVEM:
			{
				int n=instruction->instruction_arity;
				while (n>1){
					--n;
					define_parameter (&instruction->instruction_parameters[n]);
				}
				use_parameter (&instruction->instruction_parameters[0]);
				break;
			}
			case IBMOVE:
				use_parameter (&instruction->instruction_parameters[2]);
				use_parameter (&instruction->instruction_parameters[1]);
				use_parameter (&instruction->instruction_parameters[0]);
				break;
#endif
#ifdef I486
			case IDIVDU:
# if defined (I486_USE_SCRATCH_REGISTER) && !defined (THREAD32)
				define_scratch_register();
# endif
				use_parameter (&instruction->instruction_parameters[2]);
				use_parameter (&instruction->instruction_parameters[1]);
				use_parameter (&instruction->instruction_parameters[0]);
				break;
#endif
#if defined (I486) || defined (ARM)
			case IFLOORDIV: case IMOD:
				define_parameter (&instruction->instruction_parameters[2]);
				use_parameter (&instruction->instruction_parameters[1]);
				if (instruction->instruction_arity==4)
					define_parameter (&instruction->instruction_parameters[0]);					
				else
					use_parameter (&instruction->instruction_parameters[0]);
				break;
#endif
#if defined (I486) || defined (ARM)
			case ICLZB:
				define_parameter (&instruction->instruction_parameters[1]);
				use_parameter (&instruction->instruction_parameters[0]);
				break;
#endif
#if 0
			case IFBEQ:	case IFBGE: case IFBGT:	case IFBLE:	case IFBLT:	case IFBNE:
				define_scratch_register();
				break;
#endif
			/*
			case IRTS:
				break;
			*/
			case IBEQ:	case IBGE:	case IBGT:	case IBLE:	case IBLT:	case IBNE:
			case IBO:	case IBGEU:	case IBGTU:	case IBLEU:	case IBLTU:	case IBNO:
				break;
			default:
				internal_error_in_function ("store_next_uses");
				
		}
		instruction=instruction->instruction_prev;
		++instruction_number;
	}
}

static void initialize_register_allocation()
{
	int n;
	
	for (n=0; n<8; ++n){
#ifdef NEW_R_ALLOC
		if (r_reg_uses[n].value_used){
			r_reg_alloc[n+N_REAL_A_REGISTERS].reg=n;
			r_reg_uses[n].reg=n+N_REAL_A_REGISTERS;
			r_reg_alloc[n+N_REAL_A_REGISTERS].value_used=1;
			r_reg_alloc[n+N_REAL_A_REGISTERS].instruction_n=r_reg_uses[n].instruction_n;
		} else {
			r_reg_alloc[n+N_REAL_A_REGISTERS].reg=-32768;
			r_reg_alloc[n+N_REAL_A_REGISTERS].instruction_n=0;
		}
			
		if (r_reg_uses[-(n+1)].value_used){
			r_reg_alloc[(N_REAL_A_REGISTERS-1)-n].reg=-(n+1);
			r_reg_uses[-(n+1)].reg=(N_REAL_A_REGISTERS-1)-n;
			r_reg_alloc[(N_REAL_A_REGISTERS-1)-n].value_used=1;
			r_reg_alloc[(N_REAL_A_REGISTERS-1)-n].instruction_n=r_reg_uses[-(n+1)].instruction_n;
		} else {
			r_reg_alloc[(N_REAL_A_REGISTERS-1)-n].reg=-32768;
			r_reg_alloc[(N_REAL_A_REGISTERS-1)-n].instruction_n=0;
		}
#else
		if (a_reg_uses[n].value_used){
			a_reg_alloc[n].reg=n;
			a_reg_uses[n].reg=n;
			a_reg_alloc[n].value_used=1;
			a_reg_alloc[n].instruction_n=a_reg_uses[n].instruction_n;
		} else {
			a_reg_alloc[n].reg=-1;
			a_reg_alloc[n].instruction_n=0;
		}
			
		if (d_reg_uses[n].value_used){
			d_reg_alloc[n].reg=n;
			d_reg_uses[n].reg=n;
			d_reg_alloc[n].value_used=1;
			d_reg_alloc[n].instruction_n=d_reg_uses[n].instruction_n;
		} else {
			d_reg_alloc[n].reg=-1;
			d_reg_alloc[n].instruction_n=0;
		}
#endif
		if (f_reg_uses[n].value_used){
			f_reg_alloc[n].reg=n;
			f_reg_uses[n].reg=n;
			f_reg_alloc[n].value_used=1;
			f_reg_alloc[n].instruction_n=f_reg_uses[n].instruction_n;
		} else {
#ifdef NEW_R_ALLOC
			f_reg_alloc[n].reg=-32768;
#else
			f_reg_alloc[n].reg=-1;
#endif
			f_reg_alloc[n].instruction_n=0;
		}
	}

#ifdef NEW_R_ALLOC
	for (n=8; n<N_REAL_A_REGISTERS; ++n){
		if (r_reg_uses[-(n+1)].value_used){
			r_reg_alloc[(N_REAL_A_REGISTERS-1)-n].reg=-(n+1);
			r_reg_uses[-(n+1)].reg=(N_REAL_A_REGISTERS-1)-n;
			r_reg_alloc[(N_REAL_A_REGISTERS-1)-n].value_used=1;
			r_reg_alloc[(N_REAL_A_REGISTERS-1)-n].instruction_n=r_reg_uses[-(n+1)].instruction_n;
		} else {
			r_reg_alloc[(N_REAL_A_REGISTERS-1)-n].reg=-32768;
			r_reg_alloc[(N_REAL_A_REGISTERS-1)-n].instruction_n=0;
		}
	}
#endif

#ifdef F_REG_15
	for (n=8; n<15; ++n){
		f_reg_alloc[n].reg=-32768;
		f_reg_alloc[n].instruction_n=0;
	}
#endif
}

enum { USE, USE_DEF, DEF };

enum { A_REGISTER, D_REGISTER, F_REGISTER };

int do_not_alter_condition_codes;	/* TRUE if it is not allowed to alter condition codes */

static struct instruction *previous_instruction;
static struct basic_block *current_block;

static struct instruction *insert_instruction (int instruction_code,int arity,int arg_size)
{
	struct instruction *instruction,*next_instruction;
		
	instruction=(struct instruction*)fast_memory_allocate (sizeof (struct instruction)+arg_size);
	instruction->instruction_icode=instruction_code;
	instruction->instruction_arity=arity;

	if (previous_instruction==NULL){
		next_instruction=current_block->block_instructions;
		current_block->block_instructions=instruction;
	} else {
		next_instruction=previous_instruction->instruction_next;
		previous_instruction->instruction_next=instruction;
	}
	instruction->instruction_next=next_instruction;
	instruction->instruction_prev=previous_instruction;
	if (next_instruction!=NULL)
		next_instruction->instruction_prev=instruction;
		
	previous_instruction=instruction;
	
	return instruction;
}

#if defined (I486) && defined (FP_STACK_OPTIMIZATIONS)
# define set_float_register_parameter(p,r) (p).parameter_type=P_F_REGISTER; (p).parameter_flags=0; (p).parameter_data.i=(r)
#else
# define set_float_register_parameter(p,r) (p).parameter_type=P_F_REGISTER; (p).parameter_data.i=(r)
#endif

static void insert_load (int offset,int register_n,int register_flag)
{
	struct instruction *instruction;
	
	switch (register_flag){
		case D_REGISTER:
#ifdef M68000
			if (do_not_alter_condition_codes)
				instruction=insert_instruction (IMOVEM,2,2*sizeof (struct parameter));
			else
#endif
				instruction=insert_instruction (IMOVE,2,2*sizeof (struct parameter));
			instruction->instruction_parameters[1].parameter_type=P_REGISTER;
#ifdef NEW_R_ALLOC
			instruction->instruction_parameters[1].parameter_data.i=register_n-N_REAL_A_REGISTERS;
#else
			instruction->instruction_parameters[1].parameter_data.i=num_to_d_reg (register_n);
#endif
			break;
#ifndef NEW_R_ALLOC
		case A_REGISTER:
			instruction=insert_instruction (IMOVE,2,2*sizeof (struct parameter));
			
			instruction->instruction_parameters[1].parameter_type=P_REGISTER;
			instruction->instruction_parameters[1].parameter_data.i=num_to_a_reg (register_n);
			break;
#endif
		case F_REGISTER:
			instruction=insert_instruction (IFMOVE,2,2*sizeof (struct parameter));
			
			set_float_register_parameter (instruction->instruction_parameters[1],register_n);
			break;
		default:
			internal_error_in_function ("insert_load");
			return;
	}
	
	instruction->instruction_parameters[0].parameter_type=P_INDIRECT;
	instruction->instruction_parameters[0].parameter_offset=offset;
	instruction->instruction_parameters[0].parameter_data.i=B_STACK_POINTER;
}

static void insert_store (int register_n,int offset,int register_flag)
{
	struct instruction *instruction;

	switch (register_flag){
		case D_REGISTER:
#ifdef M68000
			if (do_not_alter_condition_codes)
				instruction=insert_instruction (IMOVEM,2,2*sizeof (struct parameter));
			else
#endif
				instruction=insert_instruction (IMOVE,2,2*sizeof (struct parameter));
	
			instruction->instruction_parameters[0].parameter_type=P_REGISTER;
#ifdef NEW_R_ALLOC
			instruction->instruction_parameters[0].parameter_data.i=register_n-N_REAL_A_REGISTERS;
#else
			instruction->instruction_parameters[0].parameter_data.i=num_to_d_reg (register_n);
#endif
			break;
#ifndef NEW_R_ALLOC
		case A_REGISTER:
# ifdef M68000
			if (do_not_alter_condition_codes)
				instruction=insert_instruction (IMOVEM,2,2*sizeof (struct parameter));
			else
# endif
				instruction=insert_instruction (IMOVE,2,2*sizeof (struct parameter));
	
			instruction->instruction_parameters[0].parameter_type=P_REGISTER;
			instruction->instruction_parameters[0].parameter_data.i=num_to_a_reg (register_n);
			break;
#endif
		case F_REGISTER:
			instruction=insert_instruction (IFMOVE,2,2*sizeof (struct parameter));
	
			set_float_register_parameter (instruction->instruction_parameters[0],register_n);
			break;
		default:
			internal_error_in_function ("insert_store");
			return;
	}
	
	instruction->instruction_parameters[1].parameter_type=P_INDIRECT;
	instruction->instruction_parameters[1].parameter_offset=offset;
	instruction->instruction_parameters[1].parameter_data.i=B_STACK_POINTER;
}

static void insert_move (int reg_n_1,int reg_n_2,int register_flag)
{
	struct instruction *instruction;
	
	switch (register_flag){
		case D_REGISTER:
#ifdef M68000
			if (do_not_alter_condition_codes)
				instruction=insert_instruction (IEXG,2,2*sizeof (struct parameter));
			else
#endif
				instruction=insert_instruction (IMOVE,2,2*sizeof (struct parameter));
			
			instruction->instruction_parameters[0].parameter_type=P_REGISTER;
			instruction->instruction_parameters[1].parameter_type=P_REGISTER;
#ifdef NEW_R_ALLOC
			instruction->instruction_parameters[0].parameter_data.i=reg_n_1-N_REAL_A_REGISTERS;
			instruction->instruction_parameters[1].parameter_data.i=reg_n_2-N_REAL_A_REGISTERS;
#else
			instruction->instruction_parameters[0].parameter_data.i=num_to_d_reg (reg_n_1);
			instruction->instruction_parameters[1].parameter_data.i=num_to_d_reg (reg_n_2);
#endif
			break;
#ifndef NEW_R_ALLOC
		case A_REGISTER:
			instruction=insert_instruction (IMOVE,2,2*sizeof (struct parameter));
			
			instruction->instruction_parameters[0].parameter_type=P_REGISTER;
			instruction->instruction_parameters[1].parameter_type=P_REGISTER;
			
			instruction->instruction_parameters[0].parameter_data.i=num_to_a_reg (reg_n_1);
			instruction->instruction_parameters[1].parameter_data.i=num_to_a_reg (reg_n_2);
			break;
#endif
		case F_REGISTER:
			instruction=insert_instruction (IFMOVE,2,2*sizeof (struct parameter));
			
			set_float_register_parameter (instruction->instruction_parameters[0],reg_n_1);			
			set_float_register_parameter (instruction->instruction_parameters[1],reg_n_2);
	}
}

#ifdef NEW_R_ALLOC
#define REAL_D0 (N_REAL_A_REGISTERS+0)
#define REAL_D1 (N_REAL_A_REGISTERS+1)
#define REAL_D2 (N_REAL_A_REGISTERS+2)
#define REAL_D3 (N_REAL_A_REGISTERS+3)
#define REAL_D4 (N_REAL_A_REGISTERS+4)
#define REAL_D5 (N_REAL_A_REGISTERS+5)
#define REAL_D6 (N_REAL_A_REGISTERS+6)
#define REAL_D7 (N_REAL_A_REGISTERS+7)
#define REAL_A0 (N_REAL_A_REGISTERS-1)
#define REAL_A1 (N_REAL_A_REGISTERS-2)
#define REAL_A2 (N_REAL_A_REGISTERS-3)
# ifndef THREAD64
#  define REAL_A3 (N_REAL_A_REGISTERS-4)
# endif
#define REAL_A4 (N_REAL_A_REGISTERS-5)
#define REAL_A5 (N_REAL_A_REGISTERS-6)
#define REAL_A6 (N_REAL_A_REGISTERS-7)
#define REAL_A7 (N_REAL_A_REGISTERS-8)
#endif

static int find_register (int reg_n,register struct register_allocation *reg_alloc,
						  int register_flag)
{
	int real_reg_n;
#ifdef NEW_R_ALLOC
	if ((unsigned)(reg_n+N_REAL_A_REGISTERS)<(unsigned)N_REAL_REGISTERS)
		if (register_flag==F_REGISTER)
			real_reg_n=reg_n;
		else
			real_reg_n=reg_n+N_REAL_A_REGISTERS;
#else
	if (reg_n<8)
		real_reg_n=reg_n;
#endif
	else {
		int i;
	
#ifdef NEW_R_ALLOC
		if (register_flag!=F_REGISTER){
			real_reg_n=REAL_D0;
			i=reg_alloc[REAL_D0].instruction_n;
			
			if (reg_alloc[REAL_D1].instruction_n<i){
				real_reg_n=REAL_D1;
				i=reg_alloc[REAL_D1].instruction_n;
			}
# ifndef I486
			if (reg_alloc[REAL_D2].instruction_n<i){
				real_reg_n=REAL_D2;
				i=reg_alloc[REAL_D2].instruction_n;
			}
			if (reg_alloc[REAL_D3].instruction_n<i){
				real_reg_n=REAL_D3;
				i=reg_alloc[REAL_D3].instruction_n;
			}
			if (reg_alloc[REAL_D4].instruction_n<i){
				real_reg_n=REAL_D4;
				i=reg_alloc[REAL_D4].instruction_n;
			}
# endif
# if ! (defined (I486) || defined (ARM))
			if (reg_alloc[REAL_D5].instruction_n<i){
				real_reg_n=REAL_D5;
				i=reg_alloc[REAL_D5].instruction_n;
			}
			if (reg_alloc[REAL_D6].instruction_n<i){
				real_reg_n=REAL_D6;
				i=reg_alloc[REAL_D6].instruction_n;
			}
			if (reg_alloc[REAL_D7].instruction_n<i){
				real_reg_n=REAL_D7;
				i=reg_alloc[REAL_D7].instruction_n;
			}
# endif
			if (reg_alloc[REAL_A0].instruction_n<i){
				real_reg_n=REAL_A0;
				i=reg_alloc[REAL_A0].instruction_n;
			}
			if (reg_alloc[REAL_A1].instruction_n<i){
				real_reg_n=REAL_A1;
				i=reg_alloc[REAL_A1].instruction_n;
			}
# if !(defined (I486) && !defined (G_AI64)) || defined (I486_USE_SCRATCH_REGISTER)
			if (reg_alloc[REAL_A2].instruction_n<i
#  if defined (I486_USE_SCRATCH_REGISTER)
				&& allocate_scratch_register
#  endif
			){
				real_reg_n=REAL_A2;
				i=reg_alloc[REAL_A2].instruction_n;
			}
# endif
# ifndef THREAD64
			if (reg_alloc[REAL_A3].instruction_n<i){
				real_reg_n=REAL_A3;
				i=reg_alloc[REAL_A3].instruction_n;
			}
# endif
# ifndef POWER_PC_A_STACK_OPTIMIZE
			if (reg_alloc[REAL_A4].instruction_n<i){
				real_reg_n=REAL_A4;
				i=reg_alloc[REAL_A4].instruction_n;
			}
# endif
# if defined (ARM) && defined (G_A64)
			if (reg_alloc[REAL_A5].instruction_n<i){
				real_reg_n=REAL_A5;
				i=reg_alloc[REAL_A5].instruction_n;
			}
# endif
# if ! (defined (I486) || (defined (ARM) && !defined (G_A64)) || defined (G_POWER))
			if (reg_alloc[REAL_A6].instruction_n<i){
				real_reg_n=REAL_A6;
				i=reg_alloc[REAL_A6].instruction_n;
			}
# endif
# if defined (ARM) && defined (G_A64)
			if (reg_alloc[REAL_A7].instruction_n<i){
				real_reg_n=REAL_A7;
				i=reg_alloc[REAL_A7].instruction_n;
			}
# endif
		} else {
			real_reg_n=0;
			i=reg_alloc[0].instruction_n;
			
			if (reg_alloc[1].instruction_n<i){
				real_reg_n=1;
				i=reg_alloc[1].instruction_n;
			}
			if (reg_alloc[2].instruction_n<i){
				real_reg_n=2;
				i=reg_alloc[2].instruction_n;
			}
			if (reg_alloc[3].instruction_n<i){
				real_reg_n=3;
				i=reg_alloc[3].instruction_n;
			}
			if (reg_alloc[4].instruction_n<i){
				real_reg_n=4;
				i=reg_alloc[4].instruction_n;
			}
			if (reg_alloc[5].instruction_n<i){
				real_reg_n=5;
				i=reg_alloc[5].instruction_n;
			}
			if (reg_alloc[6].instruction_n<i){
				real_reg_n=6;
				i=reg_alloc[6].instruction_n;
			}
# if ! ((defined (I486) || defined (ARM)) && !defined (G_AI64))
			if (reg_alloc[7].instruction_n<i){
				real_reg_n=7;
				i=reg_alloc[7].instruction_n;
			}
#  if defined (sparc) || defined (G_POWER) || defined (G_AI64)
			if (reg_alloc[8].instruction_n<i){
				real_reg_n=8;
				i=reg_alloc[8].instruction_n;
			}
			if (reg_alloc[9].instruction_n<i){
				real_reg_n=9;
				i=reg_alloc[9].instruction_n;
			}
			if (reg_alloc[10].instruction_n<i){
				real_reg_n=10;
				i=reg_alloc[10].instruction_n;
			}
			if (reg_alloc[11].instruction_n<i){
				real_reg_n=11;
				i=reg_alloc[11].instruction_n;
			}
			if (reg_alloc[12].instruction_n<i){
				real_reg_n=12;
				i=reg_alloc[12].instruction_n;
			}
			if (reg_alloc[13].instruction_n<i){
				real_reg_n=13;
				i=reg_alloc[13].instruction_n;
			}
			if (reg_alloc[14].instruction_n<i){
				real_reg_n=14;
				i=reg_alloc[14].instruction_n;
			}
#  endif
# endif
		}
#else
		real_reg_n=0;
		i=reg_alloc[real_reg_n].instruction_n;
		
		if (reg_alloc[1].instruction_n<i){
			real_reg_n=1;
			i=reg_alloc[1].instruction_n;
		}
# if defined (I486) || defined (ARM)
		if (register_flag!=D_REGISTER){
			if (register_flag==F_REGISTER)
				if (reg_alloc[2].instruction_n<i){
					real_reg_n=2;
					i=reg_alloc[2].instruction_n;
				}
			if (reg_alloc[3].instruction_n<i){
				real_reg_n=3;
				i=reg_alloc[3].instruction_n;
			}
			if (reg_alloc[4].instruction_n<i){
				real_reg_n=4;
				i=reg_alloc[4].instruction_n;
			}
			if (register_flag==F_REGISTER){
				if (reg_alloc[5].instruction_n<i){
					real_reg_n=5;
					i=reg_alloc[5].instruction_n;
				}
				if (reg_alloc[6].instruction_n<i){
					real_reg_n=6;
					i=reg_alloc[6].instruction_n;
				}
			}
		}
# else
		if (reg_alloc[2].instruction_n<i){
			real_reg_n=2;
			i=reg_alloc[2].instruction_n;
		}
		if (reg_alloc[3].instruction_n<i){
			real_reg_n=3;
			i=reg_alloc[3].instruction_n;
		}
		if (register_flag!=A_REGISTER){
			if (reg_alloc[4].instruction_n<i){
				real_reg_n=4;
				i=reg_alloc[4].instruction_n;
			}
			if (reg_alloc[5].instruction_n<i){
				real_reg_n=5;
				i=reg_alloc[5].instruction_n;
			}
		}
		if (reg_alloc[6].instruction_n<i){
			real_reg_n=6;
			i=reg_alloc[6].instruction_n;
		}
		if (register_flag!=A_REGISTER)
			if (reg_alloc[7].instruction_n<i){
				real_reg_n=7;
				i=reg_alloc[7].instruction_n;
			}
# endif
#endif
	}

	return real_reg_n;
}

static int find_non_reg_2_register (int reg_n,int avoid_reg_n,
									struct register_allocation *reg_alloc,int register_flag)
{
	int real_reg_n;

#ifdef NEW_R_ALLOC
	if ((unsigned)(reg_n+N_REAL_A_REGISTERS)<(unsigned)N_REAL_REGISTERS)
		if (register_flag==F_REGISTER)
			real_reg_n=reg_n;
		else
			real_reg_n=reg_n+N_REAL_A_REGISTERS;
#else
	if (reg_n<8)
		real_reg_n=reg_n;
#endif
	else {
		register int i;
	
		real_reg_n=-1;
		i=32767;
		
#ifdef NEW_R_ALLOC
		if (register_flag!=F_REGISTER){
			if (reg_alloc[REAL_D0].instruction_n<i && avoid_reg_n!=REAL_D0){
				real_reg_n=REAL_D0;
				i=reg_alloc[REAL_D0].instruction_n;
			}
			if (reg_alloc[REAL_D1].instruction_n<i && avoid_reg_n!=REAL_D1){
				real_reg_n=REAL_D1;
				i=reg_alloc[REAL_D1].instruction_n;
			}
# ifndef I486
			if (reg_alloc[REAL_D2].instruction_n<i && avoid_reg_n!=REAL_D2){
				real_reg_n=REAL_D2;
				i=reg_alloc[REAL_D2].instruction_n;
			}
			if (reg_alloc[REAL_D3].instruction_n<i && avoid_reg_n!=REAL_D3){
				real_reg_n=REAL_D3;
				i=reg_alloc[REAL_D3].instruction_n;
			}
			if (reg_alloc[REAL_D4].instruction_n<i && avoid_reg_n!=REAL_D4){
				real_reg_n=REAL_D4;
				i=reg_alloc[REAL_D4].instruction_n;
			}
# endif
# if ! (defined (I486) || defined (ARM))
			if (reg_alloc[REAL_D5].instruction_n<i && avoid_reg_n!=REAL_D5){
				real_reg_n=REAL_D5;
				i=reg_alloc[REAL_D5].instruction_n;
			}
			if (reg_alloc[REAL_D6].instruction_n<i && avoid_reg_n!=REAL_D6){
				real_reg_n=REAL_D6;
				i=reg_alloc[REAL_D6].instruction_n;
			}
			if (reg_alloc[REAL_D7].instruction_n<i && avoid_reg_n!=REAL_D7){
				real_reg_n=REAL_D7;
				i=reg_alloc[REAL_D7].instruction_n;
			}
# endif
			if (reg_alloc[REAL_A0].instruction_n<i && avoid_reg_n!=REAL_A0){
				real_reg_n=REAL_A0;
				i=reg_alloc[REAL_A0].instruction_n;
			}
			if (reg_alloc[REAL_A1].instruction_n<i && avoid_reg_n!=REAL_A1){
				real_reg_n=REAL_A1;
				i=reg_alloc[REAL_A1].instruction_n;
			}
# if !(defined (I486) && !defined (G_AI64)) || defined (I486_USE_SCRATCH_REGISTER)
			if (reg_alloc[REAL_A2].instruction_n<i && avoid_reg_n!=REAL_A2
#  if defined (I486_USE_SCRATCH_REGISTER)
				&& allocate_scratch_register
#  endif
			){
				real_reg_n=REAL_A2;
				i=reg_alloc[REAL_A2].instruction_n;
			}
# endif
# ifndef THREAD64
			if (reg_alloc[REAL_A3].instruction_n<i && avoid_reg_n!=REAL_A3){
				real_reg_n=REAL_A3;
				i=reg_alloc[REAL_A3].instruction_n;
			}
# endif
# ifndef POWER_PC_A_STACK_OPTIMIZE
			if (reg_alloc[REAL_A4].instruction_n<i && avoid_reg_n!=REAL_A4){
				real_reg_n=REAL_A4;
				i=reg_alloc[REAL_A4].instruction_n;
			}
# endif
# if defined (ARM) && defined (G_A64)
			if (reg_alloc[REAL_A5].instruction_n<i && avoid_reg_n!=REAL_A5){
				real_reg_n=REAL_A5;
				i=reg_alloc[REAL_A5].instruction_n;
			}
# endif
# if ! (defined (I486) || (defined (ARM) && !defined (G_A64)) || defined (G_POWER))
			if (reg_alloc[REAL_A6].instruction_n<i && avoid_reg_n!=REAL_A6){
				real_reg_n=REAL_A6;
				i=reg_alloc[REAL_A6].instruction_n;
			}
# endif
# if defined (ARM) && defined (G_A64)
			if (reg_alloc[REAL_A7].instruction_n<i && avoid_reg_n!=REAL_A7){
				real_reg_n=REAL_A7;
				i=reg_alloc[REAL_A7].instruction_n;
			}
# endif
		} else {
			if (reg_alloc[0].instruction_n<i && avoid_reg_n!=0){
				real_reg_n=0;
				i=reg_alloc[0].instruction_n;
			}
			if (reg_alloc[1].instruction_n<i && avoid_reg_n!=1){
				real_reg_n=1;
				i=reg_alloc[1].instruction_n;
			}
			if (reg_alloc[2].instruction_n<i && avoid_reg_n!=2){
				real_reg_n=2;
				i=reg_alloc[2].instruction_n;
			}
			if (reg_alloc[3].instruction_n<i && avoid_reg_n!=3){
				real_reg_n=3;
				i=reg_alloc[3].instruction_n;
			}
			if (reg_alloc[4].instruction_n<i && avoid_reg_n!=4){
				real_reg_n=4;
				i=reg_alloc[4].instruction_n;
			}
			if (reg_alloc[5].instruction_n<i && avoid_reg_n!=5){
				real_reg_n=5;
				i=reg_alloc[5].instruction_n;
			}
			if (reg_alloc[6].instruction_n<i && avoid_reg_n!=6){
				real_reg_n=6;
				i=reg_alloc[6].instruction_n;
			}
# if ! ((defined (I486) || defined (ARM)) && !defined (G_AI64))
			if (reg_alloc[7].instruction_n<i && avoid_reg_n!=7){
				real_reg_n=7;
				i=reg_alloc[7].instruction_n;
			}
#  if defined (sparc) || defined (G_POWER) || defined (G_AI64)
			if (reg_alloc[8].instruction_n<i && avoid_reg_n!=8){
				real_reg_n=8;
				i=reg_alloc[8].instruction_n;
			}
			if (reg_alloc[9].instruction_n<i && avoid_reg_n!=9){
				real_reg_n=9;
				i=reg_alloc[9].instruction_n;
			}
			if (reg_alloc[10].instruction_n<i && avoid_reg_n!=10){
				real_reg_n=10;
				i=reg_alloc[10].instruction_n;
			}
			if (reg_alloc[11].instruction_n<i && avoid_reg_n!=11){
				real_reg_n=11;
				i=reg_alloc[11].instruction_n;
			}
			if (reg_alloc[12].instruction_n<i && avoid_reg_n!=12){
				real_reg_n=12;
				i=reg_alloc[12].instruction_n;
			}
			if (reg_alloc[13].instruction_n<i && avoid_reg_n!=13){
				real_reg_n=13;
				i=reg_alloc[13].instruction_n;
			}
			if (reg_alloc[14].instruction_n<i && avoid_reg_n!=14){
				real_reg_n=14;
				i=reg_alloc[14].instruction_n;
			}
#  endif
# endif
		}
#else
		if (reg_alloc[0].instruction_n<i && avoid_reg_n!=0){
			real_reg_n=0;
			i=reg_alloc[0].instruction_n;
		}
		if (reg_alloc[1].instruction_n<i && avoid_reg_n!=1){
			real_reg_n=1;
			i=reg_alloc[1].instruction_n;
		}
# if defined (I486) || defined (ARM)
		if (register_flag!=D_REGISTER){
			if (register_flag==F_REGISTER)
				if (reg_alloc[2].instruction_n<i && avoid_reg_n!=2){
					real_reg_n=2;
					i=reg_alloc[2].instruction_n;
				}			
			if (reg_alloc[3].instruction_n<i && avoid_reg_n!=3){
				real_reg_n=3;
				i=reg_alloc[3].instruction_n;
			}
			if (reg_alloc[4].instruction_n<i && avoid_reg_n!=4){
				real_reg_n=4;
				i=reg_alloc[4].instruction_n;
			}
			if (register_flag==F_REGISTER){
				if (reg_alloc[5].instruction_n<i && avoid_reg_n!=5){
					real_reg_n=5;
					i=reg_alloc[5].instruction_n;
				}
				if (reg_alloc[6].instruction_n<i && avoid_reg_n!=6){
					real_reg_n=6;
					i=reg_alloc[6].instruction_n;
				}
			}
		}
# else
		if (reg_alloc[2].instruction_n<i && avoid_reg_n!=2){
			real_reg_n=2;
			i=reg_alloc[2].instruction_n;
		}
		if (reg_alloc[3].instruction_n<i && avoid_reg_n!=3){
			real_reg_n=3;
			i=reg_alloc[3].instruction_n;
		}
		if (register_flag!=A_REGISTER){
			if (reg_alloc[4].instruction_n<i && avoid_reg_n!=4){
				real_reg_n=4;
				i=reg_alloc[4].instruction_n;
			}
			if (reg_alloc[5].instruction_n<i && avoid_reg_n!=5){
				real_reg_n=5;
				i=reg_alloc[5].instruction_n;
			}
		}
		if (reg_alloc[6].instruction_n<i && avoid_reg_n!=6){
			real_reg_n=6;
			i=reg_alloc[6].instruction_n;
		}
		if (register_flag!=A_REGISTER)
			if (reg_alloc[7].instruction_n<i && avoid_reg_n!=7){
				real_reg_n=7;
				i=reg_alloc[7].instruction_n;
			}
# endif
#endif
		if (real_reg_n<0)
			internal_error_in_function ("find_non_reg_2_register");
	}
	
	return real_reg_n;
}

#if defined (M68000) || defined (NEW_R_ALLOC)
static int find_reg_not_in_set
	(int reg_n,unsigned int avoid_reg_set,struct register_allocation *reg_alloc,int register_flag)
{
	int real_reg_n;

# ifdef NEW_R_ALLOC
	if ((unsigned)(reg_n+N_REAL_A_REGISTERS)<(unsigned)N_REAL_REGISTERS)
		if (register_flag==F_REGISTER)
			real_reg_n=reg_n;
		else
			real_reg_n=reg_n+N_REAL_A_REGISTERS;
# else
	if (reg_n<8)
		real_reg_n=reg_n;
# endif
	else {
		int i;
	
		real_reg_n=-1;
		i=32767;

# ifdef NEW_R_ALLOC
		if (register_flag!=F_REGISTER){
			if (reg_alloc[REAL_D0].instruction_n<i && !(avoid_reg_set & (1<<REAL_D0))){
				real_reg_n=REAL_D0;
				i=reg_alloc[REAL_D0].instruction_n;
			}
			if (reg_alloc[REAL_D1].instruction_n<i && !(avoid_reg_set & (1<<REAL_D1))){
				real_reg_n=REAL_D1;
				i=reg_alloc[REAL_D1].instruction_n;
			}
#  ifndef I486
			if (reg_alloc[REAL_D2].instruction_n<i && !(avoid_reg_set & (1<<REAL_D2))){
				real_reg_n=REAL_D2;
				i=reg_alloc[REAL_D2].instruction_n;
			}
			if (reg_alloc[REAL_D3].instruction_n<i && !(avoid_reg_set & (1<<REAL_D3))){
				real_reg_n=REAL_D3;
				i=reg_alloc[REAL_D3].instruction_n;
			}
			if (reg_alloc[REAL_D4].instruction_n<i && !(avoid_reg_set & (1<<REAL_D4))){
				real_reg_n=REAL_D4;
				i=reg_alloc[REAL_D4].instruction_n;
			}
#  endif
#  if ! (defined (I486) || defined (ARM))
			if (reg_alloc[REAL_D5].instruction_n<i && !(avoid_reg_set & (1<<REAL_D5))){
				real_reg_n=REAL_D5;
				i=reg_alloc[REAL_D5].instruction_n;
			}
			if (reg_alloc[REAL_D6].instruction_n<i && !(avoid_reg_set & (1<<REAL_D6))){
				real_reg_n=REAL_D6;
				i=reg_alloc[REAL_D6].instruction_n;
			}
			if (reg_alloc[REAL_D7].instruction_n<i && !(avoid_reg_set & (1<<REAL_D7))){
				real_reg_n=REAL_D7;
				i=reg_alloc[REAL_D7].instruction_n;
			}
#  endif
			if (reg_alloc[REAL_A0].instruction_n<i && !(avoid_reg_set & (1<<REAL_A0))){
				real_reg_n=REAL_A0;
				i=reg_alloc[REAL_A0].instruction_n;
			}
			if (reg_alloc[REAL_A1].instruction_n<i && !(avoid_reg_set & (1<<REAL_A1))){
				real_reg_n=REAL_A1;
				i=reg_alloc[REAL_A1].instruction_n;
			}
# if !(defined (I486) && !defined (G_AI64)) || defined (I486_USE_SCRATCH_REGISTER)
			if (reg_alloc[REAL_A2].instruction_n<i && !(avoid_reg_set & (1<<REAL_A2))
#  if defined (I486_USE_SCRATCH_REGISTER)
				&& allocate_scratch_register
#  endif
			){
				real_reg_n=REAL_A2;
				i=reg_alloc[REAL_A2].instruction_n;
			}
#  endif
#  ifndef THREAD64
			if (reg_alloc[REAL_A3].instruction_n<i && !(avoid_reg_set & (1<<REAL_A3))){
				real_reg_n=REAL_A3;
				i=reg_alloc[REAL_A3].instruction_n;
			}
#  endif
#  ifndef POWER_PC_A_STACK_OPTIMIZE
			if (reg_alloc[REAL_A4].instruction_n<i && !(avoid_reg_set & (1<<REAL_A4))){
				real_reg_n=REAL_A4;
				i=reg_alloc[REAL_A4].instruction_n;
			}
#  endif
#  if defined (ARM) && defined (G_A64)
			if (reg_alloc[REAL_A5].instruction_n<i && !(avoid_reg_set & (1<<REAL_A5))){
				real_reg_n=REAL_A5;
				i=reg_alloc[REAL_A5].instruction_n;
			}
#  endif
#  if ! (defined (I486) || (defined (ARM) && !defined (G_A64)) || defined (G_POWER))
			if (reg_alloc[REAL_A6].instruction_n<i && !(avoid_reg_set & (1<<REAL_A6))){
				real_reg_n=REAL_A6;
				i=reg_alloc[REAL_A6].instruction_n;
			}
#  endif
#  if defined (ARM) && defined (G_A64)
			if (reg_alloc[REAL_A7].instruction_n<i && !(avoid_reg_set & (1<<REAL_A7))){
				real_reg_n=REAL_A7;
				i=reg_alloc[REAL_A7].instruction_n;
			}
#  endif
		} else {
			if (reg_alloc[0].instruction_n<i && !(avoid_reg_set & 1)){
				real_reg_n=0;
				i=reg_alloc[0].instruction_n;
			}
			if (reg_alloc[1].instruction_n<i && !(avoid_reg_set & 2)){
				real_reg_n=1;
				i=reg_alloc[1].instruction_n;
			}
			if (reg_alloc[2].instruction_n<i && !(avoid_reg_set & 4)){
				real_reg_n=2;
				i=reg_alloc[2].instruction_n;
			}
			if (reg_alloc[3].instruction_n<i && !(avoid_reg_set & 8)){
				real_reg_n=3;
				i=reg_alloc[3].instruction_n;
			}
			if (reg_alloc[4].instruction_n<i && !(avoid_reg_set & 16)){
				real_reg_n=4;
				i=reg_alloc[4].instruction_n;
			}
			if (reg_alloc[5].instruction_n<i && !(avoid_reg_set & 32)){
				real_reg_n=5;
				i=reg_alloc[5].instruction_n;
			}
			if (reg_alloc[6].instruction_n<i && !(avoid_reg_set & 64)){
				real_reg_n=6;
				i=reg_alloc[6].instruction_n;
			}
#  if ! ((defined (I486) || defined (ARM)) && !defined (G_AI64))
			if (reg_alloc[7].instruction_n<i && !(avoid_reg_set & 128)){
				real_reg_n=7;
				i=reg_alloc[7].instruction_n;
			}
#  if defined (sparc) || defined (G_POWER) || defined (G_AI64)
			if (reg_alloc[8].instruction_n<i && !(avoid_reg_set & 256)){
				real_reg_n=8;
				i=reg_alloc[8].instruction_n;
			}
			if (reg_alloc[9].instruction_n<i && !(avoid_reg_set & 512)){
				real_reg_n=9;
				i=reg_alloc[9].instruction_n;
			}
			if (reg_alloc[10].instruction_n<i && !(avoid_reg_set & 1024)){
				real_reg_n=10;
				i=reg_alloc[10].instruction_n;
			}
			if (reg_alloc[11].instruction_n<i && !(avoid_reg_set & 2048)){
				real_reg_n=11;
				i=reg_alloc[11].instruction_n;
			}
			if (reg_alloc[12].instruction_n<i && !(avoid_reg_set & 4096)){
				real_reg_n=12;
				i=reg_alloc[12].instruction_n;
			}
			if (reg_alloc[13].instruction_n<i && !(avoid_reg_set & 8192)){
				real_reg_n=13;
				i=reg_alloc[13].instruction_n;
			}
			if (reg_alloc[14].instruction_n<i && !(avoid_reg_set & 16384)){
				real_reg_n=14;
				i=reg_alloc[14].instruction_n;
			}
#   endif
#  endif
		}
# else
		if (reg_alloc[0].instruction_n<i && !(avoid_reg_set & 1)){
			real_reg_n=0;
			i=reg_alloc[0].instruction_n;
		}
		if (reg_alloc[1].instruction_n<i && !(avoid_reg_set & 2)){
			real_reg_n=1;
			i=reg_alloc[1].instruction_n;
		}
		if (reg_alloc[2].instruction_n<i && !(avoid_reg_set & 4)){
			real_reg_n=2;
			i=reg_alloc[2].instruction_n;
		}
		if (reg_alloc[3].instruction_n<i && !(avoid_reg_set & 8)){
			real_reg_n=3;
			i=reg_alloc[3].instruction_n;
		}
		if (register_flag!=A_REGISTER){
			if (reg_alloc[4].instruction_n<i && !(avoid_reg_set & 16)){
				real_reg_n=4;
				i=reg_alloc[4].instruction_n;
			}
			if (reg_alloc[5].instruction_n<i && !(avoid_reg_set & 32)){
				real_reg_n=5;
				i=reg_alloc[5].instruction_n;
			}
		}
		if (reg_alloc[6].instruction_n<i && !(avoid_reg_set & 64)){
			real_reg_n=6;
			i=reg_alloc[6].instruction_n;
		}
		if (register_flag!=A_REGISTER)
			if (reg_alloc[7].instruction_n<i && !(avoid_reg_set & 128)){
				real_reg_n=7;
				i=reg_alloc[7].instruction_n;
			}
# endif
		if (real_reg_n<0)
			internal_error_in_function ("find_non_reg_2_register");
	}
	
	return real_reg_n;
}
#endif

static int free_2_register (	int real_reg_n,struct register_use *reg_uses,
								struct register_allocation *reg_alloc,int register_flag)
{
	int old_reg_n;
	
	old_reg_n=reg_alloc[real_reg_n].reg;
#ifdef NEW_R_ALLOC
	if (old_reg_n!=-32768){
#else
	if (old_reg_n>=0){
#endif
		if (reg_alloc[real_reg_n].value_used){
			if (reg_uses[old_reg_n].offset==0){
#ifndef G_A64
				if (register_flag!=F_REGISTER)
					local_data_offset-=4;
				else
#endif
					local_data_offset-=8;

				reg_uses[old_reg_n].offset=local_data_offset;
				
				insert_store (real_reg_n,local_data_offset,register_flag);
			} else if (reg_alloc[real_reg_n].altered)
				insert_store (real_reg_n,reg_uses[old_reg_n].offset,register_flag);
		}
		reg_uses[old_reg_n].reg=-1;
	}
#ifdef NEW_R_ALLOC
	reg_alloc[real_reg_n].reg=-32768;
#else
	reg_alloc[real_reg_n].reg=-1;
#endif
	
	return real_reg_n;
}

static void allocate_2_register (	int reg_n,int real_reg_n,int use_flag,
									struct register_use *reg_uses,
									struct register_allocation *reg_alloc,int register_flag)
{
	free_2_register (real_reg_n,reg_uses,reg_alloc,register_flag);
	
	reg_alloc[real_reg_n].reg=reg_n;
	reg_uses[reg_n].reg=real_reg_n;
	
	if (use_flag!=DEF){
		if (reg_uses[reg_n].offset!=0){
			insert_load (reg_uses[reg_n].offset,real_reg_n,register_flag);
			reg_alloc[real_reg_n].altered=0;
		}
	}
}

static void move_2_register (	int reg_n,int real_reg_n,int use_flag,
								struct register_use *reg_uses,
								struct register_allocation *reg_alloc,int register_flag)
{
	int old_real_reg_n;
	
	old_real_reg_n=reg_uses[reg_n].reg;
	
	free_2_register (real_reg_n,reg_uses,reg_alloc,register_flag);

#ifdef NEW_R_ALLOC
	reg_alloc[old_real_reg_n].reg=-32768;
#else
	reg_alloc[old_real_reg_n].reg=-1;
#endif
	reg_alloc[old_real_reg_n].instruction_n=0;
	
	reg_alloc[real_reg_n].reg=reg_n;
	reg_uses[reg_n].reg=real_reg_n;
	
	reg_alloc[real_reg_n].altered=reg_alloc[old_real_reg_n].altered;

	if (use_flag!=DEF)
		insert_move (old_real_reg_n,real_reg_n,register_flag);
}

#ifdef NEW_R_ALLOC
static void register_use (struct reg *reg_p,int use_flag)
{
	int reg,real_reg_n,instruction_n;
	
	reg=reg_p->r;
	
	real_reg_n=r_reg_uses[reg].reg;
	if (real_reg_n<0){
		real_reg_n=find_register (reg,r_reg_alloc,D_REGISTER);
		allocate_2_register (reg,real_reg_n,use_flag,r_reg_uses,r_reg_alloc,D_REGISTER);
	}

	instruction_n=reg_p->u>>1;
	r_reg_uses[reg].instruction_n=instruction_n;
	
	r_reg_alloc[real_reg_n].instruction_n =
		(r_reg_uses[real_reg_n-N_REAL_A_REGISTERS].instruction_n>instruction_n)
		? r_reg_uses[real_reg_n-N_REAL_A_REGISTERS].instruction_n : instruction_n;

	r_reg_alloc[real_reg_n].value_used=reg_p->u & 1;

	if (use_flag!=USE)
		r_reg_alloc[real_reg_n].altered=1;

	reg_p->r=real_reg_n-N_REAL_A_REGISTERS;
}
#else
static void register_use (struct reg *reg_p,int use_flag)
{
	int reg,reg_n,real_reg_n,instruction_n;
	
	reg=reg_p->r;
	
	if (is_d_register (reg)){
		reg_n=d_reg_num (reg);
		
		real_reg_n=d_reg_uses[reg_n].reg;
		if (real_reg_n<0){
			real_reg_n=find_register (reg_n,d_reg_alloc,D_REGISTER);
			allocate_2_register (reg_n,real_reg_n,use_flag,d_reg_uses,d_reg_alloc,D_REGISTER);
		}

		instruction_n=reg_p->u>>1;
		d_reg_uses[reg_n].instruction_n=instruction_n;
		
		d_reg_alloc[real_reg_n].instruction_n =
			(d_reg_uses[real_reg_n].instruction_n>instruction_n)
			? d_reg_uses[real_reg_n].instruction_n : instruction_n;
		
		d_reg_alloc[real_reg_n].value_used=reg_p->u & 1;

		if (use_flag!=USE)
			d_reg_alloc[real_reg_n].altered=1;
		
		reg_p->r=num_to_d_reg (real_reg_n);
	} else {
		reg_n=a_reg_num (reg);
		
		real_reg_n=a_reg_uses[reg_n].reg;
		if (real_reg_n<0){
			real_reg_n=find_register (reg_n,a_reg_alloc,A_REGISTER);
			allocate_2_register (reg_n,real_reg_n,use_flag,a_reg_uses,a_reg_alloc,A_REGISTER);
		}
		
		instruction_n=reg_p->u>>1;
		a_reg_uses[reg_n].instruction_n=instruction_n;
		
		a_reg_alloc[real_reg_n].instruction_n = 
			(a_reg_uses[real_reg_n].instruction_n>instruction_n) 
			? a_reg_uses[real_reg_n].instruction_n : instruction_n;
			
		a_reg_alloc[real_reg_n].value_used=reg_p->u & 1;

		if (use_flag!=USE)
			a_reg_alloc[real_reg_n].altered=1;
		
		reg_p->r=num_to_a_reg (real_reg_n);
	}
}
#endif

static void float_register_use (struct parameter *parameter,int use_flag)
{
	int reg_n,real_reg_n,instruction_n;
	
	reg_n=parameter->parameter_data.reg.r;

	real_reg_n=f_reg_uses[reg_n].reg;
	if (real_reg_n<0){
		real_reg_n=find_register (reg_n,f_reg_alloc,F_REGISTER);
		allocate_2_register (reg_n,real_reg_n,use_flag,f_reg_uses,f_reg_alloc,F_REGISTER);
	}

	instruction_n=parameter->parameter_data.reg.u>>1;
	f_reg_uses[reg_n].instruction_n=instruction_n;
	
	f_reg_alloc[real_reg_n].instruction_n=
		(f_reg_uses[real_reg_n].instruction_n>instruction_n)
		? f_reg_uses[real_reg_n].instruction_n : instruction_n;
		
	f_reg_alloc[real_reg_n].value_used=parameter->parameter_data.reg.u & 1;

	if (use_flag!=USE)
		f_reg_alloc[real_reg_n].altered=1;
	
	parameter->parameter_data.reg.r=real_reg_n;
}

#ifdef NEW_R_ALLOC
static void use_2_same_type_registers
	(struct reg *reg_p_1,int use_flag_1,struct reg *reg_p_2,int use_flag_2,int register_flag)
{
	int reg_n_1,reg_n_2,real_reg_n_1,real_reg_n_2,instruction_n;
	struct register_use *reg_uses;
	struct register_allocation *reg_alloc;
	
	reg_n_1=reg_p_1->r;
	reg_n_2=reg_p_2->r;
	
	switch (register_flag){
		case D_REGISTER:
		case A_REGISTER:
			reg_uses=r_reg_uses;
			reg_alloc=r_reg_alloc;
			break;
		case F_REGISTER:
			reg_uses=f_reg_uses;
			reg_alloc=f_reg_alloc;
			break;
		default:
			internal_error_in_function ("use_2_same_type_registers");
			return;
	}
	
	real_reg_n_1=reg_uses[reg_n_1].reg;
	if (real_reg_n_1<0){
		int avoid_real_reg_n;
				
		if (register_flag==F_REGISTER)
			avoid_real_reg_n= reg_n_2<8 ? reg_n_2 : reg_uses [reg_n_2].reg;
		else
			avoid_real_reg_n= (unsigned)(reg_n_2+N_REAL_A_REGISTERS)<(unsigned)N_REAL_REGISTERS ? reg_n_2+N_REAL_A_REGISTERS : reg_uses [reg_n_2].reg;
		
		real_reg_n_1=find_non_reg_2_register (reg_n_1,avoid_real_reg_n,reg_alloc,register_flag);
		
		allocate_2_register (reg_n_1,real_reg_n_1,use_flag_1,reg_uses,reg_alloc,register_flag);
	} else if ((unsigned)(reg_n_1+N_REAL_A_REGISTERS)>=(unsigned)N_REAL_REGISTERS && 
		(register_flag==F_REGISTER ? real_reg_n_1==reg_n_2 : real_reg_n_1==reg_n_2+N_REAL_A_REGISTERS))
	{
		int avoid_real_reg_n;
				
		if (register_flag==F_REGISTER)
			avoid_real_reg_n= reg_n_2<8 ? reg_n_2 : reg_uses [reg_n_2].reg;
		else
			avoid_real_reg_n= (unsigned)(reg_n_2+N_REAL_A_REGISTERS)<(unsigned)N_REAL_REGISTERS ? reg_n_2+N_REAL_A_REGISTERS : reg_uses [reg_n_2].reg;
		
		real_reg_n_1=find_non_reg_2_register (reg_n_1,avoid_real_reg_n,reg_alloc,register_flag);
		
		move_2_register (reg_n_1,real_reg_n_1,use_flag_1,reg_uses,reg_alloc,register_flag);
	}
		
	real_reg_n_2=reg_uses[reg_n_2].reg;
	if (real_reg_n_2<0){
		int avoid_real_reg_n;
				
		if (register_flag==F_REGISTER)
			avoid_real_reg_n= reg_n_1<8 ? reg_n_1 : reg_uses [reg_n_1].reg;
		else
			avoid_real_reg_n= (unsigned)(reg_n_1+N_REAL_A_REGISTERS)<(unsigned)N_REAL_REGISTERS ? reg_n_1+N_REAL_A_REGISTERS : reg_uses [reg_n_1].reg;
			
		real_reg_n_2=find_non_reg_2_register (reg_n_2,avoid_real_reg_n,reg_alloc,register_flag);
		
		allocate_2_register (reg_n_2,real_reg_n_2,use_flag_2,reg_uses,reg_alloc,register_flag);
	} else if ((unsigned)(reg_n_2+N_REAL_A_REGISTERS)>=(unsigned)N_REAL_REGISTERS &&
		(register_flag==F_REGISTER ? real_reg_n_2==reg_n_1 : real_reg_n_2==reg_n_1+N_REAL_A_REGISTERS))
	{
		int avoid_real_reg_n;

		if (register_flag==F_REGISTER)
			avoid_real_reg_n= reg_n_2<8 ? reg_n_2 : reg_uses [reg_n_2].reg;
		else
			avoid_real_reg_n= (unsigned)(reg_n_2+N_REAL_A_REGISTERS)<(unsigned)N_REAL_REGISTERS ? reg_n_2+N_REAL_A_REGISTERS : reg_uses [reg_n_2].reg;
		
		real_reg_n_2=find_non_reg_2_register (reg_n_2,avoid_real_reg_n,reg_alloc,register_flag);
		
		move_2_register (reg_n_2,real_reg_n_2,use_flag_2,reg_uses,reg_alloc,register_flag);
	}

	{
	int real_reg_n_1_reg,real_reg_n_2_reg;

	if (register_flag==F_REGISTER){
		real_reg_n_1_reg=real_reg_n_1;
		real_reg_n_2_reg=real_reg_n_2;
	} else {
		real_reg_n_1_reg = real_reg_n_1-N_REAL_A_REGISTERS;
		real_reg_n_2_reg = real_reg_n_2-N_REAL_A_REGISTERS;
	}
	
	instruction_n=reg_p_1->u>>1;
	reg_uses[reg_n_1].instruction_n=instruction_n;

	reg_alloc[real_reg_n_1].instruction_n =
		(reg_uses[real_reg_n_1_reg].instruction_n>instruction_n)
		? reg_uses[real_reg_n_1_reg].instruction_n : instruction_n;
	
	reg_alloc[real_reg_n_1].value_used=reg_p_1->u & 1;

	instruction_n=reg_p_2->u>>1;
	reg_uses[reg_n_2].instruction_n=instruction_n;

	reg_alloc[real_reg_n_2].instruction_n =
		(reg_uses[real_reg_n_2_reg].instruction_n>instruction_n)
		? reg_uses[real_reg_n_2_reg].instruction_n : instruction_n;

	reg_alloc[real_reg_n_2].value_used=reg_p_2->u & 1;

	if (use_flag_1!=USE)
		reg_alloc[real_reg_n_1].altered=1;
	if (use_flag_2!=USE)
		reg_alloc[real_reg_n_2].altered=1;
	
	reg_p_1->r=real_reg_n_1_reg;
	reg_p_2->r=real_reg_n_2_reg;
	}
}
#else
static void use_2_same_type_registers
	(struct reg *reg_p_1,int use_flag_1,struct reg *reg_p_2,int use_flag_2,int register_flag)
{
	int reg_1,reg_n_1,reg_2,reg_n_2,real_reg_n_1,real_reg_n_2,instruction_n;
	struct register_use *reg_uses;
	struct register_allocation *reg_alloc;
	
	reg_1=reg_p_1->r;
	reg_2=reg_p_2->r;
	
	switch (register_flag){
		case D_REGISTER:
			reg_n_1=d_reg_num (reg_1);
			reg_n_2=d_reg_num (reg_2);
			reg_uses=d_reg_uses;
			reg_alloc=d_reg_alloc;
			break;
		case A_REGISTER:
			reg_n_1=a_reg_num (reg_1);
			reg_n_2=a_reg_num (reg_2);
			reg_uses=a_reg_uses;
			reg_alloc=a_reg_alloc;
			break;
		case F_REGISTER:
			reg_n_1=reg_1;
			reg_n_2=reg_2;
			reg_uses=f_reg_uses;
			reg_alloc=f_reg_alloc;
			break;
		default:
			internal_error_in_function ("use_2_same_type_registers");
			return;
	}
	
	real_reg_n_1=reg_uses[reg_n_1].reg;
	if (real_reg_n_1<0){
		int avoid_real_reg_n;
				
		avoid_real_reg_n= reg_n_2<8 ? reg_n_2 : reg_uses [reg_n_2].reg;
		
		real_reg_n_1=find_non_reg_2_register (reg_n_1,avoid_real_reg_n,reg_alloc,register_flag);
		
		allocate_2_register (reg_n_1,real_reg_n_1,use_flag_1,reg_uses,reg_alloc,register_flag);
	} else if (reg_n_1>=8 && real_reg_n_1==reg_n_2){
		int avoid_real_reg_n;
				
		avoid_real_reg_n= reg_n_2<8 ? reg_n_2 : reg_uses [reg_n_2].reg;
		
		real_reg_n_1=find_non_reg_2_register (reg_n_1,avoid_real_reg_n,reg_alloc,register_flag);
		
		move_2_register (reg_n_1,real_reg_n_1,use_flag_1,reg_uses,reg_alloc,register_flag);
	}
		
	real_reg_n_2=reg_uses[reg_n_2].reg;
	if (real_reg_n_2<0){
		int avoid_real_reg_n;
				
		avoid_real_reg_n= reg_n_1<8 ? reg_n_1 : reg_uses [reg_n_1].reg;
			
		real_reg_n_2=find_non_reg_2_register (reg_n_2,avoid_real_reg_n,reg_alloc,register_flag);
		
		allocate_2_register (reg_n_2,real_reg_n_2,use_flag_2,reg_uses,reg_alloc,
								register_flag);
	} else if (reg_n_2>=8 && real_reg_n_2==reg_n_1){
		int avoid_real_reg_n;
				
		avoid_real_reg_n= reg_n_2<8 ? reg_n_2 : reg_uses [reg_n_2].reg;
		
		real_reg_n_2=find_non_reg_2_register (reg_n_2,avoid_real_reg_n,reg_alloc,register_flag);
		
		move_2_register (reg_n_2,real_reg_n_2,use_flag_2,reg_uses,reg_alloc,register_flag);
	}
	
	instruction_n=reg_p_1->u>>1;
	reg_uses[reg_n_1].instruction_n=instruction_n;

	reg_alloc[real_reg_n_1].instruction_n =
		(reg_uses[real_reg_n_1].instruction_n>instruction_n)
		? reg_uses[real_reg_n_1].instruction_n : instruction_n;
	
	reg_alloc[real_reg_n_1].value_used=reg_p_1->u & 1;

	instruction_n=reg_p_2->u>>1;
	reg_uses[reg_n_2].instruction_n=instruction_n;

	reg_alloc[real_reg_n_2].instruction_n =
		(reg_uses[real_reg_n_2].instruction_n>instruction_n)
		? reg_uses[real_reg_n_2].instruction_n : instruction_n;
	reg_alloc[real_reg_n_2].value_used=reg_p_2->u & 1;

	if (use_flag_1!=USE)
		reg_alloc[real_reg_n_1].altered=1;
	if (use_flag_2!=USE)
		reg_alloc[real_reg_n_2].altered=1;
	
	switch (register_flag){
		case D_REGISTER:
			reg_p_1->r=num_to_d_reg (real_reg_n_1);
			reg_p_2->r=num_to_d_reg (real_reg_n_2);
			break;
		case A_REGISTER:
			reg_p_1->r=num_to_a_reg (real_reg_n_1);
			reg_p_2->r=num_to_a_reg (real_reg_n_2);
			break;
		case F_REGISTER:
			reg_p_1->r=real_reg_n_1;
			reg_p_2->r=real_reg_n_2;
	}
}	
#endif

#ifdef NEW_R_ALLOC
static int find_register_3
	(int reg_n_1,int reg_n_2,int reg_n_3,int register_flag,struct register_use *reg_uses,
	struct register_allocation *reg_alloc)
{
	int avoid_real_reg_n2,avoid_real_reg_n3;
	unsigned int avoid_register_set;

	if (register_flag==F_REGISTER){
		avoid_real_reg_n2= reg_n_2<8 ? reg_n_2 : reg_uses [reg_n_2].reg;
		avoid_real_reg_n3= reg_n_3<8 ? reg_n_3 : reg_uses [reg_n_3].reg;
	} else {
		avoid_real_reg_n2= (unsigned)(reg_n_2+N_REAL_A_REGISTERS)<(unsigned)N_REAL_REGISTERS ? reg_n_2+N_REAL_A_REGISTERS : reg_uses [reg_n_2].reg;
		avoid_real_reg_n3= (unsigned)(reg_n_3+N_REAL_A_REGISTERS)<(unsigned)N_REAL_REGISTERS ? reg_n_3+N_REAL_A_REGISTERS : reg_uses [reg_n_3].reg;
	}

	avoid_register_set=0;
	if (avoid_real_reg_n2>=0)
		avoid_register_set |= 1<<avoid_real_reg_n2;
	if (avoid_real_reg_n3>=0)
		avoid_register_set |= 1<<avoid_real_reg_n3;

	return find_reg_not_in_set (reg_n_1,avoid_register_set,reg_alloc,register_flag);
}

static void use_3_same_type_registers
	(struct reg *reg_p_1,int use_flag_1,struct reg *reg_p_2,int use_flag_2,
	 struct reg *reg_p_3,int use_flag_3,int register_flag)
{
	int reg_n_1,reg_n_2,reg_n_3,real_reg_n_1,real_reg_n_2,real_reg_n_3,instruction_n;
	struct register_use *reg_uses;
	struct register_allocation *reg_alloc;

	reg_n_1=reg_p_1->r;
	reg_n_2=reg_p_2->r;
	reg_n_3=reg_p_3->r;
	
	switch (register_flag){
		case D_REGISTER:
		case A_REGISTER:
			reg_uses=r_reg_uses;
			reg_alloc=r_reg_alloc;
			break;
		case F_REGISTER:
			reg_uses=f_reg_uses;
			reg_alloc=f_reg_alloc;
			break;
		default:
			internal_error_in_function ("use_3_same_type_registers");
			return;
	}
	
	real_reg_n_1=reg_uses[reg_n_1].reg;
	if (real_reg_n_1<0){
		real_reg_n_1=find_register_3 (reg_n_1,reg_n_2,reg_n_3,register_flag,reg_uses,reg_alloc);

		allocate_2_register (reg_n_1,real_reg_n_1,use_flag_1,reg_uses,reg_alloc,register_flag);
	} else if ((unsigned)(reg_n_1+N_REAL_A_REGISTERS)>=(unsigned)N_REAL_REGISTERS &&
		(register_flag==F_REGISTER ? 
			(real_reg_n_1==reg_n_2 || real_reg_n_1==reg_n_3) : 
			(real_reg_n_1==reg_n_2+N_REAL_A_REGISTERS || real_reg_n_1==reg_n_3+N_REAL_A_REGISTERS)))
	{
		real_reg_n_1=find_register_3 (reg_n_1,reg_n_2,reg_n_3,register_flag,reg_uses,reg_alloc);
		
		move_2_register (reg_n_1,real_reg_n_1,use_flag_1,reg_uses,reg_alloc,register_flag);
	}

	real_reg_n_2=reg_uses[reg_n_2].reg;
	if (real_reg_n_2<0){
		real_reg_n_2=find_register_3 (reg_n_2,reg_n_1,reg_n_3,register_flag,reg_uses,reg_alloc);

		allocate_2_register (reg_n_2,real_reg_n_2,use_flag_2,reg_uses,reg_alloc,register_flag);
	} else if ((unsigned)(reg_n_2+N_REAL_A_REGISTERS)>=(unsigned)N_REAL_REGISTERS &&
		(register_flag==F_REGISTER ? 
			(real_reg_n_2==reg_n_1 || real_reg_n_2==reg_n_3) : 
			(real_reg_n_2==reg_n_1+N_REAL_A_REGISTERS || real_reg_n_2==reg_n_3+N_REAL_A_REGISTERS)))
	{
		real_reg_n_2=find_register_3 (reg_n_2,reg_n_1,reg_n_3,register_flag,reg_uses,reg_alloc);
		
		move_2_register (reg_n_2,real_reg_n_2,use_flag_1,reg_uses,reg_alloc,register_flag);
	}

	real_reg_n_3=reg_uses[reg_n_3].reg;
	if (real_reg_n_3<0){
		real_reg_n_3=find_register_3 (reg_n_3,reg_n_1,reg_n_2,register_flag,reg_uses,reg_alloc);

		allocate_2_register (reg_n_3,real_reg_n_3,use_flag_3,reg_uses,reg_alloc,register_flag);
	} else if ((unsigned)(reg_n_3+N_REAL_A_REGISTERS)>=(unsigned)N_REAL_REGISTERS &&
		(register_flag==F_REGISTER ? 
			(real_reg_n_3==reg_n_1 || real_reg_n_3==reg_n_2) : 
			(real_reg_n_3==reg_n_1+N_REAL_A_REGISTERS || real_reg_n_3==reg_n_2+N_REAL_A_REGISTERS)))
	{
		real_reg_n_3=find_register_3 (reg_n_3,reg_n_1,reg_n_2,register_flag,reg_uses,reg_alloc);
		
		move_2_register (reg_n_3,real_reg_n_3,use_flag_1,reg_uses,reg_alloc,register_flag);
	}

	{
	int real_reg_n_1_reg,real_reg_n_2_reg,real_reg_n_3_reg;
	
	if (register_flag==F_REGISTER){
		real_reg_n_1_reg=real_reg_n_1;
		real_reg_n_2_reg=real_reg_n_2;
		real_reg_n_3_reg=real_reg_n_3;
	} else {
		real_reg_n_1_reg = real_reg_n_1-N_REAL_A_REGISTERS;
		real_reg_n_2_reg = real_reg_n_2-N_REAL_A_REGISTERS;
		real_reg_n_3_reg = real_reg_n_3-N_REAL_A_REGISTERS;
	}

	instruction_n=reg_p_1->u>>1;
	reg_uses[reg_n_1].instruction_n=instruction_n;

	reg_alloc[real_reg_n_1].instruction_n =
		(reg_uses[real_reg_n_1_reg].instruction_n>instruction_n)
		? reg_uses[real_reg_n_1_reg].instruction_n : instruction_n;
	
	reg_alloc[real_reg_n_1].value_used=reg_p_1->u & 1;

	instruction_n=reg_p_2->u>>1;
	reg_uses[reg_n_2].instruction_n=instruction_n;

	reg_alloc[real_reg_n_2].instruction_n =
		(reg_uses[real_reg_n_2_reg].instruction_n>instruction_n)
		? reg_uses[real_reg_n_2_reg].instruction_n : instruction_n;

	reg_alloc[real_reg_n_2].value_used=reg_p_2->u & 1;

	instruction_n=reg_p_3->u>>1;
	reg_uses[reg_n_3].instruction_n=instruction_n;

	reg_alloc[real_reg_n_3].instruction_n =
		(reg_uses[real_reg_n_3_reg].instruction_n>instruction_n)
		? reg_uses[real_reg_n_3_reg].instruction_n : instruction_n;

	reg_alloc[real_reg_n_3].value_used=reg_p_3->u & 1;

	if (use_flag_1!=USE)
		reg_alloc[real_reg_n_1].altered=1;
	if (use_flag_2!=USE)
		reg_alloc[real_reg_n_2].altered=1;
	if (use_flag_3!=USE)
		reg_alloc[real_reg_n_3].altered=1;
	
	reg_p_1->r=real_reg_n_1_reg;
	reg_p_2->r=real_reg_n_2_reg;
	reg_p_3->r=real_reg_n_3_reg;
	}	
}
#endif

#ifdef NEW_R_ALLOC
static void register_use_2 (struct reg *reg_p_1,int use_flag_1,struct reg *reg_p_2,int use_flag_2)
{
	use_2_same_type_registers (reg_p_1,use_flag_1,reg_p_2,use_flag_2,D_REGISTER);
}
#else
static void register_use_2 (struct reg *reg_p_1,int use_flag_1,struct reg *reg_p_2,int use_flag_2)
{
	if (is_d_register (reg_p_1->r)){
		if (is_d_register (reg_p_2->r))
			use_2_same_type_registers (reg_p_1,use_flag_1,reg_p_2,use_flag_2,D_REGISTER);
		else {
			register_use (reg_p_1,use_flag_1);
			register_use (reg_p_2,use_flag_2);
		}
	} else {
		if (is_d_register (reg_p_2->r)){
			register_use (reg_p_1,use_flag_1);
			register_use (reg_p_2,use_flag_2);
		} else
			use_2_same_type_registers (reg_p_1,use_flag_1,reg_p_2,use_flag_2,A_REGISTER);
	}
}
#endif

#ifdef M68000
static void register_use_3_d_indexed
	(struct reg *reg_p,int use_flag,struct reg *a_reg_p,struct reg *d_reg_p)
{
	if (is_d_register (reg_p->r)){
		use_2_same_type_registers (reg_p,use_flag,d_reg_p,USE,D_REGISTER);
		register_use (a_reg_p,USE);
	} else {
		use_2_same_type_registers (reg_p,use_flag,a_reg_p,USE,A_REGISTER);
		register_use (d_reg_p,USE);
	}
}

static void register_use_3_s_indexed
	(struct reg *a_reg_p,struct reg *d_reg_p,struct reg *reg_p,int use_flag)
{
	if (is_d_register (reg_p->r)){
		use_2_same_type_registers (d_reg_p,USE,reg_p,use_flag,D_REGISTER);
		register_use (a_reg_p,USE);
	} else {
		use_2_same_type_registers (a_reg_p,USE,reg_p,use_flag,A_REGISTER);
		register_use (d_reg_p,USE);
	}
}
#endif

#if 1
static void instruction_use_def_reg (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
		case P_INDIRECT:
			register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE);
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:
					register_use (&instruction->instruction_parameters[1].parameter_data.reg,DEF);
					break;
				case P_F_REGISTER:
					float_register_use (&instruction->instruction_parameters[1],DEF);
			}
			break;
#if defined (M68000) || defined (I486) || defined (ARM)
		case P_POST_INCREMENT:
		case P_PRE_DECREMENT:
			register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF);
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:	
					register_use (&instruction->instruction_parameters[1].parameter_data.reg,DEF);
					break;
				case P_F_REGISTER:
					float_register_use (&instruction->instruction_parameters[1],DEF);
			}
			break;
#endif
		case P_F_REGISTER:
			float_register_use (&instruction->instruction_parameters[0],USE);
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:
					register_use (&instruction->instruction_parameters[1].parameter_data.reg,DEF);
					break;
				case P_F_REGISTER:
					float_register_use (&instruction->instruction_parameters[1],DEF);
			}
			break;
		case P_INDEXED:
#ifdef M68000
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:
					register_use_3_s_indexed 
						(&instruction->instruction_parameters[0].parameter_data.ir->a_reg,
						 &instruction->instruction_parameters[0].parameter_data.ir->d_reg,
						 &instruction->instruction_parameters[1].parameter_data.reg,use_flag);
					break;
				case P_F_REGISTER:
					register_use (&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE);
					register_use (&instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE);
					float_register_use (&instruction->instruction_parameters[1],use_flag);
			}
#else
			use_2_same_type_registers
				(&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE,
				 &instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE,D_REGISTER);
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:
					register_use (&instruction->instruction_parameters[1].parameter_data.reg,DEF);
					break;
				case P_F_REGISTER:
					float_register_use (&instruction->instruction_parameters[1],DEF);
			}
#endif
			break;
		default:
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:
					register_use (&instruction->instruction_parameters[1].parameter_data.reg,DEF);
					break;
				case P_F_REGISTER:
					float_register_use (&instruction->instruction_parameters[1],DEF);
			}
	}
}
#endif

static void instruction_use_2 (struct instruction *instruction,int use_flag)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
		case P_INDIRECT:
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:
					register_use_2 
						(&instruction->instruction_parameters[0].parameter_data.reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.reg,use_flag);
					break;
				case P_INDIRECT:
					register_use_2 
						(&instruction->instruction_parameters[0].parameter_data.reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.reg,USE);
					break;
#if defined (M68000) || defined (I486) || defined (ARM)
				case P_POST_INCREMENT:
				case P_PRE_DECREMENT:
					register_use_2
						(&instruction->instruction_parameters[0].parameter_data.reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.reg,USE_DEF);
					break;
#endif
				case P_F_REGISTER:
					register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE);
					float_register_use (&instruction->instruction_parameters[1],use_flag);
					break;
				case P_INDEXED:
#ifdef M68000
					register_use_3_d_indexed
						(&instruction->instruction_parameters[0].parameter_data.reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.ir->a_reg,
						 &instruction->instruction_parameters[1].parameter_data.ir->d_reg);
#else
					use_3_same_type_registers
						(&instruction->instruction_parameters[0].parameter_data.reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.ir->a_reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.ir->d_reg,USE,D_REGISTER);
#endif
					break;
				default:
					register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE);
			}
			break;
#if defined (M68000) || defined (I486) || defined (ARM)
		case P_POST_INCREMENT:
		case P_PRE_DECREMENT:
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:	
					register_use_2
						(&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF,
						 &instruction->instruction_parameters[1].parameter_data.reg,use_flag);
					break;
				case P_INDIRECT:
					register_use_2
						(&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF,
						 &instruction->instruction_parameters[1].parameter_data.reg,USE);
					break;
				case P_POST_INCREMENT:
				case P_PRE_DECREMENT:
					register_use_2
						(&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF,
						 &instruction->instruction_parameters[1].parameter_data.reg,USE_DEF);
					break;				
				case P_F_REGISTER:
					register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF);
					float_register_use (&instruction->instruction_parameters[1],use_flag);
					break;
				case P_INDEXED:
#ifdef M68000
					register_use_3_d_indexed 
						(&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF,
						 &instruction->instruction_parameters[1].parameter_data.ir->a_reg,
						 &instruction->instruction_parameters[1].parameter_data.ir->d_reg);
#else
					use_3_same_type_registers
						(&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF,
						 &instruction->instruction_parameters[1].parameter_data.ir->a_reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.ir->d_reg,USE,D_REGISTER);
#endif
					break;
				default:
					register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF);
			}
			break;
#endif
		case P_F_REGISTER:
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:
					float_register_use (&instruction->instruction_parameters[0],USE);
					register_use (&instruction->instruction_parameters[1].parameter_data.reg,use_flag);
					break;
				case P_INDIRECT:
					float_register_use (&instruction->instruction_parameters[0],USE);
					register_use (&instruction->instruction_parameters[1].parameter_data.reg,USE);
					break;
#if defined (M68000) || defined (I486) || defined (ARM)
				case P_POST_INCREMENT:
				case P_PRE_DECREMENT:
					float_register_use (&instruction->instruction_parameters[0],USE);
					register_use (&instruction->instruction_parameters[1].parameter_data.reg,USE_DEF);
					break;
#endif
				case P_F_REGISTER:
					use_2_same_type_registers
						(&instruction->instruction_parameters[0].parameter_data.reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.reg,use_flag,
						 F_REGISTER);
					break;
				case P_INDEXED:
					float_register_use (&instruction->instruction_parameters[0],USE);
#ifdef M68000
					register_use (&instruction->instruction_parameters[1].parameter_data.ir->a_reg,USE);
					register_use (&instruction->instruction_parameters[1].parameter_data.ir->d_reg,USE);
#else
					register_use_2
						(&instruction->instruction_parameters[1].parameter_data.ir->a_reg,USE,
						&instruction->instruction_parameters[1].parameter_data.ir->d_reg,USE);
#endif
					break;
				default:
					float_register_use (&instruction->instruction_parameters[0],USE);
			}
			break;
		case P_INDEXED:
#ifdef M68000
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:
					register_use_3_s_indexed 
						(&instruction->instruction_parameters[0].parameter_data.ir->a_reg,
						 &instruction->instruction_parameters[0].parameter_data.ir->d_reg,
						 &instruction->instruction_parameters[1].parameter_data.reg,use_flag);
					break;
				case P_INDIRECT:
					register_use_3_s_indexed 
						(&instruction->instruction_parameters[0].parameter_data.ir->a_reg,
						 &instruction->instruction_parameters[0].parameter_data.ir->d_reg,
						 &instruction->instruction_parameters[1].parameter_data.reg,USE);
					break;
#if defined (M68000) || defined (I486) || defined (ARM)
				case P_POST_INCREMENT:
				case P_PRE_DECREMENT:
					register_use_3_s_indexed 
						(&instruction->instruction_parameters[0].parameter_data.ir->a_reg,
						 &instruction->instruction_parameters[0].parameter_data.ir->d_reg,
						 &instruction->instruction_parameters[1].parameter_data.reg,USE_DEF);
					break;
#endif
				case P_F_REGISTER:
					register_use (&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE);
					register_use (&instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE);
					float_register_use (&instruction->instruction_parameters[1],use_flag);
					break;
				case P_INDEXED:
					use_2_same_type_registers
						(&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.ir->a_reg,USE,
						 A_REGISTER);
					use_2_same_type_registers
						(&instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.ir->d_reg,USE,
						 D_REGISTER);
					break;
				default:
					register_use (&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE);
					register_use (&instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE);
			}
#else
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:
					use_3_same_type_registers
						(&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE,
						 &instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.reg,use_flag,D_REGISTER);
					break;
				case P_F_REGISTER:
					use_2_same_type_registers
						(&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE,
						 &instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE,D_REGISTER);
					float_register_use (&instruction->instruction_parameters[1],use_flag);
					break;
				case P_INDIRECT:
					use_3_same_type_registers
						(&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE,
						 &instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.reg,USE,D_REGISTER);
					break;
				case P_INDEXED:
					internal_error_in_function ("instruction_use_2");
					break;
				default:
					use_2_same_type_registers
						(&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE,
						 &instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE,D_REGISTER);
			}

#endif
			break;
		default:
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:
					register_use (&instruction->instruction_parameters[1].parameter_data.reg,use_flag);
					break;
				case P_INDIRECT:
					register_use (&instruction->instruction_parameters[1].parameter_data.reg,USE);
					break;
#if defined (M68000) || defined (I486) || defined (ARM)
				case P_POST_INCREMENT:
				case P_PRE_DECREMENT:
					register_use (&instruction->instruction_parameters[1].parameter_data.reg,USE_DEF);
					break;
#endif
				case P_F_REGISTER:
					float_register_use (&instruction->instruction_parameters[1],use_flag);
					break;
				case P_INDEXED:
#ifdef M68000
					register_use (&instruction->instruction_parameters[1].parameter_data.ir->a_reg,USE);
					register_use (&instruction->instruction_parameters[1].parameter_data.ir->d_reg,USE);
#else
					register_use_2
						(&instruction->instruction_parameters[1].parameter_data.ir->a_reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.ir->d_reg,USE);
#endif
			}
	}
}

static void instruction_use (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
		case P_INDIRECT:
			register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE);
			break;
#if defined (M68000) || defined (I486) || defined (ARM)
		case P_POST_INCREMENT:
		case P_PRE_DECREMENT:
			register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF);
			break;
#endif
		case P_F_REGISTER:
			float_register_use (&instruction->instruction_parameters[0],USE);
			break;
		case P_INDEXED:
#ifdef M68000
			register_use (&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE);
			register_use (&instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE);
#else
			register_use_2
				(&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE,
				 &instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE);			
#endif
	}
}

static void instruction_usedef (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
#if defined (M68000) || defined (I486) || defined (ARM)
		case P_POST_INCREMENT:
		case P_PRE_DECREMENT:
			register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF);
			break;
#endif
		case P_INDIRECT:
			register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE);
			break;
		case P_F_REGISTER:
			float_register_use (&instruction->instruction_parameters[0],USE_DEF);
			break;
		case P_INDEXED:
#ifdef M68000
			register_use (&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE);
			register_use (&instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE);
#else
			register_use_2
				(&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE,
				 &instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE);
#endif
	}
}

static void instruction_def (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			register_use (&instruction->instruction_parameters[0].parameter_data.reg,DEF);
			break;
		case P_INDIRECT:
			register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE);
			break;
#if defined (M68000) || defined (I486) || defined (ARM)
		case P_POST_INCREMENT:
		case P_PRE_DECREMENT:
			register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF);
			break;
#endif
		case P_F_REGISTER:
			float_register_use (&instruction->instruction_parameters[0],DEF);
			break;
		case P_INDEXED:
#ifdef M68000
			register_use (&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE);
			register_use (&instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE);
#else
			register_use_2
				(&instruction->instruction_parameters[0].parameter_data.ir->a_reg,USE,
				 &instruction->instruction_parameters[0].parameter_data.ir->d_reg,USE);
#endif
	}
}

static void instruction_usedef_usedef (struct instruction *instruction)
{
	register_use_2 (	&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF,
						&instruction->instruction_parameters[1].parameter_data.reg,USE_DEF);
}

#if defined (I486) && defined (FP_STACK_OPTIMIZATIONS)
static void instruction_fexg_usedef_usedef (struct instruction *instruction)
{
	use_2_same_type_registers (	&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF,
								&instruction->instruction_parameters[1].parameter_data.reg,USE_DEF,F_REGISTER);
}
#endif

#if ! (defined (I486) || defined (ARM))
static void instruction_mod_use_def_use (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
		{
			int reg=instruction->instruction_parameters[0].parameter_data.reg.r;
			if (is_d_register (reg)){
				if (reg!=instruction->instruction_parameters[1].parameter_data.reg.r)
					internal_error_in_function ("instruction_mode_use_def_use");
				use_2_same_type_registers
					(&instruction->instruction_parameters[1].parameter_data.reg,USE_DEF,
					 &instruction->instruction_parameters[2].parameter_data.reg,USE,
					 D_REGISTER);
				instruction->instruction_parameters[0].parameter_data.reg.r=
					instruction->instruction_parameters[1].parameter_data.reg.r;
			} else {
				register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE);
				use_2_same_type_registers
					(&instruction->instruction_parameters[1].parameter_data.reg,DEF,
					 &instruction->instruction_parameters[2].parameter_data.reg,USE,
					 D_REGISTER);
			}
			break;
		}
		case P_INDIRECT:
			register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE);
			use_2_same_type_registers
				(&instruction->instruction_parameters[1].parameter_data.reg,DEF,
				 &instruction->instruction_parameters[2].parameter_data.reg,USE,
				 D_REGISTER);
			break;
#if defined (M68000) || defined (I486) || defined (ARM)
		case P_POST_INCREMENT:
		case P_PRE_DECREMENT:
			register_use (&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF);
			use_2_same_type_registers
				(&instruction->instruction_parameters[1].parameter_data.reg,DEF,
				 &instruction->instruction_parameters[2].parameter_data.reg,USE,
				 D_REGISTER);
			break;
#endif
		default:
			use_2_same_type_registers
				(&instruction->instruction_parameters[1].parameter_data.reg,DEF,
				 &instruction->instruction_parameters[2].parameter_data.reg,USE,
				 D_REGISTER);
	}	
}
#endif

#ifdef M68000
static void instruction_movem_use_defs (struct instruction *instruction)
{
	int a_reg,a_reg_n,arity,n,a_real_reg_n,instruction_n;
	unsigned int avoid_reg_set;
	
	if (instruction->instruction_parameters[0].parameter_type!=P_INDIRECT)
		internal_error_in_function ("instruction_movem_use_defs");
		
	arity=instruction->instruction_arity;
	a_reg=instruction->instruction_parameters[0].parameter_data.reg.r;
	a_reg_n=a_reg_num (a_reg);
	
	avoid_reg_set=0;
	
	for (n=1; n<arity; ++n){
		int reg=instruction->instruction_parameters[n].parameter_data.reg.r;
		if (is_a_register (reg))
			avoid_reg_set |= ((unsigned)1 << a_reg_num (reg));
	}

	a_real_reg_n=a_reg_uses[a_reg_n].reg;
	if (a_real_reg_n<0){	
		a_real_reg_n=find_reg_not_in_set (a_reg_n,avoid_reg_set,a_reg_alloc,A_REGISTER);
		allocate_2_register (a_reg_n,a_real_reg_n,USE,a_reg_uses,a_reg_alloc,A_REGISTER);
	}

	instruction_n=instruction->instruction_parameters[0].parameter_data.reg.u>>1;
	a_reg_uses[a_reg_n].instruction_n=instruction_n;

	a_reg_alloc[a_real_reg_n].instruction_n =
		(a_reg_uses[a_real_reg_n].instruction_n>instruction_n)
		? a_reg_uses[a_real_reg_n].instruction_n : instruction_n;

	a_reg_alloc[a_real_reg_n].value_used=
		instruction->instruction_parameters[0].parameter_data.reg.u & 1;

	instruction->instruction_parameters[0].parameter_data.reg.r=num_to_a_reg (a_real_reg_n);
	
	for (n=1; n<arity; ++n){
		int reg=instruction->instruction_parameters[n].parameter_data.reg.r;
		
		if (is_d_register (reg))
			register_use (&instruction->instruction_parameters[n].parameter_data.reg,DEF);
		else {
			int reg,reg_n,real_reg_n,instruction_n;
			struct parameter *parameter;
			
			parameter=&instruction->instruction_parameters[n];
			reg=parameter->parameter_data.reg.r;
			reg_n=a_reg_num (reg);
	
			real_reg_n=a_reg_uses[reg_n].reg;
			if (real_reg_n<0) {
				int avoid_real_reg_n;
				
				avoid_real_reg_n = a_reg_n<8 ? a_reg_n : a_reg_uses [a_reg_n].reg;		
		
				real_reg_n=find_non_reg_2_register (reg_n,avoid_real_reg_n,a_reg_alloc,
													A_REGISTER);
				allocate_2_register (reg_n,real_reg_n,DEF,a_reg_uses,a_reg_alloc,A_REGISTER);
			}
	
			instruction_n=parameter->parameter_data.reg.u>>1;
			a_reg_uses[reg_n].instruction_n=instruction_n;

			a_reg_alloc[real_reg_n].instruction_n =
				(a_reg_uses[real_reg_n].instruction_n>instruction_n)
				? a_reg_uses[real_reg_n].instruction_n : instruction_n;
	
			a_reg_alloc[real_reg_n].value_used=parameter->parameter_data.reg.u & 1;
			a_reg_alloc[real_reg_n].altered=1;
	
			parameter->parameter_data.reg.r=num_to_a_reg (real_reg_n);
		}
	}
}

static void instruction_bmove_use_use_use (struct instruction *instruction)
{
	use_2_same_type_registers
		(&instruction->instruction_parameters[0].parameter_data.reg,USE,
		 &instruction->instruction_parameters[1].parameter_data.reg,USE,A_REGISTER);
	register_use (&instruction->instruction_parameters[2].parameter_data.reg,USE);
}
#endif

# ifdef I486_USE_SCRATCH_REGISTER
static void use_scratch_register (void)
{
	int reg,real_reg_n,instruction_n;
	struct scratch_register_next_uses *scratch_register_next_use;

	scratch_register_next_use=scratch_register_next_uses;
	scratch_register_next_uses=scratch_register_next_use->scratch_register_next;
	
	reg=-3;
	
	real_reg_n=r_reg_uses[reg].reg;
	if (real_reg_n<0){
		real_reg_n=find_register (reg,r_reg_alloc,D_REGISTER);
		allocate_2_register (reg,real_reg_n,DEF,r_reg_uses,r_reg_alloc,D_REGISTER);
	}

	instruction_n=scratch_register_next_use->scratch_register_u>>1;
	r_reg_uses[reg].instruction_n=instruction_n;
	
	r_reg_alloc[real_reg_n].instruction_n =
		(r_reg_uses[real_reg_n-N_REAL_A_REGISTERS].instruction_n>instruction_n)
		? r_reg_uses[real_reg_n-N_REAL_A_REGISTERS].instruction_n : instruction_n;

	r_reg_alloc[real_reg_n].value_used=scratch_register_next_use->scratch_register_u & 1;
	r_reg_alloc[real_reg_n].altered=1;

	scratch_register_next_use->scratch_register_next=scratch_register_free_list;
	scratch_register_free_list=scratch_register_next_use;
	
	allocate_scratch_register=0;
}
#endif

static void allocate_registers (struct basic_block *basic_block)
{
	struct instruction *instruction;
	
	current_block=basic_block;
	previous_instruction=NULL;
	
	instruction=basic_block->block_instructions;

#ifdef THREAD32
	allocate_scratch_register = basic_block->block_n_new_heap_cells==0;
#endif

	while (instruction!=NULL){
		switch (instruction->instruction_icode){
			case IADD:	case IAND:
#ifndef I486_USE_SCRATCH_REGISTER
			case IASR:	case ILSL:	case ILSR:
			case IDIV:
# if defined (I486) || defined (ARM)
#  ifndef ARM
			case IROTL:
#  endif
			case IROTR:
# endif
#endif
#if ((defined (I486) || defined (ARM)) && !defined (I486_USE_SCRATCH_REGISTER)) || defined (G_POWER)
			case IDIVU:
#endif
			case IEOR:
			case IFADD:	case IFCMP:	case IFDIV:	case IFMUL:	case IFREM:	case IFSUB:
			case IMUL:	case IOR:	case ISUB:
#if defined (sparc) || defined (ARM)
			case IADDO:	case ISUBO:
#endif
#if defined (G_POWER) || (defined (ARM) && defined (G_A64))
			case IUMULH:
#endif
#if defined (I486) || defined (ARM)
			case IADC:	case ISBB:
#endif
				instruction_use_2 (instruction,USE_DEF);
				break;
#ifdef I486_USE_SCRATCH_REGISTER
			case IASR:	case ILSL:	case ILSR:	case IROTR:
# ifndef ARM
			case IROTL:
# endif
				if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE){
					use_scratch_register();
					instruction_use_2 (instruction,USE_DEF);
					allocate_scratch_register=1;
				} else
					instruction_use_2 (instruction,USE_DEF);
				break;
			case IDIV:	case IREM:	case IDIVU:	case IREMU:
# ifndef THREAD32
				use_scratch_register();
				instruction_use_2 (instruction,USE_DEF);
				allocate_scratch_register=1;
# else
				if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE)
					use_3_same_type_registers
						(&instruction->instruction_parameters[0].parameter_data.reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.reg,USE_DEF,
						 &instruction->instruction_parameters[2].parameter_data.reg,DEF,D_REGISTER);
				else
					use_2_same_type_registers
						(&instruction->instruction_parameters[1].parameter_data.reg,USE_DEF,
						 &instruction->instruction_parameters[2].parameter_data.reg,DEF,D_REGISTER);
#  endif
				break;
#endif
			case ICMP:
#ifdef I486
			case ITST:
#endif
#ifdef M68000
			case ICMPW:
#endif
IF_G_POWER (case ICMPLW:)
				instruction_use_2 (instruction,USE);
				break;
#ifdef I486_USE_SCRATCH_REGISTER
			case IMOVE:
				if ((instruction->instruction_parameters[0].parameter_type==P_INDIRECT ||
					 instruction->instruction_parameters[0].parameter_type==P_INDEXED) &&
					(instruction->instruction_parameters[1].parameter_type==P_INDIRECT ||
					 instruction->instruction_parameters[1].parameter_type==P_INDEXED))
					use_scratch_register();
#if 1
				if (instruction->instruction_parameters[1].parameter_type==P_REGISTER ||
					instruction->instruction_parameters[1].parameter_type==P_F_REGISTER)
					instruction_use_def_reg (instruction);
				else
#endif
				instruction_use_2 (instruction,DEF);
				allocate_scratch_register=1;
				break;
#endif
			case IFMOVE:	case IFMOVEL:	case ILEA:
#ifndef I486_USE_SCRATCH_REGISTER
			case IMOVE:
#endif
			case IMOVEB:	case IMOVEDB:
#ifdef G_A64
			case IMOVEQB:
#endif
#ifndef ARM
			case IFCOS:		case IFSIN:
#endif
			case IFTAN:
#ifdef M68000
			case IFACOS:	case IFASIN:	case IFATAN:	case IFEXP:		case IFLN:		case IFLOG10:	
#endif
			case IFNEG:
#if !defined (G_POWER)
			case IFSQRT:	
#endif
			case IFABS:
IF_G_SPARC (case IFMOVEHI:	case IFMOVELO:)
IF_G_RISC (case IADDI: case ILSLI:)
#ifdef G_A64
			case ILOADSQB:
#endif
#ifdef G_AI64
			case IFCVT2S:
#endif
#if defined (I486) || defined (ARM)
			case IFLOADS:	case IFMOVES:
#endif
#if 1
				if (instruction->instruction_parameters[1].parameter_type==P_REGISTER ||
					instruction->instruction_parameters[1].parameter_type==P_F_REGISTER)
					instruction_use_def_reg (instruction);
				else
#endif
				instruction_use_2 (instruction,DEF);
				break;
			case IFTST:
#ifndef I486
			case ITST:
#endif
				instruction_use (instruction);
				break;
			case IEXT:
#if defined (M68000) || defined (G_POWER)
			case IEXTB:
#endif
			case INEG:
#if defined (I486) || defined (ARM) || defined (G_POWER)
			case INOT:
#endif
				instruction_usedef (instruction);
				break;
			case ISEQ:	case ISGE:	case ISGT:	case ISLE:	case ISLT:	case ISNE:
			case ISO:	case ISGEU:	case ISGTU:	case ISLEU:	case ISLTU:	case ISNO:
				do_not_alter_condition_codes=1;
				instruction_def (instruction);
				do_not_alter_condition_codes=0;
				break;
			case IFSEQ:	case IFSGE:	case IFSGT:	case IFSLE:	case IFSLT:	case IFSNE:
#if defined (I486) && !defined (G_A64)
			case IFCEQ:	case IFCGE:	case IFCGT:	case IFCLE:	case IFCLT:	case IFCNE:
#endif
				instruction_def (instruction);
				break;
#ifndef ARM
			case IEXG:
				instruction_usedef_usedef (instruction);
				break;
#endif
#if defined (I486) || (defined (ARM) && !defined (G_A64))
			case IMULUD:
# ifdef THREAD32
				use_3_same_type_registers
					(&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF,
					 &instruction->instruction_parameters[1].parameter_data.reg,USE_DEF,
					 &instruction->instruction_parameters[2].parameter_data.reg,DEF,D_REGISTER);
# else
#  ifdef I486_USE_SCRATCH_REGISTER
				use_scratch_register();
#  endif
				instruction_usedef_usedef (instruction);				
#  ifdef I486_USE_SCRATCH_REGISTER
				allocate_scratch_register=1;
#  endif
# endif
				break;
#endif
#if defined (I486) && defined (FP_STACK_OPTIMIZATIONS)
			case IFEXG:
				instruction_fexg_usedef_usedef (instruction);
				break;			
#endif

#ifdef I486
			case IASR_S: case ILSL_S: case ILSR_S: case IROTL_S: ITOTR_S:
				use_3_same_type_registers
					(&instruction->instruction_parameters[0].parameter_data.reg,USE,
					 &instruction->instruction_parameters[1].parameter_data.reg,USE_DEF,
					 &instruction->instruction_parameters[2].parameter_data.reg,DEF,D_REGISTER);
				break;
#endif
#ifndef I486_USE_SCRATCH_REGISTER
			case IREM:
# if defined (I486) || defined (ARM) || defined (G_POWER)
#  if defined (I486) || defined (ARM)
			case IREMU:
#  endif
				instruction_use_2 (instruction,USE_DEF);
# else
				instruction_mod_use_def_use (instruction);
# endif
				break;
#endif
#if defined (I486) || defined (ARM)
			case IDIVI:	case IREMI:
# ifndef THREAD32
#  ifdef I486_USE_SCRATCH_REGISTER
				use_scratch_register();
#  endif
				register_use_2
					(&instruction->instruction_parameters[1].parameter_data.reg,USE_DEF,
					 &instruction->instruction_parameters[2].parameter_data.reg,DEF);
#  ifdef I486_USE_SCRATCH_REGISTER
				allocate_scratch_register=1;
#  endif
# else
				use_3_same_type_registers
					(&instruction->instruction_parameters[1].parameter_data.reg,USE_DEF,
					 &instruction->instruction_parameters[2].parameter_data.reg,DEF,
					 &instruction->instruction_parameters[3].parameter_data.reg,DEF,D_REGISTER);
# endif
				break;
#endif
#ifdef M68000
			case IMOVEM:
				instruction_movem_use_defs (instruction);
				break;
			case IBMOVE:
				instruction_bmove_use_use_use (instruction);
				break;
#endif
#ifdef I486
			case IDIVDU:
# if defined (I486_USE_SCRATCH_REGISTER) && !defined (THREAD32)
				use_scratch_register();
# endif
				use_3_same_type_registers
					(&instruction->instruction_parameters[0].parameter_data.reg,USE,
					 &instruction->instruction_parameters[1].parameter_data.reg,USE_DEF,
					 &instruction->instruction_parameters[2].parameter_data.reg,USE_DEF,D_REGISTER);
# if defined (I486_USE_SCRATCH_REGISTER) && !defined (THREAD32)
				allocate_scratch_register=1;
# endif
				break;
#endif
#if defined (I486) || defined (ARM)
			case IFLOORDIV:	case IMOD:
				if (instruction->instruction_arity==4)
					use_3_same_type_registers
						(&instruction->instruction_parameters[0].parameter_data.reg,DEF,
						 &instruction->instruction_parameters[1].parameter_data.reg,USE_DEF,
						 &instruction->instruction_parameters[2].parameter_data.reg,DEF,D_REGISTER);
				else
					use_3_same_type_registers
						(&instruction->instruction_parameters[0].parameter_data.reg,USE,
						 &instruction->instruction_parameters[1].parameter_data.reg,USE_DEF,
						 &instruction->instruction_parameters[2].parameter_data.reg,DEF,D_REGISTER);
				break;
#endif
#if defined (I486) || defined (ARM)
			case ICLZB:
				instruction_use_2 (instruction,DEF);
				break;
#endif
#if 0
			case IFBEQ:	case IFBGE: case IFBGT:	case IFBLE:	case IFBLT:	case IFBNE:
				use_scratch_register();
				allocate_scratch_register=1;
				break;
#endif
			/*
			case IRTS:	case IJMP:	case IJSR:
				break;
			*/
			case IBEQ:	case IBGE:	case IBGT:	case IBLE:	case IBLT:	case IBNE:
			case IBO:	case IBGEU:	case IBGTU:	case IBLEU:	case IBLTU:	case IBNO:
				break;
#if defined (I486) && !defined (G_A64)
			case IFSINCOS:
				use_2_same_type_registers
					(&instruction->instruction_parameters[0].parameter_data.reg,USE_DEF,
					 &instruction->instruction_parameters[1].parameter_data.reg,DEF,
					 F_REGISTER);
				break;
#endif
			default:
				internal_error_in_function ("allocate_registers");
		}
		previous_instruction=instruction;
		instruction=instruction->instruction_next;
	}
}

static int load_parameter_registers (unsigned end_a_registers,unsigned end_d_registers,unsigned end_f_registers,
									 int not_alter_condition_codes_flag,int condition)
{
	int reg_n,condition_on_stack;

#ifdef NEW_R_ALLOC
	for (reg_n=0; reg_n<N_REAL_A_REGISTERS; ++reg_n)
		if (end_a_registers & ((unsigned)1<<reg_n) && r_reg_uses[-(reg_n+1)].reg<0)
			i_move_id_r (r_reg_uses[-(reg_n+1)].offset,B_STACK_POINTER,num_to_a_reg (reg_n));
					
	for (reg_n=0; reg_n<8; ++reg_n)
		if (end_d_registers & ((unsigned)1<<reg_n) && r_reg_uses[reg_n].reg<0)
			i_move_id_r (r_reg_uses[reg_n].offset,B_STACK_POINTER,num_to_d_reg (reg_n));
#else
	for (reg_n=0; reg_n<8; ++reg_n)
		if (end_a_registers & ((unsigned)1<<reg_n) && a_reg_uses[reg_n].reg<0)
			i_move_id_r (a_reg_uses[reg_n].offset,B_STACK_POINTER,num_to_a_reg (reg_n));
					
	for (reg_n=0; reg_n<8; ++reg_n)
		if (end_d_registers & ((unsigned)1<<reg_n) && d_reg_uses[reg_n].reg<0)
# ifdef M68000
			if (not_alter_condition_codes_flag)
				i_movem_id_r (d_reg_uses[reg_n].offset,B_STACK_POINTER,num_to_d_reg (reg_n));
			else
# endif
				i_move_id_r (d_reg_uses[reg_n].offset,B_STACK_POINTER,num_to_d_reg (reg_n));
#endif

	condition_on_stack=0;
	for (reg_n=0; reg_n<8; ++reg_n)
		if (end_f_registers & ((unsigned)1<<reg_n) && f_reg_uses[reg_n].reg<0){
#ifdef M68000
			if (not_alter_condition_codes_flag>1 && !condition_on_stack){
				condition_on_stack=1;
				instruction_pd (condition_to_set_instruction[condition],REGISTER_A7);
			}
#endif
			i_fmove_id_fr (f_reg_uses[reg_n].offset,B_STACK_POINTER,reg_n);
		}
		
	return condition_on_stack;
}

int do_register_allocation 
	(struct instruction *last_instruction,struct basic_block *basic_block,
	int highest_a_register,int highest_d_register,int highest_f_register,
	int not_alter_condition_codes_flag,int condition)
{
	int condition_on_stack;
#ifdef NEW_R_ALLOC
	struct register_use *r_reg_uses_block;
#endif

#ifdef F_REG_15
	if (highest_a_register<=N_REAL_A_REGISTERS && highest_d_register<=8 && highest_f_register<=15)
#else
	if (highest_a_register<=N_REAL_A_REGISTERS && highest_d_register<=8 && highest_f_register<=8)
#endif
		return 0;

	do_not_alter_condition_codes=0;

#if !(defined (I486) || defined (ARM))	
	end_d_registers |= ((unsigned)1<<d_reg_num (REGISTER_D7));
#endif

	if (parallel_flag)
		end_d_registers |= ((unsigned)1<<d_reg_num (REGISTER_D6));

#ifdef MORE_PARAMETER_REGISTERS
	if (end_d_registers & ((unsigned)1<<d_reg_num (REGISTER_D2))){
		if (end_d_registers & ((unsigned)1<<d_reg_num (REGISTER_D3)))
			end_a_registers |= ((unsigned)1<<a_reg_num (REGISTER_A0)) | ((unsigned)1<<a_reg_num (REGISTER_A1));
		else
			end_a_registers |= ((unsigned)1<<a_reg_num (REGISTER_A1));
		end_d_registers &= ~((unsigned)(2|1)<<d_reg_num (REGISTER_D2));
	}
#endif

	end_a_registers |= ((unsigned)1<<a_reg_num (A_STACK_POINTER)) |
					   ((unsigned)1<<a_reg_num (B_STACK_POINTER)) |
#if !(defined (I486) || defined (ARM))
					   ((unsigned)1<<a_reg_num (REGISTER_A5)) |
#endif
#ifdef G_POWER
					   ((unsigned)1<<a_reg_num (REGISTER_A7)) |
					   ((unsigned)1<<a_reg_num (REGISTER_A8)) |
					   ((unsigned)1<<a_reg_num (REGISTER_A9)) |
					   ((unsigned)1<<a_reg_num (REGISTER_A10)) |
#endif
#ifndef THREAD32
					   ((unsigned)1<<a_reg_num (HEAP_POINTER));
#else
						0;
#endif

#ifdef THREAD32
	if (basic_block->block_n_new_heap_cells!=0)
		end_a_registers |= ((unsigned)1<<a_reg_num (HEAP_POINTER));
#endif

#ifdef NEW_R_ALLOC
	r_reg_uses_block=(struct register_use*)memory_allocate ((highest_a_register+highest_d_register) * sizeof (struct register_use));
	r_reg_uses=r_reg_uses_block+highest_a_register;

	initialize_a_register_uses (r_reg_uses,highest_a_register,end_a_registers);
	initialize_register_uses (r_reg_uses,highest_d_register,end_d_registers);
#else
	a_reg_uses=(struct register_use*)memory_allocate (highest_a_register * sizeof (struct register_use));
	d_reg_uses=(struct register_use*)memory_allocate (highest_d_register * sizeof (struct register_use));

	initialize_register_uses (a_reg_uses,highest_a_register,end_a_registers);
	initialize_register_uses (d_reg_uses,highest_d_register,end_d_registers);
#endif

#ifdef F_REG_15
	{
	int max_15_and_highest_f_register;

	max_15_and_highest_f_register=highest_f_register>15 ? highest_f_register : 15;

	f_reg_uses=(struct register_use*)memory_allocate (max_15_and_highest_f_register * sizeof (struct register_use));
	initialize_register_uses (f_reg_uses,max_15_and_highest_f_register,end_f_registers);
	}
#else
	f_reg_uses=(struct register_use*)memory_allocate (highest_f_register * sizeof (struct register_use));
	initialize_register_uses (f_reg_uses,highest_f_register,end_f_registers);
#endif

#ifdef I486_USE_SCRATCH_REGISTER
	scratch_register_next_uses=NULL;
	allocate_scratch_register=1;
#endif

	store_next_uses (last_instruction);
	
	initialize_register_allocation();
	
	allocate_registers (basic_block);
	
	condition_on_stack=load_parameter_registers (end_a_registers,end_d_registers,end_f_registers,not_alter_condition_codes_flag,condition);

	memory_free (f_reg_uses);
#ifdef NEW_R_ALLOC
	memory_free (r_reg_uses_block);
#else
	memory_free (a_reg_uses);
	memory_free (d_reg_uses);
#endif
	
	return condition_on_stack;
}
