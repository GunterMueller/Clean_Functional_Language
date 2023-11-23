/*
	File:	cgstack.c
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
#include "cgconst.h"
#include "cgrconst.h"
#include "cgtypes.h"

#include "cgstack.h"

#include "cg.h"
#include "cglin.h"
#include "cgcalc.h"
#include "cgopt.h"
#include "cgcode.h"

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

#ifndef G_A64
# define g_fhighlow(gh,gl,gf) \
	(gh)=g_instruction_2 (GFHIGH,(gf),NULL); \
	(gl)=g_instruction_2 (GFLOW,(gf),(gh)); \
	(gh)->instruction_parameters[1].p=(gl)
#endif

#define	ELEMENT_MAY_BE_REMOVED			1
#define	ELEMENT_USED_BEFORE_JSR			2
#define	ELEMENT_MUST_BE_REMOVED			4
#define	BEGIN_ELEMENT_MUST_BE_REMOVED	8

struct stack {
	struct stack *		stack_next;
	WORD				stack_offset;
	WORD				stack_flags;
	INSTRUCTION_GRAPH	stack_graph;
	INSTRUCTION_GRAPH	stack_load_graph;
};

struct a_stack {
	struct a_stack *	a_stack_next;
	WORD				a_stack_offset;
	WORD				a_stack_flags;
	INSTRUCTION_GRAPH	a_stack_graph;
	INSTRUCTION_GRAPH	a_stack_load_graph;
};

struct b_stack {
	struct b_stack *	b_stack_next;
	WORD				b_stack_offset;
	WORD				b_stack_flags;
	INSTRUCTION_GRAPH	b_stack_graph;
	INSTRUCTION_GRAPH	b_stack_load_graph;
};

/* from cgcode */

struct block_graph global_block;
	
extern struct basic_block *last_block;
extern struct instruction *last_instruction;

/* from cgopt.c */
extern unsigned int end_a_registers,end_d_registers,end_f_registers;

/* from cglin.c */
extern int local_data_offset;

#define allocate_struct_from_heap(a) (struct a*)allocate_memory_from_heap(sizeof (struct a))

INSTRUCTION_GRAPH s_get_a (int offset)
{
	register struct a_stack **element_h,*element_p,*new_element;
	register int required_offset;
	INSTRUCTION_GRAPH graph;
	
	required_offset=global_block.block_graph_a_stack_top_offset+offset;
	
	element_h=&global_block.block_graph_a_stack;
	while ((element_p=*element_h)!=NULL){
		register int element_offset=element_p->a_stack_offset;
		
		if (element_offset==required_offset)
			return element_p->a_stack_graph;
			
		if (element_offset>required_offset)
			break;
			
		element_h=&element_p->a_stack_next;
	}
	
	graph=g_load
		(-((required_offset+global_block.block_graph_a_stack_begin_displacement+1)<<STACK_ELEMENT_LOG_SIZE),A_STACK_POINTER);
	
	new_element=allocate_struct_from_heap (a_stack);
	new_element->a_stack_offset=required_offset;
	new_element->a_stack_flags=0;
	new_element->a_stack_graph=graph;
	new_element->a_stack_load_graph=graph;
	
	new_element->a_stack_next=*element_h;
	*element_h=new_element;
	
	return graph;
}

static void s_put_a_l (int offset,INSTRUCTION_GRAPH graph,INSTRUCTION_GRAPH new_load_graph)
{
	register struct a_stack *element_p,**element_h,*new_element;
	register int required_offset;
	
	required_offset=global_block.block_graph_a_stack_top_offset+offset;
	
	element_h=&global_block.block_graph_a_stack;
	while ((element_p=*element_h)!=NULL){
		int element_offset=element_p->a_stack_offset;
		
		if (element_offset==required_offset){
			element_p->a_stack_graph=graph;
			return;
		}
			
		if (element_offset>required_offset)
			break;
			
		element_h=&element_p->a_stack_next;
	}
	
	new_element=allocate_struct_from_heap (a_stack);
	new_element->a_stack_offset=required_offset;
	new_element->a_stack_flags=0;
	new_element->a_stack_graph=graph;
	new_element->a_stack_load_graph=new_load_graph;
	
	new_element->a_stack_next=*element_h;
	*element_h=new_element;
}

void s_put_a (int offset,INSTRUCTION_GRAPH graph)
{
	s_put_a_l (offset,graph,NULL);
}

void s_push_a (INSTRUCTION_GRAPH graph)
{
	--global_block.block_graph_a_stack_top_offset;
	s_put_a (0,graph);
}

INSTRUCTION_GRAPH s_pop_a (VOID)
{
	INSTRUCTION_GRAPH graph;
	
	graph=s_get_a (0);
	++global_block.block_graph_a_stack_top_offset;
	
	return graph;
}

void s_remove_a (VOID)
{
	++global_block.block_graph_a_stack_top_offset;
}

void release_a_stack (VOID)
{
	register int n;
	
	global_block.block_graph_a_stack=NULL;
	for (n=0; n<N_ADDRESS_PARAMETER_REGISTERS; ++n)
		global_block.block_graph_a_register_parameter_node[n]=NULL;
		
	global_block.block_graph_begin_a_stack_size=0;
	global_block.block_graph_a_stack_top_offset=0;
	global_block.block_graph_a_stack_begin_displacement=0;
	global_block.block_graph_a_stack_end_displacement=0;
}

INSTRUCTION_GRAPH s_get_b (int offset)
{
	register struct b_stack **element_h,*element_p,*new_element;
	register int required_offset;
	INSTRUCTION_GRAPH graph;
	
	required_offset=global_block.block_graph_b_stack_top_offset+offset;
	
	element_h=&global_block.block_graph_b_stack;
	while ((element_p=*element_h)!=NULL){
		int element_offset=element_p->b_stack_offset;
		
		if (element_offset==required_offset)
			return element_p->b_stack_graph;
			
		if (element_offset>required_offset)
			break;
			
		element_h=&element_p->b_stack_next;
	}
	
	graph=g_load
		((required_offset+global_block.block_graph_b_stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
	
	new_element=allocate_struct_from_heap (b_stack);
	new_element->b_stack_offset=required_offset;
	new_element->b_stack_flags=0;
	new_element->b_stack_graph=graph;
	new_element->b_stack_load_graph=graph;
	
	new_element->b_stack_next=*element_h;
	*element_h=new_element;
	
	return graph;
}

static void s_put_b_l (int offset,INSTRUCTION_GRAPH graph,INSTRUCTION_GRAPH new_load_graph)
{
	register struct b_stack **element_h,*element_p,*new_element;
	register int required_offset;
	
	required_offset=global_block.block_graph_b_stack_top_offset+offset;
	
	element_h=&global_block.block_graph_b_stack;
	while ((element_p=*element_h)!=NULL){
		int element_offset=element_p->b_stack_offset;
		
		if (element_offset==required_offset){
			element_p->b_stack_graph=graph;
			return;
		}
			
		if (element_offset>required_offset)
			break;
			
		element_h=&element_p->b_stack_next;
	}
	
	new_element=allocate_struct_from_heap ( b_stack);
	new_element->b_stack_offset=required_offset;
	new_element->b_stack_flags=0;
	new_element->b_stack_graph=graph;
	new_element->b_stack_load_graph=new_load_graph;
	
	new_element->b_stack_next=*element_h;
	*element_h=new_element;
}

void s_put_b (int offset,INSTRUCTION_GRAPH graph)
{
	s_put_b_l (offset,graph,NULL);
}

void s_push_b (INSTRUCTION_GRAPH graph)
{
	--global_block.block_graph_b_stack_top_offset;
	s_put_b (0,graph);
}

INSTRUCTION_GRAPH s_pop_b (VOID)
{
	INSTRUCTION_GRAPH graph;
	
	graph=s_get_b (0);
	++global_block.block_graph_b_stack_top_offset;
	
	return graph;
}

void s_remove_b (VOID)
{
	++global_block.block_graph_b_stack_top_offset;
}

void release_b_stack (VOID)
{
	register int n;
	
	global_block.block_graph_b_stack=NULL;
	
	for (n=0; n<N_DATA_PARAMETER_REGISTERS
#ifdef MORE_PARAMETER_REGISTERS
				+ N_ADDRESS_PARAMETER_REGISTERS
#endif
		; ++n)
		global_block.block_graph_d_register_parameter_node[n]=NULL;

	for (n=0; n<N_FLOAT_PARAMETER_REGISTERS; ++n)
		global_block.block_graph_f_register_parameter_node[n]=NULL;
		
	global_block.block_graph_begin_b_stack_size=0;	
	global_block.block_graph_b_stack_top_offset=0;
	global_block.block_graph_b_stack_begin_displacement=0;
	global_block.block_graph_b_stack_end_displacement=0;
}

void init_a_stack (int a_stack_size)
{
	int n;
	
	global_block.block_graph_begin_a_stack_size=a_stack_size;
	
	if (a_stack_size>N_ADDRESS_PARAMETER_REGISTERS)
		a_stack_size=N_ADDRESS_PARAMETER_REGISTERS;
	
	last_block->block_n_begin_a_parameter_registers=a_stack_size;
	global_block.block_graph_a_stack_begin_displacement=-a_stack_size;
	
	for (n=0; n<a_stack_size; ++n){
		INSTRUCTION_GRAPH register_graph;
		int a_register;
		
		a_register=num_to_a_reg (a_stack_size-1-n);
		
		register_graph=g_register (a_register);
		s_put_a_l (n,register_graph,register_graph);
	}
}

void init_b_stack (int b_stack_size,ULONG vector[])
{
	int offset,stack_displacement,n,all_parameters_in_registers;
	int number_of_data_register_parameters,number_of_float_register_parameters;
	int data_offsets[N_DATA_PARAMETER_REGISTERS
#ifdef MORE_PARAMETER_REGISTERS
					+ N_ADDRESS_PARAMETER_REGISTERS
#endif
					],float_offsets[N_FLOAT_PARAMETER_REGISTERS];
	
	global_block.block_graph_begin_b_stack_size=b_stack_size;
	
	number_of_data_register_parameters=0;
	number_of_float_register_parameters=0;
	
	offset=0;
	stack_displacement=0;
	all_parameters_in_registers=1;
	
	for (offset=0; offset<b_stack_size;){
		if (test_bit (vector,offset)){
			if (mc68881_flag){
				if (number_of_float_register_parameters<N_FLOAT_PARAMETER_REGISTERS){
					float_offsets [number_of_float_register_parameters++]=offset;
					
					if (all_parameters_in_registers)
#ifdef G_A64
						stack_displacement-=1;
#else
						stack_displacement-=2;
#endif
				} else {				
					INSTRUCTION_GRAPH f_graph,h_graph,l_graph;

					f_graph=g_fload ((offset+stack_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
#ifdef G_A64
					f_graph=g_fromf (f_graph);
					s_put_b_l (offset,f_graph,f_graph);
#else
					g_fhighlow (h_graph,l_graph,f_graph);

					s_put_b_l (offset+1,l_graph,l_graph);
					s_put_b_l (offset,h_graph,h_graph);
#endif		
					all_parameters_in_registers=0;
				}
			} else
				all_parameters_in_registers=0;
#ifdef G_A64
			offset+=1;
#else
			offset+=2;
#endif
		} else {
			if (number_of_data_register_parameters < (parallel_flag ? N_DATA_PARAMETER_REGISTERS-1 : N_DATA_PARAMETER_REGISTERS)){
				data_offsets [number_of_data_register_parameters++]=offset;
					
				if (all_parameters_in_registers)
					--stack_displacement;
			} else
				all_parameters_in_registers=0;
			offset+=1;
		}
	}
	
	for (n=0; n<number_of_data_register_parameters; ++n){
		INSTRUCTION_GRAPH register_graph;
	
		register_graph=g_register (num_to_d_reg (number_of_data_register_parameters-1-n));
		s_put_b_l (data_offsets[n],register_graph,register_graph);
	}

	for (n=0; n<number_of_float_register_parameters; ++n){
		INSTRUCTION_GRAPH register_graph,h_graph,l_graph;
		int offset;

		register_graph=g_fregister (number_of_float_register_parameters-1-n);

		offset=float_offsets[n];

#ifdef G_A64
		register_graph=g_fromf (register_graph);

		s_put_b_l (offset,register_graph,register_graph);
#else
		g_fhighlow (h_graph,l_graph,register_graph);
		
		s_put_b_l (offset+1,l_graph,l_graph);
		s_put_b_l (offset,h_graph,h_graph);
#endif
	}
	
	last_block->block_n_begin_d_parameter_registers=number_of_data_register_parameters;
	
	global_block.block_graph_b_stack_begin_displacement=stack_displacement;
}

#ifdef MORE_PARAMETER_REGISTERS
void init_ab_stack (int a_stack_size,int b_stack_size,ULONG vector[])
{
	int offset,stack_displacement,n,all_parameters_in_registers;
	int number_of_data_register_parameters,number_of_float_register_parameters;
	int data_offsets[N_DATA_PARAMETER_REGISTERS+N_ADDRESS_PARAMETER_REGISTERS],float_offsets[N_FLOAT_PARAMETER_REGISTERS];
	int n_data_parameter_registers,n_extra_data_parameter_registers;

	init_a_stack (a_stack_size);
	
	n_data_parameter_registers=N_DATA_PARAMETER_REGISTERS;
	n_extra_data_parameter_registers=N_ADDRESS_PARAMETER_REGISTERS-a_stack_size;
	if (n_extra_data_parameter_registers<0)
		n_extra_data_parameter_registers=0;
	
	global_block.block_graph_begin_b_stack_size=b_stack_size;
	
	number_of_data_register_parameters=0;
	number_of_float_register_parameters=0;
	
	offset=0;
	stack_displacement=0;
	all_parameters_in_registers=1;
	
	for (offset=0; offset<b_stack_size;){
		if (test_bit (vector,offset)){
			if (mc68881_flag){
				if (number_of_float_register_parameters<N_FLOAT_PARAMETER_REGISTERS){
					float_offsets [number_of_float_register_parameters++]=offset;
					
					if (all_parameters_in_registers)
#ifdef G_A64
						stack_displacement-=1;
#else
						stack_displacement-=2;
#endif
				} else {				
					INSTRUCTION_GRAPH f_graph,h_graph,l_graph;

					f_graph=g_fload ((offset+stack_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
#ifdef G_A64
					f_graph=g_fromf (f_graph);
					
					s_put_b_l (offset,f_graph,f_graph);
#else
					g_fhighlow (h_graph,l_graph,f_graph);

					s_put_b_l (offset+1,l_graph,l_graph);
					s_put_b_l (offset,h_graph,h_graph);
#endif		
					all_parameters_in_registers=0;
				}
			} else
				all_parameters_in_registers=0;
#ifdef G_A64
			offset+=1;
#else
			offset+=2;
#endif
		} else {
			if (number_of_data_register_parameters <
				(parallel_flag ? n_data_parameter_registers-1 : n_data_parameter_registers) + n_extra_data_parameter_registers)
			{
				data_offsets [number_of_data_register_parameters++]=offset;
					
				if (all_parameters_in_registers)
					--stack_displacement;
			} else
				all_parameters_in_registers=0;
			offset+=1;
		}
	}
	
	n_extra_data_parameter_registers=number_of_data_register_parameters-n_data_parameter_registers;
	if (n_extra_data_parameter_registers<0)
		n_extra_data_parameter_registers=0;
	
	for (n=0; n<number_of_data_register_parameters; ++n){
		INSTRUCTION_GRAPH register_graph;
		int d_n;
		
		d_n=(number_of_data_register_parameters-1-n)-n_extra_data_parameter_registers;
	
		if (d_n>=0)
			register_graph=g_register (num_to_d_reg (d_n));
		else
			register_graph=g_register (num_to_a_reg (N_ADDRESS_PARAMETER_REGISTERS+d_n));
		s_put_b_l (data_offsets[n],register_graph,register_graph);
	}
	
	for (n=0; n<number_of_float_register_parameters; ++n){
		INSTRUCTION_GRAPH register_graph,h_graph,l_graph;
		int offset;
	
		register_graph=g_fregister (number_of_float_register_parameters-1-n);

		offset=float_offsets[n];

#ifdef G_A64
		register_graph=g_fromf (register_graph);
		
		s_put_b_l (offset,register_graph,register_graph);
#else
		g_fhighlow (h_graph,l_graph,register_graph);

		s_put_b_l (offset+1,l_graph,l_graph);
		s_put_b_l (offset,h_graph,h_graph);
#endif
	}
	
	last_block->block_n_begin_d_parameter_registers=number_of_data_register_parameters;
	
	global_block.block_graph_b_stack_begin_displacement=stack_displacement;
}
#endif

void insert_graph_in_b_stack (INSTRUCTION_GRAPH graph,int b_stack_size,ULONG *vector)
{
	register int offset,required_offset;
	register struct b_stack **element_p,*new_element;
	INSTRUCTION_GRAPH *graph_p;
	
	required_offset=global_block.block_graph_b_stack_top_offset;

	element_p=&global_block.block_graph_b_stack;
	while (*element_p!=NULL && (*element_p)->b_stack_offset<required_offset)
		element_p=&(*element_p)->b_stack_next;
	
	for (offset=0; offset<b_stack_size; ++offset,++required_offset){
		if (test_bit (vector,offset)){
			if ((*element_p==NULL || (*element_p)->b_stack_offset>required_offset+1) && mc68881_flag){
				INSTRUCTION_GRAPH f_graph,l_graph,h_graph;
				
				f_graph=g_fload
					((required_offset+global_block.block_graph_b_stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);

#ifdef G_A64
				f_graph=g_fromf (f_graph);

				new_element=allocate_struct_from_heap (b_stack);
				new_element->b_stack_offset=required_offset;
				new_element->b_stack_flags=0;
				new_element->b_stack_graph=f_graph;
				new_element->b_stack_load_graph=f_graph;
		
				new_element->b_stack_next=*element_p;
				*element_p=new_element;

				element_p=&new_element->b_stack_next;
#else
				g_fhighlow (h_graph,l_graph,f_graph);

				new_element=allocate_struct_from_heap (b_stack);
				new_element->b_stack_offset=required_offset;
				new_element->b_stack_flags=0;
				new_element->b_stack_graph=h_graph;
				new_element->b_stack_load_graph=h_graph;
		
				new_element->b_stack_next=*element_p;
				*element_p=new_element;

				element_p=&new_element->b_stack_next;
				++offset;
				++required_offset;
						
				new_element=allocate_struct_from_heap (b_stack);
				new_element->b_stack_offset=required_offset;
				new_element->b_stack_flags=0;
				new_element->b_stack_graph=l_graph;
				new_element->b_stack_load_graph=l_graph;
		
				new_element->b_stack_next=*element_p;
				*element_p=new_element;

				element_p=&new_element->b_stack_next;
#endif
				continue;
			}
#ifndef G_A64
			else {
				if (*element_p==NULL || (*element_p)->b_stack_offset!=required_offset){
					INSTRUCTION_GRAPH load_graph;
					
					load_graph=g_load
						((required_offset+global_block.block_graph_b_stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
					
					new_element=allocate_struct_from_heap (b_stack);
					new_element->b_stack_offset=required_offset;
					new_element->b_stack_flags=0;
					new_element->b_stack_graph=load_graph;
					new_element->b_stack_load_graph=load_graph;
		
					new_element->b_stack_next=*element_p;
					*element_p=new_element;
				}
				element_p=&(*element_p)->b_stack_next;

				++offset;
				++required_offset;
			}
#endif
		}
		
		if (*element_p==NULL || (*element_p)->b_stack_offset!=required_offset){
			INSTRUCTION_GRAPH load_graph;
			
			load_graph=g_load
				((required_offset+global_block.block_graph_b_stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
			
			new_element=allocate_struct_from_heap (b_stack);
			new_element->b_stack_offset=required_offset;
			new_element->b_stack_flags=0;
			new_element->b_stack_graph=load_graph;
			new_element->b_stack_load_graph=load_graph;

			new_element->b_stack_next=*element_p;
			*element_p=new_element;
		}
		element_p=&(*element_p)->b_stack_next;
	}
	
	required_offset=global_block.block_graph_b_stack_top_offset-1;

	element_p=&global_block.block_graph_b_stack;
	while (*element_p!=NULL && (*element_p)->b_stack_offset<required_offset){
		(*element_p)->b_stack_graph=NULL;
		element_p=&(*element_p)->b_stack_next;
	}

	if (*element_p==NULL || (*element_p)->b_stack_offset!=required_offset){
		new_element=allocate_struct_from_heap (b_stack);
		new_element->b_stack_offset=required_offset;
		new_element->b_stack_flags=0;
		new_element->b_stack_load_graph=NULL;

		new_element->b_stack_next=*element_p;
		*element_p=new_element;
	}

	graph_p=&(*element_p)->b_stack_graph;
	++required_offset;
	element_p=&(*element_p)->b_stack_next;
	
	for (offset=0; offset<b_stack_size; ++offset){
		*graph_p=(*element_p)->b_stack_graph;
		graph_p=&(*element_p)->b_stack_graph;
		element_p=&(*element_p)->b_stack_next;
	}

	*graph_p=graph;

	--global_block.block_graph_b_stack_top_offset;
}

static int count_a_stack_size (struct a_stack *a_element,register int a_stack_top_offset)
{
	int a_stack_size,offset;
	
	a_stack_size=0;
		
	while (a_element!=NULL && a_element->a_stack_offset<a_stack_top_offset)
		a_element=a_element->a_stack_next;
	
	offset=a_stack_top_offset;

	while (a_element!=NULL && a_element->a_stack_offset==offset
		&& !(a_element->a_stack_flags & ELEMENT_MAY_BE_REMOVED && a_element->a_stack_graph==NULL))
	{
		++a_stack_size;	
		a_element=a_element->a_stack_next;
		++offset;
	}
	
	return a_stack_size;
}

int get_a_stack_size (VOID)
{
	return count_a_stack_size (global_block.block_graph_a_stack,global_block.block_graph_a_stack_top_offset);
}

static int count_b_stack_size (ULONG *vector_p[],struct b_stack *b_stack,int b_stack_top_offset)
{
	struct b_stack *first_b_element,*b_element;
	int b_stack_size,offset,i;
	ULONG *vector;
		
	b_stack_size=0;
	first_b_element=b_stack;
	
	while (first_b_element!=NULL && first_b_element->b_stack_offset<b_stack_top_offset)
		first_b_element=first_b_element->b_stack_next;
		
	offset=b_stack_top_offset;
	b_element=first_b_element;
	
	while (b_element!=NULL && b_element->b_stack_offset==offset
		&& !(b_element->b_stack_flags & ELEMENT_MAY_BE_REMOVED && b_element->b_stack_graph==NULL))
	{
		++b_stack_size;
		b_element=b_element->b_stack_next;
		++offset;
	}
			
	if (b_stack_size<=VECTOR_ELEMENT_SIZE)
		vector=*vector_p;
	else {
		vector=(ULONG*)fast_memory_allocate 
			(((b_stack_size+VECTOR_ELEMENT_SIZE-1)*sizeof (ULONG))>>LOG_VECTOR_ELEMENT_SIZE);
		*vector_p=vector;
	}
		
	b_element=first_b_element;
	
	for (i=0; i<b_stack_size; ){
		struct b_stack *next_b_element;
		INSTRUCTION_GRAPH graph,next_graph;
			
#ifdef G_A64
		if (i<b_stack_size && b_element->b_stack_graph->instruction_code==GFROMF)
#else
		if (i<b_stack_size-1 
			&& (graph=b_element->b_stack_graph)->instruction_code==GFHIGH
			&& (next_graph=(next_b_element=b_element->b_stack_next)->b_stack_graph)!=NULL
			&& next_graph->instruction_code==GFLOW
			&& next_graph->instruction_parameters[0].p==graph->instruction_parameters[0].p)
#endif
		{
			set_bit (vector,i);
			++i;
#ifdef G_A64
			b_element=b_element->b_stack_next;
#else
			set_bit (vector,i);
			++i;
			b_element=next_b_element->b_stack_next;
#endif
		} else {
			clear_bit (vector,i);
			++i;
			b_element=b_element->b_stack_next;
		}
	}
	
	return b_stack_size;
}

static int count_b_stack_size_2 (ULONG *vector_p[],struct b_stack *b_stack,int b_stack_top_offset)
{
	struct b_stack *first_b_element,*b_element;
	int b_stack_size,offset,i;
	ULONG *vector;
		
	b_stack_size=0;
	first_b_element=b_stack;
	
	while (first_b_element!=NULL && first_b_element->b_stack_offset<b_stack_top_offset)
		first_b_element=first_b_element->b_stack_next;
		
	offset=b_stack_top_offset;
	b_element=first_b_element;
	
	while (b_element!=NULL && b_element->b_stack_offset==offset
		&& b_element->b_stack_graph!=NULL
		&& b_element->b_stack_flags & ELEMENT_USED_BEFORE_JSR
			/*(b_element->b_stack_graph->node_mark==2
			|| ((b_element->b_stack_graph->instruction_code==GFHIGH
				 || b_element->b_stack_graph->instruction_code==GFLOW)
				&& b_element->b_stack_graph->instruction_parameters[0].p->node_mark==2)) */
		&& !((b_element->b_stack_flags & ELEMENT_MAY_BE_REMOVED)
			 && b_element->b_stack_graph==NULL))
	{
		++b_stack_size;
		b_element=b_element->b_stack_next;
		++offset;
	}
	
	if (b_stack_size<=VECTOR_ELEMENT_SIZE)
		vector=*vector_p;
	else {
		vector=(ULONG*)fast_memory_allocate 
			(((b_stack_size+VECTOR_ELEMENT_SIZE-1)*sizeof (ULONG))>>LOG_VECTOR_ELEMENT_SIZE);
		*vector_p=vector;
	}
		
	b_element=first_b_element;

	for (i=0; i<b_stack_size; ){
		struct b_stack *next_b_element;
		INSTRUCTION_GRAPH graph,next_graph;
		
#ifdef G_A64
		if (i<b_stack_size
			&& (graph=b_element->b_stack_graph)!=NULL
			&& graph->instruction_code==GFROMF)
#else
		if (i<b_stack_size-1 
			&& (graph=b_element->b_stack_graph)!=NULL
			&& graph->instruction_code==GFHIGH
			&& (next_graph=(next_b_element=b_element->b_stack_next)->b_stack_graph)!=NULL
			&& next_graph->instruction_code==GFLOW
			&& next_graph->instruction_parameters[0].p==graph->instruction_parameters[0].p)
#endif
		{
			set_bit (vector,i);
			++i;
#ifdef G_A64
			b_element=b_element->b_stack_next;
#else
			set_bit (vector,i);
			++i;
			b_element=next_b_element->b_stack_next;
#endif
		} else {
			clear_bit (vector,i);
			++i;
			b_element=b_element->b_stack_next;
		}
	}
	
	return b_stack_size;
}

int get_b_stack_size (ULONG *vector_p[])
{
	return count_b_stack_size (vector_p,global_block.block_graph_b_stack,global_block.block_graph_b_stack_top_offset);
}

static void a_stack_load_register_values (int n_parameters,int n_address_parameter_registers)
{
	struct a_stack **element_p;
	int parameter_n;
	
	if (n_parameters>n_address_parameter_registers)
		n_parameters=n_address_parameter_registers;
	
	element_p=&global_block.block_graph_a_stack;
	for (parameter_n=0; parameter_n<n_parameters; ++parameter_n){
		struct a_stack *new_element;
		int required_offset;
		INSTRUCTION_GRAPH graph;
		
		required_offset=global_block.block_graph_a_stack_top_offset+parameter_n;
		
		while (*element_p!=NULL && (*element_p)->a_stack_offset<required_offset)
			element_p=&(*element_p)->a_stack_next;
		
		if (*element_p!=NULL && (*element_p)->a_stack_offset==required_offset){
			struct a_stack *element;
			
			element=*element_p;
			if (element->a_stack_flags & ELEMENT_MAY_BE_REMOVED && element->a_stack_graph==NULL){
				graph=g_load
					((-(1+required_offset+global_block.block_graph_a_stack_begin_displacement))<<STACK_ELEMENT_LOG_SIZE,A_STACK_POINTER);
				element->a_stack_graph=graph;
				element->a_stack_load_graph=graph;
			}
			element_p=&(*element_p)->a_stack_next;
		} else {
			graph=g_load
				((-(1+required_offset+global_block.block_graph_a_stack_begin_displacement))<<STACK_ELEMENT_LOG_SIZE,A_STACK_POINTER);
			
			new_element=allocate_struct_from_heap (a_stack);
			new_element->a_stack_offset=required_offset;
			new_element->a_stack_flags=0;
			new_element->a_stack_graph=graph;
			new_element->a_stack_load_graph=graph;
			
			new_element->a_stack_next=*element_p;
			*element_p=new_element;
			element_p=&new_element->a_stack_next;
		}
	}
}

static void a_stack_stores (int n_parameters,int n_address_parameter_registers)
{
	register struct a_stack *a_element;
	
	end_a_registers=0;
	
	if (n_parameters>n_address_parameter_registers)
		n_parameters=n_address_parameter_registers;
	
	global_block.block_graph_a_stack_end_displacement=n_parameters;
	
	for_l (a_element,global_block.block_graph_a_stack,a_stack_next)
		if (a_element->a_stack_graph!=NULL){
			if (a_element->a_stack_offset<global_block.block_graph_a_stack_top_offset)
				a_element->a_stack_graph=NULL;
			else {
				if (a_element->a_stack_offset-global_block.block_graph_a_stack_top_offset<n_parameters){
					register int register_number;
					
					register_number=n_parameters-1-(a_element->a_stack_offset-global_block.block_graph_a_stack_top_offset);
	
					a_element->a_stack_graph=
						g_store_r (num_to_a_reg (register_number),a_element->a_stack_graph);
						
					end_a_registers |= ((unsigned)1<<register_number);
				} else {
					if (a_element->a_stack_graph==a_element->a_stack_load_graph
						&& a_element->a_stack_load_graph->instruction_code!=GREGISTER
					)
						a_element->a_stack_graph=NULL;
					else {
						INSTRUCTION_GRAPH l_graph;
			
						l_graph=a_element->a_stack_graph;
						
						while (l_graph->instruction_code==GFILL)
							l_graph=l_graph->instruction_parameters[0].p;
						
						if (l_graph!=a_element->a_stack_load_graph 
							|| a_element->a_stack_load_graph->instruction_code==GREGISTER
						)
							a_element->a_stack_graph=g_store (
								(-(1+a_element->a_stack_offset+global_block.block_graph_a_stack_begin_displacement))<<STACK_ELEMENT_LOG_SIZE,
								A_STACK_POINTER,a_element->a_stack_graph,
								a_element->a_stack_load_graph
							);
					}
				}
			}
	}
}

static int set_basic_block_begin_a_registers
   (struct a_stack **element_p,int n_a_registers,INSTRUCTION_GRAPH a_register_parameter_node[])
{
	int offset;
	
	while (*element_p!=NULL && (*element_p)->a_stack_offset<0)
		element_p=&(*element_p)->a_stack_next;
	
	for (offset=0; offset<n_a_registers; ++offset){
		INSTRUCTION_GRAPH graph;
				
		if (*element_p!=NULL && (*element_p)->a_stack_offset==offset){
			struct a_stack *element;
			
			element=*element_p;
			
			if (element->a_stack_flags & ELEMENT_MAY_BE_REMOVED && element->a_stack_graph==NULL){
				graph=g_new_node (GREGISTER,0,sizeof (union instruction_parameter));
				graph->instruction_parameters[0].i=num_to_a_reg (n_a_registers-1-offset);
				
				a_register_parameter_node[n_a_registers-1-offset]=graph;
			
				element->a_stack_graph=graph;
				element->a_stack_load_graph=graph;
			} else {
				graph=element->a_stack_load_graph;
				if (graph!=NULL){
					graph->instruction_code=GREGISTER;
					graph->inode_arity=0;
					graph->instruction_parameters[0].i=num_to_a_reg (n_a_registers-1-offset);

					a_register_parameter_node[n_a_registers-1-offset]=graph;
				} else
					a_register_parameter_node[n_a_registers-1-offset]=NULL;
			}
			
			element_p=&(*element_p)->a_stack_next;
		} else {			
			struct a_stack *new_element;
			
			graph=g_new_node (GREGISTER,0,sizeof (union instruction_parameter));
			graph->instruction_parameters[0].i=num_to_a_reg (n_a_registers-1-offset);
	
			a_register_parameter_node[n_a_registers-1-offset]=graph;
			
			new_element=allocate_struct_from_heap (a_stack);
			new_element->a_stack_offset=offset;
			new_element->a_stack_flags=0;
			new_element->a_stack_graph=graph;
			new_element->a_stack_load_graph=graph;
			
			new_element->a_stack_next=*element_p;
			*element_p=new_element;
			element_p=&new_element->a_stack_next;
		}
	}
	
	return -n_a_registers;
}

static void compute_a_load_offsets (register struct a_stack *a_element,int offset)
{
	for (; a_element!=NULL; a_element=a_element->a_stack_next){
		register INSTRUCTION_GRAPH load_graph;
		
		load_graph=a_element->a_stack_load_graph;
		if (load_graph!=NULL)
			switch (load_graph->instruction_code){
				case GLOAD:
					load_graph->instruction_parameters[0].i= -((1+a_element->a_stack_offset)<<STACK_ELEMENT_LOG_SIZE)-offset;
					break;
				case GREGISTER:
					break;
				default:
					internal_error_in_function ("compute_a_load_offsets");
			}
	}
}

static void b_stack_load_register_values (int n_parameters,ULONG vector[],int n_data_parameter_registers
#ifdef MORE_PARAMETER_REGISTERS
					,int n_extra_data_parameter_registers
#endif
								)
{
	struct b_stack **element_p;
	int parameter_n;
	int number_of_d_register_parameters,number_of_f_register_parameters_m_2;
	
#ifdef MORE_PARAMETER_REGISTERS
	if (n_extra_data_parameter_registers<0)
		n_extra_data_parameter_registers=0;
#endif
	
	number_of_d_register_parameters=0;
	number_of_f_register_parameters_m_2=0;
	
	element_p=&global_block.block_graph_b_stack;
	for (parameter_n=0; parameter_n<n_parameters; ++parameter_n){
		struct b_stack *new_element;
		int required_offset;
		INSTRUCTION_GRAPH graph;
		
		required_offset=global_block.block_graph_b_stack_top_offset+parameter_n;
		
		while (*element_p!=NULL && (*element_p)->b_stack_offset<required_offset)
			element_p=&(*element_p)->b_stack_next;

		if (!test_bit (vector,parameter_n)
			?	number_of_d_register_parameters++ < n_data_parameter_registers
#ifdef MORE_PARAMETER_REGISTERS
												+ n_extra_data_parameter_registers
#endif
#ifndef G_A64
			:	(mc68881_flag && number_of_f_register_parameters_m_2++<(N_FLOAT_PARAMETER_REGISTERS<<1)))
#else
			:	(mc68881_flag && number_of_f_register_parameters_m_2++<N_FLOAT_PARAMETER_REGISTERS))
#endif
		{
			if (*element_p!=NULL && (*element_p)->b_stack_offset==required_offset){
				struct b_stack *element;
				
				element=*element_p;
				if (element->b_stack_flags & ELEMENT_MAY_BE_REMOVED && element->b_stack_graph==NULL){
					graph=g_load ((required_offset+global_block.block_graph_b_stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
					element->b_stack_graph=graph;
					element->b_stack_load_graph=graph;
				}
				element_p=&(*element_p)->b_stack_next;
			} else {
				graph=g_load ((required_offset+global_block.block_graph_b_stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
			
				new_element=allocate_struct_from_heap (b_stack);
				new_element->b_stack_offset=required_offset;
				new_element->b_stack_flags=0;
				new_element->b_stack_graph=graph;
				new_element->b_stack_load_graph=graph;
			
				new_element->b_stack_next=*element_p;
				*element_p=new_element;
				element_p=&new_element->b_stack_next;
			}
		}
	}
}

static void b_stack_stores (int n_parameters,ULONG vector[],int n_data_parameter_registers
#ifdef MORE_PARAMETER_REGISTERS
					,int n_extra_data_parameter_registers,
					INSTRUCTION_GRAPH a_register_parameter_nodes[],INSTRUCTION_GRAPH d_register_parameter_nodes[]
#endif
							)
{
	struct b_stack *b_element;
	int n,displacement,parameter_n;
	int number_of_d_register_parameters,number_of_f_register_parameters;
#ifdef MORE_PARAMETER_REGISTERS
	INSTRUCTION_GRAPH *d_graphs_p[N_DATA_PARAMETER_REGISTERS+N_ADDRESS_PARAMETER_REGISTERS],
						d_graphs[N_DATA_PARAMETER_REGISTERS+N_ADDRESS_PARAMETER_REGISTERS];
#else
	INSTRUCTION_GRAPH *d_graphs_p[N_DATA_PARAMETER_REGISTERS],d_graphs[N_DATA_PARAMETER_REGISTERS];
#endif
	INSTRUCTION_GRAPH *f_graphs_p[N_FLOAT_PARAMETER_REGISTERS],f_graphs[N_FLOAT_PARAMETER_REGISTERS<<1];

#ifdef MORE_PARAMETER_REGISTERS
	if (n_extra_data_parameter_registers<0)
		n_extra_data_parameter_registers=0;
#endif

	end_d_registers=0;
	end_f_registers=0;
	
	number_of_d_register_parameters=0;
	number_of_f_register_parameters=0;
	
	for_l (b_element,global_block.block_graph_b_stack,b_stack_next){
		INSTRUCTION_GRAPH graph;
		
		if (b_element->b_stack_offset<global_block.block_graph_b_stack_top_offset){
			b_element->b_stack_graph=NULL;		
			continue;
		}
		
		graph=b_element->b_stack_graph;
		
		parameter_n=b_element->b_stack_offset-global_block.block_graph_b_stack_top_offset;
		if ((unsigned)parameter_n<(unsigned)n_parameters)
			if (test_bit (vector,parameter_n)){
				if (number_of_f_register_parameters<N_FLOAT_PARAMETER_REGISTERS && mc68881_flag){
#ifdef G_A64
					f_graphs[number_of_f_register_parameters]=g_fp_arg (graph);
					f_graphs_p[number_of_f_register_parameters]=&b_element->b_stack_graph;
					++number_of_f_register_parameters;
#else
					struct b_stack *next_b_element;
					
					next_b_element=b_element->b_stack_next;
					
					if (graph==NULL || next_b_element==NULL || next_b_element->b_stack_graph==NULL)
						internal_error_in_function ("b_stack_stores");

					f_graphs[number_of_f_register_parameters]=g_fjoin (graph,next_b_element->b_stack_graph);					
					f_graphs_p[number_of_f_register_parameters]=&b_element->b_stack_graph;
					
					next_b_element->b_stack_graph=NULL;
					++number_of_f_register_parameters;
					
					b_element=next_b_element;
#endif					
					continue;
				}
			} else {
				if (number_of_d_register_parameters<n_data_parameter_registers
#ifdef MORE_PARAMETER_REGISTERS
												+ n_extra_data_parameter_registers
#endif
				){
					d_graphs[number_of_d_register_parameters]=graph;
					d_graphs_p[number_of_d_register_parameters]=&b_element->b_stack_graph;
					++number_of_d_register_parameters;
					
					continue;
				}
			}
		
		if (graph!=NULL){
			struct b_stack *next_b_element;
			INSTRUCTION_GRAPH next_graph;
#ifdef G_A64
			if (graph->instruction_code==GFROMF){
				if (graph==b_element->b_stack_load_graph &&
					graph->instruction_parameters[0].p->instruction_code!=GFREGISTER)
				{
					b_element->b_stack_graph=NULL;
				} else {
					b_element->b_stack_graph=g_fstore (
						(b_element->b_stack_offset+global_block.block_graph_b_stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,
						B_STACK_POINTER,graph->instruction_parameters[0].p,
						b_element->b_stack_load_graph
					);
				}
				continue;
			}
#else
			if (graph->instruction_code==GFHIGH
				&& (next_b_element=b_element->b_stack_next)!=NULL
				&& (next_graph=next_b_element->b_stack_graph)!=NULL
				&& next_graph->instruction_code==GFLOW
				&& next_b_element->b_stack_offset==b_element->b_stack_offset+1
				&& next_graph->instruction_parameters[0].p==graph->instruction_parameters[0].p
			){
				if (graph==b_element->b_stack_load_graph &&
					next_graph==next_b_element->b_stack_load_graph &&
					graph->instruction_parameters[0].p->instruction_code!=GFREGISTER)
				{
					b_element->b_stack_graph=NULL;
					next_b_element->b_stack_graph=NULL;
				} else {
					b_element->b_stack_graph=g_fstore (
						(b_element->b_stack_offset+global_block.block_graph_b_stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,
						B_STACK_POINTER,graph->instruction_parameters[0].p,
						b_element->b_stack_load_graph,next_b_element->b_stack_load_graph
					);
					next_b_element->b_stack_graph=NULL;
				}
				b_element=next_b_element;					
				continue;
			}	
#endif				
			if (graph==b_element->b_stack_load_graph && graph->instruction_code!=GREGISTER)
				b_element->b_stack_graph=NULL;
			else
				b_element->b_stack_graph=g_store (
					(b_element->b_stack_offset+global_block.block_graph_b_stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,
					B_STACK_POINTER,graph,b_element->b_stack_load_graph
				);
		}
	}
	
#ifdef MORE_PARAMETER_REGISTERS
	n_extra_data_parameter_registers=number_of_d_register_parameters-n_data_parameter_registers;
	if (n_extra_data_parameter_registers<0)
		n_extra_data_parameter_registers=0;
#endif
	
	for (n=0; n<number_of_d_register_parameters; ++n)
		if (d_graphs[n]!=NULL){
			register int d_reg_n;
		
#ifdef MORE_PARAMETER_REGISTERS
			d_reg_n=(number_of_d_register_parameters-1-n)-n_extra_data_parameter_registers;

			if (d_reg_n>=0){
				end_d_registers |= ((unsigned)1<<d_reg_n);
			
				*d_graphs_p[n]=g_store_r (num_to_d_reg (d_reg_n),d_graphs[n]);
			} else {
# if 1
				int extra_d_reg_n;
				
				extra_d_reg_n=n_data_parameter_registers-1-d_reg_n;
				
				end_d_registers |= ((unsigned)1<<extra_d_reg_n);

				*d_graphs_p[n]=g_store_r (num_to_d_reg (extra_d_reg_n),d_graphs[n]);
				
				if (a_register_parameter_nodes[N_ADDRESS_PARAMETER_REGISTERS+d_reg_n]!=NULL){
					INSTRUCTION_GRAPH register_node;

					register_node=a_register_parameter_nodes[N_ADDRESS_PARAMETER_REGISTERS+d_reg_n];
					register_node->instruction_parameters[0].i=num_to_d_reg (extra_d_reg_n);
					d_register_parameter_nodes[extra_d_reg_n]=register_node;
					a_register_parameter_nodes[N_ADDRESS_PARAMETER_REGISTERS+d_reg_n]=NULL;
					global_block.block_graph_d_register_parameter_node[extra_d_reg_n]=register_node;
					global_block.block_graph_a_register_parameter_node[N_ADDRESS_PARAMETER_REGISTERS+d_reg_n]=NULL;
				}
# else
				end_a_registers |= ((unsigned)1<<N_ADDRESS_PARAMETER_REGISTERS+d_reg_n);
			
				*d_graphs_p[n]=g_store_r (num_to_a_reg (N_ADDRESS_PARAMETER_REGISTERS+d_reg_n),d_graphs[n]);
# endif
			}
#else
			d_reg_n=number_of_d_register_parameters-1-n;
		
			end_d_registers |= ((unsigned)1<<d_reg_n);
		
			*d_graphs_p[n]=g_store_r (num_to_d_reg (d_reg_n),d_graphs[n]);
#endif
		}
	
	for (n=0; n<number_of_f_register_parameters; ++n)
		if (f_graphs[n]!=NULL){
			int f_reg_n;

			f_reg_n=number_of_f_register_parameters-1-n;

			end_f_registers |= ((unsigned)1<<f_reg_n);
		
			*f_graphs_p[n]=g_fstore_r (f_reg_n,f_graphs[n]);
		}
	
	displacement=0;
	number_of_d_register_parameters=0;
	number_of_f_register_parameters=0;
	
	for (parameter_n=0; parameter_n<n_parameters; ++parameter_n)
		if (test_bit (vector,parameter_n)){
			if (number_of_f_register_parameters<N_FLOAT_PARAMETER_REGISTERS
				&& mc68881_flag)
			{
				++number_of_f_register_parameters;
#ifdef G_A64
				displacement+=1;
#else
				displacement+=2;
				++parameter_n;
#endif
			} else
				break;
		} else {
			if (number_of_d_register_parameters<n_data_parameter_registers
#ifdef MORE_PARAMETER_REGISTERS
											+ n_extra_data_parameter_registers
#endif
			){
				++number_of_d_register_parameters;
				++displacement;
			} else
				break;
		}
		
	global_block.block_graph_b_stack_end_displacement=displacement;
}

static int set_basic_block_begin_d_registers
	(struct b_stack **element_p,int b_stack_size,ULONG vector[],
	 INSTRUCTION_GRAPH d_register_parameter_node[],INSTRUCTION_GRAPH f_register_parameter_node[]
#ifdef MORE_PARAMETER_REGISTERS
	,int n_extra_data_parameter_registers,INSTRUCTION_GRAPH a_register_parameter_node[]
#endif
	 )
{
	int offset,stack_displacement;
	int n_d_registers,n_f_registers,all_parameters_in_registers;
	int n_data_parameter_registers;
	
	n_data_parameter_registers =
		(parallel_flag ? N_DATA_PARAMETER_REGISTERS-1 : N_DATA_PARAMETER_REGISTERS)
#ifdef MORE_PARAMETER_REGISTERS
		+ n_extra_data_parameter_registers
#endif
		;

	n_d_registers=0;
	n_f_registers=0;

	for (offset=0; offset<b_stack_size; ++offset)
		if (!test_bit (vector,offset)){
#if defined (I486) || defined (ARM)
			if (n_d_registers<n_data_parameter_registers)
#else
			if (n_d_registers<n_data_parameter_registers-1)
#endif
				++n_d_registers;
		} else {
			if (n_f_registers<N_FLOAT_PARAMETER_REGISTERS && mc68881_flag)
				++n_f_registers;
#ifndef G_A64
			++offset;
#endif
		}
				
	stack_displacement=0;
	all_parameters_in_registers=1;
	
	for (offset=0; offset<b_stack_size; ++offset){
		INSTRUCTION_GRAPH graph;
		
		if (!test_bit (vector,offset)){
			if (n_d_registers<=0)
				all_parameters_in_registers=0;
			else {
				--n_d_registers;

				if (all_parameters_in_registers)
					--stack_displacement;
				
				while (*element_p!=NULL && (*element_p)->b_stack_offset<offset)
					element_p=&(*element_p)->b_stack_next;

				if (*element_p!=NULL && (*element_p)->b_stack_offset==offset){
					struct b_stack *element;
					
					element=*element_p;
					
					if (element->b_stack_flags & ELEMENT_MAY_BE_REMOVED && element->b_stack_graph==NULL){					
						graph=g_new_node (GREGISTER,0,sizeof (union instruction_parameter));
#ifdef MORE_PARAMETER_REGISTERS
						{
							int d_reg_n;
							
							d_reg_n=n_d_registers - n_extra_data_parameter_registers;
							
							if (d_reg_n>=0){
								graph->instruction_parameters[0].i=num_to_d_reg (d_reg_n);				
								d_register_parameter_node [d_reg_n]=graph;
							} else {
								graph->instruction_parameters[0].i=num_to_a_reg (N_ADDRESS_PARAMETER_REGISTERS+d_reg_n);				
								a_register_parameter_node [N_ADDRESS_PARAMETER_REGISTERS+d_reg_n]=graph;
							}
						}
#else
						graph->instruction_parameters[0].i=num_to_d_reg (n_d_registers);
						d_register_parameter_node [n_d_registers]=graph;
#endif					
						element->b_stack_graph=NULL;
						element->b_stack_load_graph=NULL;
					} else {
						graph=element->b_stack_load_graph;
						if (graph!=NULL){
#ifdef G_A64
							if (graph->instruction_code==GFROMF &&
								graph->instruction_parameters[0].p->instruction_code==GFLOAD)
							{
								INSTRUCTION_GRAPH fload_graph,low_graph;
								
								fload_graph=graph->instruction_parameters[0].p;
								
								fload_graph->instruction_code=GTOF;
								fload_graph->instruction_parameters[0].p=graph;
							}
#else
							if (graph->instruction_code==GFHIGH &&
								graph->instruction_parameters[0].p->instruction_code==GFLOAD)
							{
								struct b_stack *next_element;
								INSTRUCTION_GRAPH fload_graph,low_graph;
								
								fload_graph=graph->instruction_parameters[0].p;
								
								next_element=element->b_stack_next;
								if (next_element==NULL || next_element->b_stack_offset!=offset+1)
									internal_error_in_function ("compute_b_load_offsets");
								
								low_graph=next_element->b_stack_load_graph;
								if (low_graph==NULL || low_graph->instruction_code!=GFLOW
									|| low_graph->instruction_parameters[0].p!=fload_graph)
									internal_error_in_function ("compute_b_load_offsets");

								low_graph->instruction_code=GLOAD;
								low_graph->instruction_parameters[0].i=fload_graph->instruction_parameters[0].i+4;
								low_graph->instruction_parameters[1].i=fload_graph->instruction_parameters[1].i;
								
								fload_graph->instruction_code=GFJOIN;
								fload_graph->instruction_parameters[0].p=graph;
								fload_graph->instruction_parameters[1].p=low_graph;
							}
#endif
							graph->instruction_code=GREGISTER;
							graph->inode_arity=0;
#ifdef MORE_PARAMETER_REGISTERS
							{
								int d_reg_n;
								
								d_reg_n=n_d_registers - n_extra_data_parameter_registers;
								
								if (d_reg_n>=0){
									graph->instruction_parameters[0].i=num_to_d_reg (d_reg_n);				
									d_register_parameter_node[d_reg_n]=graph;
								} else {
									graph->instruction_parameters[0].i=num_to_a_reg (N_ADDRESS_PARAMETER_REGISTERS+d_reg_n);				
									a_register_parameter_node[N_ADDRESS_PARAMETER_REGISTERS+d_reg_n]=graph;
								}
							}
#else
							graph->instruction_parameters[0].i=num_to_d_reg (n_d_registers);				
							d_register_parameter_node[n_d_registers]=graph;
#endif
						} else
#ifdef MORE_PARAMETER_REGISTERS
							{
								int d_reg_n;
								
								d_reg_n=n_d_registers - n_extra_data_parameter_registers;
								
								if (d_reg_n>=0)
									d_register_parameter_node[d_reg_n]=NULL;
								else
									a_register_parameter_node[N_ADDRESS_PARAMETER_REGISTERS+d_reg_n]=NULL;
							}
#else
							d_register_parameter_node[n_d_registers]=NULL;
#endif
					}
					
					element_p=&(*element_p)->b_stack_next;
				} else {			
					struct b_stack *new_element;
					
					graph=g_new_node (GREGISTER,0,sizeof (union instruction_parameter));
#ifdef MORE_PARAMETER_REGISTERS
					{
						int d_reg_n;
						
						d_reg_n=n_d_registers - n_extra_data_parameter_registers;
						
						if (d_reg_n>=0){
							graph->instruction_parameters[0].i=num_to_d_reg (d_reg_n);
							d_register_parameter_node[d_reg_n]=graph;
						} else {
							graph->instruction_parameters[0].i=num_to_a_reg (N_ADDRESS_PARAMETER_REGISTERS+d_reg_n);
							a_register_parameter_node[N_ADDRESS_PARAMETER_REGISTERS+d_reg_n]=graph;
						}
					}
#else
					graph->instruction_parameters[0].i=num_to_d_reg (n_d_registers);
					d_register_parameter_node[n_d_registers]=graph;
#endif
					new_element=allocate_struct_from_heap (b_stack);
					new_element->b_stack_offset=offset;
					new_element->b_stack_flags=0;
					new_element->b_stack_graph=graph;
					new_element->b_stack_load_graph=graph;
					
					new_element->b_stack_next=*element_p;
					*element_p=new_element;
					element_p=&new_element->b_stack_next;
				}
			}
		} else {
			if (n_f_registers<=0)
				all_parameters_in_registers=0;
			else {
				INSTRUCTION_GRAPH r_graph;
				int f_register_not_used_flag;
				struct b_stack *element;
				
				--n_f_registers;
				
				if (all_parameters_in_registers)
					--stack_displacement;

				while (*element_p!=NULL && (*element_p)->b_stack_offset<offset)
					element_p=&(*element_p)->b_stack_next;

				r_graph=NULL;
				
				if ((element=*element_p)!=NULL){
					if (element->b_stack_offset==offset){
						if ((graph=element->b_stack_load_graph)!=NULL &&
#ifdef G_A64
							graph->instruction_code==GFROMF)
#else
							graph->instruction_code==GFHIGH)
#endif
						{
							r_graph=graph->instruction_parameters[0].p;
							r_graph->instruction_code=GFREGISTER;
							r_graph->inode_arity=0;
							r_graph->instruction_parameters[0].i=n_f_registers;
						}
						element=element->b_stack_next;
					}
#ifndef G_A64
					if (element!=NULL && element->b_stack_offset==offset+1 &&
						(graph=element->b_stack_load_graph)!=NULL &&
						graph->instruction_code==GFLOW)
					{
						r_graph=graph->instruction_parameters[0].p;
						r_graph->instruction_code=GFREGISTER;
						r_graph->inode_arity=0;
						r_graph->instruction_parameters[0].i=n_f_registers;
					}
#endif
				}
				
				if (r_graph==NULL){
					r_graph=g_new_node (GFREGISTER,0,sizeof (union instruction_parameter));
					r_graph->instruction_parameters[0].i=n_f_registers;
				}
				
				f_register_not_used_flag=0;
				
   				if ((element=*element_p)!=NULL && element->b_stack_offset==offset){
					if (element->b_stack_flags & ELEMENT_MAY_BE_REMOVED && element->b_stack_graph==NULL){
#ifdef G_A64
						graph=g_fromf (r_graph);
#else
						graph=g_new_node (GFHIGH,0,2*sizeof (union instruction_parameter));
						graph->instruction_parameters[1].p=NULL;
						graph->instruction_parameters[0].p=r_graph;
#endif												
						element->b_stack_graph=NULL;
						element->b_stack_load_graph=NULL;
					} else {
						graph=element->b_stack_load_graph;
						if (graph!=NULL){
#ifdef G_A64
							graph->instruction_code=GFROMF;
							graph->inode_arity=0;
							graph->instruction_parameters[0].p=r_graph;
#else
							graph->instruction_code=GFHIGH;
							graph->inode_arity=0;
							graph->instruction_parameters[0].p=r_graph;
							graph->instruction_parameters[1].p=NULL;
#endif
						} else
							++f_register_not_used_flag;
					}
					
					element_p=&(*element_p)->b_stack_next;
				} else {			
					struct b_stack *new_element;
#ifdef G_A64
					graph=g_fromf (r_graph);
#else
					graph=g_new_node (GFHIGH,0,2*sizeof (union instruction_parameter));
					graph->instruction_parameters[1].p=NULL;
					graph->instruction_parameters[0].p=r_graph;
#endif								
					new_element=allocate_struct_from_heap (b_stack);
					new_element->b_stack_offset=offset;
					new_element->b_stack_flags=0;
					new_element->b_stack_graph=graph;
					new_element->b_stack_load_graph=graph;
					
					new_element->b_stack_next=*element_p;
					*element_p=new_element;
					element_p=&new_element->b_stack_next;
				}
				
#ifndef G_A64
				++offset;
				
				if (all_parameters_in_registers)
					--stack_displacement;
									
				if (*element_p!=NULL && (*element_p)->b_stack_offset==offset){
					register struct b_stack *element;
					
					element=*element_p;
					if (element->b_stack_flags & ELEMENT_MAY_BE_REMOVED && element->b_stack_graph==NULL){
						graph=g_new_node (GFLOW,0,2*sizeof (union instruction_parameter));
						graph->instruction_parameters[1].p=NULL;
						graph->instruction_parameters[0].p=r_graph;
						
						element->b_stack_graph=NULL;
						element->b_stack_load_graph=NULL;
					} else {
						graph=element->b_stack_load_graph;
						if (graph!=NULL){
							graph->instruction_code=GFLOW;
							graph->inode_arity=0;
							graph->instruction_parameters[0].p=r_graph;
							graph->instruction_parameters[1].p=NULL;
						} else
							++f_register_not_used_flag;
					}
					
					element_p=&(*element_p)->b_stack_next;
				} else {			
					register struct b_stack *new_element;
					
					graph=g_new_node (GFLOW,0,2*sizeof (union instruction_parameter));
					graph->instruction_parameters[1].p=NULL;

					graph->instruction_parameters[0].p=r_graph;
								
					new_element=allocate_struct_from_heap (b_stack);
					new_element->b_stack_offset=offset;
					new_element->b_stack_flags=0;
					new_element->b_stack_graph=graph;
					new_element->b_stack_load_graph=graph;
					
					new_element->b_stack_next=*element_p;
					*element_p=new_element;
					element_p=&new_element->b_stack_next;
				}
#endif
				f_register_parameter_node[n_f_registers]=
					f_register_not_used_flag!=2 ? r_graph : NULL;
			}
		}
	}
	
	return stack_displacement;
}

static void compute_b_load_offsets (register struct b_stack *b_element,int offset)
{
	for (; b_element!=NULL; b_element=b_element->b_stack_next){
		INSTRUCTION_GRAPH load_graph;
		
		load_graph=b_element->b_stack_load_graph;
	
		if (load_graph!=NULL)
			switch (load_graph->instruction_code){
				case GLOAD:
					load_graph->instruction_parameters[0].i=
						(b_element->b_stack_offset<<STACK_ELEMENT_LOG_SIZE)+offset;
					break;
				case GREGISTER:
				case GFREGISTER:
					break;
#ifdef G_A64
				case GFROMF:
				{
					INSTRUCTION_GRAPH graph_1;
					
					graph_1=load_graph->instruction_parameters[0].p;
					if (graph_1->instruction_code==GFLOAD)
						graph_1->instruction_parameters[0].i = (b_element->b_stack_offset<<STACK_ELEMENT_LOG_SIZE)+offset;
					else if (graph_1->instruction_code!=GFREGISTER)
						internal_error_in_function ("compute_b_load_offsets");

					break;
				}
#else
				case GFHIGH:
				{
					INSTRUCTION_GRAPH graph_1;
					
					graph_1=load_graph->instruction_parameters[0].p;
					if (graph_1->instruction_code==GFLOAD)
						graph_1->instruction_parameters[0].i = (b_element->b_stack_offset<<STACK_ELEMENT_LOG_SIZE)+offset;
					else if (graph_1->instruction_code!=GFREGISTER)
						internal_error_in_function ("compute_b_load_offsets");

					break;
				}
				case GFLOW:
				{
					INSTRUCTION_GRAPH graph_1;
					
					graph_1=load_graph->instruction_parameters[0].p;
					if (graph_1->instruction_code==GFLOAD)
						graph_1->instruction_parameters[0].i = ((b_element->b_stack_offset-1)<<STACK_ELEMENT_LOG_SIZE)+offset;
					else if (graph_1->instruction_code!=GFREGISTER)
						internal_error_in_function ("compute_b_load_offsets");
								
					break;
				}
#endif
				default:
					internal_error_in_function ("compute_b_load_offsets");
			}
	}
}

static void remove_stack_element (struct stack **element_p)
{
	struct stack *element;

	element=(*element_p)->stack_next;
	*element_p=element;
	
	while (element!=NULL){
		--element->stack_offset;
		element=element->stack_next;
	}
}

static void remove_end_stack_element
	(struct stack **element_p,int remove_offset,int stack_begin_displacement,int stack_top_offset,int b_stack_flag)
{
	struct stack *element;
	INSTRUCTION_GRAPH graph_1;
	int offset,flags_1,begin_offset;
			
	element=*element_p;
	
	graph_1=NULL;
	flags_1=0;

	begin_offset= stack_top_offset<=0 ? stack_top_offset : 0;

	while (element!=NULL && element->stack_offset<begin_offset){
		element_p=&element->stack_next;
		element=*element_p;
	}
	
	for (offset=begin_offset; offset<remove_offset; ++offset){
		INSTRUCTION_GRAPH graph_2;
		int flags_2;
		
		if (element==NULL || element->stack_offset!=offset){
			struct stack *new_element;
			INSTRUCTION_GRAPH graph;

			if (!b_stack_flag)
				graph=g_load (-(offset+stack_begin_displacement+1)<<STACK_ELEMENT_LOG_SIZE,A_STACK_POINTER);
			else
				graph=g_load ((offset+stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
		
			graph->node_mark=offset<stack_top_offset ? 0 : 2;
			
			new_element=allocate_struct_from_heap (stack);
			new_element->stack_offset=offset;
			new_element->stack_flags=0;
			new_element->stack_graph=graph;
			new_element->stack_load_graph=graph;
	
			new_element->stack_next=element;
			*element_p=new_element;
			element=new_element;
		}
				
		graph_2=graph_1;
		flags_2=flags_1;
		
		graph_1=element->stack_graph;
		flags_1=element->stack_flags;
		
		element->stack_graph=graph_2;
		element->stack_flags= (element->stack_flags & ~ELEMENT_USED_BEFORE_JSR) | (flags_2 & ELEMENT_USED_BEFORE_JSR);
		
		element_p=&element->stack_next;
		element=*element_p;
	}

	element->stack_graph=graph_1;
	element->stack_flags= (element->stack_flags & ~ELEMENT_USED_BEFORE_JSR) | (flags_1 & ELEMENT_USED_BEFORE_JSR);
}

static void remove_begin_stack_element
   (struct stack **element_p,int remove_offset,int stack_begin_displacement,
	int stack_top_offset,int b_stack_flag)
{
	struct stack *element,*previous_element;
	int offset,begin_offset;
	
	begin_offset= stack_top_offset<=0 ? stack_top_offset : 0;

	previous_element=NULL;	
	element=*element_p;

	while (element!=NULL && element->stack_offset<begin_offset){
		previous_element=element;
		element_p=&element->stack_next;
		element=*element_p;
	}

	for (offset=begin_offset; offset<=remove_offset; ++offset){
		if (element==NULL || element->stack_offset!=offset){
			struct stack *new_element;
			INSTRUCTION_GRAPH graph;

			if (!b_stack_flag)
				graph=g_load (-(offset+stack_begin_displacement+1)<<STACK_ELEMENT_LOG_SIZE,A_STACK_POINTER);
			else
				graph=g_load ((offset+stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
			
			graph->node_mark= offset<stack_top_offset ? 0 : 2;
			
			new_element=allocate_struct_from_heap (stack);
			new_element->stack_offset=offset;
			new_element->stack_flags=0;
			new_element->stack_load_graph=graph;
			new_element->stack_graph=graph;
	
			new_element->stack_next=element;
			*element_p=new_element;
			element=new_element;
		}
		
		if (previous_element==NULL || previous_element->stack_offset!=offset-1){
			struct stack *new_element;
							
			new_element=allocate_struct_from_heap (stack);
			new_element->stack_offset=offset-1;
			new_element->stack_flags=0;
			new_element->stack_load_graph=NULL;
			new_element->stack_graph=NULL;
	
			new_element->stack_next=element;
			*element_p=new_element;
			element_p=&new_element->stack_next;
			previous_element=new_element;
		}
		
		previous_element->stack_graph=element->stack_graph;
		previous_element->stack_flags= (previous_element->stack_flags & ~ELEMENT_USED_BEFORE_JSR) 
										| (element->stack_flags & ELEMENT_USED_BEFORE_JSR);

		element->stack_graph=NULL;
		element->stack_flags &= ~ELEMENT_USED_BEFORE_JSR;

		if (offset<remove_offset){
			previous_element=element;
			element_p=&element->stack_next;
			element=*element_p;
		}
	}
		
	if (element!=NULL)
		*element_p=element->stack_next;
	
	for (element=*element_p; element!=NULL; element=element->stack_next)
		--element->stack_offset;
}

#define INSERT_LOAD_GRAPHS

#ifdef INSERT_LOAD_GRAPHS
	static struct stack ** insert_load_graphs
	   (struct stack **element_p,int remove_offset,int stack_begin_displacement,int stack_top_offset,int b_stack_flag)
	{
		struct stack *element;
		int offset,begin_offset;
		
		begin_offset= stack_top_offset<=0 ? stack_top_offset : 0;
	
		element=*element_p;
	
		while (element!=NULL && element->stack_offset<begin_offset){
			element_p=&element->stack_next;
			element=*element_p;
		}
	
		for (offset=begin_offset; offset<remove_offset; ++offset){
			if (element==NULL || element->stack_offset!=offset){
				struct stack *new_element;
				INSTRUCTION_GRAPH graph;
	
				if (!b_stack_flag)
					graph=g_load (-(offset+stack_begin_displacement+1)<<STACK_ELEMENT_LOG_SIZE,A_STACK_POINTER);
				else
					graph=g_load ((offset+stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
				
				graph->node_mark= offset<stack_top_offset ? 0 : 2;
				
				new_element=allocate_struct_from_heap (stack);
				new_element->stack_offset=offset;
				new_element->stack_flags=0;
				new_element->stack_load_graph=graph;
				new_element->stack_graph=graph;
		
				new_element->stack_next=element;
				*element_p=new_element;
				element=new_element;
			}
	
			element_p=&element->stack_next;
			element=*element_p;
		}
			
		return element_p;
	}
#endif

static void remove_not_used_a_stack_elements (struct block_graph *block_graph,struct block_graph *next_block_graph)
{
	struct a_stack *a_element_1,**a_element_1_p;
	struct a_stack *a_element_2,**a_element_2_p;
	int stack_offset_1_min_2,first_non_parameter_offset,offset;
	
#ifdef DEBUG
	printf ("%d %d %d %d\n",block_graph->block_graph_a_stack_top_offset,
							block_graph->block_graph_end_a_stack_size,
							-next_block_graph->block_graph_begin_a_stack_size,
							block_graph->block_graph_used_a_stack_elements);
#endif
			
	a_element_1_p=&block_graph->block_graph_a_stack;
	a_element_1=*a_element_1_p;
	
	while (a_element_1!=NULL && a_element_1->a_stack_offset<block_graph->block_graph_a_stack_top_offset){
		if (a_element_1->a_stack_flags & (ELEMENT_MUST_BE_REMOVED | BEGIN_ELEMENT_MUST_BE_REMOVED)){
			if (a_element_1->a_stack_flags & ELEMENT_MUST_BE_REMOVED)
				internal_error_in_function ("remove_not_used_a_stack_elements");
			
			remove_begin_stack_element
				((struct stack **)&block_graph->block_graph_a_stack,
				 a_element_1->a_stack_offset,block_graph->block_graph_a_stack_begin_displacement,
				 block_graph->block_graph_a_stack_top_offset,0);
			a_element_1=*a_element_1_p;
					
			--block_graph->block_graph_a_stack_top_offset;
		} else {
			a_element_1_p=&a_element_1->a_stack_next;
			a_element_1=*a_element_1_p;
		}
	}
	
	offset=block_graph->block_graph_a_stack_top_offset;
	first_non_parameter_offset=	block_graph->block_graph_used_a_stack_elements
								+block_graph->block_graph_a_stack_top_offset;
	
	while (offset<first_non_parameter_offset && a_element_1!=NULL && a_element_1->a_stack_offset==offset){
		if (a_element_1->a_stack_flags & (ELEMENT_MUST_BE_REMOVED | BEGIN_ELEMENT_MUST_BE_REMOVED)){
			if (a_element_1->a_stack_flags & ELEMENT_MUST_BE_REMOVED)
				internal_error_in_function ("remove_not_used_a_stack_elements");
			
			remove_begin_stack_element
				((struct stack **)&block_graph->block_graph_a_stack,
				 offset,block_graph->block_graph_a_stack_begin_displacement,
				 block_graph->block_graph_a_stack_top_offset,0);
			a_element_1=*a_element_1_p;
					
			--block_graph->block_graph_a_stack_top_offset;
			--first_non_parameter_offset;
		} else {
			a_element_1_p=&a_element_1->a_stack_next;
			a_element_1=*a_element_1_p;
			++offset;
		}
	}
	
	stack_offset_1_min_2=	block_graph->block_graph_a_stack_top_offset
							+block_graph->block_graph_end_a_stack_size
							-next_block_graph->block_graph_begin_a_stack_size;

	a_element_2_p=&next_block_graph->block_graph_a_stack;
	a_element_2=*a_element_2_p;
	
	if (offset>=first_non_parameter_offset)
		while (a_element_1!=NULL && a_element_1->a_stack_offset==offset){
			int offset_2;
	
			offset_2=offset-stack_offset_1_min_2;
			
			while (a_element_2!=NULL && a_element_2->a_stack_offset<offset_2){
				a_element_2_p=&a_element_2->a_stack_next;
				a_element_2=*a_element_2_p;
			}
	
			if (a_element_1->a_stack_flags & ELEMENT_MUST_BE_REMOVED
				|| (a_element_1->a_stack_flags & BEGIN_ELEMENT_MUST_BE_REMOVED &&
					(	(a_element_2!=NULL && a_element_2->a_stack_offset==offset_2)
					?	(a_element_2->a_stack_load_graph==NULL || !a_element_2->a_stack_load_graph->node_mark)
					:	offset_2<next_block_graph->block_graph_a_stack_top_offset	)))
			{
				remove_stack_element ((struct stack **)a_element_1_p);
				a_element_1=*a_element_1_p;
				--stack_offset_1_min_2;
				
				if (a_element_2!=NULL && a_element_2->a_stack_offset==offset_2){
					if (a_element_2->a_stack_flags & ELEMENT_MAY_BE_REMOVED)
						a_element_2->a_stack_flags |= ELEMENT_MUST_BE_REMOVED;
					else {
						a_element_2->a_stack_flags |= BEGIN_ELEMENT_MUST_BE_REMOVED;
#ifdef INSERT_LOAD_GRAPHS
						a_element_2_p=(struct a_stack**)insert_load_graphs
							((struct stack **)&next_block_graph->block_graph_a_stack,offset_2,
							next_block_graph->block_graph_a_stack_begin_displacement,
							next_block_graph->block_graph_a_stack_top_offset,0);
#endif
					}
				} else {
					struct a_stack *new_element;

					new_element=allocate_struct_from_heap (a_stack);
					new_element->a_stack_offset=offset_2;
					new_element->a_stack_flags=BEGIN_ELEMENT_MUST_BE_REMOVED;
					new_element->a_stack_graph=NULL;
					new_element->a_stack_load_graph=NULL;
				
					new_element->a_stack_next=a_element_2;
					*a_element_2_p=new_element;
					a_element_2=new_element;
#ifdef INSERT_LOAD_GRAPHS
					a_element_2_p=(struct a_stack**)insert_load_graphs
						((struct stack **)&next_block_graph->block_graph_a_stack,offset_2,
						next_block_graph->block_graph_a_stack_begin_displacement,
						next_block_graph->block_graph_a_stack_top_offset,0);
#endif
				}
			} else if (a_element_1->a_stack_flags & BEGIN_ELEMENT_MUST_BE_REMOVED){
				remove_begin_stack_element
					((struct stack **)&block_graph->block_graph_a_stack,
					 offset,block_graph->block_graph_a_stack_begin_displacement,
					 block_graph->block_graph_a_stack_top_offset,0);
				a_element_1=*a_element_1_p;
					
				--block_graph->block_graph_a_stack_top_offset;
				--stack_offset_1_min_2;
			} else {
				if (	(a_element_2!=NULL && a_element_2->a_stack_offset==offset_2)
					?	(a_element_2->a_stack_load_graph==NULL || !a_element_2->a_stack_load_graph->node_mark)
					:	offset_2<next_block_graph->block_graph_a_stack_top_offset	)
				{
					remove_end_stack_element
					   ((struct stack **)&block_graph->block_graph_a_stack,offset,
						block_graph->block_graph_a_stack_begin_displacement,
						block_graph->block_graph_a_stack_top_offset,0);
					a_element_1=*a_element_1_p;
						
					++block_graph->block_graph_a_stack_top_offset;
					
					if (a_element_2!=NULL && a_element_2->a_stack_offset==offset_2){
						if (a_element_2->a_stack_flags & ELEMENT_MAY_BE_REMOVED)
							a_element_2->a_stack_flags |= ELEMENT_MUST_BE_REMOVED;
						else {
							a_element_2->a_stack_flags |= BEGIN_ELEMENT_MUST_BE_REMOVED;
#ifdef INSERT_LOAD_GRAPHS
							a_element_2_p=(struct a_stack**)insert_load_graphs
								((struct stack **)&next_block_graph->block_graph_a_stack,offset_2,
								next_block_graph->block_graph_a_stack_begin_displacement,
								next_block_graph->block_graph_a_stack_top_offset,0);
#endif
						}
					} else {
						struct a_stack *new_element;
	
						new_element=allocate_struct_from_heap (a_stack);
						new_element->a_stack_offset=offset_2;
						new_element->a_stack_flags=BEGIN_ELEMENT_MUST_BE_REMOVED;
						new_element->a_stack_graph=NULL;
						new_element->a_stack_load_graph=NULL;
					
						new_element->a_stack_next=a_element_2;
						*a_element_2_p=new_element;
						a_element_2=new_element;
#ifdef INSERT_LOAD_GRAPHS
						a_element_2_p=(struct a_stack**)insert_load_graphs
							((struct stack **)&next_block_graph->block_graph_a_stack,offset_2,
							next_block_graph->block_graph_a_stack_begin_displacement,
							next_block_graph->block_graph_a_stack_top_offset,0);
#endif
					}
				}

				++offset;
				a_element_1_p=&a_element_1->a_stack_next;
				a_element_1=*a_element_1_p;
			}
		}

	while (a_element_1!=NULL){
		if (a_element_1->a_stack_flags & ELEMENT_MUST_BE_REMOVED){
			int offset_2;

			offset=a_element_1->a_stack_offset;
			offset_2=offset-stack_offset_1_min_2;
			
			while (a_element_2!=NULL && a_element_2->a_stack_offset<offset_2){
				a_element_2_p=&a_element_2->a_stack_next;
				a_element_2=*a_element_2_p;
			}
	
			remove_stack_element ((struct stack **)a_element_1_p);
			a_element_1=*a_element_1_p;

			--stack_offset_1_min_2;
			
			if (a_element_2!=NULL && a_element_2->a_stack_offset==offset_2){
				if (a_element_2->a_stack_flags & ELEMENT_MAY_BE_REMOVED)
					a_element_2->a_stack_flags |= ELEMENT_MUST_BE_REMOVED;
				else {
					a_element_2->a_stack_flags |= BEGIN_ELEMENT_MUST_BE_REMOVED;
#ifdef INSERT_LOAD_GRAPHS
					a_element_2_p=(struct a_stack**)insert_load_graphs
						((struct stack **)&next_block_graph->block_graph_a_stack,offset_2,
						next_block_graph->block_graph_a_stack_begin_displacement,
						next_block_graph->block_graph_a_stack_top_offset,0);
#endif
				}
			} else {
				struct a_stack *new_element;

				new_element=allocate_struct_from_heap (a_stack);
				new_element->a_stack_offset=offset_2;
				new_element->a_stack_flags=BEGIN_ELEMENT_MUST_BE_REMOVED;
				new_element->a_stack_graph=NULL;
				new_element->a_stack_load_graph=NULL;
			
				new_element->a_stack_next=a_element_2;
				*a_element_2_p=new_element;
				a_element_2=new_element;
#ifdef INSERT_LOAD_GRAPHS
				a_element_2_p=(struct a_stack**)insert_load_graphs
					((struct stack **)&next_block_graph->block_graph_a_stack,offset_2,
					next_block_graph->block_graph_a_stack_begin_displacement,
					next_block_graph->block_graph_a_stack_top_offset,0);
#endif
			}
		} else if (a_element_1->a_stack_flags & BEGIN_ELEMENT_MUST_BE_REMOVED){
			remove_begin_stack_element
				((struct stack **)&block_graph->block_graph_a_stack,
				 a_element_1->a_stack_offset,block_graph->block_graph_a_stack_begin_displacement,
				 block_graph->block_graph_a_stack_top_offset,0);
			a_element_1=*a_element_1_p;
				
			--block_graph->block_graph_a_stack_top_offset;
			--stack_offset_1_min_2;
		} else {
			a_element_1_p=&a_element_1->a_stack_next;
			a_element_1=*a_element_1_p;
		}
	}
}
#undef DEBUG

static void remove_not_used_b_stack_elements (struct block_graph *block_graph,struct block_graph *next_block_graph)
{
	struct b_stack *b_element_1,**b_element_1_p;
	struct b_stack *b_element_2,**b_element_2_p;
	int stack_offset_1_min_2,first_non_parameter_offset_1,offset_1;
		 
#ifdef DEBUG
	printf ("%d %d %d %d\n",block_graph->block_graph_b_stack_top_offset,
							block_graph->block_graph_end_b_stack_size,
							-next_block_graph->block_graph_begin_b_stack_size,
							block_graph->block_graph_used_b_stack_elements);
#endif
	
	b_element_1_p=&block_graph->block_graph_b_stack;
	b_element_1=*b_element_1_p;
	
	while (b_element_1!=NULL && b_element_1->b_stack_offset<block_graph->block_graph_b_stack_top_offset){
		if (b_element_1->b_stack_flags & (ELEMENT_MUST_BE_REMOVED | BEGIN_ELEMENT_MUST_BE_REMOVED)){
			if (b_element_1->b_stack_flags & ELEMENT_MUST_BE_REMOVED)
				internal_error_in_function ("remove_not_used_b_stack_elements");
			
			remove_begin_stack_element
				((struct stack **)&block_graph->block_graph_b_stack,
				 b_element_1->b_stack_offset,block_graph->block_graph_b_stack_begin_displacement,
				 block_graph->block_graph_b_stack_top_offset,1);
			b_element_1=*b_element_1_p;
					
			--block_graph->block_graph_b_stack_top_offset;
		} else {
			b_element_1_p=&b_element_1->b_stack_next;
			b_element_1=*b_element_1_p;
		}
	}

	offset_1=block_graph->block_graph_b_stack_top_offset;
	first_non_parameter_offset_1=
		block_graph->block_graph_used_b_stack_elements
		+block_graph->block_graph_b_stack_top_offset;
	
	while (offset_1<first_non_parameter_offset_1 && b_element_1!=NULL && b_element_1->b_stack_offset==offset_1){
		if (b_element_1->b_stack_flags & (ELEMENT_MUST_BE_REMOVED | BEGIN_ELEMENT_MUST_BE_REMOVED)){
			if (b_element_1->b_stack_flags & ELEMENT_MUST_BE_REMOVED)
				internal_error_in_function ("remove_not_used_b_stack_elements");
						
			remove_begin_stack_element
				((struct stack **)&block_graph->block_graph_b_stack,
				 offset_1,block_graph->block_graph_b_stack_begin_displacement,
				 block_graph->block_graph_b_stack_top_offset,1);
			b_element_1=*b_element_1_p;
			
			--block_graph->block_graph_b_stack_top_offset;
			--first_non_parameter_offset_1;
		} else {
			b_element_1_p=&b_element_1->b_stack_next;
			b_element_1=*b_element_1_p;
			++offset_1;
		}
	}

	stack_offset_1_min_2=
		block_graph->block_graph_b_stack_top_offset
		+block_graph->block_graph_end_b_stack_size
		-next_block_graph->block_graph_begin_b_stack_size;
	
	b_element_2_p=&next_block_graph->block_graph_b_stack;
	b_element_2=*b_element_2_p;

	if (offset_1>=first_non_parameter_offset_1)
		while (b_element_1!=NULL && b_element_1->b_stack_offset==offset_1){
			INSTRUCTION_GRAPH load_graph;
			int offset_2;
			
			offset_2=offset_1-stack_offset_1_min_2;
			
			while (b_element_2!=NULL && b_element_2->b_stack_offset<offset_2){
				b_element_2_p=&b_element_2->b_stack_next;
				b_element_2=*b_element_2_p;
			}

			if (b_element_1->b_stack_flags & ELEMENT_MUST_BE_REMOVED ||
				(b_element_1->b_stack_flags & BEGIN_ELEMENT_MUST_BE_REMOVED && 
					(	(b_element_2!=NULL && b_element_2->b_stack_offset==offset_2)
					?  ((load_graph=b_element_2->b_stack_load_graph)==NULL || 
						(!load_graph->node_mark && 
						 !(
#ifdef G_A64
							load_graph->instruction_code==GFROMF
#else
							(load_graph->instruction_code==GFHIGH ||
						   load_graph->instruction_code==GFLOW)
#endif
						  && load_graph->instruction_parameters[0].p->node_mark)))
					:  offset_2<next_block_graph->block_graph_b_stack_top_offset)))
			{
				remove_stack_element ((struct stack **)b_element_1_p);
				b_element_1=*b_element_1_p;
				--stack_offset_1_min_2;
				
				if (b_element_2!=NULL && b_element_2->b_stack_offset==offset_2){
					if (b_element_2->b_stack_flags & ELEMENT_MAY_BE_REMOVED)
						b_element_2->b_stack_flags |= ELEMENT_MUST_BE_REMOVED;
					else {
						b_element_2->b_stack_flags |= BEGIN_ELEMENT_MUST_BE_REMOVED;
#ifdef INSERT_LOAD_GRAPHS
						b_element_2_p=(struct b_stack**)insert_load_graphs
								((struct stack **)&next_block_graph->block_graph_b_stack,offset_2,
								next_block_graph->block_graph_b_stack_begin_displacement,
								next_block_graph->block_graph_b_stack_top_offset,1);
#endif
					}
				} else {
					struct b_stack *new_element;

					new_element=allocate_struct_from_heap (b_stack);
					new_element->b_stack_offset=offset_2;
					new_element->b_stack_flags=BEGIN_ELEMENT_MUST_BE_REMOVED;
					new_element->b_stack_graph=NULL;
					new_element->b_stack_load_graph=NULL;
				
					new_element->b_stack_next=b_element_2;
					*b_element_2_p=new_element;
					b_element_2=new_element;
#ifdef INSERT_LOAD_GRAPHS
					b_element_2_p=(struct b_stack**)insert_load_graphs
							((struct stack **)&next_block_graph->block_graph_b_stack,offset_2,
							next_block_graph->block_graph_b_stack_begin_displacement,
							next_block_graph->block_graph_b_stack_top_offset,1);
#endif
				}
			} else if (b_element_1->b_stack_flags & BEGIN_ELEMENT_MUST_BE_REMOVED){
				remove_begin_stack_element
					((struct stack **)&block_graph->block_graph_b_stack,
					 offset_1,block_graph->block_graph_b_stack_begin_displacement,
					 block_graph->block_graph_b_stack_top_offset,1);
				b_element_1=*b_element_1_p;
					
				--block_graph->block_graph_b_stack_top_offset;
				--stack_offset_1_min_2;
			} else {
				if ((b_element_2!=NULL && b_element_2->b_stack_offset==offset_2)
					?  ((load_graph=b_element_2->b_stack_load_graph)==NULL || 
						(!load_graph->node_mark && 
						 !(
#ifdef G_A64
							load_graph->instruction_code==GFROMF
#else
							(load_graph->instruction_code==GFHIGH ||
						   load_graph->instruction_code==GFLOW)
#endif
						  && load_graph->instruction_parameters[0].p->node_mark)))
					:  offset_2<next_block_graph->block_graph_b_stack_top_offset)
				{
					remove_end_stack_element
						((struct stack **)&block_graph->block_graph_b_stack,offset_1,
						 block_graph->block_graph_b_stack_begin_displacement,
						 block_graph->block_graph_b_stack_top_offset,1);
					b_element_1=*b_element_1_p;
					
					++block_graph->block_graph_b_stack_top_offset;
					
					if (b_element_2!=NULL && b_element_2->b_stack_offset==offset_2){
						if (b_element_2->b_stack_flags & ELEMENT_MAY_BE_REMOVED)
							b_element_2->b_stack_flags |= ELEMENT_MUST_BE_REMOVED;
						else {
							b_element_2->b_stack_flags |= BEGIN_ELEMENT_MUST_BE_REMOVED;
#ifdef INSERT_LOAD_GRAPHS
							b_element_2_p=(struct b_stack**)insert_load_graphs
								((struct stack **)&next_block_graph->block_graph_b_stack,offset_2,
								next_block_graph->block_graph_b_stack_begin_displacement,
								next_block_graph->block_graph_b_stack_top_offset,1);
#endif
						}
					} else {
						struct b_stack *new_element;
	
						new_element=allocate_struct_from_heap (b_stack);
						new_element->b_stack_offset=offset_2;
						new_element->b_stack_flags=BEGIN_ELEMENT_MUST_BE_REMOVED;
						new_element->b_stack_graph=NULL;
						new_element->b_stack_load_graph=NULL;
					
						new_element->b_stack_next=b_element_2;
						*b_element_2_p=new_element;
						b_element_2=new_element;
#ifdef INSERT_LOAD_GRAPHS
						b_element_2_p=(struct b_stack**)insert_load_graphs
								((struct stack **)&next_block_graph->block_graph_b_stack,offset_2,
								next_block_graph->block_graph_b_stack_begin_displacement,
								next_block_graph->block_graph_b_stack_top_offset,1);
#endif
					}
				}

				++offset_1;
				b_element_1_p=&b_element_1->b_stack_next;
				b_element_1=*b_element_1_p;
			}
		}

	while (b_element_1!=NULL){
		if (b_element_1->b_stack_flags & ELEMENT_MUST_BE_REMOVED){
			int offset_2;
			
			offset_1=b_element_1->b_stack_offset;
			offset_2=offset_1-stack_offset_1_min_2;
			
			while (b_element_2!=NULL && b_element_2->b_stack_offset<offset_2){
				b_element_2_p=&b_element_2->b_stack_next;
				b_element_2=*b_element_2_p;
			}

			remove_stack_element ((struct stack **)b_element_1_p);
			b_element_1=*b_element_1_p;
			--stack_offset_1_min_2;
			
			if (b_element_2!=NULL && b_element_2->b_stack_offset==offset_2){
				if (b_element_2->b_stack_flags & ELEMENT_MAY_BE_REMOVED)
					b_element_2->b_stack_flags |= ELEMENT_MUST_BE_REMOVED;
				else {
					b_element_2->b_stack_flags |= BEGIN_ELEMENT_MUST_BE_REMOVED;
#ifdef INSERT_LOAD_GRAPHS
					b_element_2_p=(struct b_stack**)insert_load_graphs
						((struct stack **)&next_block_graph->block_graph_b_stack,offset_2,
						next_block_graph->block_graph_b_stack_begin_displacement,
						next_block_graph->block_graph_b_stack_top_offset,1);
#endif
				}
			} else {
				struct b_stack *new_element;

				new_element=allocate_struct_from_heap (b_stack);
				new_element->b_stack_offset=offset_2;
				new_element->b_stack_flags=BEGIN_ELEMENT_MUST_BE_REMOVED;
				new_element->b_stack_graph=NULL;
				new_element->b_stack_load_graph=NULL;
			
				new_element->b_stack_next=b_element_2;
				*b_element_2_p=new_element;
				b_element_2=new_element;
#ifdef INSERT_LOAD_GRAPHS
				b_element_2_p=(struct b_stack**)insert_load_graphs
						((struct stack **)&next_block_graph->block_graph_b_stack,offset_2,
						next_block_graph->block_graph_b_stack_begin_displacement,
						next_block_graph->block_graph_b_stack_top_offset,1);
#endif
			}
		} else if (b_element_1->b_stack_flags & BEGIN_ELEMENT_MUST_BE_REMOVED){
			remove_begin_stack_element
				((struct stack **)&block_graph->block_graph_b_stack,
				 b_element_1->b_stack_offset,block_graph->block_graph_b_stack_begin_displacement,
				 block_graph->block_graph_b_stack_top_offset,1);
			b_element_1=*b_element_1_p;
				
			--block_graph->block_graph_b_stack_top_offset;
			--stack_offset_1_min_2;
		} else {
			b_element_1_p=&b_element_1->b_stack_next;
			b_element_1=*b_element_1_p;
		}
	}

}

static void remove_not_used_stack_elements_from_last_block (struct block_graph *block_graph)
{
	struct a_stack *a_element_1,**a_element_1_p;
	struct b_stack *b_element_1,**b_element_1_p;

	a_element_1_p=&block_graph->block_graph_a_stack;
	a_element_1=*a_element_1_p;

	while (a_element_1!=NULL){
		if (a_element_1->a_stack_flags & BEGIN_ELEMENT_MUST_BE_REMOVED){
			remove_begin_stack_element
				((struct stack **)&block_graph->block_graph_a_stack,
				 a_element_1->a_stack_offset,block_graph->block_graph_a_stack_begin_displacement,
				 block_graph->block_graph_a_stack_top_offset,0);
			a_element_1=*a_element_1_p;
				
			--block_graph->block_graph_a_stack_top_offset;
		} else {
			if (a_element_1->a_stack_flags & ELEMENT_MUST_BE_REMOVED){
				internal_error_in_function ("remove_not_used_stack_elements_from_last_block");
			} else
				a_element_1_p=&a_element_1->a_stack_next;
			a_element_1=*a_element_1_p;
		}
	}
	
	b_element_1_p=&block_graph->block_graph_b_stack;
	b_element_1=*b_element_1_p;

	while (b_element_1!=NULL){
		if (b_element_1->b_stack_flags & BEGIN_ELEMENT_MUST_BE_REMOVED){
			remove_begin_stack_element
				((struct stack **)&block_graph->block_graph_b_stack,
				 b_element_1->b_stack_offset,block_graph->block_graph_b_stack_begin_displacement,
				 block_graph->block_graph_b_stack_top_offset,1);
			b_element_1=*b_element_1_p;
				
			--block_graph->block_graph_b_stack_top_offset;
		} else {
			if (b_element_1->b_stack_flags & ELEMENT_MUST_BE_REMOVED){
				internal_error_in_function ("remove_not_used_stack_elements_from_last_block");
			} else
				b_element_1_p=&b_element_1->b_stack_next;
			b_element_1=*b_element_1_p;
		}
	}
}

static struct block_graph *first_block_graph,*last_block_graph;

static void insert_dummy_graphs_for_unused_a_stack_elements 
	(struct block_graph *block_graph,struct block_graph *next_block_graph)
{
	struct a_stack *a_element_1,**a_element_1_p;
	struct a_stack *a_element_2;
	int stack_offset_difference,offset,n;
	int first_non_parameter_offset_1,first_non_parameter_offset_2;
	
#ifdef DEBUG
	printf ("%d %d %d %d\n",block_graph->block_graph_a_stack_top_offset,
							block_graph->block_graph_end_a_stack_size,
							-next_block_graph->block_graph_begin_a_stack_size,
							block_graph->block_graph_used_a_stack_elements);
#endif
	
	stack_offset_difference=	block_graph->block_graph_a_stack_top_offset
								+block_graph->block_graph_end_a_stack_size
								-next_block_graph->block_graph_begin_a_stack_size;
	first_non_parameter_offset_1=	block_graph->block_graph_used_a_stack_elements
								+block_graph->block_graph_a_stack_top_offset;
	
	a_element_1_p=&block_graph->block_graph_a_stack;
	a_element_1=*a_element_1_p;
	
	a_element_2=next_block_graph->block_graph_a_stack;

	first_non_parameter_offset_2=first_non_parameter_offset_1-stack_offset_difference;
	while (a_element_2!=NULL && a_element_2->a_stack_offset<first_non_parameter_offset_2)
		a_element_2=a_element_2->a_stack_next;

	for (; a_element_2!=NULL; a_element_2=a_element_2->a_stack_next){
		INSTRUCTION_GRAPH load_graph;
		
		if (a_element_2->a_stack_flags & ELEMENT_MAY_BE_REMOVED
			 || (load_graph=a_element_2->a_stack_load_graph)==NULL
			 	|| !load_graph->node_mark)
		{
			offset=a_element_2->a_stack_offset+stack_offset_difference;
		
			while (a_element_1!=NULL && a_element_1->a_stack_offset<offset){
				a_element_1_p=&a_element_1->a_stack_next;
				a_element_1=*a_element_1_p;
			}
			 
			if (a_element_1==NULL || a_element_1->a_stack_offset!=offset){
				struct a_stack *new_element;
#ifdef DEBUG
				printf ("%d ",offset);
#endif				
				new_element=allocate_struct_from_heap (a_stack);
				new_element->a_stack_offset=offset;
				new_element->a_stack_flags=ELEMENT_MAY_BE_REMOVED;
				new_element->a_stack_graph=NULL;
				new_element->a_stack_load_graph=NULL;
				
				new_element->a_stack_next=a_element_1;
				*a_element_1_p=new_element;
				a_element_1_p=&new_element->a_stack_next;
			}
		}
	}

#ifdef DEBUG
	printf ("| ");
#endif

	a_element_1_p=&block_graph->block_graph_a_stack;
	a_element_1=*a_element_1_p;
	
	a_element_2=next_block_graph->block_graph_a_stack;
	
	n=first_non_parameter_offset_1-stack_offset_difference;
	if (n<0)
		n=0;
		
	for (; n<next_block_graph->block_graph_a_stack_top_offset; ++n){
		while (a_element_2!=NULL && a_element_2->a_stack_offset<n)
			a_element_2=a_element_2->a_stack_next;
		if (a_element_2==NULL || a_element_2->a_stack_offset!=n){
			
			while (a_element_1!=NULL && a_element_1->a_stack_offset<n+stack_offset_difference){
				a_element_1_p=&a_element_1->a_stack_next;
				a_element_1=*a_element_1_p;
			}
			if (a_element_1==NULL || a_element_1->a_stack_offset!=n+stack_offset_difference){
				struct a_stack *new_element;
#ifdef DEBUG				
				printf ("%d ",n+stack_offset_difference);
#endif	
				new_element=allocate_struct_from_heap (a_stack);
				new_element->a_stack_offset=n+stack_offset_difference;
				new_element->a_stack_flags=ELEMENT_MAY_BE_REMOVED;
				new_element->a_stack_graph=NULL;
				new_element->a_stack_load_graph=NULL;
	
				new_element->a_stack_next=a_element_1;
				*a_element_1_p=new_element;
				a_element_1_p=&new_element->a_stack_next;
			} 
		}
	}
	
#ifdef DEBUG
	printf ("\n");
#endif
}

static void insert_dummy_graphs_for_unused_b_stack_elements 
   (register struct block_graph *block_graph,struct block_graph *next_block_graph)
{
	struct b_stack *b_element_1,**b_element_1_p,*b_element_2;
	int stack_offset_1_min_2,offset_1,offset_2;
	int first_non_parameter_offset_1,first_non_parameter_offset_2;
	
	/*
	printf ("%d %d %d %d\n",block_graph->block_graph_b_stack_top_offset,
							block_graph->block_graph_end_b_stack_size,
							-next_block_graph->block_graph_begin_b_stack_size,
							block_graph->block_graph_used_b_stack_elements);
	*/
	
	stack_offset_1_min_2=
		block_graph->block_graph_b_stack_top_offset
		+block_graph->block_graph_end_b_stack_size
		-next_block_graph->block_graph_begin_b_stack_size;
	first_non_parameter_offset_1=
		block_graph->block_graph_used_b_stack_elements
		+block_graph->block_graph_b_stack_top_offset;

	/*	
		insert dummy graphs in the current block for elements for which a node
		has been made in the next block, but will not be used any more
	*/
	
	b_element_1_p=&block_graph->block_graph_b_stack;
	b_element_1=*b_element_1_p;
	
	b_element_2=next_block_graph->block_graph_b_stack;

	first_non_parameter_offset_2=first_non_parameter_offset_1-stack_offset_1_min_2;
	while (b_element_2!=NULL && b_element_2->b_stack_offset<first_non_parameter_offset_2)
		b_element_2=b_element_2->b_stack_next;

	for (; b_element_2!=NULL; b_element_2=b_element_2->b_stack_next){
		INSTRUCTION_GRAPH load_graph;
		
		if (b_element_2->b_stack_flags & ELEMENT_MAY_BE_REMOVED || 
			((load_graph=b_element_2->b_stack_load_graph)==NULL ||
			 (!load_graph->node_mark && 
			  !(
#ifdef G_A64
				load_graph->instruction_code==GFROMF
#else
				(load_graph->instruction_code==GFHIGH || 
				 load_graph->instruction_code==GFLOW)
#endif
				&& load_graph->instruction_parameters[0].p->node_mark))))
		{
			offset_1=b_element_2->b_stack_offset+stack_offset_1_min_2;
		
			while (b_element_1!=NULL && b_element_1->b_stack_offset<offset_1){
				b_element_1_p=&b_element_1->b_stack_next;
				b_element_1=*b_element_1_p;
			}
	
			if (b_element_1==NULL || b_element_1->b_stack_offset!=offset_1){
				register struct b_stack *new_element;
				
				/* printf ("%d ",offset_1); */
				
				new_element=allocate_struct_from_heap (b_stack);
				new_element->b_stack_offset=offset_1;
				new_element->b_stack_flags=ELEMENT_MAY_BE_REMOVED;
				new_element->b_stack_graph=NULL;
				new_element->b_stack_load_graph=NULL;
								
				new_element->b_stack_next=b_element_1;
				*b_element_1_p=new_element;
				b_element_1_p=&new_element->b_stack_next;
			}
		}
	}
	
	/* printf ("| "); */
	
	/*	
		insert dummy graphs in the current block for elements for which are popped
		from the stack in the next block
	*/

	b_element_1_p=&block_graph->block_graph_b_stack;
	b_element_1=*b_element_1_p;
	
	b_element_2=next_block_graph->block_graph_b_stack;
	
	offset_2=first_non_parameter_offset_2;
	if (offset_2<0)
		offset_2=0;
	
	for (; offset_2<next_block_graph->block_graph_b_stack_top_offset; ++offset_2){
		while (b_element_2!=NULL && b_element_2->b_stack_offset<offset_2)
			b_element_2=b_element_2->b_stack_next;
		if (b_element_2==NULL || b_element_2->b_stack_offset!=offset_2){
			offset_1=offset_2+stack_offset_1_min_2;
			while (b_element_1!=NULL && b_element_1->b_stack_offset<offset_1){
				b_element_1_p=&b_element_1->b_stack_next;
				b_element_1=*b_element_1_p;
			}
			if (b_element_1==NULL || b_element_1->b_stack_offset!=offset_1){
				register struct b_stack *new_element;
				
				/* printf ("%d ",offset_1); */
				
				new_element=allocate_struct_from_heap (b_stack);
				new_element->b_stack_offset=offset_1;
				new_element->b_stack_flags=ELEMENT_MAY_BE_REMOVED;
				new_element->b_stack_graph=NULL;
				new_element->b_stack_load_graph=NULL;
	
				new_element->b_stack_next=b_element_1;
				*b_element_1_p=new_element;
				b_element_1_p=&new_element->b_stack_next;
			}
		}
	}
	
	/* printf ("\n"); */
}

static void mark_stack_graphs_1
   (struct block_graph *block_graph,struct block_graph *next_block_graph,int jmp_jsr_or_rtn_flag)
{
	int stack_offset_difference,first_non_parameter_offset,offset;
	struct b_stack *b_element_1,*b_element_2,**b_element_1_p;
	struct a_stack *a_element;
	int a_stack_top_offset,b_stack_top_offset;
	
	a_stack_top_offset=block_graph->block_graph_a_stack_top_offset;
	a_element=block_graph->block_graph_a_stack;

	while (a_element!=NULL && a_element->a_stack_offset<a_stack_top_offset)
		a_element=a_element->a_stack_next;

	for (; a_element!=NULL; a_element=a_element->a_stack_next)
		if (a_element->a_stack_graph!=NULL)
			mark_graph_2 (a_element->a_stack_graph);

	stack_offset_difference=block_graph->block_graph_b_stack_top_offset
		+block_graph->block_graph_end_b_stack_size
		-next_block_graph->block_graph_begin_b_stack_size;
	first_non_parameter_offset=block_graph->block_graph_used_b_stack_elements
		+block_graph->block_graph_b_stack_top_offset;
	
	/*
	printf ("%d %d %d %d\n",
		block_graph->block_graph_used_b_stack_elements,
		block_graph->block_graph_b_stack_top_offset,
		stack_offset_difference,first_non_parameter_offset);
	*/

	b_element_2=next_block_graph->block_graph_b_stack;

	b_stack_top_offset=block_graph->block_graph_b_stack_top_offset;
	b_element_1=block_graph->block_graph_b_stack;

	while (b_element_1!=NULL && b_element_1->b_stack_offset<b_stack_top_offset)
		b_element_1=b_element_1->b_stack_next;
	
	for (; b_element_1!=NULL; b_element_1=b_element_1->b_stack_next)
		if (b_element_1->b_stack_graph!=NULL){
			/* printf ("%d",b_element_1->b_stack_offset); */

			if (b_element_1->b_stack_offset<first_non_parameter_offset){
				b_element_1->b_stack_flags|=ELEMENT_USED_BEFORE_JSR;
				mark_graph_2 (b_element_1->b_stack_graph);
			} else {
				int required_offset;
				
				required_offset=b_element_1->b_stack_offset-stack_offset_difference;
				
				while (b_element_2!=NULL && b_element_2->b_stack_offset<required_offset)
					b_element_2=b_element_2->b_stack_next;
				
				if (!jmp_jsr_or_rtn_flag ||
					block_graph->block_graph_kind!=JSR_EVAL_BLOCK ||
					(b_element_2!=NULL && b_element_2->b_stack_offset==required_offset
					  && b_element_2->b_stack_load_graph!=NULL 
					  && (b_element_2->b_stack_load_graph->node_mark==2 || 
						  (
#ifdef G_A64
						  b_element_2->b_stack_load_graph->instruction_code==GFROMF
#else
						  (b_element_2->b_stack_load_graph->instruction_code==GFHIGH
							|| b_element_2->b_stack_load_graph->instruction_code==GFLOW)
#endif
						   && b_element_2->b_stack_load_graph->instruction_parameters[0].p->node_mark==2))))
				{
					b_element_1->b_stack_flags|=ELEMENT_USED_BEFORE_JSR;
					mark_graph_2 (b_element_1->b_stack_graph);
				} else {
					mark_graph_1 (b_element_1->b_stack_graph);
					/* printf ("*"); */
				}
			}
			/* printf (" "); */
		}

	if (block_graph->block_graph_kind==JSR_EVAL_BLOCK){
		b_element_1_p=&block_graph->block_graph_b_stack;
		b_element_1=*b_element_1_p;
	
		for (b_element_2=next_block_graph->block_graph_b_stack;
			b_element_2!=NULL; b_element_2=b_element_2->b_stack_next)
		{
			INSTRUCTION_GRAPH load_graph,next_load_graph,graph_1,next_graph_1;
			struct b_stack *next_b_element_2,*next_b_element_1;

			load_graph=b_element_2->b_stack_load_graph;
			if (load_graph!=NULL && 
				(load_graph->node_mark==2 || 
					(
#ifdef G_A64
					 load_graph->instruction_code==GFROMF
#else
					 (load_graph->instruction_code==GFHIGH || load_graph->instruction_code==GFLOW)
#endif
					 && load_graph->instruction_parameters[0].p->node_mark==2)) && 
				(offset=b_element_2->b_stack_offset+stack_offset_difference)>=first_non_parameter_offset)
			{		
				while (b_element_1!=NULL && b_element_1->b_stack_offset<offset){
					b_element_1_p=&b_element_1->b_stack_next;
					b_element_1=*b_element_1_p;
				}
				
#ifndef G_A64
				if (load_graph->instruction_code==GFHIGH && 
					(next_b_element_2=b_element_2->b_stack_next)!=NULL && 
					next_b_element_2->b_stack_offset==b_element_2->b_stack_offset+1 && 
					(next_load_graph=next_b_element_2->b_stack_load_graph)!=NULL && 
					next_load_graph->instruction_code==GFLOW && 
					next_load_graph->instruction_parameters[0].p==load_graph->instruction_parameters[0].p &&
					b_element_1!=NULL && b_element_1->b_stack_offset==offset && 
					(graph_1=b_element_1->b_stack_graph)!=NULL && 
					graph_1->instruction_code==GLOAD && 
					(next_b_element_1=b_element_1->b_stack_next)!=NULL && 
					next_b_element_1->b_stack_offset==offset+1 && 
					(next_graph_1=next_b_element_1->b_stack_graph)!=NULL && 
					next_graph_1->instruction_code==GLOAD && 
					graph_1->instruction_parameters[0].i+4==next_graph_1->instruction_parameters[0].i && 
					graph_1->instruction_parameters[1].i==next_graph_1->instruction_parameters[1].i)
				{
					INSTRUCTION_GRAPH f_graph;
					
					/* printf ("%d## ",offset); */
					
					f_graph=g_fload
						(graph_1->instruction_parameters[0].i,graph_1->instruction_parameters[1].i);
					f_graph->node_mark=2;
					
					graph_1->instruction_code=GFHIGH;
					graph_1->instruction_parameters[0].p=f_graph;
					graph_1->instruction_parameters[1].p=next_graph_1;
					graph_1->node_mark=2;
					
					next_graph_1->instruction_code=GFLOW;
					next_graph_1->instruction_parameters[0].p=f_graph;
					next_graph_1->instruction_parameters[1].p=graph_1;
					next_graph_1->node_mark=2;					
				} else
#endif
				if (b_element_1==NULL || b_element_1->b_stack_offset!=offset){
#ifdef G_A64
					if (load_graph->instruction_code==GFROMF)
#else
					if (load_graph->instruction_code==GFHIGH &&
						(next_b_element_2=b_element_2->b_stack_next)!=NULL &&
						next_b_element_2->b_stack_offset==b_element_2->b_stack_offset+1 && 
						(next_load_graph=next_b_element_2->b_stack_load_graph)!=NULL && 
						next_load_graph->instruction_code==GFLOW && 
						next_load_graph->instruction_parameters[0].p==load_graph->instruction_parameters[0].p && 
						(b_element_1==NULL || b_element_1->b_stack_offset!=offset+1))
#endif
					{
						struct b_stack *new_element;
						INSTRUCTION_GRAPH f_graph,l_graph,h_graph;
					
						/* printf ("%d# ",offset); */
				
						f_graph=g_fload
							((offset+block_graph->block_graph_b_stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
						f_graph->node_mark=2;

#ifdef G_A64
						f_graph=g_fromf (f_graph);
						f_graph->node_mark=2;

						new_element=allocate_struct_from_heap (b_stack);
						new_element->b_stack_offset=offset;
						new_element->b_stack_flags=ELEMENT_USED_BEFORE_JSR;
						new_element->b_stack_graph=f_graph;
						new_element->b_stack_load_graph=f_graph;
					
						new_element->b_stack_next=b_element_1;
						*b_element_1_p=new_element;
						b_element_1_p=&new_element->b_stack_next;
#else
						g_fhighlow (h_graph,l_graph,f_graph);
						h_graph->node_mark=2;
						l_graph->node_mark=2;
						
						new_element=allocate_struct_from_heap (b_stack);
						new_element->b_stack_offset=offset;
						new_element->b_stack_flags=ELEMENT_USED_BEFORE_JSR;
						new_element->b_stack_graph=h_graph;
						new_element->b_stack_load_graph=h_graph;
					
						new_element->b_stack_next=b_element_1;
						*b_element_1_p=new_element;
						b_element_1_p=&new_element->b_stack_next;

						new_element=allocate_struct_from_heap (b_stack);
						new_element->b_stack_offset=offset+1;
						new_element->b_stack_flags=ELEMENT_USED_BEFORE_JSR;
						new_element->b_stack_graph=l_graph;
						new_element->b_stack_load_graph=l_graph;
					
						new_element->b_stack_next=b_element_1;
						*b_element_1_p=new_element;
						b_element_1_p=&new_element->b_stack_next;
						
						b_element_2=next_b_element_2;
#endif
					} else {
						struct b_stack *new_element;
						INSTRUCTION_GRAPH graph;
		
						/* printf ("%d ",offset); */
		
						graph=g_load
							((offset+block_graph->block_graph_b_stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
						graph->node_mark=2;
						
						new_element=allocate_struct_from_heap (b_stack);
						new_element->b_stack_offset=offset;
						new_element->b_stack_flags=ELEMENT_USED_BEFORE_JSR;
						new_element->b_stack_graph=graph;
						new_element->b_stack_load_graph=graph;
					
						new_element->b_stack_next=b_element_1;
						*b_element_1_p=new_element;
						b_element_1_p=&new_element->b_stack_next;
					}
				}
			}
		}
	}
	
	b_element_1_p=&block_graph->block_graph_b_stack;
	b_element_1=*b_element_1_p;
	
	for (offset=block_graph->block_graph_b_stack_top_offset; offset<first_non_parameter_offset; ++offset){
		while (b_element_1!=NULL && b_element_1->b_stack_offset<offset){
			b_element_1_p=&b_element_1->b_stack_next;
			b_element_1=*b_element_1_p;
		}
	
		if (b_element_1==NULL || b_element_1->b_stack_offset!=offset){
			int n;
			
			n=offset-block_graph->block_graph_b_stack_top_offset;
			
			if ((unsigned)n < (unsigned)block_graph->block_graph_end_b_stack_size
				&& test_bit (block_graph->block_graph_end_stack_vector,n)
				&& (b_element_1==NULL || b_element_1->b_stack_offset!=offset+1)
				&&	mc68881_flag)
			{
				struct b_stack *new_element;
				INSTRUCTION_GRAPH f_graph,l_graph,h_graph;
		
				/* printf ("%d$# ",offset); */

				f_graph=g_fload
					((offset+block_graph->block_graph_b_stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
				f_graph->node_mark=2;

#ifdef G_A64
				f_graph=g_fromf (f_graph);
				f_graph->node_mark=2;
				
				new_element=allocate_struct_from_heap (b_stack);
				new_element->b_stack_offset=offset;
				new_element->b_stack_flags=ELEMENT_USED_BEFORE_JSR;
				new_element->b_stack_graph=f_graph;
				new_element->b_stack_load_graph=f_graph;
			
				new_element->b_stack_next=b_element_1;
				*b_element_1_p=new_element;
				b_element_1_p=&new_element->b_stack_next;
#else
				g_fhighlow (h_graph,l_graph,f_graph);
				h_graph->node_mark=2;
				l_graph->node_mark=2;
				
				new_element=allocate_struct_from_heap (b_stack);
				new_element->b_stack_offset=offset;
				new_element->b_stack_flags=ELEMENT_USED_BEFORE_JSR;
				new_element->b_stack_graph=h_graph;
				new_element->b_stack_load_graph=h_graph;
			
				new_element->b_stack_next=b_element_1;
				*b_element_1_p=new_element;
				b_element_1_p=&new_element->b_stack_next;

				new_element=allocate_struct_from_heap (b_stack);
				new_element->b_stack_offset=offset+1;
				new_element->b_stack_flags=ELEMENT_USED_BEFORE_JSR;
				new_element->b_stack_graph=l_graph;
				new_element->b_stack_load_graph=l_graph;
			
				new_element->b_stack_next=b_element_1;
				*b_element_1_p=new_element;
				b_element_1_p=&new_element->b_stack_next;
				
				++offset;
#endif
			} else {
				struct b_stack *new_element;
				INSTRUCTION_GRAPH graph;
	
				/* printf ("%d$ ",offset); */
	
				graph=g_load
					((offset+block_graph->block_graph_b_stack_begin_displacement)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
				graph->node_mark=2;
					
				new_element=allocate_struct_from_heap (b_stack);
				new_element->b_stack_offset=offset;
				new_element->b_stack_flags=ELEMENT_USED_BEFORE_JSR;
				new_element->b_stack_graph=graph;
				new_element->b_stack_load_graph=graph;
				
				new_element->b_stack_next=b_element_1;
				*b_element_1_p=new_element;
				b_element_1_p=&new_element->b_stack_next;
			}
		}
	}
	
	/* printf ("\n"); */
}

static void mark_stack_graphs_2 (struct block_graph *block_graph)
{
	struct a_stack *a_element;
	struct b_stack *b_element;
	int a_stack_top_offset,b_stack_top_offset;
	
	a_stack_top_offset=block_graph->block_graph_a_stack_top_offset;

	a_element=block_graph->block_graph_a_stack;

	while (a_element!=NULL && a_element->a_stack_offset<a_stack_top_offset)
		a_element=a_element->a_stack_next;

	for (; a_element!=NULL; a_element=a_element->a_stack_next)
		if (a_element->a_stack_graph!=NULL)
			mark_graph_2 (a_element->a_stack_graph);

	b_stack_top_offset=block_graph->block_graph_b_stack_top_offset;

	b_element=block_graph->block_graph_b_stack;
	while (b_element!=NULL && b_element->b_stack_offset<b_stack_top_offset)
		b_element=b_element->b_stack_next;

	for (; b_element!=NULL; b_element=b_element->b_stack_next)
		if (b_element->b_stack_graph!=NULL){
			b_element->b_stack_flags|=ELEMENT_USED_BEFORE_JSR;
			mark_graph_2 (b_element->b_stack_graph);
		}
}

#ifndef M68000
extern LONG offset_from_heap_register;
#endif
#ifdef G_POWER
extern LONG heap_pointer_offset_in_basic_block;
#endif

static void allocate_registers (void)
{
	int n;
	
	free_all_aregisters();
	free_all_dregisters();
	free_all_fregisters();
	
	for (n=0; n<N_ADDRESS_PARAMETER_REGISTERS; ++n){
		INSTRUCTION_GRAPH register_graph;
		
		register_graph=global_block.block_graph_a_register_parameter_node[n];
		if (register_graph!=NULL && register_graph->node_count>0)			
			allocate_aregister (register_graph->instruction_parameters[0].i);
	}
		
	for (n=0; n<N_DATA_PARAMETER_REGISTERS
#ifdef MORE_PARAMETER_REGISTERS
				+ N_ADDRESS_PARAMETER_REGISTERS
#endif
				; ++n){
		INSTRUCTION_GRAPH register_graph;
		
		register_graph=global_block.block_graph_d_register_parameter_node[n];
	
		if (register_graph!=NULL && register_graph->node_count>0)
			allocate_dregister (register_graph->instruction_parameters[0].i);
	}
	
	if (mc68881_flag)
		for (n=0; n<N_FLOAT_PARAMETER_REGISTERS; ++n){
			INSTRUCTION_GRAPH register_graph;
		
			register_graph=global_block.block_graph_f_register_parameter_node[n];
	
			if (register_graph!=NULL && register_graph->node_count>0)			
				allocate_fregister (register_graph->instruction_parameters[0].i);
		}
}

static void calculate_and_linearize_graphs (int n_elements,INSTRUCTION_GRAPH graphs[])
{
	int n;
	
	local_data_offset=
		(global_block.block_graph_b_stack_top_offset+
		 global_block.block_graph_b_stack_begin_displacement+
		 global_block.block_graph_b_stack_end_displacement)<<STACK_ELEMENT_LOG_SIZE;
	if (local_data_offset>0)
		local_data_offset=0;

	for (n=0; n<n_elements; ++n){
		INSTRUCTION_GRAPH a_graph;
		
		a_graph=graphs[n];
		
		if (a_graph->instruction_code!=GFILL)
			count_graph (a_graph);
		else {
			int n;
			
			for (n=0; n<a_graph->inode_arity; ++n)
				if (a_graph->instruction_parameters[n].p!=NULL)
					count_graph (a_graph->instruction_parameters[n].p);
		}
	}
	
	allocate_registers();

	for (n=0; n<n_elements; ++n)
		calculate_graph_register_uses (graphs[n]);

#ifndef M68000
	offset_from_heap_register=0;
#endif
#ifdef G_POWER
	heap_pointer_offset_in_basic_block=0;
#endif

	evaluate_arguments_and_free_addresses ((union instruction_parameter*)graphs,n_elements);

#ifndef M68000
	if (offset_from_heap_register!=0)
# ifdef G_POWER
		optimize_heap_pointer_increment (last_block,offset_from_heap_register);
# else
		i_add_i_r (offset_from_heap_register,HEAP_POINTER);
# endif
#endif
}

static int allocate_and_fill_graph_array (INSTRUCTION_GRAPH **graphs_p)
{
	int element_n,n_a_elements,n_b_elements;
	struct a_stack *a_element;
	struct b_stack *b_element;
	INSTRUCTION_GRAPH *graphs;

	n_a_elements=0;
	for_l (a_element,global_block.block_graph_a_stack,a_stack_next)
		if (a_element->a_stack_graph!=NULL)
			++n_a_elements;
	
	n_b_elements=0;
	for_l (b_element,global_block.block_graph_b_stack,b_stack_next)
		if (b_element->b_stack_graph!=NULL)
			++n_b_elements;
	
	if (n_a_elements+n_b_elements==0){
		*graphs_p=NULL;
		return 0;
	}
	
	graphs=(INSTRUCTION_GRAPH*)memory_allocate (sizeof (INSTRUCTION_GRAPH) * (n_a_elements+n_b_elements));
	*graphs_p=graphs;
	
	if (global_block.block_graph_a_stack_top_offset+
		global_block.block_graph_a_stack_begin_displacement+
		global_block.block_graph_a_stack_end_displacement<=0)
	{
		element_n=n_a_elements+n_b_elements;
		for_l (a_element,global_block.block_graph_a_stack,a_stack_next)
			if (a_element->a_stack_graph!=NULL)
				graphs[--element_n]=a_element->a_stack_graph;
	} else {
		element_n=n_b_elements;
		for_l (a_element,global_block.block_graph_a_stack,a_stack_next)
			if (a_element->a_stack_graph!=NULL)
				graphs[element_n++]=a_element->a_stack_graph;
	}
		
	if (global_block.block_graph_b_stack_top_offset+
		global_block.block_graph_b_stack_begin_displacement+
		global_block.block_graph_b_stack_end_displacement<=0)
	{
		element_n=n_b_elements;
		for_l (b_element,global_block.block_graph_b_stack,b_stack_next)
			if (b_element->b_stack_graph!=NULL)
				graphs[--element_n]=b_element->b_stack_graph;
	} else {
		element_n=0;
		for_l (b_element,global_block.block_graph_b_stack,b_stack_next)
			if (b_element->b_stack_graph!=NULL)
				graphs[element_n++]=b_element->b_stack_graph;
	}
	
	return n_a_elements+n_b_elements;
}

void linearize_stack_graphs (VOID)
{
	int n_elements;
	INSTRUCTION_GRAPH *graphs;

	n_elements=allocate_and_fill_graph_array (&graphs);

	if (graphs!=NULL){
		calculate_and_linearize_graphs (n_elements,graphs);

#ifdef THREAD32
		if (last_block->block_n_new_heap_cells!=0)
			i_move_r_id (HEAP_POINTER,0,REGISTER_A4);
#endif

		memory_free (graphs);
	} else
		allocate_registers();
}

void linearize_stack_graphs_with_overflow_test (INSTRUCTION_GRAPH test_overflow_graph,INSTRUCTION_GRAPH store_calculate_with_overflow_graph)
{
	int n_elements;
	INSTRUCTION_GRAPH *graphs;

	count_graph (store_calculate_with_overflow_graph);

	n_elements=allocate_and_fill_graph_array (&graphs);

	if (graphs!=NULL){
		int n;
		
		local_data_offset= (global_block.block_graph_b_stack_top_offset+
							global_block.block_graph_b_stack_begin_displacement+
			 				global_block.block_graph_b_stack_end_displacement)<<STACK_ELEMENT_LOG_SIZE;
		if (local_data_offset>0)
			local_data_offset=0;

		for (n=0; n<n_elements; ++n){
			INSTRUCTION_GRAPH a_graph;
			
			a_graph=graphs[n];
			
			if (a_graph->instruction_code!=GFILL)
				count_graph (a_graph);
			else {
				int n;
				
				for (n=0; n<a_graph->inode_arity; ++n)
					if (a_graph->instruction_parameters[n].p!=NULL)
						count_graph (a_graph->instruction_parameters[n].p);
			}
		}
	}

	if (test_overflow_graph->node_count==1 && store_calculate_with_overflow_graph->node_count==1
		&& (store_calculate_with_overflow_graph->instruction_code==GSTORE_R
			? store_calculate_with_overflow_graph->instruction_parameters[1].p->node_count==2
			: store_calculate_with_overflow_graph->instruction_parameters[2].p->node_count==2))
	{
		test_overflow_graph->node_count=0;
		if (store_calculate_with_overflow_graph->instruction_code==GSTORE_R)
			store_calculate_with_overflow_graph->instruction_parameters[1].p->node_count=1;
		else
			store_calculate_with_overflow_graph->instruction_parameters[2].p->node_count=1;
	}
	
	allocate_registers();

	if (graphs!=NULL){
		int n;

		for (n=0; n<n_elements; ++n)
			calculate_graph_register_uses (graphs[n]);

#ifndef M68000
		offset_from_heap_register=0;
#endif
#ifdef G_POWER
		heap_pointer_offset_in_basic_block=0;
#endif

		evaluate_arguments_and_free_addresses ((union instruction_parameter*)graphs,n_elements);

#ifndef M68000
		if (offset_from_heap_register!=0)
# ifdef G_POWER
			optimize_heap_pointer_increment (last_block,offset_from_heap_register);
# else
			i_add_i_r (offset_from_heap_register,HEAP_POINTER);
# endif
#endif

#ifdef THREAD32
		if (last_block->block_n_new_heap_cells!=0)
			i_move_r_id (HEAP_POINTER,0,REGISTER_A4);
#endif

		memory_free (graphs);
	}
	
	calculate_and_linearize_graph (store_calculate_with_overflow_graph);
}

INSTRUCTION_GRAPH search_and_remove_graph_from_b_stack (INSTRUCTION_GRAPH calculate_with_overflow_graph)
{
	struct b_stack *b_element;
	
	for_l (b_element,global_block.block_graph_b_stack,b_stack_next){
		INSTRUCTION_GRAPH stack_graph;
		
		stack_graph=b_element->b_stack_graph;
		if (stack_graph!=NULL &&
			((stack_graph->instruction_code==GSTORE_R && stack_graph->instruction_parameters[1].p==calculate_with_overflow_graph)
			 || (stack_graph->instruction_code==GSTORE && stack_graph->instruction_parameters[2].p==calculate_with_overflow_graph)))
		{
			b_element->b_stack_graph=NULL;
			return stack_graph;
		}
	}

	return NULL;
}

static int block_check;
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
int block_a_stack_displacement,block_b_stack_displacement;
static WORD *a_check_size_p,*b_check_size_p;
#else
int block_stack_displacement;
static WORD *check_size_p;
#endif

static int stack_access_and_adjust_a_stack_pointer (int extra_b_offset,int do_not_alter_condition_codes
# ifdef ARM
	,int try_adjust_b_stack_pointer
# endif
	)
{
	int a_offset,b_offset,minimum_b_offset;
	
	a_offset=-(	global_block.block_graph_a_stack_top_offset+
				global_block.block_graph_a_stack_begin_displacement+
				global_block.block_graph_a_stack_end_displacement)<<STACK_ELEMENT_LOG_SIZE;
	b_offset=(	global_block.block_graph_b_stack_top_offset+
				global_block.block_graph_b_stack_begin_displacement+
				global_block.block_graph_b_stack_end_displacement)<<STACK_ELEMENT_LOG_SIZE;
	
	minimum_b_offset= local_data_offset<b_offset ? local_data_offset : b_offset;
	
	if (block_check){
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
		int a_check_size,b_check_size;

		if (last_block_graph!=NULL){
			last_block_graph->block_graph_a_stack_displacement=a_offset;
			last_block_graph->block_graph_b_stack_displacement=b_offset;
		}

		if (a_check_size_p==NULL){
			a_check_size=a_offset>0 ? a_offset : 0;
			b_check_size=minimum_b_offset<0 ? -b_offset : 0;

			a_check_size_p=&last_block->block_a_stack_check_size;
			b_check_size_p=&last_block->block_b_stack_check_size;
			*a_check_size_p=a_check_size;
			*b_check_size_p=b_check_size;
			block_a_stack_displacement=a_offset;
			block_b_stack_displacement=-b_offset;
		} else {
			a_check_size=block_a_stack_displacement+(a_offset>0 ? a_offset : 0);
			b_check_size=block_b_stack_displacement+(minimum_b_offset<0 ? -b_offset : 0);
			if (a_check_size>*a_check_size_p)
				*a_check_size_p=a_check_size;
			if (b_check_size>*b_check_size_p)
				*b_check_size_p=b_check_size;
			block_a_stack_displacement+=a_offset;
			block_b_stack_displacement-=b_offset;
		}
	} else {
		last_block->block_a_stack_check_size=a_offset>0 ? a_offset : 0;
		last_block->block_b_stack_check_size=minimum_b_offset<0 ? -b_offset : 0;
	}
#else
		int check_size;

		if (last_block_graph!=NULL)
			last_block_graph->block_graph_stack_displacement=a_offset+b_offset;

		if (check_size_p==NULL){
			check_size=(minimum_b_offset<0 ? -b_offset : 0) + (a_offset>0 ? a_offset : 0);

			check_size_p=&last_block->block_stack_check_size;
			*check_size_p=check_size;
			block_stack_displacement=a_offset-b_offset;
		} else {
			check_size=block_stack_displacement+(minimum_b_offset<0 ? -b_offset : 0) + (a_offset>0 ? a_offset : 0);
			if (check_size>*check_size_p)
				*check_size_p=check_size;
			block_stack_displacement+=a_offset-b_offset;
		}
	} else
		last_block->block_stack_check_size=(minimum_b_offset<0 ? -b_offset : 0) + (a_offset>0 ? a_offset : 0);
#endif

	b_offset+=extra_b_offset;

#if defined (M68000) || defined (I486) || defined (ARM) || defined (G_POWER)
	optimize_stack_access (last_block,&a_offset,&b_offset
# ifdef ARM
		,try_adjust_b_stack_pointer
# endif
		);
#endif

	if (a_offset!=0)
#ifdef I486
		if (do_not_alter_condition_codes)
			i_lea_id_r (a_offset,A_STACK_POINTER,A_STACK_POINTER);
		else
#endif
		if (a_offset>0)
			i_add_i_r (a_offset,A_STACK_POINTER);
		else
			i_sub_i_r (-a_offset,A_STACK_POINTER);

	return b_offset;
}

static void stack_access (int do_not_alter_condition_codes)
{
	register int b_offset;

	b_offset=stack_access_and_adjust_a_stack_pointer (0,do_not_alter_condition_codes
# ifdef ARM
														,1
# endif
														);
	
	if (b_offset!=0)
#ifdef I486
		if (do_not_alter_condition_codes)
			i_lea_id_r (b_offset,B_STACK_POINTER,B_STACK_POINTER);
		else
#endif
		if (b_offset>0)
			i_add_i_r (b_offset,B_STACK_POINTER);
		else
			i_sub_i_r (-b_offset,B_STACK_POINTER);
}

static int local_register_allocation_and_adjust_a_stack_pointer (int extra_b_offset
# ifdef ARM
	,int try_adjust_b_stack_pointer
# endif
	)
{
	int n_virtual_a_regs,n_virtual_d_regs,n_virtual_f_regs;
	
	get_n_virtual_registers (&n_virtual_a_regs,&n_virtual_d_regs,&n_virtual_f_regs);
	do_register_allocation (last_instruction,last_block,n_virtual_a_regs,n_virtual_d_regs,n_virtual_f_regs,0,0);
	return stack_access_and_adjust_a_stack_pointer (extra_b_offset,0
# ifdef ARM
													,try_adjust_b_stack_pointer
# endif
													);
}

void adjust_stack_pointers (void)
{
	int n_virtual_a_regs,n_virtual_d_regs,n_virtual_f_regs;
	
	get_n_virtual_registers (&n_virtual_a_regs,&n_virtual_d_regs,&n_virtual_f_regs);
	do_register_allocation (last_instruction,last_block,n_virtual_a_regs,n_virtual_d_regs,n_virtual_f_regs,0,0);
	stack_access (0);
}

int adjust_stack_pointers_without_altering_condition_codes (int float_condition,int condition)
{
	int n_virtual_a_regs,n_virtual_d_regs,n_virtual_f_regs,condition_on_stack;
	
	get_n_virtual_registers (&n_virtual_a_regs,&n_virtual_d_regs,&n_virtual_f_regs);
	condition_on_stack=do_register_allocation (last_instruction,last_block,n_virtual_a_regs,n_virtual_d_regs,n_virtual_f_regs,1+float_condition,condition);
	stack_access (1);
	return condition_on_stack;
}

struct basic_block *allocate_empty_basic_block (VOID)
{
	struct basic_block *block;
	
	block=(struct basic_block*)fast_memory_allocate (sizeof (struct basic_block));
	block->block_next=NULL;
	block->block_instructions=NULL;
	block->block_last_instruction=NULL;
	block->block_labels=NULL;
	block->block_n_new_heap_cells=0;
	block->block_n_begin_a_parameter_registers=0;
	block->block_n_begin_d_parameter_registers=0;
	block->block_n_node_arguments=-100;
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
	block->block_a_stack_check_size=0;
	block->block_b_stack_check_size=0;
#else
	block->block_stack_check_size=0;
#endif
	block->block_begin_module=0;
	block->block_profile=0;
#ifdef G_POWER
	block->block_gc_kind=0;
#endif
	
	return block;
}

#ifdef G_POWER
#	define SMALLER_EVAL
#endif

#ifdef M68000
static int
#else
static void
#endif
generate_code_for_jsr_eval (int n_a_registers,int n_d_registers,int n_f_registers,int offset)
{
	int n,node_a_register;
	struct basic_block *new_block;
#ifdef M68000
	int code_size;
#endif

#if defined (sparc) || defined (I486) || defined (ARM) || defined (G_POWER)
	int a_offset,b_offset;
#endif
#if defined (M68000)
	static int d_registers[]={
		REGISTER_D0,REGISTER_D1,REGISTER_D2,REGISTER_D3,REGISTER_D4,
		REGISTER_D5,REGISTER_D6
	};
#endif
#if defined (ARM)
	static int reversed_d_registers[]={
# ifdef G_A64
		REGISTER_D6,REGISTER_D5,
# endif
		REGISTER_D4,REGISTER_D3,REGISTER_D2,REGISTER_D1,REGISTER_D0
	};
#endif
	
	node_a_register=n_a_registers-offset-1;
	
	last_instruction=NULL;

	new_block=allocate_empty_basic_block();
	
	new_block->block_n_begin_a_parameter_registers=n_a_registers;
	new_block->block_n_begin_d_parameter_registers=n_d_registers+1;
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
	new_block->block_a_stack_check_size=(n_a_registers)<<STACK_ELEMENT_LOG_SIZE;
	new_block->block_b_stack_check_size=(n_d_registers<<STACK_ELEMENT_LOG_SIZE) + (n_f_registers<<3);
#else
	new_block->block_stack_check_size=((n_a_registers+n_d_registers)<<STACK_ELEMENT_LOG_SIZE) + (n_f_registers<<3);
#endif
	
	new_block->block_next=last_block->block_next;
	last_block->block_next=new_block;
	last_block=new_block;

#ifdef M68000
	code_size=0;
	for (n=n_a_registers-1; n>=0; --n)
		if (n!=node_a_register){
			i_move_r_pi (num_to_a_reg (n),A_STACK_POINTER);
			code_size+=2;
		}
#else
	a_offset=0;
#	ifdef SMALLER_EVAL
	if (n_a_registers>1)
		i_mtctr (num_to_d_reg (n_d_registers));
#	else
#		if defined (ARM)
	if (node_a_register!=0 && (n_a_registers==1 || (n_a_registers==2 && node_a_register==1))){
		i_move_r_idpa (num_to_a_reg (0),A_STACK_POINTER,STACK_ELEMENT_SIZE);
	} else if (node_a_register==0 && n_a_registers==2){
		i_move_r_idpa (num_to_a_reg (1),A_STACK_POINTER,STACK_ELEMENT_SIZE);
	} else {
		if (n_a_registers>2){
			int a_registers[3],a_reg_n;
			
			a_reg_n=0;
			for (n=0; n<n_a_registers; ++n)
				if (n!=node_a_register)
					a_registers[a_reg_n++]=num_to_a_reg (n);
			i_movem_rs_pi (a_reg_n,a_registers,A_STACK_POINTER);
		} else {
			for (n=0; n<n_a_registers; ++n)
				if (n!=node_a_register){
					i_move_r_id (num_to_a_reg (n),a_offset,A_STACK_POINTER);
					a_offset+=STACK_ELEMENT_SIZE;
				}
			if (a_offset>0)
				i_add_i_r (a_offset,A_STACK_POINTER);
		}
	}
#		else
	for (n=n_a_registers-1; n>=0; --n)
		if (n!=node_a_register){
			i_move_r_id (num_to_a_reg (n),a_offset,A_STACK_POINTER);
			a_offset+=STACK_ELEMENT_SIZE;
		}
	if (a_offset>0)
		i_add_i_r (a_offset,A_STACK_POINTER);
#		endif
#	endif
#endif

#ifndef SMALLER_EVAL
	if (node_a_register!=0){
		i_move_r_r (num_to_a_reg (node_a_register),REGISTER_A0);
#	ifdef M68000
		code_size+=2;
#	endif
	}
#endif

#ifdef M68000
	if (n_d_registers>=4){
		i_movem_pd (B_STACK_POINTER,n_d_registers,d_registers);
		code_size+=4;
	} else
		for (n=0; n<n_d_registers; ++n){
			i_move_r_pd (num_to_d_reg (n),B_STACK_POINTER);
			code_size+=2;
		}
#elif defined (I486)
	b_offset=0;
	for (n=0; n<n_d_registers; ++n)
		i_move_r_pd (num_to_d_reg (n),B_STACK_POINTER);
#elif defined (ARM)
	b_offset = n_d_registers << STACK_ELEMENT_LOG_SIZE;
	if (n_d_registers!=0){
		if (n_d_registers==1){
			i_move_r_pd (num_to_d_reg (0),B_STACK_POINTER);
			b_offset=0;
		} else {
			i_movem_rs_pd (n_d_registers,&reversed_d_registers[N_DATA_PARAMETER_REGISTERS-n_d_registers],B_STACK_POINTER);
			b_offset=0;
			/*
			i_sub_i_r (b_offset,B_STACK_POINTER);
			for (n=0; n<n_d_registers; ++n){
				b_offset-=STACK_ELEMENT_SIZE;
				i_move_r_id (num_to_d_reg (n),b_offset,B_STACK_POINTER);
			}
			*/
		}
	}
#else
	b_offset=0;
	for (n=0; n<n_d_registers; ++n){
		b_offset+=STACK_ELEMENT_SIZE;
		i_move_r_id (num_to_d_reg (n),-b_offset,B_STACK_POINTER);
	}
#endif

#ifdef M68000
	for (n=0; n<n_f_registers; ++n){
		i_fmove_fr_pd (n,B_STACK_POINTER);
		code_size+=4;
	}
#else
	for (n=0; n<n_f_registers; ++n){
		b_offset+=8;
		i_fmove_fr_id (n,-b_offset,B_STACK_POINTER);
	}
#	if defined (I486) || defined (ARM)
		if (b_offset)
			i_sub_i_r (b_offset,B_STACK_POINTER);
#	else
#		if !defined (G_POWER)
			i_sub_i_r (b_offset+4,B_STACK_POINTER);
#		endif
#	endif
#endif

#ifdef M68000
	i_move_r_r (num_to_d_reg (n_d_registers),REGISTER_A1);
	i_jsr_id (0,REGISTER_A1,256);
	code_size+=4;
#elif defined (I486)
	i_jsr_id (0,num_to_a_reg (node_a_register),0);
#elif defined (ARM)
# ifdef G_A64
	i_jsr_r_idu (REGISTER_D7,-STACK_ELEMENT_SIZE);
# else
	i_jsr_r_idu (REGISTER_D6,-STACK_ELEMENT_SIZE);
# endif
#elif defined (G_POWER)
#	ifdef SMALLER_EVAL
		if (n_a_registers>1){
			struct label *eval_label;

			if (n_a_registers==2)
				eval_label = node_a_register==0 ? eval_01_label : eval_11_label;
			else
				eval_label = node_a_register==0 ? eval_02_label : node_a_register==1 ? eval_12_label : eval_22_label;

			i_jsr_l_idu (eval_label,-(b_offset+4));
		} else
#	endif
	i_jsr_id_idu (0,num_to_d_reg (n_d_registers),-(b_offset+4));
#else
	i_jsr_id_id (0,num_to_d_reg (n_d_registers),0);
#endif

#ifdef M68000
	for (n=n_f_registers-1; n>=0; --n){
		i_fmove_pi_fr (B_STACK_POINTER,n);
		code_size+=4;
	}
#else
	offset=0;
	for (n=n_f_registers-1; n>=0; --n){
		i_fmove_id_fr (-offset,B_STACK_POINTER,n);
		offset-=8;
	}
#endif

#ifdef M68000
	if (n_d_registers>=4){
		i_movem_pi (B_STACK_POINTER,n_d_registers,d_registers);
		code_size+=4;
	} else
		for (n=n_d_registers-1; n>=0; --n){
			i_move_pi_r (B_STACK_POINTER,num_to_d_reg (n));
			code_size+=2;
		}
#elif defined (I486)
		if (b_offset>0)
			i_add_i_r (b_offset,B_STACK_POINTER);
		for (n=n_d_registers-1; n>=0; --n)
			i_move_pi_r (B_STACK_POINTER,num_to_d_reg (n));	
#else
#	if defined (ARM)
		if (offset==0){
			if (n_d_registers==1){
				i_move_pi_r (B_STACK_POINTER,num_to_d_reg (0));				
				offset -= STACK_ELEMENT_SIZE;
			} else if (n_d_registers>1){
				i_movem_pi_rs (B_STACK_POINTER,n_d_registers,&reversed_d_registers[N_DATA_PARAMETER_REGISTERS-n_d_registers]);
				offset -= n_d_registers << STACK_ELEMENT_LOG_SIZE;
			}
		} else
#	endif
		{
#	ifdef THUMB
			/* i_movem_rs_pd hasn't pushed the registers in the right order if n_d_registers>2 */
			if (n_d_registers>2){
				i_move_id_r (-offset,B_STACK_POINTER,REGISTER_D1);
				offset-=STACK_ELEMENT_SIZE;
				i_move_id_r (-offset,B_STACK_POINTER,REGISTER_D0);
				offset-=STACK_ELEMENT_SIZE;
				for (n=n_d_registers-1; n>=2; --n){
					i_move_id_r (-offset,B_STACK_POINTER,num_to_d_reg (n));
					offset-=STACK_ELEMENT_SIZE;
				}
			} else
#	endif
			for (n=n_d_registers-1; n>=0; --n){
				i_move_id_r (-offset,B_STACK_POINTER,num_to_d_reg (n));
				offset-=STACK_ELEMENT_SIZE;
			}
			if (offset!=0)
				i_add_i_r (-offset,B_STACK_POINTER);
		}
#endif

	if (node_a_register!=0){
		i_move_r_r (REGISTER_A0,num_to_a_reg (node_a_register));
#ifdef M68000
		code_size+=2;
#endif
	}

#ifdef M68000
	for (n=0; n<n_a_registers; ++n)
		if (n!=node_a_register){
			i_move_pd_r (A_STACK_POINTER,num_to_a_reg (n));
			code_size+=2;
		}
#else
	offset=0;
#	ifdef G_POWER
	{
		int last_a_register;
		
		last_a_register=n_a_registers-1;
		if (last_a_register==node_a_register)
			--last_a_register;
		
		for (n=0; n<n_a_registers; ++n)
			if (n!=node_a_register){
				offset-=4;
				if (n==last_a_register)
					i_move_idu_r (offset,A_STACK_POINTER,num_to_a_reg (n));
				else
					i_move_id_r (offset,A_STACK_POINTER,num_to_a_reg (n));
			}
	}
#	elif defined (ARM)
	if (n_a_registers>2){
		int a_registers[3],a_reg_n;
		
		a_reg_n=0;
		for (n=0; n<n_a_registers; ++n)
			if (n!=node_a_register)
				a_registers[a_reg_n++]=num_to_a_reg (n);
		i_movem_pd_rs (A_STACK_POINTER,a_reg_n,a_registers);
	} else {
		int last_a_register;
		
		last_a_register=0;
		if (last_a_register==node_a_register)
			++last_a_register;

		for (n=n_a_registers-1; n>=0; --n)
			if (n!=node_a_register){
				offset-=STACK_ELEMENT_SIZE;
				if (n==last_a_register)
					i_move_idu_r (offset,A_STACK_POINTER,num_to_a_reg (n));
				else
					i_move_id_r (offset,A_STACK_POINTER,num_to_a_reg (n));
			}
	}
#	else
	for (n=0; n<n_a_registers; ++n)
		if (n!=node_a_register){
			offset-=STACK_ELEMENT_SIZE;
			i_move_id_r (offset,A_STACK_POINTER,num_to_a_reg (n));
		}
	if (a_offset>0)
		i_sub_i_r (a_offset,A_STACK_POINTER);
#	endif
#endif

#ifdef M68000
	return code_size;
#endif
}

static void generate_code_for_basic_block (struct block_graph *next_block_graph)
{
	struct block_graph *block_graph;
	struct basic_block *old_last_block;
	struct instruction *block_instructions,*block_last_instruction;
	int n_allocated_d_regs,n_allocated_f_regs,n_data_parameter_registers;
	int end_b_stack_size;
	ULONG *vector;
#ifdef M68000
	LONG *branch_offset_p;
#endif
	
	old_last_block=last_block;
	
	block_graph=last_block_graph;
	/*
	last_block_graph=block_graph->block_graph_previous;
	if (last_block_graph!=NULL)
		last_block_graph->block_graph_next=NULL;
	else
		first_block_graph=NULL;
	*/
	
	last_block=block_graph->block_graph_block;
	
	block_instructions=last_block->block_instructions;
	block_last_instruction=last_block->block_last_instruction;
	
	last_block->block_instructions=NULL;
	last_block->block_last_instruction=NULL;
	last_instruction=NULL;
	
	global_block=*block_graph;
	if (global_block.block_graph_end_b_stack_size<=VECTOR_ELEMENT_SIZE){
		global_block.block_graph_small_end_stack_vector = *global_block.block_graph_end_stack_vector;
		global_block.block_graph_end_stack_vector = &global_block.block_graph_small_end_stack_vector;
	}

	n_data_parameter_registers =
#if !(defined (I486) || defined (ARM))
		block_graph->block_graph_kind==JSR_EVAL_BLOCK ? N_DATA_PARAMETER_REGISTERS-1 :
#endif
		N_DATA_PARAMETER_REGISTERS;

	if (parallel_flag)
		--n_data_parameter_registers;
	
	end_b_stack_size=block_graph->block_graph_end_b_stack_size;
	if (block_graph->block_graph_kind==JSR_BLOCK
		|| block_graph->block_graph_kind==JSR_I_BLOCK
#ifdef G_POWER
		|| block_graph->block_graph_kind==JSR_BLOCK_WITH_INSTRUCTIONS
#endif	
	)
		--end_b_stack_size;
	
	a_stack_load_register_values (block_graph->block_graph_end_a_stack_size,N_ADDRESS_PARAMETER_REGISTERS);
	b_stack_load_register_values (end_b_stack_size,block_graph->block_graph_end_stack_vector,n_data_parameter_registers
#ifdef MORE_PARAMETER_REGISTERS
							,N_ADDRESS_PARAMETER_REGISTERS-block_graph->block_graph_end_a_stack_size
#endif
							);
	
	a_stack_stores (block_graph->block_graph_end_a_stack_size,N_ADDRESS_PARAMETER_REGISTERS);
	b_stack_stores (end_b_stack_size,block_graph->block_graph_end_stack_vector,n_data_parameter_registers
#ifdef MORE_PARAMETER_REGISTERS
				,N_ADDRESS_PARAMETER_REGISTERS-block_graph->block_graph_end_a_stack_size,
				block_graph->block_graph_a_register_parameter_node,block_graph->block_graph_d_register_parameter_node
#endif
				);
	
	linearize_stack_graphs();
		
	switch (block_graph->block_graph_kind){
		case JSR_EVAL_BLOCK:
		{
			int n,b_stack_size,n_data_parameter_registers;
			
			n_data_parameter_registers = parallel_flag ? N_DATA_PARAMETER_REGISTERS-1 : N_DATA_PARAMETER_REGISTERS;
			
			adjust_stack_pointers();

			vector=block_graph->block_graph_end_stack_vector;
			b_stack_size=block_graph->block_graph_end_b_stack_size;
			
			n_allocated_d_regs=0;
			n_allocated_f_regs=0;
			
			for (n=0; n<b_stack_size; ++n)
				if (!test_bit (vector,n)){
#if defined (I486) || defined (ARM)
					if (n_allocated_d_regs<n_data_parameter_registers)
#else
					if (n_allocated_d_regs<n_data_parameter_registers-1)
#endif
						++n_allocated_d_regs;
				} else {
					if (n_allocated_f_regs<N_FLOAT_PARAMETER_REGISTERS && mc68881_flag)
						++n_allocated_f_regs;
#ifndef G_A64
					++n;
#endif
				}
#ifdef I486
			i_btst_i_id (2,0,num_to_a_reg (block_graph->block_graph_end_a_stack_size
							 -block_graph->block_graph_jsr_eval_offset-1));
			i_bne_l (block_graph->block_graph_last_instruction_label);
#else
			i_move_id_r (0-NODE_POINTER_OFFSET,num_to_a_reg (block_graph->block_graph_end_a_stack_size
						 -block_graph->block_graph_jsr_eval_offset-1),
#	if defined (ARM)
#    ifdef G_A64
						 REGISTER_D7);
#    else
						 REGISTER_D6);
#    endif
#	else
						 num_to_d_reg (n_allocated_d_regs));
#	endif
#	ifdef M68000
			if (check_stack || parallel_flag)
				i_bmi_l (block_graph->block_graph_last_instruction_label);
			else
				branch_offset_p=i_bmi_i();
#	else
#		if defined (ARM)
#        ifdef G_A64
			i_btst_i_r (2,REGISTER_D7);
#        else
			i_btst_i_r (2,REGISTER_D6);
#        endif
#		else
			i_btst_i_r (2,num_to_d_reg (n_allocated_d_regs));
#		endif
#		ifdef G_POWER
			i_bnep_l (block_graph->block_graph_last_instruction_label);
#		else
			i_bne_l (block_graph->block_graph_last_instruction_label);
#		endif
#	endif
#endif
			break;
		}
#ifdef G_POWER
		case JSR_BLOCK_WITH_INSTRUCTIONS:
			if (block_last_instruction!=NULL){
				if (last_block->block_instructions!=NULL)
					last_instruction->instruction_next=block_instructions;
				else
					last_block->block_instructions=block_instructions;

				last_block->block_last_instruction=block_last_instruction;				
				last_instruction=block_last_instruction;
				block_last_instruction=NULL;
			}
			/* no break */
#endif
		case JSR_BLOCK:
		{
			int b_offset;
			
#if ! (defined (sparc) || defined (G_POWER) || defined (ARM))
			b_offset=local_register_allocation_and_adjust_a_stack_pointer
				(end_b_stack_size==global_block.block_graph_b_stack_end_displacement ? STACK_ELEMENT_SIZE : 0);
#else
			b_offset=local_register_allocation_and_adjust_a_stack_pointer (0
# ifdef ARM
				,end_b_stack_size!=global_block.block_graph_b_stack_end_displacement
# endif
				);
#endif

#if defined (G_POWER) || defined (ARM)
			{
				int return_offset;
				
				return_offset = (end_b_stack_size-global_block.block_graph_b_stack_end_displacement)<<STACK_ELEMENT_LOG_SIZE;

				if (return_offset==0 && b_offset!=0)
					i_jsr_l_idu (block_graph->block_graph_last_instruction_label,b_offset);
				else {
					if (b_offset!=0)
						if (b_offset<0)
							i_sub_i_r (-b_offset,B_STACK_POINTER);
						else
							i_add_i_r (b_offset,B_STACK_POINTER);
					i_jsr_l_id (block_graph->block_graph_last_instruction_label,return_offset);
				}
			}
#else
			if (b_offset!=0)
				if (b_offset<0)
					i_sub_i_r (-b_offset,B_STACK_POINTER);
				else
					i_add_i_r (b_offset,B_STACK_POINTER);

# if ! defined (sparc)
			{
				int n_a_and_f_registers,n_a_registers;
				
				n_a_and_f_registers=0;

				if (mc68881_flag){
					int parameter_n;
					ULONG *vector;
					
					vector=block_graph->block_graph_end_stack_vector;
										
					for (parameter_n=0; parameter_n<end_b_stack_size; ++parameter_n)
						if (test_bit (vector,parameter_n))
							if (n_a_and_f_registers<N_FLOAT_PARAMETER_REGISTERS){
								++n_a_and_f_registers;
								++parameter_n;
							} else
								break;
				}
				
				n_a_registers=block_graph->block_graph_end_a_stack_size;
				if (n_a_registers>N_ADDRESS_PARAMETER_REGISTERS)
					n_a_registers=N_ADDRESS_PARAMETER_REGISTERS;
				n_a_and_f_registers+=n_a_registers<<4;

				if (end_b_stack_size!=global_block.block_graph_b_stack_end_displacement)
					i_jmp_l (block_graph->block_graph_last_instruction_label,n_a_and_f_registers);
				else
					i_jsr_l (block_graph->block_graph_last_instruction_label,n_a_and_f_registers);
			}
# else
			i_jsr_l_id (block_graph->block_graph_last_instruction_label,
						 (end_b_stack_size-global_block.block_graph_b_stack_end_displacement)<<STACK_ELEMENT_LOG_SIZE);
# endif
#endif
			if (block_check){
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
				int a_stack_change,b_stack_change;
				
				a_stack_change=
					(next_block_graph->block_graph_begin_a_stack_size+
					 next_block_graph->block_graph_a_stack_begin_displacement)-
					(block_graph->block_graph_end_a_stack_size-
					 block_graph->block_graph_a_stack_end_displacement);
				b_stack_change=
					(next_block_graph->block_graph_begin_b_stack_size+
					 next_block_graph->block_graph_b_stack_begin_displacement)-
					(block_graph->block_graph_end_b_stack_size-
					 block_graph->block_graph_b_stack_end_displacement);
				block_a_stack_displacement+=a_stack_change<<STACK_ELEMENT_LOG_SIZE;
				block_b_stack_displacement+=b_stack_change<<STACK_ELEMENT_LOG_SIZE;
				block_graph->block_graph_a_stack_displacement+=a_stack_change<<STACK_ELEMENT_LOG_SIZE;
				block_graph->block_graph_b_stack_displacement+=b_stack_change<<STACK_ELEMENT_LOG_SIZE;
#else
				int stack_change;
				
				stack_change=
					(next_block_graph->block_graph_begin_a_stack_size+
					 next_block_graph->block_graph_a_stack_begin_displacement)-
					(block_graph->block_graph_end_a_stack_size-
					 block_graph->block_graph_a_stack_end_displacement)+
					(next_block_graph->block_graph_begin_b_stack_size+
					 next_block_graph->block_graph_b_stack_begin_displacement)-
					(block_graph->block_graph_end_b_stack_size-
					 block_graph->block_graph_b_stack_end_displacement);
				block_stack_displacement+=stack_change<<STACK_ELEMENT_LOG_SIZE;
				block_graph->block_graph_stack_displacement+=stack_change<<STACK_ELEMENT_LOG_SIZE;
#endif
			}

			break;
		}
		case APPLY_BLOCK:
		{
			int b_offset;
			
#if defined (sparc) || defined (G_POWER)
			b_offset=local_register_allocation_and_adjust_a_stack_pointer (-4);
#else
			b_offset=local_register_allocation_and_adjust_a_stack_pointer (0
# ifdef ARM
																			,1
# endif
																			);
#endif

			if (b_offset!=0)
				if (b_offset<0)
					i_sub_i_r (-b_offset,B_STACK_POINTER);
				else
					i_add_i_r (b_offset,B_STACK_POINTER);

#if defined (I486) || defined (ARM)
			i_move_id_r (0,REGISTER_A1,REGISTER_A2);
# ifdef MACH_O64
			i_jsr_id (8-2,REGISTER_A2,0);
# elif defined (G_AI64) && defined (LINUX)
			i_jsr_id (pic_flag ? 8-2 : 4-2,REGISTER_A2,0);
# elif defined (ARM)
			i_jsr_id_idu (4-2,REGISTER_A2,-STACK_ELEMENT_SIZE);
# else
			i_jsr_id (4-2,REGISTER_A2,0);
# endif
#elif defined (M68000)
# if !defined (SUN)
			i_add_r_r (GLOBAL_DATA_REGISTER,REGISTER_A2);
# endif
			i_jsr_id (0,REGISTER_A2,2<<4);
#else
			i_jsr_id_id (0,REGISTER_A2,0);
#endif
			break;
		}
		case JSR_I_BLOCK:
		{
			int b_offset,n_a_registers,a_reg_n;
			
			b_offset=local_register_allocation_and_adjust_a_stack_pointer
				(end_b_stack_size==global_block.block_graph_b_stack_end_displacement ? STACK_ELEMENT_SIZE : 0
#ifdef ARM
				,1
#endif
				);

			if (b_offset!=0)
				if (b_offset<0)
					i_sub_i_r (-b_offset,B_STACK_POINTER);
				else
					i_add_i_r (b_offset,B_STACK_POINTER);

			n_a_registers=block_graph->block_graph_end_a_stack_size;
			if (n_a_registers>N_ADDRESS_PARAMETER_REGISTERS)
				n_a_registers=N_ADDRESS_PARAMETER_REGISTERS;

			a_reg_n = a_reg_num (N_ADDRESS_PARAMETER_REGISTERS);

			i_move_id_r (0,num_to_a_reg (n_a_registers-1),a_reg_n);

#ifdef MACH_O64
			i_move_id_r (block_graph->block_graph_jsr_eval_offset & -2,a_reg_n,a_reg_n);
#elif defined (G_A64) && defined (LINUX)
			if (pic_flag)
				i_move_id_r (block_graph->block_graph_jsr_eval_offset & -2,a_reg_n,a_reg_n);
			else
				i_loadsqb_id_r (block_graph->block_graph_jsr_eval_offset & -2,a_reg_n,a_reg_n);
#else
# if defined (G_A64) && !defined (LINUX)
			i_loadsqb_id_r (block_graph->block_graph_jsr_eval_offset & -2,a_reg_n,a_reg_n);
# else
			i_move_id_r (block_graph->block_graph_jsr_eval_offset & -2,a_reg_n,a_reg_n);
# endif
#endif
			if (block_graph->block_graph_jsr_eval_offset & 1)
#ifndef ARM
# ifdef G_AI64
				i_sub_i_r (32,a_reg_n);	/* if profiling */
# else
				i_sub_i_r (28,a_reg_n);	/* if profiling */
# endif
#else
# ifdef G_A64
				i_sub_i_r (28,a_reg_n);	/* if profiling */
# else
				i_sub_i_r (20,a_reg_n);	/* if profiling */
# endif
#endif
			else
#ifndef ARM
				i_sub_i_r (20,a_reg_n);
#else
				i_sub_i_r (12,a_reg_n);
#endif

			if (end_b_stack_size!=global_block.block_graph_b_stack_end_displacement)
				i_jmp_r (a_reg_n);
			else
#ifndef ARM
				i_jsr_r (a_reg_n);
#else
				i_jsr_r_idu (a_reg_n,-STACK_ELEMENT_SIZE);
#endif

			if (block_check){
# ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
				int a_stack_change,b_stack_change;
				
				a_stack_change=
					(next_block_graph->block_graph_begin_a_stack_size+
					 next_block_graph->block_graph_a_stack_begin_displacement)-
					(block_graph->block_graph_end_a_stack_size-
					 block_graph->block_graph_a_stack_end_displacement);
				b_stack_change=
					(next_block_graph->block_graph_begin_b_stack_size+
					 next_block_graph->block_graph_b_stack_begin_displacement)-
					(block_graph->block_graph_end_b_stack_size-
					 block_graph->block_graph_b_stack_end_displacement);
				block_a_stack_displacement+=a_stack_change<<STACK_ELEMENT_LOG_SIZE;
				block_b_stack_displacement+=b_stack_change<<STACK_ELEMENT_LOG_SIZE;
				block_graph->block_graph_a_stack_displacement+=a_stack_change<<STACK_ELEMENT_LOG_SIZE;
				block_graph->block_graph_b_stack_displacement+=b_stack_change<<STACK_ELEMENT_LOG_SIZE;
# else
				int stack_change;
				
				stack_change=
					(next_block_graph->block_graph_begin_a_stack_size+
					 next_block_graph->block_graph_a_stack_begin_displacement)-
					(block_graph->block_graph_end_a_stack_size-
					 block_graph->block_graph_a_stack_end_displacement)+
					(next_block_graph->block_graph_begin_b_stack_size+
					 next_block_graph->block_graph_b_stack_begin_displacement)-
					(block_graph->block_graph_end_b_stack_size-
					 block_graph->block_graph_b_stack_end_displacement);
				block_stack_displacement+=stack_change<<STACK_ELEMENT_LOG_SIZE;
				block_graph->block_graph_stack_displacement+=stack_change<<STACK_ELEMENT_LOG_SIZE;
# endif
			}

			break;
		}
		default:
			internal_error_in_function ("generate_code_for_basic_block");
	}
	
	if (block_last_instruction!=NULL){
		if (last_block->block_instructions!=NULL){
			last_instruction->instruction_next=block_instructions;
			last_block->block_last_instruction=block_last_instruction;
		} else {
			last_block->block_instructions=block_instructions;
			last_block->block_last_instruction=block_last_instruction;
		}
	} else
		last_block->block_last_instruction=last_instruction;
	
	if (block_graph->block_graph_kind==JSR_EVAL_BLOCK)
#ifdef M68000
		if (!check_stack && !parallel_flag){
			*branch_offset_p
				= generate_code_for_jsr_eval (block_graph->block_graph_end_a_stack_size,n_allocated_d_regs,
					 n_allocated_f_regs,block_graph->block_graph_jsr_eval_offset);
		} else
#endif
		generate_code_for_jsr_eval
			(block_graph->block_graph_end_a_stack_size,n_allocated_d_regs,
			 n_allocated_f_regs,block_graph->block_graph_jsr_eval_offset);
	
	last_block=old_last_block;
}

static int optimize_jsr_eval (struct block_graph *block_graph,int a_stack_size,struct block_graph *next_block_graph)
{
	struct a_stack *a_element,*a_element_0;
	struct a_stack *begin_a_element;
	int offset,n;
	INSTRUCTION_GRAPH graph;

	offset=block_graph->block_graph_a_stack_top_offset;
	
	a_element=block_graph->block_graph_a_stack;
	while (a_element!=NULL && a_element->a_stack_offset<offset)
		a_element=a_element->a_stack_next;
	
	if (a_element==NULL || a_element->a_stack_offset!=offset)
		return a_stack_size;
	
	a_element_0=a_element;
	graph=a_element->a_stack_graph;
	
	begin_a_element=next_block_graph->block_graph_a_stack;
	while (begin_a_element!=NULL && begin_a_element->a_stack_offset<0)
		begin_a_element=begin_a_element->a_stack_next;
	
	if ((begin_a_element!=NULL && begin_a_element->a_stack_offset==0)
		?	(begin_a_element->a_stack_load_graph!=NULL
			&& begin_a_element->a_stack_load_graph->node_mark)
		:	0>=next_block_graph->block_graph_a_stack_top_offset
	)
		return a_stack_size;
			
	for (n=1; n<a_stack_size; ++n){
		a_element=a_element->a_stack_next;
		if (a_element==NULL || a_element->a_stack_offset!=offset+n)
			return a_stack_size;
		if (a_element->a_stack_graph==graph)
			break;
	}
	
	if (n>=a_stack_size)
		return a_stack_size;

	remove_end_stack_element
	   ((struct stack **)&block_graph->block_graph_a_stack,offset,
		block_graph->block_graph_a_stack_begin_displacement,
		block_graph->block_graph_a_stack_top_offset,0);
	/*
	a_element_0->a_stack_graph=NULL;
	a_element_0->a_stack_flags &= ~ELEMENT_USED_BEFORE_JSR;;
	*/
	++block_graph->block_graph_a_stack_top_offset;
	block_graph->block_graph_jsr_eval_offset=n-1;

	remove_begin_stack_element 
	   ((struct stack **)&next_block_graph->block_graph_a_stack,0,next_block_graph->block_graph_a_stack_begin_displacement,
		next_block_graph->block_graph_a_stack_top_offset,0);
	--next_block_graph->block_graph_a_stack_top_offset;
	
	return a_stack_size-1;
}

void generate_code_for_previous_blocks (int jmp_jsr_or_rtn_flag)
{
	if (check_stack){
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
		a_check_size_p=NULL;
		b_check_size_p=NULL;
#else
		check_size_p=NULL;
#endif
		block_check=1;
	}

	if (last_block_graph!=NULL){
		struct block_graph *block_graph,*next_block_graph;
		struct block_graph end_block_graph;
		
		last_block->block_last_instruction=last_instruction;
		
		end_block_graph=global_block;

		end_block_graph.block_graph_end_a_stack_size=0;
		end_block_graph.block_graph_end_b_stack_size=0;
		end_block_graph.block_graph_end_stack_vector=NULL;

		mark_stack_graphs_2 (&global_block);	
		
		next_block_graph=&end_block_graph;
		for_l (block_graph,last_block_graph,block_graph_previous){
			insert_dummy_graphs_for_unused_a_stack_elements (block_graph,next_block_graph);
			insert_dummy_graphs_for_unused_b_stack_elements (block_graph,next_block_graph);
		
			mark_stack_graphs_1 (block_graph,next_block_graph,jmp_jsr_or_rtn_flag);
			if (block_graph->block_graph_kind!=JSR_EVAL_BLOCK)
				jmp_jsr_or_rtn_flag=1;
			
			next_block_graph=block_graph;
		}

		for_l (block_graph,first_block_graph,block_graph_next){
			next_block_graph=block_graph->block_graph_next;
			
			if (next_block_graph==NULL)
				next_block_graph=&end_block_graph;

			remove_not_used_a_stack_elements (block_graph,next_block_graph);
			remove_not_used_b_stack_elements (block_graph,next_block_graph);
		}
		remove_not_used_stack_elements_from_last_block (&end_block_graph);
		
		for_l (block_graph,first_block_graph,block_graph_next){
			next_block_graph=block_graph->block_graph_next;
			if (next_block_graph==NULL)
				next_block_graph=&end_block_graph;
			
			if (block_graph->block_graph_kind!=JSR_EVAL_BLOCK){
				compute_a_load_offsets (next_block_graph->block_graph_a_stack,
					next_block_graph->block_graph_a_stack_begin_displacement<<STACK_ELEMENT_LOG_SIZE);
				compute_b_load_offsets (next_block_graph->block_graph_b_stack,
					next_block_graph->block_graph_b_stack_begin_displacement<<STACK_ELEMENT_LOG_SIZE);
			} else {
				int a_stack_size,b_stack_size;
				ULONG *vector;
				
				a_stack_size=count_a_stack_size (block_graph->block_graph_a_stack,
												 block_graph->block_graph_a_stack_top_offset);
				if (a_stack_size<1)
					a_stack_size=1;
				else
					if (a_stack_size>N_ADDRESS_PARAMETER_REGISTERS+1)
						a_stack_size=N_ADDRESS_PARAMETER_REGISTERS+1;
							
				block_graph->block_graph_end_stack_vector=
					&block_graph->block_graph_small_end_stack_vector;
				b_stack_size=count_b_stack_size_2
					(&block_graph->block_graph_end_stack_vector,
					block_graph->block_graph_b_stack,
					block_graph->block_graph_b_stack_top_offset);

				vector=block_graph->block_graph_end_stack_vector;

				a_stack_size=optimize_jsr_eval (block_graph,a_stack_size,next_block_graph);

				if (a_stack_size>N_ADDRESS_PARAMETER_REGISTERS)
					a_stack_size=N_ADDRESS_PARAMETER_REGISTERS;
				block_graph->block_graph_end_a_stack_size=a_stack_size;
				block_graph->block_graph_end_b_stack_size=b_stack_size;

				if (block_graph->block_graph_next!=NULL)
					next_block_graph->block_graph_block->block_n_begin_a_parameter_registers=a_stack_size;
				else
					last_block->block_n_begin_a_parameter_registers=a_stack_size;

				next_block_graph->block_graph_a_stack_begin_displacement=
					set_basic_block_begin_a_registers
					   (&next_block_graph->block_graph_a_stack,a_stack_size,
						next_block_graph->block_graph_a_register_parameter_node);
				compute_a_load_offsets (next_block_graph->block_graph_a_stack,
					next_block_graph->block_graph_a_stack_begin_displacement<<STACK_ELEMENT_LOG_SIZE);
				
				next_block_graph->block_graph_b_stack_begin_displacement=
					set_basic_block_begin_d_registers
					   (&next_block_graph->block_graph_b_stack,b_stack_size,
					    block_graph->block_graph_end_stack_vector,
						next_block_graph->block_graph_d_register_parameter_node,
						next_block_graph->block_graph_f_register_parameter_node
#ifdef MORE_PARAMETER_REGISTERS
						,N_ADDRESS_PARAMETER_REGISTERS - a_stack_size,
						next_block_graph->block_graph_a_register_parameter_node
#endif
						);
				compute_b_load_offsets (next_block_graph->block_graph_b_stack,
					next_block_graph->block_graph_b_stack_begin_displacement<<STACK_ELEMENT_LOG_SIZE);
			}
		}

		for_l (block_graph,first_block_graph,block_graph_next){
			struct block_graph *next_block_graph;
			
			last_block_graph=block_graph;
			next_block_graph=block_graph->block_graph_next;
			if (next_block_graph==NULL)
				next_block_graph=&end_block_graph;
			generate_code_for_basic_block (next_block_graph);	
		}
		
		if (check_stack){
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
			if (a_check_size_p!=NULL){
				struct block_graph *block_graph;
				int a_stack_displacement,b_stack_displacement;
			
				a_stack_displacement=0;	
				b_stack_displacement=0;	
				for_l (block_graph,first_block_graph,block_graph_next){
					a_stack_displacement+=block_graph->block_graph_a_stack_displacement;
					b_stack_displacement+=block_graph->block_graph_b_stack_displacement;
	
					if (block_graph->block_graph_kind==JSR_EVAL_BLOCK){
						struct basic_block *block;
						int a_check_size,b_check_size;
				
						if (block_graph->block_graph_block==NULL || block_graph->block_graph_block->block_next==NULL)
							internal_error_in_function ("generate_code_for_previous_blocks");
						
						block=block_graph->block_graph_block->block_next;
						a_check_size=block->block_a_stack_check_size;
						b_check_size=block->block_b_stack_check_size;
						
						if (a_check_size>0 && a_stack_displacement+a_check_size<=*a_check_size_p)
							block->block_a_stack_check_size=0;
						if (b_check_size>0 && b_stack_displacement+b_check_size<=*b_check_size_p)
							block->block_b_stack_check_size=0;
					}
				}
			}
#else
			if (check_size_p!=NULL){
				struct block_graph *block_graph;
				int stack_displacement;
			
				stack_displacement=0;	
				for_l (block_graph,first_block_graph,block_graph_next){
					stack_displacement+=block_graph->block_graph_stack_displacement;
	
					if (block_graph->block_graph_kind==JSR_EVAL_BLOCK){
						struct basic_block *block;
						int check_size;
				
						if (block_graph->block_graph_block==NULL || block_graph->block_graph_block->block_next==NULL)
							internal_error_in_function ("generate_code_for_previous_blocks");
						
						block=block_graph->block_graph_block->block_next;
						check_size=block->block_stack_check_size;
						
						if (check_size>0 && stack_displacement+check_size<=*check_size_p)
							block->block_stack_check_size=0;
					}
				}
			}
#endif		
			block_check=0;
		}
		
		first_block_graph=last_block_graph=NULL;
		
		global_block=end_block_graph;

		global_block.block_graph_end_a_stack_size=0;
		global_block.block_graph_end_b_stack_size=0;
		global_block.block_graph_end_stack_vector=NULL;
				
		last_instruction=last_block->block_last_instruction;
	}
}

#if defined (I486) || defined (ARM)
int end_basic_block_with_registers_and_return_address_and_return_b_stack_offset
	(int n_a_parameters,int n_b_parameters,ULONG vector[],int n_data_parameter_registers)
{
	int b_stack_offset;

	a_stack_load_register_values (n_a_parameters,N_ADDRESS_PARAMETER_REGISTERS);
	b_stack_load_register_values (n_b_parameters,vector,n_data_parameter_registers
# ifdef MORE_PARAMETER_REGISTERS
							,N_ADDRESS_PARAMETER_REGISTERS-n_a_parameters
# endif
							);
	
	generate_code_for_previous_blocks (1);
	
	a_stack_stores (n_a_parameters,N_ADDRESS_PARAMETER_REGISTERS);
	b_stack_stores (n_b_parameters,vector,n_data_parameter_registers
# ifdef MORE_PARAMETER_REGISTERS
				,N_ADDRESS_PARAMETER_REGISTERS-n_a_parameters,
				global_block.block_graph_a_register_parameter_node,global_block.block_graph_d_register_parameter_node
# endif
				);
	
	linearize_stack_graphs();
	b_stack_offset=local_register_allocation_and_adjust_a_stack_pointer (0
# ifdef ARM
																			,1
# endif
																			);
	
	return b_stack_offset;
}
#endif

int end_basic_block_with_registers_and_return_b_stack_offset (int n_a_parameters,int n_b_parameters,ULONG vector[],int n_address_parameter_registers)
{
	int b_stack_offset;
	
	a_stack_load_register_values (n_a_parameters,n_address_parameter_registers);
	b_stack_load_register_values (n_b_parameters,vector,parallel_flag ? N_DATA_PARAMETER_REGISTERS-1: N_DATA_PARAMETER_REGISTERS
#ifdef MORE_PARAMETER_REGISTERS
							,n_address_parameter_registers-n_a_parameters
#endif
							);
	
	generate_code_for_previous_blocks (1);
	
	a_stack_stores (n_a_parameters,n_address_parameter_registers);
	b_stack_stores (n_b_parameters,vector,parallel_flag ? N_DATA_PARAMETER_REGISTERS-1 : N_DATA_PARAMETER_REGISTERS
#ifdef MORE_PARAMETER_REGISTERS
				,n_address_parameter_registers-n_a_parameters,
				global_block.block_graph_a_register_parameter_node,global_block.block_graph_d_register_parameter_node
#endif
				);
	
	linearize_stack_graphs();
	b_stack_offset=local_register_allocation_and_adjust_a_stack_pointer (0
# ifdef ARM
																		,1
# endif
																		);
	
	return b_stack_offset;
}

void end_basic_block_with_registers (int n_a_parameters,int n_b_parameters,ULONG vector[])
{
	int b_offset;

	b_offset=end_basic_block_with_registers_and_return_b_stack_offset (n_a_parameters,n_b_parameters,vector,N_ADDRESS_PARAMETER_REGISTERS);

	if (b_offset!=0)
		if (b_offset>0)
			i_add_i_r (b_offset,B_STACK_POINTER);
		else
			i_sub_i_r (-b_offset,B_STACK_POINTER);
}

void end_stack_elements (int n_a_parameters,int n_b_parameters,ULONG vector[])
{
	int n_data_parameter_registers;
	
	n_data_parameter_registers = parallel_flag ? N_DATA_PARAMETER_REGISTERS-1 : N_DATA_PARAMETER_REGISTERS;
			
	a_stack_load_register_values (n_a_parameters,N_ADDRESS_PARAMETER_REGISTERS);
	b_stack_load_register_values (n_b_parameters,vector,n_data_parameter_registers
#ifdef MORE_PARAMETER_REGISTERS
							,N_ADDRESS_PARAMETER_REGISTERS-n_a_parameters
#endif
							);

	a_stack_stores (n_a_parameters,N_ADDRESS_PARAMETER_REGISTERS);
	b_stack_stores (n_b_parameters,vector,n_data_parameter_registers
#ifdef MORE_PARAMETER_REGISTERS
				,N_ADDRESS_PARAMETER_REGISTERS-n_a_parameters,
				global_block.block_graph_a_register_parameter_node,global_block.block_graph_d_register_parameter_node
#endif
				);
}

void begin_new_basic_block (VOID)
{
	last_block->block_last_instruction=last_instruction;
	
	last_instruction=NULL;

	last_block->block_next=allocate_empty_basic_block();
	last_block=last_block->block_next;

	release_a_stack();
	release_b_stack();
	
	release_heap();
	
	load_indexed_list=NULL;
}

void insert_basic_block (int block_graph_kind,int a_stack_size,int b_stack_size,ULONG *vector_p,LABEL *label)
{
	struct block_graph *new_block;
	
	last_block->block_last_instruction=last_instruction;
	
	new_block=allocate_struct_from_heap (block_graph);
	
	*new_block=global_block;
	
	new_block->block_graph_kind=block_graph_kind;
	new_block->block_graph_block=last_block;

	new_block->block_graph_used_a_stack_elements=block_graph_kind==JSR_EVAL_BLOCK ? 1 : a_stack_size;
	new_block->block_graph_used_b_stack_elements=b_stack_size;

	new_block->block_graph_end_a_stack_size=a_stack_size;
	new_block->block_graph_end_b_stack_size=b_stack_size;	
	
	if (b_stack_size<=VECTOR_ELEMENT_SIZE){
		new_block->block_graph_small_end_stack_vector=*vector_p;
		new_block->block_graph_end_stack_vector=&new_block->block_graph_small_end_stack_vector;
	} else {
		int vector_size;
		ULONG *vector,*old_vector;
			
		vector_size=(b_stack_size+VECTOR_ELEMENT_SIZE-1)>>LOG_VECTOR_ELEMENT_SIZE;
		vector=(ULONG*)fast_memory_allocate (vector_size * sizeof (ULONG));
		label->label_vector=vector;
		new_block->block_graph_end_stack_vector=vector;
		
		old_vector=vector_p;
		while (vector_size>0){
			*vector++=*old_vector++;
			--vector_size;
		}
	}

	new_block->block_graph_jsr_eval_offset=0;
	new_block->block_graph_last_instruction_label=label;
	
	if (last_block_graph==NULL)
		first_block_graph=new_block;
	else
		last_block_graph->block_graph_next=new_block;
	new_block->block_graph_previous=last_block_graph;
	new_block->block_graph_next=NULL;
	last_block_graph=new_block;
	
	last_instruction=NULL;
	
	last_block->block_next=allocate_empty_basic_block();
	last_block=last_block->block_next;
	
	release_a_stack();
	release_b_stack();
	
	load_indexed_list=NULL;
}

void insert_basic_block_with_extra_parameters_on_stack (int block_graph_kind,int a_stack_size,int b_stack_size,ULONG *vector_p,
														int extra_a_stack_size,int extra_b_stack_size,LABEL *label)
{
	insert_basic_block (block_graph_kind,a_stack_size,b_stack_size,vector_p,label);
	
	last_block_graph->block_graph_used_a_stack_elements+=extra_a_stack_size;
	last_block_graph->block_graph_used_b_stack_elements+=extra_b_stack_size;
}

void insert_basic_JSR_I_block (int a_stack_size,int b_stack_size,ULONG *vector_p,int offset)
{
	insert_basic_block (JSR_I_BLOCK,a_stack_size,b_stack_size,vector_p,NULL);

	last_block_graph->block_graph_jsr_eval_offset=offset;
}

void initialize_stacks (VOID)
{
	release_a_stack();
	
	release_b_stack();
	
	last_block_graph=NULL;
	first_block_graph=NULL;
	
	block_check=0;
	
	load_indexed_list=NULL;
}
