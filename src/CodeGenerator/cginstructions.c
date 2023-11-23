/*
	File:	cginstructions.c
	Author:	John van Groningen
	At:		University of Nijmegen
*/

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#if defined (LINUX) && defined (G_AI64)
# include <stdint.h>
#elif defined (__GNUC__) && defined (__SIZEOF_POINTER__)
# if __SIZEOF_POINTER__==8
#  include <stdint.h>
# endif
#endif
#include <stdlib.h>

#include "cgport.h"
#include "cg.h"
#include "cgconst.h"
#include "cgrconst.h"
#include "cgtypes.h"
#include "cgcode.h"
#include "cgcodep.h"
#include "cgstack.h"
#include "cglin.h"
#include "cginstructions.h"
#ifdef G_POWER
#	include "cgpas.h"
#	include "cgpwas.h"
#elif defined (I486)
# ifdef G_A64
#	include "cgaas.h"
#	include "cgawas.h"
# else
#	include "cgias.h"
#	include "cgiwas.h"
# endif
#elif defined (ARM)
# ifdef G_A64
#	include "cgarm64as.h"
#	include "cgarm64was.h"
# else
#	include "cgarmas.h"
#	include "cgarmwas.h"
# endif
#elif defined (SOLARIS)
#	include "cgswas.h"
#else
#	include "cgas.h"
#	include "cgwas.h"
#endif
#if defined (THREAD32) || defined (THREAD64)
# include "cgiconst.h"
#endif
#define GEN_OBJ

#define LTEXT 0
#define LDATA 1

extern ULONG *offered_vector;
extern int offered_a_stack_size;
extern int offered_b_stack_size;

extern LABEL *enter_label (char *label_name,int label_flags);
extern LABEL *new_local_label (int label_flags);

extern LABEL *	system_sp_label,
				*string_to_string_node_label,*int_array_to_node_label,*real_array_to_node_label,
				*new_int_reducer_label,*channelP_label,*stop_reducer_label,*send_request_label,*send_graph_label;

#if ((defined (I486) || defined (ARM)) && !defined (THREAD64)) || defined (G_POWER)
LABEL *saved_heap_p_label,*saved_a_stack_p_label;
#endif
#ifdef MACH_O
LABEL *dyld_stub_binding_helper_p_label;
#endif
#if defined (THREAD32) || defined (THREAD64)
LABEL *tlsp_tls_index_label;
#endif

extern struct basic_block *last_block;

extern ULONG e_vector[],i_vector[],i_i_vector[],i_i_i_vector[],
#ifdef ARM
# ifndef G_A64
	i_i_i_i_i_vector[],
# else
	i_i_i_i_i_i_i_vector[],
# endif
#endif
	r_vector[];
extern int reachable;

extern int line_number; /* from cginput.c */

#define HIGH_LOW_FIRST_REAL_IN_RECORD
#define RESERVE_NEW_REDUCER

LABEL		*realloc_0_label,*realloc_1_label,*realloc_2_label,*realloc_3_label,
			*schedule_0_label,*schedule_1_label,*schedule_2_label,*schedule_3_label,
			*schedule_eval_label,*stack_overflow_label;

#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
LABEL	*end_a_stack_label,*end_b_stack_label;
#endif

INSTRUCTION_GRAPH g_new_node (int instruction_code,int arity,int arg_size)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=(struct instruction_node*)allocate_memory_from_heap (sizeof (struct instruction_node)+arg_size);

	instruction->instruction_code=instruction_code;
	instruction->inode_arity=arity;
	instruction->node_count=0;
	instruction->node_mark=0;
	instruction->instruction_d_min_a_cost=0;
	instruction->order_mode=0;

	return instruction;
}

INSTRUCTION_GRAPH g_instruction_1 (int instruction_code,INSTRUCTION_GRAPH graph_1)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (instruction_code,1,sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	
	return instruction;
}

INSTRUCTION_GRAPH g_instruction_2 (int instruction_code,INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (instruction_code,2,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;
	
	return instruction;
}

INSTRUCTION_GRAPH g_instruction_2_0 (int instruction_code,INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (instruction_code,3,3*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;
	instruction->instruction_parameters[2].p=NULL;
	
	return instruction;
}

INSTRUCTION_GRAPH g_test_o (INSTRUCTION_GRAPH graph_1)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GTEST_O,1,sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	
	graph_1->instruction_parameters[2].p=instruction;
	
	return instruction;
}

INSTRUCTION_GRAPH g_allocate (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,int n)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GALLOCATE,2+n,(2+n)*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;
	
	graph_2->instruction_d_min_a_cost+=1;
	
	return instruction;
}

static INSTRUCTION_GRAPH g_before0 (INSTRUCTION_GRAPH graph_1,int n)
{
	INSTRUCTION_GRAPH instruction;
	int argument_number;
	
	instruction=g_new_node (GBEFORE0,n+1,(n+1)*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	
	for (argument_number=0; argument_number<n; ++argument_number)
		instruction->instruction_parameters[1+argument_number].p=NULL;
	
	return instruction;
}

INSTRUCTION_GRAPH g_copy (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GCOPY,2,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;

	return instruction;
}

INSTRUCTION_GRAPH g_create_1 (INSTRUCTION_GRAPH graph_1)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GCREATE,1,sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;

	return instruction;
}

INSTRUCTION_GRAPH g_create_2 (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GCREATE,2,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;

	return instruction;
}

INSTRUCTION_GRAPH g_create_3 (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,INSTRUCTION_GRAPH graph_3)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GCREATE,3,3*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;
	instruction->instruction_parameters[2].p=graph_3;

	return instruction;
}

INSTRUCTION_GRAPH g_create_m (int arity)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GCREATE,arity,arity*sizeof (union instruction_parameter));
	
	return instruction;
}

INSTRUCTION_GRAPH g_create_r (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GCREATE_R,2,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;

	return instruction;
}

INSTRUCTION_GRAPH g_exit_if (LABEL *label,INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2)
{
	INSTRUCTION_GRAPH exit_if_graph;
	
	exit_if_graph=g_new_node (GEXIT_IF,3,3*sizeof (union instruction_parameter));
	
	exit_if_graph->instruction_parameters[0].l=label;
	exit_if_graph->instruction_parameters[1].p=graph_1;
	exit_if_graph->instruction_parameters[2].p=graph_2;

	return exit_if_graph; 
}

INSTRUCTION_GRAPH g_fill_2 (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFILL,2,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;

	graph_1->instruction_d_min_a_cost+=1;

	if (graph_1->instruction_code==GBEFORE0)
		graph_1->instruction_code=GBEFORE;
	else if (graph_1->instruction_code==GCREATE && graph_1->inode_arity>0)
		graph_1->instruction_parameters[0].p=NULL;
	
	return instruction;
}

INSTRUCTION_GRAPH g_fill_3 (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,INSTRUCTION_GRAPH graph_3)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFILL,3,3*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;
	instruction->instruction_parameters[2].p=graph_3;

	graph_1->instruction_d_min_a_cost+=1;
	
	if (graph_1->instruction_code==GBEFORE0)
		graph_1->instruction_code=GBEFORE;
	else if (graph_1->instruction_code==GCREATE){
		int arity;

		arity=graph_1->inode_arity;
		if (arity>2)
			arity=2;
		
		while (arity>0)
			graph_1->instruction_parameters[--arity].p=NULL;
	}

	return instruction; 
}

INSTRUCTION_GRAPH g_fill_4 (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,INSTRUCTION_GRAPH graph_3,
							INSTRUCTION_GRAPH graph_4)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFILL,4,4*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;
	instruction->instruction_parameters[2].p=graph_3;
	instruction->instruction_parameters[3].p=graph_4;

	graph_1->instruction_d_min_a_cost+=1;
	
	if (graph_1->instruction_code==GBEFORE0)
		graph_1->instruction_code=GBEFORE;
	else if (graph_1->instruction_code==GCREATE){
		int arity;

		arity=graph_1->inode_arity;
		if (arity>3)
			arity=3;
		
		while (arity>0)
			graph_1->instruction_parameters[--arity].p=NULL;
	}

	return instruction; 
}

INSTRUCTION_GRAPH g_fill_m (INSTRUCTION_GRAPH graph_1,int arity)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFILL,arity+1,(arity+1)*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	
	graph_1->instruction_d_min_a_cost+=1;

	if (graph_1->instruction_code==GBEFORE0)
		graph_1->instruction_code=GBEFORE;
	else if (graph_1->instruction_code==GCREATE){
		int arity;
		
		arity=graph_1->inode_arity;
		if (arity>2)
			arity=2;
		
		while (arity>0)
			graph_1->instruction_parameters[--arity].p=NULL;
	}

	return instruction;
}

INSTRUCTION_GRAPH g_fill_r (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,INSTRUCTION_GRAPH graph_3)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFILL_R,3,3*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;
	instruction->instruction_parameters[2].p=graph_3;

	graph_1->instruction_d_min_a_cost+=1;
	
	if (graph_1->instruction_code==GBEFORE0)
		graph_1->instruction_code=GBEFORE;
	else if (graph_1->instruction_code==GCREATE){
		int arity=graph_1->inode_arity;
		if (arity>3)
			arity=3;
		
		while (arity>0)
			graph_1->instruction_parameters[--arity].p=NULL;
	}

	return instruction; 
}

#ifdef G_A64
INSTRUCTION_GRAPH g_fp_arg (INSTRUCTION_GRAPH graph_1)
{
	if (graph_1->instruction_code==GFROMF)
		return graph_1->instruction_parameters[0].p;

	if (graph_1->instruction_code==GLOAD){
		INSTRUCTION_GRAPH fload_graph;

		fload_graph=g_fload (graph_1->instruction_parameters[0].i,graph_1->instruction_parameters[1].i);

		graph_1->instruction_code=GFROMF;
		graph_1->instruction_parameters[0].p=fload_graph;

		return fload_graph;
	}

	if (graph_1->instruction_code==GLOAD_ID){
		INSTRUCTION_GRAPH fload_graph;
				
		fload_graph=
			g_fload_id (graph_1->instruction_parameters[0].i,graph_1->instruction_parameters[1].p);

		graph_1->instruction_code=GFROMF;
		graph_1->instruction_parameters[0].p=fload_graph;

		return fload_graph;
	}

	if (graph_1->instruction_code==GMOVEMI){
		INSTRUCTION_GRAPH fmovemi_graph,movem_graph;
		int number;
				
		movem_graph=graph_1->instruction_parameters[0].p;
		number=graph_1->inode_arity;

		fmovemi_graph=g_new_node (GFMOVEMI,number,2*sizeof (union instruction_parameter));
		
		fmovemi_graph->instruction_parameters[0].p=movem_graph;
		fmovemi_graph->instruction_parameters[1].i=0;
		
		movem_graph->instruction_parameters[2+number].p=fmovemi_graph;
		movem_graph->instruction_parameters[2+number+1].p=NULL;

		graph_1->instruction_code=GFROMF;
		graph_1->instruction_parameters[0].p=fmovemi_graph;
		
		return fmovemi_graph;		
	}

	if (graph_1->instruction_code==GLOAD_X){
		INSTRUCTION_GRAPH fload_graph,*previous_loadx;

		previous_loadx=&load_indexed_list;

		while (*previous_loadx!=NULL && *previous_loadx!=graph_1)
			previous_loadx=&(*previous_loadx)->instruction_parameters[3].p;
		
		fload_graph=g_new_node (GFLOAD_X,0,4*sizeof (union instruction_parameter));
		
		fload_graph->instruction_parameters[0].p=graph_1->instruction_parameters[0].p;
		fload_graph->instruction_parameters[1].i=graph_1->instruction_parameters[1].i;
		fload_graph->instruction_parameters[2].p=graph_1->instruction_parameters[2].p;
		fload_graph->instruction_parameters[3].p=graph_1->instruction_parameters[3].p;

		if (*previous_loadx!=NULL)
			*previous_loadx=fload_graph;

		fload_graph->instruction_d_min_a_cost+=1;
		
		graph_1->instruction_code=GFROMF;
		graph_1->instruction_parameters[0].p=fload_graph;

		return fload_graph;
	}

	return g_tof (graph_1);	
}
#else
INSTRUCTION_GRAPH g_fjoin (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2)
{
	if (graph_1->instruction_code==GFHIGH && graph_2->instruction_code==GFLOW
		&& graph_1->instruction_parameters[0].p==graph_2->instruction_parameters[0].p)
			return graph_1->instruction_parameters[0].p;

	if (graph_1->instruction_code==GLOAD && graph_2->instruction_code==GLOAD
		&& graph_1->instruction_parameters[1].i==graph_2->instruction_parameters[1].i
		&& graph_1->instruction_parameters[0].i+4==graph_2->instruction_parameters[0].i)
	{
		INSTRUCTION_GRAPH fload_graph;
				
		fload_graph=g_fload (graph_1->instruction_parameters[0].i,graph_1->instruction_parameters[1].i);
		
		graph_1->instruction_code=GFHIGH;
		graph_2->instruction_code=GFLOW;
		graph_1->instruction_parameters[0].p=fload_graph;
		graph_2->instruction_parameters[0].p=fload_graph;

		graph_1->instruction_parameters[1].p=graph_2;
		graph_2->instruction_parameters[1].p=graph_1;

		return fload_graph;
	}

	if (graph_1->instruction_code==GLOAD_ID && graph_2->instruction_code==GLOAD_ID
# ifdef HIGH_LOW_FIRST_REAL_IN_RECORD
		)
		if (!(graph_1->instruction_parameters[1].i==graph_2->instruction_parameters[1].i
			&& graph_1->instruction_parameters[0].i+4==graph_2->instruction_parameters[0].i))
		{
			INSTRUCTION_GRAPH join_graph,load_id_graph_1,load_id_graph_2;
			
			load_id_graph_1=g_load_id (graph_1->instruction_parameters[0].i,graph_1->instruction_parameters[1].p);
			load_id_graph_2=g_load_id (graph_2->instruction_parameters[0].i,graph_2->instruction_parameters[1].p);
			
			join_graph=g_instruction_2 (GFJOIN,load_id_graph_1,load_id_graph_2);

			graph_1->instruction_code=GFHIGH;
			graph_1->instruction_parameters[0].p=join_graph;
			graph_1->instruction_parameters[1].p=graph_2;
	
			graph_2->instruction_code=GFLOW;
			graph_2->instruction_parameters[0].p=join_graph;
			graph_2->instruction_parameters[1].p=graph_1;

			return join_graph;
		} else
# else
		&& graph_1->instruction_parameters[1].i==graph_2->instruction_parameters[1].i
		&& graph_1->instruction_parameters[0].i+4==graph_2->instruction_parameters[0].i)
# endif
	{
		INSTRUCTION_GRAPH fload_graph;
				
		fload_graph=
			g_fload_id (graph_1->instruction_parameters[0].i,graph_1->instruction_parameters[1].p);

		graph_1->instruction_code=GFHIGH;
		graph_1->instruction_parameters[0].p=fload_graph;
		graph_1->instruction_parameters[1].p=graph_2;

		graph_2->instruction_code=GFLOW;
		graph_2->instruction_parameters[0].p=fload_graph;
		graph_2->instruction_parameters[1].p=graph_1;

		return fload_graph;
	}

	if (graph_1->instruction_code==GMOVEMI && graph_2->instruction_code==GMOVEMI
		&&	graph_1->instruction_parameters[0].p==graph_2->instruction_parameters[0].p
		&&	graph_1->inode_arity+1==graph_2->inode_arity)
	{
		INSTRUCTION_GRAPH fmovemi_graph,movem_graph;
		int number;
				
		movem_graph=graph_1->instruction_parameters[0].p;
		number=graph_1->inode_arity;

		fmovemi_graph=g_new_node (GFMOVEMI,number,2*sizeof (union instruction_parameter));
		
		fmovemi_graph->instruction_parameters[0].p=movem_graph;
		fmovemi_graph->instruction_parameters[1].i=0;
		
		movem_graph->instruction_parameters[2+number].p=fmovemi_graph;
		movem_graph->instruction_parameters[2+number+1].p=NULL;

		graph_1->instruction_code=GFHIGH;
		graph_1->instruction_parameters[0].p=fmovemi_graph;
		graph_1->instruction_parameters[1].p=graph_2;
		
		graph_2->instruction_code=GFLOW;
		graph_2->instruction_parameters[0].p=fmovemi_graph;
		graph_2->instruction_parameters[1].p=graph_1;
		
		return fmovemi_graph;		
	}

	if (graph_1->instruction_code==GLOAD_X && graph_2->instruction_code==GLOAD_X
		&& graph_1->instruction_parameters[1].i+(4<<2)==graph_2->instruction_parameters[1].i
		&& graph_1->instruction_parameters[0].p==graph_2->instruction_parameters[0].p
		&& graph_1->instruction_parameters[2].p==graph_2->instruction_parameters[2].p
		&& graph_1->instruction_parameters[3].p==graph_2)
	{
		INSTRUCTION_GRAPH fload_graph,*previous_loadx;

		previous_loadx=&load_indexed_list;

		while (*previous_loadx!=NULL && *previous_loadx!=graph_1)
			previous_loadx=&(*previous_loadx)->instruction_parameters[3].p;
		
		fload_graph=g_new_node (GFLOAD_X,0,4*sizeof (union instruction_parameter));
		
		fload_graph->instruction_parameters[0].p=graph_1->instruction_parameters[0].p;
		fload_graph->instruction_parameters[1].i=graph_1->instruction_parameters[1].i;
		fload_graph->instruction_parameters[2].p=graph_1->instruction_parameters[2].p;

		fload_graph->instruction_parameters[3].p=graph_2->instruction_parameters[3].p;

		if (*previous_loadx!=NULL)
			*previous_loadx=fload_graph;

		fload_graph->instruction_d_min_a_cost+=1;
		
		graph_1->instruction_code=GFHIGH;
		graph_1->instruction_parameters[0].p=fload_graph;
		graph_1->instruction_parameters[1].p=graph_2;
		graph_1->instruction_parameters[3].p=fload_graph;

		graph_2->instruction_code=GFLOW;
		graph_2->instruction_parameters[0].p=fload_graph;
		graph_2->instruction_parameters[1].p=graph_1;
		graph_2->instruction_parameters[3].p=fload_graph;

		return fload_graph;
	}

	return g_instruction_2 (GFJOIN,graph_1,graph_2);
}
#endif

INSTRUCTION_GRAPH g_fload (int offset,int stack)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFLOAD,0,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].i=offset;
	instruction->instruction_parameters[1].i=stack;
	
	return instruction;
}

INSTRUCTION_GRAPH g_fload_i (DOUBLE v)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFLOAD_I,0,sizeof (DOUBLE));
	
	*(DOUBLE*)&instruction->instruction_parameters[0]=v;
	
	return instruction;
}

INSTRUCTION_GRAPH g_fload_id (int offset,INSTRUCTION_GRAPH graph_1)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFLOAD_ID,0,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].i=offset;
	instruction->instruction_parameters[1].p=graph_1;
	
	graph_1->instruction_d_min_a_cost+=1;
	
	return instruction;
}

INSTRUCTION_GRAPH g_fload_x (INSTRUCTION_GRAPH graph_1,int offset,int shift,INSTRUCTION_GRAPH graph_2)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFLOAD_X,0,4*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].i=(offset<<2) | shift;
	instruction->instruction_parameters[2].p=graph_2;
	instruction->instruction_parameters[3].p=load_indexed_list;

#if defined (sparc) || defined (G_POWER)
	if (offset!=0 && graph_2!=NULL)
		graph_2->instruction_d_min_a_cost+=1;
	else
#endif
	graph_1->instruction_d_min_a_cost+=1;
	
	load_indexed_list=instruction;

	return instruction;
}

#if defined (I486) || defined (ARM)
INSTRUCTION_GRAPH g_fload_s_x (INSTRUCTION_GRAPH graph_1,int offset,int shift,INSTRUCTION_GRAPH graph_2)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFLOAD_S_X,0,4*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].i=(offset<<2) | shift;
	instruction->instruction_parameters[2].p=graph_2;
	instruction->instruction_parameters[3].p=load_indexed_list;

	graph_1->instruction_d_min_a_cost+=1;
	
	load_indexed_list=instruction;

	return instruction;
}
#endif

INSTRUCTION_GRAPH g_fstore (int offset,int reg_1,INSTRUCTION_GRAPH graph_1,
#ifdef G_A64
	INSTRUCTION_GRAPH graph_2)
#else
	INSTRUCTION_GRAPH graph_2,INSTRUCTION_GRAPH graph_3)
#endif
{
	INSTRUCTION_GRAPH instruction;
	
#ifdef G_A64
	instruction=g_new_node (GFSTORE,0,4*sizeof (union instruction_parameter));
#else
	instruction=g_new_node (GFSTORE,0,5*sizeof (union instruction_parameter));
#endif
	instruction->instruction_parameters[0].i=offset;
	instruction->instruction_parameters[1].i=reg_1;
	instruction->instruction_parameters[2].p=graph_1;
	
#ifdef G_A64
	if (graph_2 && graph_2->instruction_code==GTOF)
		instruction->instruction_parameters[3].p=graph_2->instruction_parameters[0].p;
	else
		instruction->instruction_parameters[3].p=graph_2;
#else
	if (graph_2 && (graph_2->instruction_code==GFLOW || graph_2->instruction_code==GFHIGH))
		instruction->instruction_parameters[3].p=graph_2->instruction_parameters[0].p;
	else
		instruction->instruction_parameters[3].p=graph_2;
		
	if (graph_3 && (graph_3->instruction_code==GFLOW || graph_3->instruction_code==GFHIGH))
		instruction->instruction_parameters[4].p=graph_3->instruction_parameters[0].p;
	else
		instruction->instruction_parameters[4].p=graph_3;
#endif		
	return instruction;
}

INSTRUCTION_GRAPH g_fstore_r (int reg_1,INSTRUCTION_GRAPH graph_1)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFSTORE_R,0,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].i=reg_1;
	instruction->instruction_parameters[1].p=graph_1;

	return instruction;
}

INSTRUCTION_GRAPH g_lea (LABEL *label)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GLEA,0,sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].l=label;
	
	return instruction;
}

INSTRUCTION_GRAPH g_lea_i (LABEL *label,int offset)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GLEA,1,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].l=label;
	instruction->instruction_parameters[1].i=offset;
				
	return instruction;
}

INSTRUCTION_GRAPH g_load (int offset,int stack)
{
	register INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GLOAD,0,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].i=offset;
	instruction->instruction_parameters[1].i=stack;
	
	return instruction;
}

INSTRUCTION_GRAPH g_load_i (CleanInt value)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GLOAD_I,0,sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].imm=value;
	
	return instruction;
}

INSTRUCTION_GRAPH g_load_id (int offset,INSTRUCTION_GRAPH graph_1)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GLOAD_ID,0,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].i=offset;
	instruction->instruction_parameters[1].p=graph_1;
	
	graph_1->instruction_d_min_a_cost+=1;
	
	return instruction;
}

INSTRUCTION_GRAPH g_load_b_x (INSTRUCTION_GRAPH graph_1,int offset,int sign_extend,INSTRUCTION_GRAPH graph_2)
{
	register INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GLOAD_B_X,0,4*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].i=(offset<<2) | sign_extend;
	instruction->instruction_parameters[2].p=graph_2;
	instruction->instruction_parameters[3].p=load_indexed_list;
	
	graph_1->instruction_d_min_a_cost+=1;
	
	load_indexed_list=instruction;

	return instruction;
}

INSTRUCTION_GRAPH g_load_x (INSTRUCTION_GRAPH graph_1,int offset,int shift,INSTRUCTION_GRAPH graph_2)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GLOAD_X,0,4*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].i=(offset<<2) | shift;
	instruction->instruction_parameters[2].p=graph_2;
	instruction->instruction_parameters[3].p=load_indexed_list;

#if defined (sparc) || defined (G_POWER)
	if (offset!=0 && graph_2!=NULL)
		graph_2->instruction_d_min_a_cost+=1;
	else
#endif
	graph_1->instruction_d_min_a_cost+=1;
	
	load_indexed_list=instruction;

	return instruction;
}

INSTRUCTION_GRAPH g_load_b_id (int offset,INSTRUCTION_GRAPH graph_1)
{
	register INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GLOAD_B_ID,0,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].i=offset;
	instruction->instruction_parameters[1].p=graph_1;
	
	graph_1->instruction_d_min_a_cost+=1;
	
	return instruction;
}

INSTRUCTION_GRAPH g_load_des_i (LABEL *descriptor_label,int arity)
{
	register INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GLOAD_DES_I,0,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].l=descriptor_label;
#if defined (I486) || defined (ARM)
# ifdef MACH_O64
	instruction->instruction_parameters[1].i=(arity<<4)+2;
# else
#  if defined (G_A64) && defined (LINUX)
	if (pic_flag)
		instruction->instruction_parameters[1].i=(arity<<4)+2;
	else
#  endif
	instruction->instruction_parameters[1].i=(arity<<3)+2;
# endif
#else
	instruction->instruction_parameters[1].i=arity;
#endif
	
	return instruction;
}

INSTRUCTION_GRAPH g_load_des_id (int offset,INSTRUCTION_GRAPH graph_1)
{
	register INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GLOAD_DES_ID,0,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].i=offset;
	instruction->instruction_parameters[1].p=graph_1;
	
	graph_1->instruction_d_min_a_cost+=1;
	
	return instruction;
}

#ifdef G_A64
INSTRUCTION_GRAPH g_load_s_x (INSTRUCTION_GRAPH graph_1,int offset,int shift,INSTRUCTION_GRAPH graph_2)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GLOAD_S_X,0,4*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].imm=(((CleanInt)offset)<<4) | (shift<<2);
	instruction->instruction_parameters[2].p=graph_2;
	instruction->instruction_parameters[3].p=load_indexed_list;

	graph_1->instruction_d_min_a_cost+=1;
	
	load_indexed_list=instruction;

	return instruction;
}
#endif

#ifdef G_A64
INSTRUCTION_GRAPH g_load_sqb_id (int offset,INSTRUCTION_GRAPH graph_1)
{
	INSTRUCTION_GRAPH instruction;

	instruction=g_new_node (GLOAD_SQB_ID,0,2*sizeof (union instruction_parameter));

	instruction->instruction_parameters[0].i=offset;
	instruction->instruction_parameters[1].p=graph_1;

	graph_1->instruction_d_min_a_cost+=1;

	return instruction;
}
#endif

INSTRUCTION_GRAPH g_movem (int offset,INSTRUCTION_GRAPH graph_1,int n)
{
	INSTRUCTION_GRAPH instruction;
	int argument_number;
	
	instruction=g_new_node (GMOVEM,n,(2+n)*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].i=offset;
	instruction->instruction_parameters[1].p=graph_1;
	
	for (argument_number=0; argument_number<n; ++argument_number)
		instruction->instruction_parameters[2+argument_number].p=NULL;
	
	return instruction;
}

INSTRUCTION_GRAPH g_movemi (int number,INSTRUCTION_GRAPH movem_graph)
{
	register INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GMOVEMI,number,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=movem_graph;
	instruction->instruction_parameters[1].i=0;
	
	movem_graph->instruction_parameters[2+number].p=instruction;
	
	return instruction;
}

INSTRUCTION_GRAPH g_fregister (int float_reg)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFREGISTER,0,sizeof (union instruction_parameter));

	if ((unsigned)float_reg<(unsigned)N_FLOAT_PARAMETER_REGISTERS)
		global_block.block_graph_f_register_parameter_node[float_reg]=instruction;
			
	instruction->instruction_parameters[0].i=float_reg;
			
	return instruction;
}

INSTRUCTION_GRAPH g_fstore_x (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,int offset,int shift,INSTRUCTION_GRAPH graph_3)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFSTORE_X,0,5*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;
	instruction->instruction_parameters[2].i=(offset<<2) | shift;
	instruction->instruction_parameters[3].p=graph_3;
	instruction->instruction_parameters[4].p=load_indexed_list;

#if defined (sparc) || defined (G_POWER)
	if (offset!=0 && graph_3!=NULL)
		graph_3->instruction_d_min_a_cost+=1;
	else
#endif
	graph_2->instruction_d_min_a_cost+=1;
	
	return instruction;
}

#if defined (I486) || defined (ARM)
INSTRUCTION_GRAPH g_fstore_s_x (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,int offset,int shift,INSTRUCTION_GRAPH graph_3)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GFSTORE_S_X,0,5*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;
	instruction->instruction_parameters[2].i=(offset<<2) | shift;
	instruction->instruction_parameters[3].p=graph_3;
	instruction->instruction_parameters[4].p=load_indexed_list;

	graph_2->instruction_d_min_a_cost+=1;
	
	return instruction;
}
#endif

INSTRUCTION_GRAPH g_g_register (int reg)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GGREGISTER,0,sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].i=reg;
	
	return instruction;
}

INSTRUCTION_GRAPH g_register (int reg)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GREGISTER,0,sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].i=reg;
	
	if ((unsigned)a_reg_num (reg)<(unsigned)N_ADDRESS_PARAMETER_REGISTERS)
		global_block.block_graph_a_register_parameter_node[a_reg_num (reg)]=instruction;
		
	if ((unsigned)d_reg_num (reg)<(unsigned)N_DATA_PARAMETER_REGISTERS)
		global_block.block_graph_d_register_parameter_node[d_reg_num (reg)]=instruction;
		
	return instruction;
}

INSTRUCTION_GRAPH g_store (int offset,int reg_1,INSTRUCTION_GRAPH graph_1,
							INSTRUCTION_GRAPH graph_2)
{
	register INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GSTORE,0,4*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].i=offset;
	instruction->instruction_parameters[1].i=reg_1;
	instruction->instruction_parameters[2].p=graph_1;
	
#ifdef G_A64
	if (graph_2 && graph_2->instruction_code==GTOF)
#else
	if (graph_2 && (graph_2->instruction_code==GFLOW || graph_2->instruction_code==GFHIGH))
#endif
		instruction->instruction_parameters[3].p=graph_2->instruction_parameters[0].p;
	else
		instruction->instruction_parameters[3].p=graph_2;
	
	return instruction;
}

INSTRUCTION_GRAPH g_store_b_x (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,int offset,INSTRUCTION_GRAPH graph_3)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GSTORE_B_X,0,5*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;
	instruction->instruction_parameters[2].i=(offset<<2);
	instruction->instruction_parameters[3].p=graph_3;
	instruction->instruction_parameters[4].p=load_indexed_list;
	
	graph_2->instruction_d_min_a_cost+=1;
	
	return instruction;
}

#ifdef G_A64
INSTRUCTION_GRAPH g_store_s_x (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,int offset,int shift,INSTRUCTION_GRAPH graph_3)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GSTORE_S_X,0,5*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;
	instruction->instruction_parameters[2].imm=(((CleanInt)offset)<<4) | (shift<<2);
	instruction->instruction_parameters[3].p=graph_3;
	instruction->instruction_parameters[4].p=load_indexed_list;

	graph_2->instruction_d_min_a_cost+=1;
	
	return instruction;
}
#endif

INSTRUCTION_GRAPH g_store_x (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,int offset,int shift,INSTRUCTION_GRAPH graph_3)
{
	INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GSTORE_X,0,5*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].p=graph_1;
	instruction->instruction_parameters[1].p=graph_2;
	instruction->instruction_parameters[2].i=(offset<<2) | shift;
	instruction->instruction_parameters[3].p=graph_3;
	instruction->instruction_parameters[4].p=load_indexed_list;

#if defined (sparc) || defined (G_POWER)
	if (offset!=0 && graph_3!=NULL)
		graph_3->instruction_d_min_a_cost+=1;
	else
#endif
	graph_2->instruction_d_min_a_cost+=1;
	
	return instruction;
}

INSTRUCTION_GRAPH g_store_r (int reg_1,INSTRUCTION_GRAPH graph_1)
{
	register INSTRUCTION_GRAPH instruction;
	
	instruction=g_new_node (GSTORE_R,0,2*sizeof (union instruction_parameter));
	
	instruction->instruction_parameters[0].i=reg_1;
	instruction->instruction_parameters[1].p=graph_1;
	
	if (graph_1->instruction_code==GMOVEMI)
		graph_1->instruction_parameters[1].i=(reg_1<<1)+1;
	
	return instruction;
}

LABEL *w_code_string (char *string,int length)
{
	LABEL *string_label;

	string_label=new_local_label (LOCAL_LABEL
#ifdef G_POWER
									| DATA_LABEL
#endif
	);

#ifdef FUNCTION_LEVEL_LINKING
	as_new_data_module();
	if (assembly_flag)
		w_as_new_data_module();
#endif

#ifdef GEN_OBJ
	define_data_label (string_label);
	store_c_string_in_data_section (string,length);
#endif	
	if (assembly_flag)
		w_as_labeled_c_string_in_data_section (string,length,string_label->label_number);
	
	return string_label;
}

LABEL *w_code_descriptor_length_and_string (char *string,int length)
{
	LABEL *string_label;

	if (_STRING__label==NULL)
		_STRING__label=enter_label ("__STRING__",IMPORT_LABEL | DATA_LABEL);

	string_label=new_local_label (LOCAL_LABEL
#ifdef G_POWER
									| DATA_LABEL
#endif
	);

#ifdef FUNCTION_LEVEL_LINKING
	as_new_data_module();
	if (assembly_flag)
		w_as_new_data_module();
#endif

#ifdef GEN_OBJ
# ifdef MACH_O64
	as_data_align_quad();
# endif
	define_data_label (string_label);
	if (_STRING__label->label_id<0)
		_STRING__label->label_id=next_label_id++;
	store_descriptor_in_data_section (_STRING__label);
	store_abc_string_in_data_section (string,length);
#endif
	if (assembly_flag){
# if defined (MACH_O64) || (defined (ARM) && defined (G_A64))
		w_as_align_and_define_data_label (string_label->label_number);
# else
		w_as_define_data_label (string_label->label_number);
# endif
		w_as_descriptor_in_data_section (_STRING__label->label_name);
		w_as_abc_string_in_data_section (string,length);
	}
	
	return string_label;
}

LABEL *w_code_length_and_string (char *string,int length)
{
	LABEL *string_label;

	string_label=new_local_label (LOCAL_LABEL
#ifdef G_POWER
									| DATA_LABEL
#endif
	);

#ifdef FUNCTION_LEVEL_LINKING
	as_new_data_module();
	if (assembly_flag)
		w_as_new_data_module();
#endif

#ifdef GEN_OBJ
# ifdef MACH_O64
	as_data_align_quad();
# endif
	define_data_label (string_label);
	store_abc_string_in_data_section (string,length);
#endif
	if (assembly_flag){
		w_as_define_data_label (string_label->label_number);
		w_as_abc_string_in_data_section (string,length);
	}

	return string_label;
}

void w_descriptor_string (char *string,int length,int string_code_label_id,LABEL *string_label)
{
#ifdef GEN_OBJ
	store_descriptor_string_in_data_section (string,length,string_label);
#endif
	if (assembly_flag)
		w_as_descriptor_string_in_data_section (string,length,string_code_label_id,string_label);
}

void code_n_string (char string[],int string_length)
{
}

void code_fill1_r (char descriptor_name[],int a_size,int b_size,int root_offset,char bits[])
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	LABEL *descriptor_label;
	
	graph_1=s_get_a (root_offset);

	if (bits[0]=='1'){
		descriptor_label=enter_label (descriptor_name,DATA_LABEL);

		if (!parallel_flag && descriptor_label->label_last_lea_block==last_block)
			graph_2=descriptor_label->label_last_lea;
		else {
			graph_2=g_load_des_i (descriptor_label,0);

			if (!parallel_flag ){
				descriptor_label->label_last_lea=graph_2;
				descriptor_label->label_last_lea_block=last_block;
			}
		}
	} else
		graph_2=NULL;

	switch (a_size+b_size){
		case 0:
			graph_4=g_fill_2 (graph_1,graph_2);
			break;
		case 1:
			if (bits[1]=='0')
				graph_5=NULL;
			else
				if (a_size!=0){
					graph_5=s_pop_a();
					--root_offset;
				} else
					graph_5=s_pop_b();
			graph_4=g_fill_3 (graph_1,graph_2,graph_5);
			break;
		case 2:
			switch (b_size){
				case 0:
					if (bits[1]=='0')
						graph_5=NULL;
					else {
						graph_5=s_pop_a();
						--root_offset;
					}
					if (bits[2]=='0')
						graph_6=NULL;
					else {
						graph_6=s_pop_a();
						--root_offset;
					}
					break;				
				case 1:
					if (bits[1]=='0')
						graph_5=NULL;
					else {
						graph_5=s_pop_a();
						--root_offset;
					}
					if (bits[2]=='0')
						graph_6=NULL;
					else
						graph_6=s_pop_b();
					break;
				default:
					if (bits[1]=='0')
						graph_5=NULL;
					else
						graph_5=s_pop_b();
					if (bits[2]=='0')
						graph_6=NULL;
					else
						graph_6=s_pop_b();
			}
			graph_4=g_fill_4 (graph_1,graph_2,graph_5,graph_6);
			break;
		default:
		{
			union instruction_parameter *parameter;
			int a_n,b_n;
			
			a_n=0;
			b_n=0;
			
			if (a_n<a_size){
				graph_5=s_pop_a();
				--root_offset;
				++a_n;
			} else {
				graph_5=s_pop_b();
				++b_n;
			}
			
			graph_3=g_create_m (a_size+b_size-1);
			
			parameter=graph_3->instruction_parameters;

			while (a_n<a_size){
				if (bits[a_n+1]=='0')
					parameter->p=NULL;
				else {
					parameter->p=s_pop_a();
					--root_offset;
				}
				++parameter;
				++a_n;
			}

			while (b_n<b_size){
				if (bits[b_n+a_size+1]=='0')
					parameter->p=NULL;
				else
					parameter->p=s_pop_b();
				++parameter;
				++b_n;
			}

			graph_4=g_fill_4 (graph_1,graph_2,graph_5,graph_3);
		}
	}
	
	s_put_a (root_offset,graph_4);
}

#define g_keep(g1,g2) g_instruction_2(GKEEP,(g1),(g2))

void code_fill2_r (char descriptor_name[],int a_size,int b_size,int root_offset,char bits[])
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;
	LABEL *descriptor_label;
	union instruction_parameter *parameter;
	int a_n,b_n;
	
	graph_1=s_get_a (root_offset);
	if (graph_1->instruction_code==GBEFORE0)
		graph_1->instruction_code=GBEFORE;

	if (bits[0]=='1'){
		descriptor_label=enter_label (descriptor_name,DATA_LABEL);

		if (!parallel_flag && descriptor_label->label_last_lea_block==last_block)
			graph_2=descriptor_label->label_last_lea;
		else {
			graph_2=g_load_des_i (descriptor_label,0);

			if (!parallel_flag ){
				descriptor_label->label_last_lea=graph_2;
				descriptor_label->label_last_lea_block=last_block;
			}
		}
	} else
		graph_2=NULL;

	a_n=0;
	b_n=0;
		
	if (a_n<a_size){
		if (bits[a_n+1]=='0')
			graph_5=NULL;
		else {
			graph_5=s_pop_a();
			--root_offset;
		}
		++a_n;
	} else {
		if (bits[b_n+a_size+1]=='0')
			graph_5=NULL;
		else
			graph_5=s_pop_b();
		++b_n;
	}
	
	graph_3=g_fill_m (g_load_id (2*STACK_ELEMENT_SIZE,graph_1),a_size+b_size-1);
	
	parameter=&graph_3->instruction_parameters[1];

	while (a_n<a_size){
		if (bits[a_n+1]=='0')
			parameter->p=NULL;
		else {
			parameter->p=s_pop_a();
			--root_offset;
		}
		++parameter;
		++a_n;
	}

	while (b_n<b_size){
		if (bits[b_n+a_size+1]=='0')
			parameter->p=NULL;
		else
			parameter->p=s_pop_b();
		++parameter;
		++b_n;
	}

	graph_4=g_fill_3 (g_keep (graph_3,graph_1),graph_2,graph_5);
	
	s_put_a (root_offset,graph_4);
}

extern LABEL *cycle_in_spine_label,*reserve_label;

void code_fill3_r (char descriptor_name[],int a_size,int b_size,int root_offset,char bits[])
{
	INSTRUCTION_GRAPH graph_0,graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	LABEL *descriptor_label;
	union instruction_parameter *parameter;
	int a_n,b_n;
	
	graph_0=s_pop_a();
	if (graph_0->instruction_code==GBEFORE0)
		graph_0->instruction_code=GBEFORE;
	--root_offset;
	
#ifndef RESERVE_CODE_REGISTER
	if (!parallel_flag){
		if (cycle_in_spine_label==NULL){
			cycle_in_spine_label=enter_label ("__cycle__in__spine",IMPORT_LABEL | NODE_ENTRY_LABEL);
			cycle_in_spine_label->label_arity=0;
			cycle_in_spine_label->label_descriptor=EMPTY_label;
		}
		graph_6=g_lea (cycle_in_spine_label);
	} else {
		if (reserve_label==NULL){
			reserve_label=enter_label ("__reserve",IMPORT_LABEL | NODE_ENTRY_LABEL);
			reserve_label->label_arity=0;
			reserve_label->label_descriptor=EMPTY_label;
		}
		graph_6=g_lea (reserve_label);
	}
#else
	graph_6=g_g_register (RESERVE_CODE_REGISTER);
#endif
	graph_0=g_fill_2 (graph_0,graph_6);
		
	graph_1=s_get_a (root_offset);
	if (graph_1->instruction_code==GBEFORE0)
		graph_1->instruction_code=GBEFORE;

	descriptor_label=enter_label (descriptor_name,DATA_LABEL);

	if (!parallel_flag && descriptor_label->label_last_lea_block==last_block)
		graph_2=descriptor_label->label_last_lea;
	else {
		graph_2=g_load_des_i (descriptor_label,0);

		if (!parallel_flag ){
			descriptor_label->label_last_lea=graph_2;
			descriptor_label->label_last_lea_block=last_block;
		}
	}

	a_n=0;
	b_n=0;

	if (bits[0]=='0'){
		graph_5=g_load_id (STACK_ELEMENT_SIZE,graph_0);
		if (a_n<a_size)
			++a_n;
		else
			++b_n;
	} else {
		if (a_n<a_size){
			graph_5=s_pop_a();
			--root_offset;
			++a_n;
		} else {
			graph_5=s_pop_b();
			++b_n;
		}
	}
	
	graph_0=g_load_id (2*STACK_ELEMENT_SIZE,graph_0);

	graph_3=g_fill_m (graph_0,a_size+b_size-1);
	
	parameter=&graph_3->instruction_parameters[1];

	while (a_n<a_size){
		if (bits[a_n]=='0')
			parameter->p=NULL;
		else {
			parameter->p=s_pop_a();
			--root_offset;
		}
		++parameter;
		++a_n;
	}

	while (b_n<b_size){
		if (bits[b_n+a_size]=='0')
			parameter->p=NULL;
		else
			parameter->p=s_pop_b();
		++parameter;
		++b_n;
	}

	graph_4=g_fill_4 (graph_1,graph_2,graph_5,graph_3);
	
	s_put_a (root_offset,graph_4);
}

#define ARGUMENTS_OFFSET	STACK_ELEMENT_SIZE

void code_push_args_u (int a_offset,int arity,int n_arguments)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_5,*graph_p;
	
	graph_1=s_get_a (a_offset);

	graph_5=g_before0 (graph_1,n_arguments);
	graph_p=&graph_5->instruction_parameters[1+n_arguments].p;

	s_put_a (a_offset,graph_5);

	if (n_arguments>0){
		graph_2=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);

		if (n_arguments!=1)
			if (n_arguments==2 && arity==2){
				graph_3=g_load_id (2*STACK_ELEMENT_SIZE-NODE_POINTER_OFFSET,graph_1);
				*--graph_p=graph_3;
				s_push_a (graph_3);
			} else {
				INSTRUCTION_GRAPH graph_4;
				
				graph_3=g_load_id (2*STACK_ELEMENT_SIZE-NODE_POINTER_OFFSET,graph_1);
				--n_arguments;
				
				if (n_arguments==1){
					graph_4=g_load_id (0-NODE_POINTER_OFFSET,graph_3);
					*--graph_p=graph_4;
					s_push_a (graph_4);
				} else {
#if ! (defined (I486) || defined (ARM))
					if (n_arguments>=8){
#endif
						while (n_arguments!=0){
							INSTRUCTION_GRAPH graph_5;
						
							--n_arguments;
		
							graph_5=g_load_id ((n_arguments<<STACK_ELEMENT_LOG_SIZE)-NODE_POINTER_OFFSET,graph_3);
							*--graph_p=graph_5;
							s_push_a (graph_5);
						}
#if ! (defined (I486) || defined (ARM))
					} else {
						graph_4=g_movem (0-NODE_POINTER_OFFSET,graph_3,n_arguments);
						while (n_arguments!=0){
							INSTRUCTION_GRAPH graph_5;
						
							--n_arguments;
		
							graph_5=g_movemi (n_arguments,graph_4);
							*--graph_p=graph_5;
							s_push_a (graph_5);
						}
					}
#endif
				}
			}
		
		*--graph_p=graph_2;
		s_push_a (graph_2);
	}
}

void code_push_r_args_u (int a_offset,int a_size,int b_size)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_5,graph_6,*graph_p;

	graph_1=s_get_a (a_offset);

	graph_6=g_before0 (graph_1,a_size+b_size);
	graph_p=&graph_6->instruction_parameters[1+a_size+b_size].p;

	s_put_a (a_offset,graph_6);

	switch (a_size+b_size){
		case 0:
			return;
		case 1:
			graph_2=g_load_id (ARGUMENTS_OFFSET,graph_1);
			*--graph_p=graph_2;
			if (a_size!=0)
				s_push_a (graph_2);
			else
				s_push_b (graph_2);
			return;
		case 2:
			graph_2=g_load_id (ARGUMENTS_OFFSET,graph_1);
			graph_3=g_load_id (2*STACK_ELEMENT_SIZE,graph_1);
			*--graph_p=graph_3;
			*--graph_p=graph_2;
			switch (b_size){
				case 0:
					s_push_a (graph_3);
					s_push_a (graph_2);
					break;
				case 1:
					s_push_a (graph_2);
					s_push_b (graph_3);
					break;
				default:
					s_push_b (graph_3);
					s_push_b (graph_2);		
			}			
			return;
		default:
			graph_2=g_load_id (ARGUMENTS_OFFSET,graph_1);
			graph_3=g_load_id (2*STACK_ELEMENT_SIZE,graph_1);

#ifdef M68000
			if (a_size+b_size-1>=8){
#endif
				b_size+=a_size;
	
				while (b_size>a_size && b_size>1){
					--b_size;			
					graph_5=g_load_id ((b_size-1)<<STACK_ELEMENT_LOG_SIZE,graph_3);
					*--graph_p=graph_5;
					s_push_b (graph_5);
				}
	
				while (a_size>1){
					--a_size;
					graph_5=g_load_id ((a_size-1)<<STACK_ELEMENT_LOG_SIZE,graph_3);
					*--graph_p=graph_5;
					s_push_a (graph_5);
				}				
#ifdef M68000
			} else {
				INSTRUCTION_GRAPH graph_4;
				
				graph_4=g_movem (0,graph_3,a_size+b_size-1);
	
				b_size+=a_size;
	
				while (b_size>a_size && b_size>1){
					--b_size;			
					graph_5=g_movemi (b_size-1,graph_4);
					*--graph_p=graph_5;
					s_push_b (graph_5);
				}
	
				while (a_size>1){
					--a_size;			
					graph_5=g_movemi (a_size-1,graph_4);
					*--graph_p=graph_5;
					s_push_a (graph_5);
				}
			}
#endif
			*--graph_p=graph_2;
			if (a_size>0)
				s_push_a (graph_2);
			else
				s_push_b (graph_2);
			return;
	}
}

void code_push_r_arg_u (int a_offset,int a_size,int b_size,int a_arg_offset,int a_arg_size,int b_arg_offset,int b_arg_size)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_5,graph_6,*graph_p;

	graph_1=s_get_a (a_offset);

	if (graph_1->instruction_code==GBEFORE0 && graph_1->inode_arity==a_size+b_size+1)
		graph_p=&graph_1->instruction_parameters[1].p;
	else {
		graph_6=g_before0 (graph_1,a_size+b_size);
		graph_p=&graph_6->instruction_parameters[1+a_size+b_size].p;

		s_put_a (a_offset,graph_6);

		switch (a_size+b_size){
			case 0:
				break;
			case 1:
				graph_2=g_load_id (ARGUMENTS_OFFSET,graph_1);
				*--graph_p=graph_2;
				break;
			case 2:
				graph_2=g_load_id (ARGUMENTS_OFFSET,graph_1);
				graph_3=g_load_id (2*STACK_ELEMENT_SIZE,graph_1);
				*--graph_p=graph_3;
				*--graph_p=graph_2;
				break;
			default:
			{
				int ab_size;
				
				graph_2=g_load_id (ARGUMENTS_OFFSET,graph_1);
				graph_3=g_load_id (2*STACK_ELEMENT_SIZE,graph_1);

				ab_size=a_size+b_size-1;
#ifdef M68000
				if (ab_size>=8){
#endif
					while (ab_size>0){
						--ab_size;
						graph_5=g_load_id (ab_size<<STACK_ELEMENT_LOG_SIZE,graph_3);
						*--graph_p=graph_5;
					}				
#ifdef M68000
				} else {
					INSTRUCTION_GRAPH graph_4;
					
					graph_4=g_movem (0,graph_3,ab_size);
		
					while (ab_size>1){
						--ab_size;			
						graph_5=g_movemi (ab_size,graph_4);
						*--graph_p=graph_5;
					}
				}
#endif
				*--graph_p=graph_2;
				break;
			}
		}
	}

	while (a_arg_size>0){
		--a_arg_size;
		s_push_a (graph_p[a_arg_offset-1+a_arg_size]);
	}
	
	while (b_arg_size>0){
		--b_arg_size;
		s_push_b (graph_p[a_size+b_arg_offset-1+b_arg_size]);
	}
}

/* convert string to integer */

#ifdef _WIN64
# define A64
#endif
#if defined (__GNUC__) && defined (__SIZEOF_POINTER__)
# if __SIZEOF_POINTER__==8
#  define A64
# endif
#endif

#ifdef _MSC_VER
# define U_LONG_LONG unsigned __int64
#else
# define U_LONG_LONG unsigned long long
#endif

#ifdef A64
# define IF_INT_64_OR_32(if64,if32) if64
# define N_bits_in_int 64
# define Max_bit_n_in_int 63
# define N_digits_in_part 27
# define N_digits_in_part_m1 26
# define I5PD 7450580596923828125
# define I2T5PD 14901161193847656250
# define I1E18 1000000000000000000
# define IM1E18 (-1000000000000000000)
#else
# define IF_INT_64_OR_32(if64,if32) if32
# define N_bits_in_int 32
# define Max_bit_n_in_int 31
# define N_digits_in_part 13
# define N_digits_in_part_m1 12
# define I5PD 1220703125
# define I2T5PD 2441406250
#endif
#define I1E9 1000000000

#ifdef A64
# ifdef __GNUC__
# define UW unsigned long long
# define W long long
# else
# define UW unsigned __int64
# define W __int64
# endif
#else
# define UW unsigned int
# define W int
#endif

#ifdef _WIN64
UW _umul128 (UW multiplier, UW multiplicand, UW* highproduct);
# pragma intrinsic (_umul128)
#endif

#ifdef A64
# ifdef ARM
#    define umul_hl(h,l,a,b) \
	(l)=(a)*(b); \
	__asm__ ("umulh %0,%1,%2" : "=r" (h) : "r" (a), "r" (b))
# else
#  ifdef __GNUC__
#   ifdef __clang__
#    define umul_hl(h,l,a,b) \
	__asm__ ("mulq %3" \
			: "=a" (l), \
			  "=d" (h)  \
			: "%0" (a), \
			  "rm" (b))
#   else
#   define umul_hl(h,l,a,b) \
	__asm__ ("mulq %3" \
			: "=a" ((UW)(l)), \
			  "=d" ((UW)(h))  \
			: "%0" ((UW)(a)), \
			  "rm" ((UW)(b)))
#   endif
#  else
#   define umul_hl(h,l,a,b) l=_umul128 (a,b,&h)
#  endif
# endif
#endif

struct integer {
	W   s;
	UW *a;
};

static UW convertchars (int i,int end_i,char s[])
{
	UW n;
	
	n=0;
	while (i<end_i){
		n=n*10+(s[i]-48);
		i=i+1;
	}
	return n;
}

static UW convert9c (int i,char s[])
{
	UW n;

 	n=s[i]-48;
	n=n*10+(s[i+1]-48);
	n=n*10+(s[i+2]-48);
	n=n*10+(s[i+3]-48);
	n=n*10+(s[i+4]-48);
	n=n*10+(s[i+5]-48);
	n=n*10+(s[i+6]-48);
	n=n*10+(s[i+7]-48);
	n=n*10+(s[i+8]-48);

	return n;
}

#ifdef A64
UW
#else
static U_LONG_LONG
#endif
	convert10to13c (int n_chars,char s[])
{
 	int i;
 	UW nl,nh;
#ifndef A64
	U_LONG_LONG hl;
#endif

 	i = n_chars-9;
	nl = convert9c (i,s);
	nh = convertchars (0,i,s);
#ifdef A64
	return nh*I1E9+nl;
#else
	hl = ((U_LONG_LONG)nh)*((U_LONG_LONG)I1E9);

	return hl+nl;
#endif
}

#ifndef A64
static U_LONG_LONG convert13c_32 (int i,char s[])
{
	UW nl,nh;
	U_LONG_LONG hl;
	
	nl=convert9c (i+4,s);

	nh=s[i]-48;
	nh=nh*10+(s[i+1]-48);
	nh=nh*10+(s[i+2]-48);
	nh=nh*10+(s[i+3]-48);

	hl = ((U_LONG_LONG)nh)*((U_LONG_LONG)I1E9);
	return hl+nl;
}
#endif

#ifdef A64
static UW convert18c_64 (int i,char s[])
{
	UW t48,n;

	t48 = 0x3000000030;
	n=(((UW)s[i]<<32)+s[i+9])-t48;
	n=n*10+((((UW)s[i+1]<<32)+s[i+10])-t48);
	n=n*10+((((UW)s[i+2]<<32)+s[i+11])-t48);
	n=n*10+((((UW)s[i+3]<<32)+s[i+12])-t48);
	n=n*10+((((UW)s[i+4]<<32)+s[i+13])-t48);
	n=n*10+((((UW)s[i+5]<<32)+s[i+14])-t48);
	n=n*10+((((UW)s[i+6]<<32)+s[i+15])-t48);
	n=n*10+((((UW)s[i+7]<<32)+s[i+16])-t48);
	n=n*10+((((UW)s[i+8]<<32)+s[i+17])-t48);
	return (n>>32) * I1E9 + (n & 0xffffffff);
}

static UW convert19to27c_64 (int n_chars,char *s,UW *h_p)
{
	int i;
	UW nh,nl,h,l;

	i = n_chars-18;
	nl = convert18c_64 (i,s);
	nh = convertchars (0,i,s);

	umul_hl (h,l,nh,I1E18);
	l = l+nl;
	*h_p = h+(l<nl);
	return l;
}

static UW convert27c_64 (int i,char s[],UW *h_p)
{
	UW nh,nl,h,l;
	
	nl=convert18c_64 (i+9,s);
   	nh=convert9c (i,s);

	umul_hl (h,l,nh,I1E18);
	l = l+nl;
	*h_p = h+(l<nl);
	return l;
}
#endif

static int convert_first_chars (int n_chars_in_first_part,char s[],int i_a_f,UW a[])
{
	if (n_chars_in_first_part==0)
		return i_a_f;

	if (n_chars_in_first_part<IF_INT_64_OR_32 (19,10)){
		UW n;
		
		n = convertchars (0,n_chars_in_first_part,s);
		a[i_a_f]=n;
		return i_a_f+1;
	} else {
		UW h,l;
#ifdef A64
		l = convert19to27c_64 (n_chars_in_first_part,s,&h);
#else
		U_LONG_LONG hl;

		hl = convert10to13c (n_chars_in_first_part,s);
		h=(UW)(hl>>N_bits_in_int);
		l=(UW)hl;
#endif
		a[i_a_f]=l;
		if (h==0)
			return i_a_f+1;
		else {
			a[i_a_f+1]=h;
			return i_a_f+2;
		}
	}
}

static int mul_5pd_add (int i,int i_a,UW a[])
{
	UW n;
	
	n=0;

	while (i!=i_a){
		UW ai;
#ifdef A64
		UW h,l;
#else
		U_LONG_LONG hl;
#endif	
		ai=a[i];
#ifdef A64
		umul_hl (h,l,ai,I5PD);
		l=l+n;
		h=h+(l<n);
		a[i]=l;
		n=h;
#else
		hl=((U_LONG_LONG)ai)*((U_LONG_LONG)I5PD);
		hl=hl+n;
		a[i]=(unsigned int)hl;
		n=(unsigned int)(hl>>32);
#endif
		++i;
	}

	if (n!=0){
		a[i]=n;
		return i+1;
	} else
		return i;
}

static int addi (UW n,int i_a_f,int i_a_e,UW a[])
{
	UW s;
	
	if (i_a_f==i_a_e){
		a[i_a_f]=n;
		return i_a_f+1;
	}
	s=a[i_a_f]+n;
	a[i_a_f]=s;
	if (s<n){ /* carry */
		int i;
		
		i=i_a_f+1;
		while (i<i_a_e){
			UW ai;

			ai=a[i]+1;
			a[i]=ai;
			if (ai!=0)
				return i_a_e;
			i=i+1;
		}
		a[i]=1;
		return i_a_e+1;
	}
	return i_a_e;
}

static int shift_left (int i,UW n,int shift,int i_a,UW a[])
{
	while (i<i_a){
		UW ai,new_n;
		
		ai=a[i];
		new_n = ai>>(N_bits_in_int-shift);
		ai = (ai<<shift)+n;
		a[i]=ai;
		i=i+1;
		n = new_n;
	}

	if (n==0)
		return i_a;
	else
		a[i_a]=n;
		return i_a+1;
}

static void stoi_next_parts (int i_s,char s[],int size_s,int i_a_f,int i_a_e,int shift,UW r,UW a[],int size_a)
{
	while (i_s<size_s){
#ifdef A64
		UW h,l,yh,yl;
#else
		U_LONG_LONG hl,yhl;
#endif

#ifdef A64
		l = convert27c_64 (i_s,s,&h);
		umul_hl (yh,yl,r,I5PD);
#else
		hl = convert13c_32 (i_s,s);
		yhl = ((U_LONG_LONG)r)*((U_LONG_LONG)I5PD);
#endif
		if (shift<IF_INT_64_OR_32 (37,19)){
			UW x,new_r,n;
#ifdef A64
			UW rh,rl;
			
			x = l & 0x7ffffff;
			l = (l>>N_digits_in_part)+(h<<37);

			rl = yl+l;
			rh = yh+(rl<yl);
			new_r = x | ((rl & ((((UW)1)<<shift)-1))<<N_digits_in_part);
			n = (rl>>shift)+(rh<<(N_bits_in_int-shift));
#else
			UW l;
			U_LONG_LONG rhl;

			x = (UW)hl & 0x1fff;
			l = (UW)(hl>>N_digits_in_part);
			rhl = yhl+l;
			new_r = x | ((((UW)rhl) & ((((UW)1)<<shift)-1))<<N_digits_in_part);
			n = (UW)(rhl>>shift);
#endif

			i_a_e = mul_5pd_add (i_a_f,i_a_e,a);
			i_a_e = addi (n,i_a_f,i_a_e,a);
			shift += N_digits_in_part;
			r = new_r;
		} else if (shift==IF_INT_64_OR_32 (37,19)){
#ifdef A64
			yh =(yh<<N_digits_in_part) + (yl>>IF_INT_64_OR_32 (37,19));
			yl = yl<<N_digits_in_part;
			l=l+yl;
			h=h+yh+(l<yl);
#else
			yhl = yhl<<N_digits_in_part;
			hl = yhl + hl;
#endif
			i_a_e = mul_5pd_add (i_a_f,i_a_e,a);
			i_a_e = addi (IF_INT_64_OR_32 (h,(UW)(hl>>32)),i_a_f,i_a_e,a);

			if (i_a_f<=0)
				printf ("error in stoi_next_parts\n");

			i_a_f = i_a_f-1;
			a[i_a_f]=IF_INT_64_OR_32 (l,(UW)hl);

			shift = 0;
			r = 0;
		} else {
			UW new_r;
			int n,ys;

			n = shift-IF_INT_64_OR_32 (37,19);
			new_r = (IF_INT_64_OR_32 (l,(UW)hl)) & ((((UW)1)<<n)-1);
#ifdef A64
			l =(l>>n) + (h<<(N_bits_in_int-n));
			h = h>>n;
#else
			hl = hl>>n;
#endif
			ys = N_digits_in_part-n;
#ifdef A64
			yh =(yh<<ys) + (yl>>(N_bits_in_int-ys));
			yl = yl<<ys;
			l=l+yl;
			h=h+yh+(l<yl);
#else
			yhl = yhl << ys;
			hl = yhl+hl;
#endif
			i_a_e = mul_5pd_add (i_a_f,i_a_e,a);
			i_a_e = addi (IF_INT_64_OR_32 (h,(UW)(hl>>32)),i_a_f,i_a_e,a);

			if (i_a_f<=0)
				printf ("error in stoi_next_parts\n");
			i_a_f = i_a_f-1;
			a[i_a_f]=IF_INT_64_OR_32 (l,(UW)hl);

			shift = n;
			r = new_r;
		}
		i_s += N_digits_in_part;
	}

	if (i_s==size_s && i_a_f==0 && i_a_e<=size_a){
		if (shift!=0)
			i_a_e=shift_left (0,r,shift,i_a_e,a);
		return;
	} else
		printf ("error in stoi_next_parts\n");
}

static struct integer octal_string_to_integer (W sign,char *s,int size_s)
{
	int n_bits,n_zero_bits_in_msd;
	
	while (size_s>0 && s[0]=='0'){
		--size_s;
		++s;
	}

	if (size_s>0){
		int n;

		n=s[size_s-1] & 7;
		if (n<3)
			n_zero_bits_in_msd=3-n;
		else if (n==3)
			n_zero_bits_in_msd=1;
		else
			n_zero_bits_in_msd=0;

		n_bits = 3*size_s-n_zero_bits_in_msd;
	} else {
		n_bits=0;
		n_zero_bits_in_msd=0; /* not used */
	}

	if (n_bits<=IF_INT_64_OR_32(64,32)){
		struct integer i;
		UW l;
		
		l=0;
		while (size_s>0){
			char c;
			
			c=*s++;
			l<<=(UW)3;
			l+=(UW) (c & 7);
			--size_s;
		}

		if ((UW)l < (UW)(((UW)1<<(UW)Max_bit_n_in_int)-sign)){
			i.s=(l ^ sign)-sign;
			i.a=NULL;
		
			return i;
		} else {
			UW *a;

			a=calloc (2,sizeof (UW));
			if (a==NULL)
				error ("Out of memory\n");

			a[0]=1;
			a[1]=l;
			
			i.s=sign;
			i.a=a+1;

			return i;
		}		
	} else {
		int size_a,i,j,n_auw_bits;
		struct integer si;
		UW *a,auw;

		size_a = IF_INT_64_OR_32 ((n_bits+63)>>6,(n_bits+31)>>5);

		a = calloc (size_a+1,sizeof(UW));
		if (a==NULL)
			printf ("Out of memory\n");
		++a;

		auw=0;
		n_auw_bits=0;
		
		j=size_s;
		i=0;
		
		while (j>IF_INT_64_OR_32(21,10)){
			UW uw;
			int n_uw_bits;
			
			uw=0;
			n_uw_bits=0;
			do {
				--j;
				uw |= ((UW)(s[j] & 7)) << ((UW)n_uw_bits);
				
				n_uw_bits+=3;
			} while (n_uw_bits<IF_INT_64_OR_32(63,30));

			auw |= uw << (UW)n_auw_bits;
			n_auw_bits+=n_uw_bits;
			if (n_auw_bits>=IF_INT_64_OR_32(64,32)){
				a[i]=auw;
				++i;
				n_auw_bits-=IF_INT_64_OR_32(64,32);
				auw=uw >> (UW)(n_uw_bits-n_auw_bits);
			}
		}
		
		{
			UW uw,m;
			int n_uw_bits;
			
			uw=0;
			n_uw_bits=0;
			while (j>0){
				--j;
				uw |= ((UW)(s[j] & 7)) << ((UW)n_uw_bits);
				
				n_uw_bits+=3;
			};

			n_uw_bits-=n_zero_bits_in_msd;

			auw |= uw << (UW)n_auw_bits;
			n_auw_bits+=n_uw_bits;
			if (n_auw_bits>=IF_INT_64_OR_32(64,32)){
				a[i]=auw;
				++i;
				n_auw_bits-=IF_INT_64_OR_32(64,32);
				auw=uw >> (UW)(n_uw_bits-n_auw_bits);
			}
			
			if (n_auw_bits>0)
				a[i]=auw;
				++i;
		}

		si.a=a;
		si.s=sign;
		a[-1]=size_a;
			
		return si;
	}
}

static struct integer hex_string_to_integer (W sign,char *s,int size_s)
{
	while (size_s>0 && s[0]=='0'){
		--size_s;
		++s;
	}

	if (size_s<=IF_INT_64_OR_32(16,8)){
		struct integer i;
		UW l;
		
		l=0;
		while (size_s>0){
			char c;
			
			c=*s++;
			l<<=(UW)4;
			l+=(UW) (c<='9' ? c-'0' : (c | 0x20)-('a'-10));
			--size_s;
		}

		if ((UW)l < (UW)(((UW)1<<(UW)Max_bit_n_in_int)-sign)){
			i.s=(l ^ sign)-sign;
			i.a=NULL;
		
			return i;
		} else {
			UW *a;

			a=calloc (2,sizeof (UW));
			if (a==NULL)
				error ("Out of memory\n");

			a[0]=1;
			a[1]=l;
			
			i.s=sign;
			i.a=a+1;

			return i;
		}
	} else {
		int size_a,i,j;
		UW *a,uw;
		struct integer si;

		size_a = IF_INT_64_OR_32 ((size_s+15)>>4,(size_s+7)>>3);

		a = calloc (size_a+1,sizeof(UW));
		if (a==NULL)
			printf ("Out of memory\n");
		++a;

		i=size_a-1;

		uw=0;

		j=size_s & IF_INT_64_OR_32(15,7);
		if (j==0)
			j=IF_INT_64_OR_32(16,8);

		do {
			char c;
			
			c=*s++;
			uw<<=(UW)4;
			uw+=(UW) (c<='9' ? c-'0' : (c | 0x20)-('a'-10));
		} while (--j!=0);

		a[i]=uw;
		--i;

		while (i>=0){
			uw=0;
			
			for (j=IF_INT_64_OR_32(16,8); j!=0; --j){
				char c;
				
				c=*s++;
				uw<<=(UW)4;
				uw+=(UW) (c<='9' ? c-'0' : (c | 0x20)-('a'-10));				
			}
			
			a[i]=uw;
			--i;
		}

		si.a=a;
		si.s=sign;
		a[-1]=size_a;
			
		return si;
	}
}

static struct integer string_to_integer (W sign,char *s,int size_s)
{
	if (s[0]=='-'){
		sign=-1;
		--size_s;
		++s;
	}

	if (size_s>2 && s[0]=='0'){
		if ((s[1] | 0x20)=='x')
			return hex_string_to_integer (sign,s+2,size_s-2);
		else if ((s[1] | 0x20)=='o')
			return octal_string_to_integer (sign,s+2,size_s-2);
	}

	if (size_s<=N_digits_in_part){
		if (size_s<IF_INT_64_OR_32 (19,10)){
			struct integer i;

			i.s=(convertchars (0,size_s,s) ^ sign)-sign;
			i.a=NULL;
			
			return i;
		} else {
			UW h,l;

#ifdef A64
			l = convert19to27c_64 (size_s,s,&h);
#else
			U_LONG_LONG hl;

			hl = convert10to13c (size_s,s);
			h=(UW)(hl>>N_bits_in_int);
			l=(UW)hl;
#endif

			if (h==0){
				struct integer i;

				if ((UW)l < (UW)(((UW)1<<(UW)Max_bit_n_in_int)-sign)){
					i.s=(l ^ sign)-sign;
					i.a=NULL;
				
					return i;
				} else {
					UW *a;

					a=calloc (2,sizeof (UW));
					if (a==NULL)
						error ("Out of memory\n");

					a[0]=1;
					a[1]=l;
					
					i.s=sign;
					i.a=a+1;

					return i;
				}
			} else {
				struct integer i;
				UW *a;

				a=calloc (3,sizeof (UW));
				if (a==NULL)
					error ("Out of memory\n");
				
				a[0]=2;
				a[1]=l;
				a[2]=h;
				
				i.s=sign;
				i.a=a+1;

				return i;
			}
		}
	} else {
		int n_chars,n_parts,n_chars_in_parts,n_chars_in_first_part,n_shifts,size_a,i_a_f,i_a_e,i;
		UW *a;

		n_chars = size_s;
		n_parts = n_chars/N_digits_in_part;
		n_chars_in_parts = n_parts * N_digits_in_part;
		n_chars_in_first_part = n_chars-n_chars_in_parts;
		n_shifts = n_chars_in_parts>>IF_INT_64_OR_32(6,5);
		size_a = n_parts + 3 + n_shifts;

		a = calloc (size_a+1,sizeof(UW));
		if (a==NULL)
			printf ("Out of memory\n");
		++a;

		i_a_f = n_shifts;
		i_a_e = convert_first_chars (n_chars_in_first_part,s,i_a_f,a);

		stoi_next_parts (n_chars_in_first_part,s,size_s,i_a_f,i_a_e,0,0,a,size_a);

		i=size_a-1;
		while (i!=0 && a[i]==0)
			--i;

		if (i==0 && (UW)a[0] < (UW)(((UW)1<<(UW)Max_bit_n_in_int)-sign)){
			struct integer si;

			si.a=NULL;
			si.s=(a[0] ^ sign)-sign;
			
			free (a-1);
			
			return si;
		} else if (i+1==size_a){
			struct integer si;

			si.a=a;
			si.s=sign;
			a[-1]=i+1;
			
			return si;
		} else {
			struct integer si;

			a=1+(UW*)realloc (a-1,sizeof (UW)*(i+1+1));
			if (a==0)
				printf ("realloc failed\n");			

			a[-1]=i+1;

			si.a=a;
			si.s=sign;

			return si;
		}
	}
}

#define g_cmp_eq(g1,g2) g_instruction_2(GCMP_EQ,(g1),(g2))

void code_jmp_not_eqZ (char *integer_string,int integer_string_length,char label_name[])
{
	struct integer integer;
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;

	integer=string_to_integer (0,integer_string,integer_string_length);

	if (integer.a==NULL){
		graph_1=s_get_b (0);
		graph_2=g_load_i (integer.s);
		graph_3=g_cmp_eq (graph_2,graph_1);
		s_push_b (graph_3);
		code_jmp_false (label_name);

		graph_1=s_get_a (0);
		graph_2=g_load_id (STACK_ELEMENT_SIZE,graph_1);
		graph_3=g_load_i (0);
		graph_4=g_cmp_eq (graph_3,graph_2);
		s_push_b (graph_4);
		code_jmp_false (label_name);
	} else {
		int i,integer_size;

		integer_size=integer.a[-1];
		
		graph_1=s_get_a (0);
		graph_2=g_load_id (STACK_ELEMENT_SIZE,graph_1);
		graph_3=g_load_i (integer_size);
		graph_4=g_cmp_eq (graph_3,graph_2);
		s_push_b (graph_4);
		code_jmp_false (label_name);	

		for (i=0; i<integer_size; ++i){
			graph_1=s_get_a (0);
			graph_2=g_load_id ((i+2)<<STACK_ELEMENT_LOG_SIZE,graph_1);
			graph_3=g_load_i (integer.a[i]);
			graph_4=g_cmp_eq (graph_3,graph_2);
			s_push_b (graph_4);
			code_jmp_false (label_name);	
		}

		graph_1=s_get_b (0);
		graph_2=g_load_i (integer.s);
		graph_3=g_cmp_eq (graph_2,graph_1);
		s_push_b (graph_3);
		code_jmp_false (label_name);		
	}
}

void code_pushZ (char *integer_string,int integer_string_length)
{
	struct integer integer;
	INSTRUCTION_GRAPH graph_1,graph_2;

	integer=string_to_integer (0,integer_string,integer_string_length);
	
	graph_1=g_load_i (integer.s);
	if (integer.a==NULL)
		graph_2=g_create_unboxed_int_array (0);
	else {
		int i,n_elements;

		n_elements=integer.a[-1];
		graph_2=g_create_unboxed_int_array (n_elements);
		for (i=0; i<n_elements; ++i)
			graph_2->instruction_parameters[3+i].p=g_load_i (integer.a[i]);
	}

	s_push_b (graph_1);
	s_push_a (graph_2);
}

static struct integer shift_right (struct integer n,unsigned int n_bits)
{
	UW *a;
	
	a=n.a;
	if (a==NULL)
		n.s = n.s>>n_bits;
	else {
		UW previous_e;
		int i,n_n_elements;

		n_n_elements=a[-1];

		previous_e=0;
		for (i=n_n_elements-1; i>=0; --i){
			UW e;

			e = a[i];
			a[i] = (e>>n_bits) + (previous_e<<(N_bits_in_int-n_bits));
			previous_e = e;
		}

		if (a[n_n_elements-1]==0){
			--n_n_elements;
			a[-1]=n_n_elements;
		}
		
		if (n_n_elements==1 && (W)a[0]>=0){
			n.s=a[0];
			n.a=NULL;
		}
	}

	return n;
}

static int divisible_by_5 (struct integer n)
{
	UW s;
	
	if (n.a==NULL)
		s=n.s;
	else {
		UW *a;
		int i,n_elements;
		
		a=n.a;
		n_elements=a[-1];

		s=0;
		for (i=0; ; ){
			int end_i;
			
			end_i=i+10000;
			if (end_i>n_elements)
				end_i=n_elements;
			
			while (i<end_i){
				UW e;
				
				e=a[i];
				s+=IF_INT_64_OR_32 ((e & 0xffffffffu)+(e>>32u),(e & 0xffffu)+(e>>16u));
				++i;
			}

			if (i>=n_elements)
				break;

			s = s % 5;
		}
	}
	
	return s % 5==0;
}

static struct integer exact_div_5 (struct integer n)
{
	if (n.a==NULL)
		n.s=n.s / 5;
	else {
		int i,n_elements;
		UW borrow,*a;
		
		a=n.a;
		n_elements=a[-1];
	
		borrow=0;
		for (i=0; i<n_elements; ++i){
			UW ai,e,ed5,h;
			
			ai=a[i];

			e=ai-borrow;
			borrow = e>ai;

			ed5=e * IF_INT_64_OR_32 (0xcccccccccccccccd,0xcccccccd);

			h = (ed5 + (ed5<<2u)) < ed5;
			borrow += h;
			borrow += ed5>>IF_INT_64_OR_32 (62u,30u);

			a[i]=ed5;
		}

		if (a[n_elements-1]==0){
			--n_elements;
			a[-1]=n_elements;
		}
		
		if (n_elements==1 && (W)a[0]>=0){
			n.s=a[0];
			n.a=NULL;
		}		
	}
	
	return n;
}

void code_pushZR (int sign,char *integer_string,int integer_string_length,int exponent)
{
	struct integer numerator,denominator;
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	char *numerator_string;
	int denominator_string_length;

	while (integer_string[0]=='0' && integer_string_length>1){
		++integer_string;
		--integer_string_length;
	}

	while (exponent<0 && integer_string_length>1 && integer_string[integer_string_length-1]=='0'){
		--integer_string_length;
		++exponent;
	}

	if (integer_string_length==1 && integer_string[0]=='0')
		exponent=0;	
	
	if (exponent>0){
		int i,new_string_length;

		new_string_length=integer_string_length+exponent;
		numerator_string=memory_allocate (new_string_length+1);
		
		for (i=0; i<integer_string_length; ++i)
			numerator_string[i]=integer_string[i];
		for ( ; i<new_string_length; ++i)
			numerator_string[i]='0';
		numerator_string[i]='\0';
		
		integer_string=numerator_string;
		integer_string_length=new_string_length;
	} else
		numerator_string=NULL;

	numerator=string_to_integer (sign,integer_string,integer_string_length);

	if (numerator_string!=NULL){
		memory_free (numerator_string);
		numerator_string=NULL;
	}

	if (exponent<0){
		char *denominator_string;
		int i,exponent2,exponent5;

		denominator_string_length=1-exponent;
		denominator_string=memory_allocate (denominator_string_length+1);

		denominator_string[0]='1';
		for (i=1; i<denominator_string_length; ++i)
			denominator_string[i]='0';
		denominator_string[i]='\0';

		denominator=string_to_integer (0,denominator_string,denominator_string_length);

		memory_free (denominator_string);

		exponent2=-exponent;
		exponent5=exponent2;

		if (exponent2>=N_bits_in_int && numerator.a!=NULL){
			int n_n_elements,n_d_elements;
			UW *n_a,*d_a;

			n_a=numerator.a;
			n_n_elements=n_a[-1];

			d_a=denominator.a;
			n_d_elements=d_a[-1];

			while (exponent2>=N_bits_in_int && n_a[0]==0){
				--n_n_elements;
				++n_a;

				--n_d_elements;
				++d_a;
				
				exponent2-=N_bits_in_int;
			}

			if (n_n_elements==1 && (W)n_a[0]>=0){
				numerator.s=n_a[0];
				numerator.a=NULL;
			} else {
				numerator.a=n_a;
				n_a[-1]=n_n_elements;
			}

			/* >= 32 bits, because >= 5^32 */
			denominator.a=d_a;
			d_a[-1]=n_d_elements;
		}

		if (exponent2>0){
			UW n0;

			if (numerator.a==NULL)
				n0=numerator.s;
			else
				n0=numerator.a[0];

			if ((n0 & 1)==0){
				unsigned int n_0_bits,max_bits;

				n0=n0>>1;
				n_0_bits=1;
				while (n_0_bits<exponent2 && (n0 & 1)==0){
					n0=n0>>1;
					++n_0_bits;
				}
				
				exponent2-=n_0_bits;

				numerator = shift_right (numerator,n_0_bits);
				denominator = shift_right (denominator,n_0_bits);
			}
		}
		
		while (exponent5>0 && divisible_by_5 (numerator)){
			numerator = exact_div_5 (numerator);
			denominator = exact_div_5 (denominator);
			--exponent5;
		}
	} else {
		denominator.s=1;
		denominator.a=NULL;
	}

	graph_1=g_load_i (numerator.s);
	if (numerator.a==NULL)
		graph_2=g_create_unboxed_int_array (0);
	else {
		int i,n_elements;

		n_elements=numerator.a[-1];
		graph_2=g_create_unboxed_int_array (n_elements);
		for (i=0; i<n_elements; ++i)
			graph_2->instruction_parameters[3+i].p=g_load_i (numerator.a[i]);
	}

	graph_3=g_load_i (denominator.s);
	if (denominator.a==NULL)
		graph_4=g_create_unboxed_int_array (0);
	else {
		int i,n_elements;

		n_elements=denominator.a[-1];
		graph_4=g_create_unboxed_int_array (n_elements);
		for (i=0; i<n_elements; ++i)
			graph_4->instruction_parameters[3+i].p=g_load_i (denominator.a[i]);
	}

	s_push_b (graph_3);
	s_push_a (graph_4);
	s_push_b (graph_1);
	s_push_a (graph_2);
}

extern int profile_flag;
extern LABEL *profile_function_label;

void code_pd (void)
{
	profile_flag=PROFILE_DOUBLE;
}

void code_pe (void)
{
	profile_function_label=NULL;
}

void code_pl (void)
{
	profile_flag=PROFILE_CURRIED;
}

void code_pld (void)
{
	profile_flag=PROFILE_CURRIED_DOUBLE;
}

void code_pn (void)
{
	profile_flag=PROFILE_NOT;
}

void code_pt (void)
{
	profile_flag=PROFILE_TAIL;
}

static int in_out_stack_offset=0;

#ifdef G_POWER
#	define REGISTER_R3 (-21)
#endif

void code_in (char parameters[])
{
	/* [Rn] [On]+ [W|L|S|SDn|C([Dn|Sn]+)|An|Dn] */

#if defined (M68000) || defined (G_POWER)
	register char *p;
	register int first_parameter_offset;
	int n_data_parameter_registers;

	if (parallel_flag && system_sp_label==NULL)
		system_sp_label=enter_label ("system_sp",IMPORT_LABEL);

	end_basic_block_with_registers (offered_a_stack_size,offered_b_stack_size,offered_vector);	

	begin_new_basic_block();

	if (parallel_flag){
		n_data_parameter_registers=N_DATA_PARAMETER_REGISTERS-1;
		i_move_r_r (B_STACK_POINTER,REGISTER_A3);
		i_move_l_r (system_sp_label,B_STACK_POINTER);
	} else
		n_data_parameter_registers=N_DATA_PARAMETER_REGISTERS;

	if (offered_b_stack_size<=n_data_parameter_registers)
		in_out_stack_offset=0;
	else
		in_out_stack_offset=(offered_b_stack_size-n_data_parameter_registers)<<2;
	/* in_out_stack_offset only correct when there are no reals ! */

	first_parameter_offset=0;
	
	p=parameters;
	while (*p!=0){
		register int offset,stack;
		
		stack=*p++ & ~0x20;
		offset=*p++;

		if (*p=='R'){
			int n;
			
			++p;
			n=(unsigned char)*p++;
			n=(n<<8)+(unsigned char)*p++;
			
			if (n!=0){
				i_sub_i_r (n,B_STACK_POINTER);
				first_parameter_offset+=n;
			}
		}

		while (*p=='O'){
			int n;
#ifdef G_POWER
			int d_register;
#endif
			++p;
			n=*p++;
			n=(n<<8)+*p++;
#ifdef G_POWER
			d_register=*p++;
			i_lea_id_r (n,B_STACK_POINTER,REGISTER_R3+d_register);
#else
			if (n!=0){
				i_word_i (0x486F);
				i_word_i (n);
			} else
				i_word_i (0x2F0F);

			first_parameter_offset+=4;
#endif			
		}

		switch (*p){
			case 'W':
			{
				register int n_registers;
				
				if (stack=='A'){
					n_registers=offered_a_stack_size;
					if (n_registers>N_ADDRESS_PARAMETER_REGISTERS)
						n_registers=N_ADDRESS_PARAMETER_REGISTERS;
#ifdef G_POWER
					if (offset<n_registers)
						i_movew_r_idu (num_to_a_reg (n_registers-offset-1),-2,B_STACK_POINTER);
					else
						i_movew_id_idu ((offset-n_registers)<<2,A_STACK_POINTER,-2,B_STACK_POINTER);
#else					
					if (offset<n_registers)
						i_movew_r_pd (num_to_a_reg (n_registers-offset-1),REGISTER_A7);
					else
						i_movew_id_pd ((offset-n_registers)<<2,A_STACK_POINTER,REGISTER_A7);
#endif
				} else {
					n_registers=offered_b_stack_size;
					if (n_registers>n_data_parameter_registers)
						n_registers=n_data_parameter_registers;					
#ifdef G_POWER
					if (offset<n_registers)
						i_movew_r_idu (num_to_d_reg (n_registers-offset-1),-2,B_STACK_POINTER);
					else
						i_movew_id_idu
							(first_parameter_offset+((offset-n_registers)<<2)+2,B_STACK_POINTER,-2,B_STACK_POINTER);
#else
					if (offset<n_registers)
						i_movew_r_pd (num_to_d_reg (n_registers-offset-1),REGISTER_A7);
					else
						if (!parallel_flag)
							i_movew_id_pd
								(first_parameter_offset+((offset-n_registers)<<2)+2,B_STACK_POINTER,REGISTER_A7);
						else
							i_movew_id_pd (((offset-n_registers)<<2)+2,REGISTER_A3,REGISTER_A7);
#endif
				}
				++p;
				first_parameter_offset+=2;
				break;
			}
			case 'L':
			{
				register int n_registers;
				
				if (stack=='A'){
					n_registers=offered_a_stack_size;
					if (n_registers>N_ADDRESS_PARAMETER_REGISTERS)
						n_registers=N_ADDRESS_PARAMETER_REGISTERS;
#ifdef G_POWER
					if (offset<n_registers)
						i_move_r_idu (num_to_a_reg (n_registers-offset-1),-4,B_STACK_POINTER);
					else
						i_move_id_idu ((offset-n_registers)<<2,A_STACK_POINTER,-4,B_STACK_POINTER);
#else
					if (offset<n_registers)
						i_move_r_pd (num_to_a_reg (n_registers-offset-1),REGISTER_A7);
					else
						i_move_id_pd ((offset-n_registers)<<2,A_STACK_POINTER,REGISTER_A7);
#endif
				} else {
					n_registers=offered_b_stack_size;
					if (n_registers>n_data_parameter_registers)
						n_registers=n_data_parameter_registers;					
#ifdef G_POWER
					if (offset<n_registers)
						i_move_r_idu (num_to_d_reg (n_registers-offset-1),-4,B_STACK_POINTER);
					else
						i_move_id_idu
							(first_parameter_offset+((offset-n_registers)<<2),B_STACK_POINTER,-4,B_STACK_POINTER);
#else
					if (offset<n_registers)
						i_move_r_pd (num_to_d_reg (n_registers-offset-1),REGISTER_A7);
					else
						if (!parallel_flag)
							i_move_id_pd
								(first_parameter_offset+((offset-n_registers)<<2),B_STACK_POINTER,REGISTER_A7);
						else
							i_move_id_pd (((offset-n_registers)<<2),REGISTER_A3,REGISTER_A7);
#endif
				}
				++p;
				first_parameter_offset+=4;
				break;
			}
			case 'S':
				if (stack=='A'){
					int n_registers;
					
					n_registers=offered_a_stack_size;
					if (n_registers>N_ADDRESS_PARAMETER_REGISTERS)
						n_registers=N_ADDRESS_PARAMETER_REGISTERS;
					
					if (offset<n_registers){
						int areg;
						
						areg=num_to_a_reg (n_registers-offset-1);
						++p;
#ifdef G_POWER
						i_lea_id_r (7,areg,REGISTER_R3+ *p++);
#else						
						i_word_i (0x4868+n_registers-offset-1);
						i_word_i (7);

						first_parameter_offset+=4;
#endif
						break;
					}
				}
				error ("Error in string parameter for in instruction");
				break;
			case 'C':
				if (stack=='A'){
					int n_registers;
					
					n_registers=offered_a_stack_size;
					if (n_registers>N_ADDRESS_PARAMETER_REGISTERS)
						n_registers=N_ADDRESS_PARAMETER_REGISTERS;
					
					if (offset<n_registers){
						int areg;
						
						areg=num_to_a_reg (n_registers-offset-1);
						++p;
						while (*p=='D' || *p=='S'){
							if (*p=='D'){
								++p;
#ifdef G_POWER
								i_lea_id_r (8,areg,REGISTER_R3+ *p++);
#else						
								i_word_i (0x4868+n_registers-offset-1);
								i_word_i (8);
								first_parameter_offset+=4;
#endif
							} else {
								++p;
#ifdef G_POWER
								i_move_id_r (4,areg,REGISTER_R3+ *p++);
#else
								i_move_id_pd (4,areg,REGISTER_A7);
								first_parameter_offset+=4;
#endif							
							}
						}
						break;
					}
				}
				error ("Error in characters parameter for in instruction");
				break;
			case 'A':
			{
				int n_registers;
#ifdef M68000			
				n_registers=offered_a_stack_size;
				if (n_registers>N_ADDRESS_PARAMETER_REGISTERS)
					n_registers=N_ADDRESS_PARAMETER_REGISTERS;

				if (stack!='A' || n_registers-offset-1!=p[1])
					error ("Wrong address register for in instruction");
#else /* for G_POWER */
				n_registers=offered_b_stack_size;
				if (n_registers>n_data_parameter_registers)
					n_registers=n_data_parameter_registers;

				if (stack!='B' || p[1]>N_ADDRESS_PARAMETER_REGISTERS)
					error ("Wrong address register for in instruction");

				if (offset<n_registers)
					i_move_r_r (REGISTER_D0+(n_registers-offset-1),REGISTER_A0-p[1]);
				else					
					i_move_id_r
						(first_parameter_offset+((offset-n_registers)<<2),B_STACK_POINTER,REGISTER_A0-p[1]);
#endif

				p+=2;
				break;
			}
			case 'D':
			{
				int n_registers;
				
				n_registers=offered_b_stack_size;
				if (n_registers>n_data_parameter_registers)
					n_registers=n_data_parameter_registers;
#ifdef M68000			
				if (stack!='B' || n_registers-offset-1!=p[1])
					error ("Wrong data register for in instruction");
#else /* for G_POWER */
				if (stack!='B' || p[1]>8)
					error ("Wrong data register for in instruction");

				if (offset<n_registers)
					i_move_r_r (REGISTER_D0+(n_registers-offset-1),REGISTER_R3+p[1]);
				else
					i_move_id_r
						(first_parameter_offset+((offset-n_registers)<<2),B_STACK_POINTER,REGISTER_R3+p[1]);
#endif
				p+=2;
				break;
			}
			case 'U':
				++p;
				break;
			default:
				error ("Error in parameters for in instruction");
		}
	}
#else
	error ("ABC instruction 'in' not implemented");
#endif
}

static void out_parameter_error (void)
{
	error_i ("Error in parameters for out instruction at line %d",line_number);
}

void code_out (char parameters[])
{
	/* [Rn] [In] [W|L|Z|An|Dn] */
#if defined (M68000) || defined (G_POWER)
	register char *p;
	int deschedule_count;
	
	deschedule_count=-1;

	p=parameters;
	while (*p!=0){
		int offset,stack;
		
		stack=*p++;
		offset=*p++;

		if (*p=='R' && deschedule_count<0){
			int n;
			
			++p;
			n=(unsigned char)*p++;
			n=(n<<8)+(unsigned char)*p++;
			
			deschedule_count=n;
		}

		if (*p=='I'){
			int n;
			
			++p;
			n=(unsigned char)*p++;
			n=(n<<8)+(unsigned char)*p++;
				
			i_add_i_r (n,B_STACK_POINTER);
		}
		
		switch (*p){
			case 'W':
			{
				int n_registers;
				
				if (stack=='A'){
					n_registers=offered_a_stack_size;
					if (n_registers>N_ADDRESS_PARAMETER_REGISTERS)
						n_registers=N_ADDRESS_PARAMETER_REGISTERS;
					
					if (offset<n_registers){
#ifdef G_POWER
						i_movew_id_r (0,B_STACK_POINTER,num_to_a_reg (n_registers-offset-1));
						i_add_i_r (2,B_STACK_POINTER);
#else
						i_movew_pi_r (REGISTER_A7,num_to_a_reg (n_registers-offset-1));
#endif
					} else
						out_parameter_error();
						/* i_movew_pi_id (REGISTER_A7,2+((offset-n_registers)<<2),A_STACK_POINTER); */
				} else {
					n_registers=offered_b_stack_size;
					if (n_registers>N_DATA_PARAMETER_REGISTERS)
						n_registers=N_DATA_PARAMETER_REGISTERS;
					
					if (offset<n_registers){
						int d_register;

						d_register=num_to_d_reg (n_registers-offset-1);
#ifdef G_POWER
						i_movew_id_r (0,B_STACK_POINTER,d_register);
						i_add_i_r (2,B_STACK_POINTER);
#else
						i_movew_pi_r (REGISTER_A7,d_register);
						i_ext_r (d_register);
#endif
					} else
						out_parameter_error();
						/* i_movew_pi_id (REGISTER_A7,2-((1+offset-n_registers)<<2),B_STACK_POINTER); */
				}
				++p;
				break;
			}
			case 'L':
			{
				int n_registers;
				
				if (stack=='A'){
					n_registers=offered_a_stack_size;
					if (n_registers>N_ADDRESS_PARAMETER_REGISTERS)
						n_registers=N_ADDRESS_PARAMETER_REGISTERS;
					
					if (offset<n_registers){
#ifdef G_POWER
						i_move_id_r (0,B_STACK_POINTER,num_to_a_reg (n_registers-offset-1));
						i_add_i_r (4,B_STACK_POINTER);
#else
						i_move_pi_r (REGISTER_A7,num_to_a_reg (n_registers-offset-1));
#endif
					} else
						out_parameter_error();
						/* i_move_pi_id (REGISTER_A7,(offset-n_registers)<<2,A_STACK_POINTER); */
				} else {
					n_registers=offered_b_stack_size;
					if (n_registers>N_DATA_PARAMETER_REGISTERS)
						n_registers=N_DATA_PARAMETER_REGISTERS;
					
					if (offset<n_registers){
						int d_register;
					
						d_register=num_to_d_reg (n_registers-offset-1);
#ifdef G_POWER
						i_move_id_r (0,B_STACK_POINTER,d_register);
						i_add_i_r (4,B_STACK_POINTER);
#else
						i_move_pi_r (REGISTER_A7,d_register);
#endif
					} else
						out_parameter_error();
						/* i_move_pi_id (REGISTER_A7,-(1+offset-n_registers)<<2,B_STACK_POINTER); */
				}
				++p;
				break;
			}
			case 'D':
#ifdef G_POWER
			{
				int d_register,n_registers;
			
				++p;
				d_register=*p++;

				n_registers=offered_b_stack_size;
				if (n_registers>N_DATA_PARAMETER_REGISTERS)
					n_registers=N_DATA_PARAMETER_REGISTERS;

				if (d_register>8 || offset>=n_registers)
					out_parameter_error();
					
				i_move_r_r (REGISTER_R3+d_register,num_to_d_reg (n_registers-offset-1));
			}
#else
				p+=2;
#endif
				break;
			case 'A':
				p+=2;
				break;
			case 'Z':
			{
				int n_registers;
				
				if (stack=='A'){
					n_registers=offered_a_stack_size;
					if (n_registers>N_ADDRESS_PARAMETER_REGISTERS)
						n_registers=N_ADDRESS_PARAMETER_REGISTERS;
					
					if (offset<n_registers)
						i_move_i_r (0,num_to_a_reg (n_registers-offset-1));
					else
						out_parameter_error();
				} else {
					n_registers=offered_b_stack_size;
					if (n_registers>N_DATA_PARAMETER_REGISTERS)
						n_registers=N_DATA_PARAMETER_REGISTERS;
					
					if (offset<n_registers)
						i_move_i_r (0,num_to_d_reg (n_registers-offset-1));
					else
						out_parameter_error();
				}
				++p;
				break;
			}
			case 'B':
			{
				int n_registers,result_d_register;
#ifdef G_POWER
				int d_register;
#endif
				++p;

				n_registers=offered_b_stack_size;
				if (n_registers>N_DATA_PARAMETER_REGISTERS)
					n_registers=N_DATA_PARAMETER_REGISTERS;
#ifdef G_POWER
				d_register=*p++;

				if (d_register>8 || offset>=n_registers)
					out_parameter_error();
				
				result_d_register=num_to_d_reg (n_registers-offset-1);
				i_move_r_r (REGISTER_R3+d_register,result_d_register);
				i_and_i_r (1,result_d_register);
				/* neg rn,rn: */
				i_word_i (0x7C0000D0|((24+result_d_register)<<21)|((24+result_d_register)<<16));
				break;
#else
				if (offset<n_registers){
					result_d_register=num_to_d_reg (n_registers-offset-1);
					i_move_i_r (1,result_d_register);
					i_word_i (0xC01F | (result_d_register<<9));	/* and.b (sp)+,dn */
					i_word_i (0x4480 | result_d_register);		/* neg.l dn */
				} else
					out_parameter_error();
				break;
#endif
			}
			default:
				out_parameter_error();
		}
	}
	
	if (parallel_flag){
		if (in_out_stack_offset!=0)
			i_add_i_r (in_out_stack_offset,REGISTER_A3);
		i_move_r_r (REGISTER_A3,B_STACK_POINTER);

		if (deschedule_count>0){
			i_sub_i_r (deschedule_count,REGISTER_D6);
			i_word_i (0x6404);
			i_schedule_i (offered_a_stack_size<<4);
		}
	} else
		if (in_out_stack_offset!=0)
			i_add_i_r (in_out_stack_offset,B_STACK_POINTER);

	if (last_block->block_instructions!=NULL)
		begin_new_basic_block();
	else {
		release_a_stack();
		release_b_stack();
	}
	
	init_a_stack (offered_a_stack_size);	
	init_b_stack (offered_b_stack_size,offered_vector);
#else
	error ("ABC instruction 'out' not implemented");
#endif
}

#ifdef ALIGN_C_CALLS
# define REGISTER_O0 (-13)
#endif

#if defined (M68000) || defined (G_POWER)
void code_call (char *s1,int length,char *s2)
{
	LABEL *label;

# if defined (G_POWER) && defined (MACH_O)
	if (s2[0]=='.'){
		char label_name [202];

		label_name[0]='_';
		strcpy (&label_name[1],s2+1);
		
		label=enter_label (label_name,0);
		
		if (dyld_stub_binding_helper_p_label==NULL)
			dyld_stub_binding_helper_p_label=enter_label ("dyld_stub_binding_helper",IMPORT_LABEL);
	} else
#endif
	label=enter_label (s2,0);

#ifdef M68000
	i_jsr_l (label,0);
#else
	if (length>0 && s1[0]=='G'){
		if (saved_heap_p_label==NULL)
			saved_heap_p_label=enter_label ("saved_heap_p",IMPORT_LABEL);
		if (saved_a_stack_p_label==NULL)
			saved_a_stack_p_label=enter_label ("saved_a_stack_p",IMPORT_LABEL);

		i_lea_l_i_r (saved_a_stack_p_label,0,REGISTER_A3);
		i_move_r_id (A_STACK_POINTER,0,REGISTER_A3);
		i_lea_l_i_r (saved_heap_p_label,0,REGISTER_A3);
		i_move_r_id (HEAP_POINTER,0,REGISTER_A3);
		i_move_r_id (REGISTER_D7,4,REGISTER_A3);

# ifdef ALIGN_C_CALLS
		i_move_r_r (B_STACK_POINTER,REGISTER_O0);
		i_or_i_r (28,B_STACK_POINTER);
# endif
		i_call_l (label,64);

		i_lea_l_i_r (saved_a_stack_p_label,0,REGISTER_A3);
		i_move_id_r (0,REGISTER_A3,A_STACK_POINTER);
		i_lea_l_i_r (saved_heap_p_label,0,REGISTER_A3);
		i_move_id_r (0,REGISTER_A3,HEAP_POINTER);
		i_move_id_r (4,REGISTER_A3,REGISTER_D7);
	} else {
# ifdef ALIGN_C_CALLS
		i_move_r_r (B_STACK_POINTER,REGISTER_O0);
		i_or_i_r (28,B_STACK_POINTER);
# endif
		i_call_l (label,64);
	}
#endif
}
#endif

static char ccall_error_string[] = "Error in ccall of '%s'";

#if defined (sparc) || defined (G_POWER)
#	ifdef sparc
#		define N_C_PARAMETER_REGISTERS 6
#		define C_PARAMETER_REGISTER_0 8
#		define FIRST_C_STACK_PARAMETER_WORD_OFFSET 17
#		define SP_REGISTER 14
#	else
#		define N_C_PARAMETER_REGISTERS 8
#		define C_PARAMETER_REGISTER_0 (-21)
#    ifdef LINUX_ELF
#		define FIRST_C_STACK_PARAMETER_WORD_OFFSET (2-8-32)
#    else
#	  ifdef ALIGN_C_CALLS
#		define FIRST_C_STACK_PARAMETER_WORD_OFFSET (6-32-7)
#	  else
#		define FIRST_C_STACK_PARAMETER_WORD_OFFSET (6-32)
#	  endif
#    endif
#	 define SP_REGISTER B_STACK_POINTER
#	endif
#endif

#ifdef G_AI64
# define REGISTER_RBP (-5)
#endif

#ifdef ALIGN_C_CALLS
# define B_STACK_REGISTER REGISTER_O0
#else
# define B_STACK_REGISTER B_STACK_POINTER
#endif

#ifdef G_AI64
static void remove_at_sign_size_from_function_name (char c_function_name[])
{
	int l;
	
	l=strlen (c_function_name)-1;
	if (l>=0 && isdigit (c_function_name[l])){
		do
			--l;
		while (l>=0 && isdigit (c_function_name[l]));
		if (l>0 && c_function_name[l]=='@')
			c_function_name[l]='\0';
	}
}
#endif

static void push_extra_clean_b_register_parameters (int n_extra_clean_b_register_parameters)
{
	int n,offset;
	
	offset=-STACK_ELEMENT_SIZE;
	for (n=0; n<n_extra_clean_b_register_parameters-1; ++n){
#ifdef i486
		i_move_r_pd (REGISTER_D0+n,B_STACK_POINTER);
#else
		i_move_r_id (REGISTER_D0+n,offset,B_STACK_POINTER);
#endif
		offset-=STACK_ELEMENT_SIZE;
	}

#ifdef G_POWER
	i_move_r_idu (REGISTER_D0+n,offset,B_STACK_POINTER);
#elif defined (sparc)
	i_move_r_id (REGISTER_D0+n,offset,B_STACK_POINTER);
	i_sub_i_r (-offset,B_STACK_POINTER);
#else
	i_move_r_pd (REGISTER_D0+n,B_STACK_POINTER);
#endif
}

#if (defined (sparc) && !defined (SOLARIS)) || (defined (I486) && !defined (LINUX_ELF) && !defined (G_AI64)) || (defined (G_POWER) && !defined (LINUX_ELF)) || defined (MACH_O) || defined (MACH_O64)
static LABEL *enter_c_function_name_label (char *c_function_name)
{
	char label_name [202];

# if defined (G_POWER) && !defined (MACH_O)
	label_name[0]='.';
# else
	label_name[0]='_';
# endif
	strcpy (&label_name[1],c_function_name);

	return enter_label (label_name,
# if defined (G_A64) && defined (LINUX)
		pic_flag ? USE_PLT_LABEL : 0);
# else
		0);
# endif
}
#else
# if defined (G_A64) && defined (LINUX)
# define enter_c_function_name_label(c_function_name) enter_label (c_function_name, pic_flag ? USE_PLT_LABEL : 0)
# else
# define enter_c_function_name_label(c_function_name) enter_label (c_function_name, 0)
# endif
#endif

static LABEL *enter_string_to_string_node_label (void)
{
	return enter_label ("string_to_string_node",
#if defined (G_AI64) && defined (LINUX)
						rts_got_flag ? (USE_GOT_LABEL | IMPORT_LABEL) :
#endif
						IMPORT_LABEL);
}

#if defined (G_POWER) || defined (sparc)
static void ccall_load_b_offset (int b_o,int c_parameter_n)
{
	if (c_parameter_n<N_C_PARAMETER_REGISTERS)
		i_lea_id_r (b_o,B_STACK_REGISTER,C_PARAMETER_REGISTER_0+c_parameter_n);
	else {
		i_lea_id_r (b_o,B_STACK_REGISTER,REGISTER_A3);
		i_move_r_id (REGISTER_A3,(FIRST_C_STACK_PARAMETER_WORD_OFFSET+c_parameter_n)<<2,SP_REGISTER);
	}
}

static void ccall_load_string_or_array_offset (int offset,int c_parameter_n,int a_o)
{
	i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0);
	if (c_parameter_n<N_C_PARAMETER_REGISTERS)
		i_lea_id_r (offset,REGISTER_A0,C_PARAMETER_REGISTER_0+c_parameter_n);
	else {
		i_lea_id_r (offset,REGISTER_A0,REGISTER_A3);
		i_move_r_id (REGISTER_A3,(FIRST_C_STACK_PARAMETER_WORD_OFFSET+c_parameter_n)<<2,SP_REGISTER);
	}
}
#endif

#if defined (THREAD64) && (defined (LINUX_ELF) || defined (MACH_O64))
LABEL *pthread_getspecific_label=NULL;
#endif

#ifdef THREAD32
# define SAVED_A_STACK_P_OFFSET 12
# define STRING_tlsp_tls_index "tlsp_tls_index"
#else
# ifdef THREAD64
#  define SAVED_HEAP_P_OFFSET 24
#  define SAVED_R15_OFFSET 32
#  define SAVED_A_STACK_P_OFFSET 40
#  ifdef MACH_O64
#   define STRING_tlsp_tls_index "_tlsp_tls_index"
#   define STRING_pthread_getspecific "_pthread_getspecific"
#  else
#   define STRING_tlsp_tls_index "tlsp_tls_index"
#   define STRING_pthread_getspecific "pthread_getspecific"
#  endif
# endif
#endif

#ifdef ARM
# ifndef G_A64
#  include "cgarmc.c"
# else
#  include "cgarm64c.c"
# endif
#else

void code_ccall (char *c_function_name,char *s,int length)
{
	LABEL *label;
	int l,min_index;
	int a_offset,b_offset,a_result_offset,b_result_offset;
	int result,a_o,b_o,float_parameters;
	int n_clean_b_register_parameters,clean_b_register_parameter_n;
	int n_extra_clean_b_register_parameters;
	int first_pointer_result_index,callee_pops_arguments,save_state_in_global_variables;
	int function_address_parameter;
	int n_a_c_in_clean_out_parameters_size,n_b_c_in_clean_out_parameters_size;
	int c_offset;		

#if ! (defined (sparc) || defined (G_POWER) || defined (I486))
	error ("ABC instruction 'ccall' not implemented");
#endif
#if defined (sparc) || defined (G_POWER)
	int	c_parameter_n;
#endif
#if defined (G_POWER) || (defined (G_A64) && (defined (LINUX_ELF) || defined (MACH_O64)))
	int c_fp_parameter_n;
	
	c_fp_parameter_n=0;
#endif

	function_address_parameter=0;

	if (*s=='G'){
		++s;
		--length;
		save_state_in_global_variables=1;
#if (defined (I486) && !defined (THREAD64)) || defined (G_POWER)
		if (saved_heap_p_label==NULL)
			saved_heap_p_label=enter_label ("saved_heap_p",IMPORT_LABEL);
		if (saved_a_stack_p_label==NULL)
			saved_a_stack_p_label=enter_label ("saved_a_stack_p",IMPORT_LABEL);
#endif
	} else	
		save_state_in_global_variables=0;

	if (*s=='P'){
		++s;
		--length;
		callee_pops_arguments=1;

#ifdef G_AI64
		remove_at_sign_size_from_function_name (c_function_name);
#endif
	} else
		callee_pops_arguments=0;

#if defined (sparc) || defined (I486) || defined (G_POWER)
	float_parameters=0;
			
	a_offset=0;
	b_offset=0;
	n_clean_b_register_parameters=0;
	n_a_c_in_clean_out_parameters_size=0;
	n_b_c_in_clean_out_parameters_size=0;

	for (l=0; l<length; ++l){
		switch (s[l]){
			case '-':
			case ':':
				min_index=l;
				break;
			case 'I':
			case 'p':
				b_offset+=STACK_ELEMENT_SIZE;
				if (!float_parameters)
					++n_clean_b_register_parameters;
# if defined (I486) && !defined (G_AI64)
				if (s[l+1]=='>'){
					++l;
					n_b_c_in_clean_out_parameters_size+=STACK_ELEMENT_SIZE;
				}
# endif
				continue;
# if defined (I486) || defined (G_POWER)
			case 'r':
# endif
			case 'R':
				float_parameters=1;
				b_offset+=8;
# if defined (G_A64) && (defined (LINUX_ELF) || defined (MACH_O64))
				++c_fp_parameter_n;
# endif
				continue;
			case 'S':
			case 's':
			case 'A':
				a_offset+=STACK_ELEMENT_SIZE;
# if defined (I486) && !defined (G_AI64)
				if (s[l+1]=='>'){
					++l;
					n_a_c_in_clean_out_parameters_size+=STACK_ELEMENT_SIZE;
				}
# endif
				continue;
			case 'O':
			case 'F':
				if (function_address_parameter)
					error_s (ccall_error_string,c_function_name);
				function_address_parameter=s[l];
				
				while (l+1<length && (s[l+1]=='*' || s[l+1]=='[')){
					++l;
					if (s[l]=='['){
						++l;
						while (l<length && (unsigned)(s[l]-'0')<(unsigned)10)
							++l;
						if (!(l<length && s[l]==']'))
							error_s (ccall_error_string,c_function_name);
					}
				}
				b_offset+=STACK_ELEMENT_SIZE;
				if (!float_parameters)
					++n_clean_b_register_parameters;
				continue;
			default:
				error_s (ccall_error_string,c_function_name);
		}
		break;
	}
	if (l>=length)
		error_s (ccall_error_string,c_function_name);
	
	a_result_offset=0;
	b_result_offset=0;

	n_extra_clean_b_register_parameters=0;

	for (++l; l<length; ++l){
		switch (s[l]){
			case 'I':
			case 'p':
				b_result_offset+=STACK_ELEMENT_SIZE;
				continue;
			case 'R':
				float_parameters=1;
				b_result_offset+=8;
				continue;
			case 'S':
				a_result_offset+=STACK_ELEMENT_SIZE;
				continue;
			case 'A':
				++l;
				if (l<length && (s[l]=='i' || s[l]=='r')){
					a_result_offset+=STACK_ELEMENT_SIZE;
					continue;
				} else {
					error_s (ccall_error_string,c_function_name);
					break;
				}
			case ':':
				if (l==min_index+1 || l==length-1)
					error_s (ccall_error_string,c_function_name);
				else {
					int new_length;
					
					new_length=l;
					
					for (++l; l<length; ++l){
						switch (s[l]){
							case 'I':
							case 'p':
								if (!float_parameters)
									++n_extra_clean_b_register_parameters;
								break;
							case 'R':
								float_parameters=1;
								break;
							case 'S':
							case 'A':
								continue;
							default:
								error_s (ccall_error_string,c_function_name);
						}
					}
					
					length=new_length;
				}
				break;
			case 'V':
				if ((l==min_index+1 && l!=length-1) || n_a_c_in_clean_out_parameters_size+n_b_c_in_clean_out_parameters_size!=0)
					continue;
			default:
				error_s (ccall_error_string,c_function_name);
		}
	}

	if (n_clean_b_register_parameters>N_DATA_PARAMETER_REGISTERS){
		n_clean_b_register_parameters=N_DATA_PARAMETER_REGISTERS;
		n_extra_clean_b_register_parameters=0;
	} else if (n_clean_b_register_parameters+n_extra_clean_b_register_parameters>N_DATA_PARAMETER_REGISTERS)
		n_extra_clean_b_register_parameters=N_DATA_PARAMETER_REGISTERS-n_clean_b_register_parameters;

	end_basic_block_with_registers (0,n_clean_b_register_parameters+n_extra_clean_b_register_parameters,e_vector);

	b_offset-=n_clean_b_register_parameters<<STACK_ELEMENT_LOG_SIZE;

	if (n_extra_clean_b_register_parameters!=0)
		push_extra_clean_b_register_parameters (n_extra_clean_b_register_parameters);

# ifndef sparc
	c_offset=b_offset;
# endif

	if (s[min_index]=='-' && length-1!=min_index+1){
		result='V';
		first_pointer_result_index=min_index+1;
	} else {
		result=s[min_index+1];
		first_pointer_result_index=min_index+2;

		switch (result){
			case 'I':
			case 'p':
				b_result_offset-=STACK_ELEMENT_SIZE;
				break;
			case 'R':
				b_result_offset-=8;
				break;
			case 'S':
				a_result_offset-=STACK_ELEMENT_SIZE;
				break;
			case 'A':
				a_result_offset-=STACK_ELEMENT_SIZE;
				++first_pointer_result_index;
		}
	}
#endif

	if (!function_address_parameter){
		label = enter_c_function_name_label (c_function_name);

#if defined (G_POWER) && defined (MACH_O)
		if (dyld_stub_binding_helper_p_label==NULL)
			dyld_stub_binding_helper_p_label=enter_label ("dyld_stub_binding_helper",IMPORT_LABEL);
#endif
	}

#if defined (G_POWER) || defined (sparc)
	{
		int b_a_offset;

# ifdef G_POWER
		if (a_result_offset+b_result_offset>b_offset){
			i_sub_i_r (a_result_offset+b_result_offset-b_offset,B_STACK_POINTER);
			c_offset=a_result_offset+b_result_offset;
		}
		b_o=c_offset-b_result_offset;
# else
		b_o=b_offset-b_result_offset;
# endif
		b_a_offset=b_o;

# ifdef ALIGN_C_CALLS
		i_move_r_r (B_STACK_POINTER,REGISTER_O0);
		i_or_i_r (28,B_STACK_POINTER);
# endif

		c_parameter_n=(b_offset+a_offset>>2)+n_clean_b_register_parameters-(function_address_parameter=='F');
		
		for (l=first_pointer_result_index; l<length; ++l){
			switch (s[l]){
				case 'I':
				case 'p':
					ccall_load_b_offset (b_o,c_parameter_n);
					++c_parameter_n;
					b_o+=STACK_ELEMENT_SIZE;
					break;
				case 'R':
					ccall_load_b_offset (b_o,c_parameter_n);
					++c_parameter_n;
					b_o+=8;
					break;
				case 'S':
					b_a_offset-=STACK_ELEMENT_SIZE;
					ccall_load_b_offset (b_a_offset,c_parameter_n);
					++c_parameter_n;
					break;
				case 'V':
					break;
				default:
					error_s (ccall_error_string,c_function_name);
			}
		}
	}

	a_o=0;
# ifdef G_POWER
	b_o=c_offset-b_offset;
# else
	b_o=0;
# endif
	c_parameter_n=0;
# ifdef G_POWER
	c_fp_parameter_n=0;
# endif

	{
	int function_address_reg;
	
	clean_b_register_parameter_n=0;
	for (l=0; l<min_index; ++l){
		switch (s[l]){
			case 'I':
			case 'p':
				if (clean_b_register_parameter_n < n_clean_b_register_parameters){
					int clean_b_reg_n;
					
					clean_b_reg_n=REGISTER_D0+n_extra_clean_b_register_parameters+n_clean_b_register_parameters-1-clean_b_register_parameter_n;
					if (c_parameter_n<N_C_PARAMETER_REGISTERS)
						i_move_r_r (clean_b_reg_n,C_PARAMETER_REGISTER_0+c_parameter_n);
					else
						i_move_r_id (clean_b_reg_n,(FIRST_C_STACK_PARAMETER_WORD_OFFSET+c_parameter_n)<<2,SP_REGISTER);
					++c_parameter_n;
					++clean_b_register_parameter_n;
				} else {
					if (c_parameter_n<N_C_PARAMETER_REGISTERS)
						i_move_id_r (b_o,B_STACK_REGISTER,C_PARAMETER_REGISTER_0+c_parameter_n++);
					else {
						i_move_id_r (b_o,B_STACK_REGISTER,REGISTER_A3);
						i_move_r_id (REGISTER_A3,(FIRST_C_STACK_PARAMETER_WORD_OFFSET+c_parameter_n++)<<2,SP_REGISTER);
					}
					b_o+=STACK_ELEMENT_SIZE;
				}					
				break;
# ifdef G_POWER
			case 'r':
				if (c_fp_parameter_n<13){
					++c_parameter_n;
					i_fmove_id_fr (b_o,B_STACK_REGISTER,1+c_fp_parameter_n-14);
					i_word_i (0xFC000018 | ((1+c_fp_parameter_n) << 21) | ((1+c_fp_parameter_n) << 11)); // frsp frp,frp
				} else
					error_s ("Passing single precision argument in fp position > 13 not implemented (in '%s')",c_function_name);
				++c_fp_parameter_n;
				b_o+=8;
				break;
# endif
			case 'R':
# ifdef G_POWER
#  ifdef LINUX_ELF
				if (c_fp_parameter_n<8){
#  else
				if (c_fp_parameter_n<13){
					c_parameter_n+=2;
#  endif
					i_fmove_id_fr (b_o,B_STACK_REGISTER,1+c_fp_parameter_n-14);
				} else {
#  ifdef LINUX_ELF
					error_s ("Passing more than 8 fp registers not implemented (in '%s')",c_function_name);
#  else
					i_move_id_r (b_o,B_STACK_REGISTER,REGISTER_A3);
					i_move_r_id (REGISTER_A3,(FIRST_C_STACK_PARAMETER_WORD_OFFSET+c_parameter_n++)<<2,SP_REGISTER);
					i_move_id_r (b_o+4,B_STACK_REGISTER,REGISTER_A3);
					i_move_r_id (REGISTER_A3,(FIRST_C_STACK_PARAMETER_WORD_OFFSET+c_parameter_n++)<<2,SP_REGISTER);
#  endif
				}
				++c_fp_parameter_n;
# else
				if (c_parameter_n<N_C_PARAMETER_REGISTERS)
					i_move_id_r (b_o,B_STACK_REGISTER,C_PARAMETER_REGISTER_0+c_parameter_n++);
				else {
					i_move_id_r (b_o,B_STACK_REGISTER,REGISTER_A3);
					i_move_r_id (REGISTER_A3,(FIRST_C_STACK_PARAMETER_WORD_OFFSET+c_parameter_n++)<<2,SP_REGISTER);
				}
				if (c_parameter_n<N_C_PARAMETER_REGISTERS)
					i_move_id_r (b_o+4,B_STACK_REGISTER,C_PARAMETER_REGISTER_0+c_parameter_n++);
				else {
					i_move_id_r (b_o+4,B_STACK_REGISTER,REGISTER_A3);
					i_move_r_id (REGISTER_A3,(FIRST_C_STACK_PARAMETER_WORD_OFFSET+c_parameter_n++)<<2,SP_REGISTER);
				}
# endif
				b_o+=8;
				break;
			case 'S':
				a_o-=STACK_ELEMENT_SIZE;
				ccall_load_string_or_array_offset (4,c_parameter_n,a_o);
				++c_parameter_n;
				break;
			case 's':
				a_o-=STACK_ELEMENT_SIZE;
				ccall_load_string_or_array_offset (8,c_parameter_n,a_o);
				++c_parameter_n;
				break;
			case 'A':
				a_o-=STACK_ELEMENT_SIZE;
				ccall_load_string_or_array_offset (12,c_parameter_n,a_o);
				++c_parameter_n;
				break;
			case 'F':
			case 'O':
				if (clean_b_register_parameter_n < n_clean_b_register_parameters){
					int clean_b_reg_n;
					
					clean_b_reg_n=REGISTER_D0+n_extra_clean_b_register_parameters+n_clean_b_register_parameters-1-clean_b_register_parameter_n;

					if (function_address_parameter=='O'){
						if (c_parameter_n<N_C_PARAMETER_REGISTERS)
							i_move_r_r (clean_b_reg_n,C_PARAMETER_REGISTER_0+c_parameter_n);
						else
							i_move_r_id (clean_b_reg_n,(FIRST_C_STACK_PARAMETER_WORD_OFFSET+c_parameter_n)<<2,SP_REGISTER);
						++c_parameter_n;
					}

					function_address_reg=clean_b_reg_n;

					while (l+1<length && (s[l+1]=='*' || s[l+1]=='[')){
						int n;
						
						++l;
						n=0;
						
						if (s[l]=='['){
							++l;
							while (l<length && (unsigned)(s[l]-'0')<(unsigned)10){
								n=n*10+(s[l]-'0');
								++l;
							}
						}
						
						i_move_id_r (n,clean_b_reg_n,clean_b_reg_n);
					}


					++clean_b_register_parameter_n;
					break;
				}
			default:
				error_s (ccall_error_string,c_function_name);
		}
	}
# ifdef G_POWER
	if (save_state_in_global_variables){
		i_lea_l_i_r (saved_a_stack_p_label,0,REGISTER_A3);
		i_move_r_id (A_STACK_POINTER,0,REGISTER_A3);
		i_lea_l_i_r (saved_heap_p_label,0,REGISTER_A3);
		i_move_r_id (HEAP_POINTER,0,REGISTER_A3);
		i_move_r_id (REGISTER_D7,4,REGISTER_A3);
	}

	if (!function_address_parameter)
		i_call_l (label,128);
	else
		i_call_r (function_address_reg,128);

	if (save_state_in_global_variables){
		i_lea_l_i_r (saved_a_stack_p_label,0,REGISTER_A3);
		i_move_id_r (0,REGISTER_A3,A_STACK_POINTER);
		i_lea_l_i_r (saved_heap_p_label,0,REGISTER_A3);
		i_move_id_r (0,REGISTER_A3,HEAP_POINTER);
		i_move_id_r (4,REGISTER_A3,REGISTER_D7);
	}

	begin_new_basic_block(); /* MTLR/MFLR optimization only finds IJSR at end of basic block */
# else
	if (!function_address_parameter)
		i_call_l (label);
	else
		i_call_r (function_address_reg);
# endif
	}

	if (a_offset!=0)
		i_add_i_r (-a_offset,A_STACK_POINTER);
# ifdef G_POWER
	if (c_offset-(b_result_offset+a_result_offset)!=0)
		i_add_i_r (c_offset-(b_result_offset+a_result_offset),B_STACK_POINTER);
# else
	if (b_offset-(b_result_offset+a_result_offset)!=0)
		i_add_i_r (b_offset-(b_result_offset+a_result_offset),B_STACK_POINTER);
# endif

	for (l=first_pointer_result_index; l<length; ++l){
		switch (s[l]){
			case 'I':
			case 'p':
			case 'R':
				break;
			case 'S':
				if (string_to_string_node_label==NULL)
					string_to_string_node_label=enter_string_to_string_node_label();

				i_move_id_r (0,B_STACK_POINTER,REGISTER_A0);
				i_jsr_l_id (string_to_string_node_label,0);
				i_move_r_id (REGISTER_A0,0,A_STACK_POINTER);
				i_add_i_r (STACK_ELEMENT_SIZE,A_STACK_POINTER);
				break;
			case 'V':
				break;
			default:
				error_s (ccall_error_string,c_function_name);
		}
	}
	
	switch (result){
		case 'I':
		case 'p':
			i_move_r_r (C_PARAMETER_REGISTER_0,REGISTER_D0);
			begin_new_basic_block();
			init_b_stack (1,i_vector);
			break;
		case 'R':
# ifdef G_POWER
			i_fmove_fr_fr (1-14,0);
# endif
			begin_new_basic_block();
			init_b_stack (2,r_vector);
			break;
		case 'S':
			if (string_to_string_node_label==NULL)
				string_to_string_node_label=enter_string_to_string_node_label();

			i_move_r_r (C_PARAMETER_REGISTER_0,REGISTER_A0);
			i_sub_i_r (STACK_ELEMENT_SIZE,B_STACK_POINTER);
			i_jsr_l_id (string_to_string_node_label,0);

			begin_new_basic_block();
			init_a_stack (1);
			break;
		case 'V':
			begin_new_basic_block();
			break;
		default:
			error_s (ccall_error_string,c_function_name);
	}

#elif defined (I486)

# ifndef G_AI64 /* for I486 && ! G_AI64 */
	{
		int c_offset_before_pushing_arguments,function_address_reg;
		int b_out_and_ab_result_size;

		b_out_and_ab_result_size = n_b_c_in_clean_out_parameters_size+a_result_offset+b_result_offset;

		a_o = -b_out_and_ab_result_size;
		b_o = -n_b_c_in_clean_out_parameters_size;

		if (b_out_and_ab_result_size>b_offset){
			i_sub_i_r (b_out_and_ab_result_size-b_offset,B_STACK_POINTER);
			c_offset=b_out_and_ab_result_size;
		}
		
		c_offset_before_pushing_arguments=c_offset;

		for (l=length-1; l>=first_pointer_result_index; --l){
			switch (s[l]){
				case 'I':
				case 'p':
					b_o-=STACK_ELEMENT_SIZE;
					i_lea_id_r (b_o+c_offset,B_STACK_POINTER,REGISTER_A0);
					i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
					c_offset+=STACK_ELEMENT_SIZE;
					break;
				case 'R':
					b_o-=8;
					i_lea_id_r (b_o+c_offset,B_STACK_POINTER,REGISTER_A0);
					i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
					c_offset+=STACK_ELEMENT_SIZE;
					break;
				case 'i':
				case 'r':
					--l;
				case 'S':
					i_lea_id_r (a_o+c_offset,B_STACK_POINTER,REGISTER_A0);
					i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
					a_o+=STACK_ELEMENT_SIZE;
					c_offset+=STACK_ELEMENT_SIZE;
					break;
				case 'V':
					break;
				default:
					error_s (ccall_error_string,c_function_name);
			}
		}

		{
			int last_register_parameter_index,reg_n,a_out_offset,b_out_offset;
			
			last_register_parameter_index=-1;
			
			reg_n=0;
			l=0;
			while (reg_n<n_clean_b_register_parameters && l<min_index){
				if (s[l]=='I' || s[l]=='p' || s[l]=='F' || s[l]=='O'){
					++reg_n;
					last_register_parameter_index=l;
				}
				++l;
			}
			
			reg_n=0;
			a_o=-a_offset;
			b_o=0;
			a_out_offset=a_o;
			b_out_offset=0;

			for (l=min_index-1; l>=0; --l){
				switch (s[l]){
					case 'I':
					case 'p':
						if (l<=last_register_parameter_index){
							i_move_r_pd (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,B_STACK_POINTER);
							++reg_n;
						} else {
							b_o-=STACK_ELEMENT_SIZE;
							i_move_id_pd (b_o+c_offset,B_STACK_POINTER,B_STACK_POINTER);
						}
						c_offset+=STACK_ELEMENT_SIZE;
						break;
					case 'r':
					{
						int offset;
						
						b_o-=8;

						i_lea_id_r (-4,B_STACK_POINTER,B_STACK_POINTER);

						offset=b_o+c_offset+4;

						i_word_i (0xDD);	//	fldl <b_o+c_offset+4>(%esp)
						if ((signed char)offset==offset){
							i_word_i (0x44);
							i_word_i (0x24);
							i_word_i (offset);
						} else {
							i_word_i (0x84);
							i_word_i (0x24);
							i_word_i (offset);
							i_word_i (offset>>8);						
							i_word_i (offset>>16);
							i_word_i (offset>>24);
						}

						i_word_i (0xD9);	//	fstps (%esp)
						i_word_i (0x1C);
						i_word_i (0x24);

						c_offset+=4;
						break;
					}
					case 'R':
						b_o-=8;
						i_move_id_pd (b_o+c_offset+4,B_STACK_POINTER,B_STACK_POINTER);
						i_move_id_pd (b_o+(c_offset+4),B_STACK_POINTER,B_STACK_POINTER);
						c_offset+=8;
						break;
					case 'S':
						i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0);
						i_add_i_r (STACK_ELEMENT_SIZE,REGISTER_A0);
						i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
						a_o+=STACK_ELEMENT_SIZE;
						c_offset+=STACK_ELEMENT_SIZE;
						break;
					case 's':
						i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0);
						i_add_i_r (8,REGISTER_A0);
						i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
						a_o+=STACK_ELEMENT_SIZE;
						c_offset+=STACK_ELEMENT_SIZE;
						break;
					case 'A':
						i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0);
						i_add_i_r (12,REGISTER_A0);
						i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
						a_o+=STACK_ELEMENT_SIZE;
						c_offset+=STACK_ELEMENT_SIZE;
						break;
					case 'F':
					case 'O':
					case '*':
					case ']':
						/* while (l>=0 && !(s[l]=='F' || s[l]=='O')) bug in watcom c */
						while (l>=0 && (s[l]!='F' && s[l]!='O'))
							--l;
						
						if (l<=last_register_parameter_index){
							int clean_b_reg_n,i;
							
							clean_b_reg_n=REGISTER_D0+n_extra_clean_b_register_parameters+reg_n;

							if (function_address_parameter=='O'){
								i_move_r_pd (clean_b_reg_n,B_STACK_POINTER);
								c_offset+=STACK_ELEMENT_SIZE;
							}
							
							++reg_n;

							function_address_reg=clean_b_reg_n;
							i=l;
							while (i+1<length && (s[i+1]=='*' || s[i+1]=='[')){
								int n;
								
								++i;
								n=0;
								
								if (s[i]=='['){
									++i;
									while (i<length && (unsigned)(s[i]-'0')<(unsigned)10){
										n=n*10+(s[i]-'0');
										++i;
									}
								}
								
								i_move_id_r (n,clean_b_reg_n,clean_b_reg_n);
							}
							break;
						}
					case '>':
					{
						char c;

						--l;
						c = s[l];
						if (c=='I' || c=='p'){
							int parameter_reg_n;
							
							if (l<=last_register_parameter_index){
								parameter_reg_n=REGISTER_D0+n_extra_clean_b_register_parameters+reg_n;
								i_move_r_pd (parameter_reg_n,B_STACK_POINTER);
								++reg_n;
							} else {
								parameter_reg_n=REGISTER_A0;
								b_o-=STACK_ELEMENT_SIZE;
								i_move_id_r (b_o+c_offset,B_STACK_POINTER,parameter_reg_n);
								i_move_r_pd (parameter_reg_n,B_STACK_POINTER);
							}
							c_offset+=STACK_ELEMENT_SIZE;
							b_out_offset-=STACK_ELEMENT_SIZE;
							i_move_r_id (parameter_reg_n,b_out_offset+c_offset,B_STACK_POINTER);
						} else {
							int string_or_array_offset;
							
							switch (c){
								case 'S':
									string_or_array_offset=STACK_ELEMENT_SIZE;
									break;
								case 's':
									string_or_array_offset=8;
									break;
								case 'A':
									string_or_array_offset=12;
									break;
								default:
									error_s (ccall_error_string,c_function_name);
							}

							i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0);
							if (a_o!=a_out_offset)
								i_move_r_id (REGISTER_A0,a_out_offset,A_STACK_POINTER);
							i_add_i_r (string_or_array_offset,REGISTER_A0);
							i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
							a_o+=STACK_ELEMENT_SIZE;
							c_offset+=STACK_ELEMENT_SIZE;
							a_out_offset+=STACK_ELEMENT_SIZE;
						}
						break;
					}
					default:
						error_s (ccall_error_string,c_function_name);
				}
			}
		}
		
		if (float_parameters){
			int freg_n;

			for (freg_n=0; freg_n<8; ++freg_n){
	 			i_word_i (0xdd);
				i_word_i (0xc0+freg_n); /* ffree */
			}
		}

		if (save_state_in_global_variables){
#  ifndef THREAD32
			i_move_r_l (-4/*ESI*/,saved_a_stack_p_label);
			i_move_r_l (-5/*EDI*/,saved_heap_p_label);
#  else
			i_move_r_id (A_STACK_POINTER,SAVED_A_STACK_P_OFFSET,-5/*EDI*/);
#  endif
		}

		if (!function_address_parameter)
			i_jsr_l (label,0);
		else
			i_jsr_r (function_address_reg);

		if (save_state_in_global_variables){
#  ifndef THREAD32
			i_move_l_r (saved_a_stack_p_label,-4/*ESI*/);
			i_move_l_r (saved_heap_p_label,-5/*EDI*/);
#  else
			i_move_id_r (SAVED_A_STACK_P_OFFSET,-5/*EDI*/,A_STACK_POINTER);
#  endif
		}

		if (callee_pops_arguments)
			c_offset=c_offset_before_pushing_arguments;
		
		if (a_offset-n_a_c_in_clean_out_parameters_size!=0)
			i_sub_i_r (a_offset-n_a_c_in_clean_out_parameters_size,A_STACK_POINTER);
		if (c_offset-b_out_and_ab_result_size!=0)
			i_add_i_r (c_offset-b_out_and_ab_result_size,B_STACK_POINTER);

		}
		
		for (l=length-1; l>=first_pointer_result_index; --l){
			switch (s[l]){
				case 'I':
				case 'p':
				case 'R':
					break;
				case 'S':
					if (string_to_string_node_label==NULL)
						string_to_string_node_label=enter_string_to_string_node_label();
					i_move_pi_r (B_STACK_POINTER,REGISTER_A0);
					i_jsr_l (string_to_string_node_label,0);
					i_move_r_id (REGISTER_A0,0,A_STACK_POINTER);
					i_add_i_r (STACK_ELEMENT_SIZE,A_STACK_POINTER);
					break;
				case 'i':
					--l;
					if (int_array_to_node_label==NULL)
						int_array_to_node_label=enter_label ("int_array_to_node",IMPORT_LABEL);
					i_move_pi_r (B_STACK_POINTER,REGISTER_A0);
					i_jsr_l (int_array_to_node_label,0);
					i_move_r_id (REGISTER_A0,0,A_STACK_POINTER);
					i_add_i_r (STACK_ELEMENT_SIZE,A_STACK_POINTER);
					break;
				case 'r':
					--l;
					if (real_array_to_node_label==NULL)
						real_array_to_node_label=enter_label ("real_array_to_node",IMPORT_LABEL);
					i_move_pi_r (B_STACK_POINTER,REGISTER_A0);
					i_jsr_l (real_array_to_node_label,0);
					i_move_r_id (REGISTER_A0,0,A_STACK_POINTER);
					i_add_i_r (STACK_ELEMENT_SIZE,A_STACK_POINTER);
					break;
				case 'V':
					break;
				default:
					error_s (ccall_error_string,c_function_name);
			}
		}

		switch (result){
			case 'I':
			case 'p':
				begin_new_basic_block();
				init_b_stack (1,i_vector);
				break;
			case 'R':
				begin_new_basic_block();
				init_b_stack (2,r_vector);
				break;
			case 'S':
				if (string_to_string_node_label==NULL)
					string_to_string_node_label=enter_string_to_string_node_label();

				i_move_r_r (REGISTER_D0,REGISTER_A0);
				i_jsr_l (string_to_string_node_label,0);

				begin_new_basic_block();
				init_a_stack (1);
				break;
			case 'A':
				i_move_r_r (REGISTER_D0,REGISTER_A0);
				if (s[min_index+2]=='i'){
					if (int_array_to_node_label==NULL)
						int_array_to_node_label=enter_label ("int_array_to_node",IMPORT_LABEL);
					i_jsr_l (int_array_to_node_label,0);
				} else if (s[min_index+2]=='r'){
					if (real_array_to_node_label==NULL)
						real_array_to_node_label=enter_label ("real_array_to_node",IMPORT_LABEL);
					i_jsr_l (real_array_to_node_label,0);
				}
				begin_new_basic_block();
				init_a_stack (1);
				break;
			case 'V':
				begin_new_basic_block();
				break;
			default:
				error_s (ccall_error_string,c_function_name);
		}
# else /* for I486 && G_AI64 */
		a_o=-b_result_offset-a_result_offset;
		b_o=0;

		if (a_result_offset+b_result_offset>b_offset){
			i_sub_i_r (a_result_offset+b_result_offset-b_offset,B_STACK_POINTER);
			c_offset=a_result_offset+b_result_offset;
		}

#  ifdef THREAD64
	if (save_state_in_global_variables){
		if (tlsp_tls_index_label==NULL)
			tlsp_tls_index_label=enter_label (STRING_tlsp_tls_index,IMPORT_LABEL);

		i_move_r_id (A_STACK_POINTER,SAVED_A_STACK_P_OFFSET,-4/*R9*/);
		i_move_r_id (-7/*RDI*/,SAVED_HEAP_P_OFFSET,-4/*R9*/);
		i_move_r_id (REGISTER_D7,SAVED_R15_OFFSET,-4/*R9*/);
	}
#  endif

#  if defined (LINUX_ELF) || defined (MACH_O64) /* for I486 && G_AI64 && (LINUX_ELF || MACH_O64) */
		{
		int c_offset_before_pushing_arguments,function_address_reg,c_parameter_n,n_c_parameters,n_c_fp_register_parameters;
		int a_stack_pointer,heap_pointer;
		unsigned int used_clean_b_parameter_registers;
		static int c_parameter_registers[6] = { HEAP_POINTER, A_STACK_POINTER, REGISTER_A1, REGISTER_A0, REGISTER_A2, REGISTER_A3 };

		c_offset_before_pushing_arguments=c_offset;

		n_c_parameters=((a_offset+b_offset+a_result_offset+b_result_offset)>>STACK_ELEMENT_LOG_SIZE)+n_clean_b_register_parameters;
		used_clean_b_parameter_registers = ((1<<n_clean_b_register_parameters)-1)<<n_extra_clean_b_register_parameters;
		c_parameter_n=n_c_parameters;
		n_c_fp_register_parameters = c_fp_parameter_n<=8 ? c_fp_parameter_n : 8;

		i_move_r_r (B_STACK_POINTER,REGISTER_RBP);
#   ifdef THREAD64
		if (!save_state_in_global_variables){
			if ((c_parameter_n-n_c_fp_register_parameters)>6 && ((c_parameter_n-n_c_fp_register_parameters) & 1)!=0){
				i_sub_i_r (16+8,B_STACK_POINTER);
				i_move_r_id (-4/*R9*/,8,B_STACK_POINTER);
				i_or_i_r (8,B_STACK_POINTER);		
			} else {
				i_sub_i_r (16,B_STACK_POINTER);
				i_move_r_id (-4/*R9*/,0,B_STACK_POINTER);
				i_and_i_r (-16,B_STACK_POINTER);		
			}
		} else
#   endif
		if ((c_parameter_n-n_c_fp_register_parameters)>6 && ((c_parameter_n-n_c_fp_register_parameters) & 1)!=0){
			i_sub_i_r (8,B_STACK_POINTER);
			i_or_i_r (8,B_STACK_POINTER);		
		} else {
			i_and_i_r (-16,B_STACK_POINTER);		
		}

		a_stack_pointer=A_STACK_POINTER;
		heap_pointer=HEAP_POINTER;

		for (l=length-1; l>=first_pointer_result_index; --l){
			char sl;
			
			sl=s[l];
			if (sl!='V'){
				int c_int_parameter_n;
				
				--c_parameter_n;
				c_int_parameter_n = c_parameter_n - n_c_fp_register_parameters;
				if (c_int_parameter_n<6){
					int c_parameter_reg;					
					
					c_parameter_reg=c_parameter_registers[c_int_parameter_n];
					if (c_int_parameter_n<2){
						if (c_int_parameter_n==0){
							if ((used_clean_b_parameter_registers & (1<<6))==0){
								heap_pointer=REGISTER_D6;
								used_clean_b_parameter_registers |= 1<<6;
							} else if ((used_clean_b_parameter_registers & (1<<5))==0){
								heap_pointer=REGISTER_D5;
								used_clean_b_parameter_registers |= 1<<5;
							} else
								error_s (ccall_error_string,c_function_name);								
							i_move_r_r (HEAP_POINTER,heap_pointer);
						} else {
							if ((used_clean_b_parameter_registers & (1<<5))==0){
								a_stack_pointer=REGISTER_D5;
								used_clean_b_parameter_registers |= 1<<5;
							} else if ((used_clean_b_parameter_registers & (1<<6))==0){
								a_stack_pointer=REGISTER_D6;
								used_clean_b_parameter_registers |= 1<<6;
							} else
								error_s (ccall_error_string,c_function_name);								
							i_move_r_r (A_STACK_POINTER,a_stack_pointer);
						}
					}
					switch (sl){
						case 'I':
						case 'p':
							b_o-=STACK_ELEMENT_SIZE;
							i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,c_parameter_reg);
							break;
						case 'R':
							b_o-=8;
							i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,c_parameter_reg);
							break;
						case 'S':
							i_lea_id_r (a_o+c_offset_before_pushing_arguments,REGISTER_RBP,c_parameter_reg);
							a_o+=STACK_ELEMENT_SIZE;
							break;
						default:
							error_s (ccall_error_string,c_function_name);
					}					
				} else {
					switch (sl){
						case 'I':
						case 'p':
							b_o-=STACK_ELEMENT_SIZE;
							i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,REGISTER_A0);
							i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
							c_offset+=STACK_ELEMENT_SIZE;
							break;
						case 'R':
							b_o-=8;
							i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,REGISTER_A0);
							i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
							c_offset+=STACK_ELEMENT_SIZE;
							break;
						case 'S':
							i_lea_id_r (a_o+c_offset_before_pushing_arguments,REGISTER_RBP,REGISTER_A0);
							i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
							c_offset+=STACK_ELEMENT_SIZE;
							a_o+=STACK_ELEMENT_SIZE;
							break;
						default:
							error_s (ccall_error_string,c_function_name);
					}
				}
			}
		}
		
		{
			int last_register_parameter_index,reg_n;
			
			last_register_parameter_index=-1;
			
			reg_n=0;
			l=0;
			while (reg_n<n_clean_b_register_parameters && l<min_index){
				if (s[l]=='I' || s[l]=='p' || s[l]=='F' || s[l]=='O'){
					++reg_n;
					last_register_parameter_index=l;
				}
				++l;
			}
			
			reg_n=0;
			a_o=-a_offset;
			b_o=0;
			for (l=min_index-1; l>=0; --l){
				char sl;
				
				sl=s[l];
				switch (sl){
					case 'I':
					case 'p':
					{
						int c_int_parameter_n;
				
						--c_parameter_n;
						c_int_parameter_n = c_parameter_n - n_c_fp_register_parameters;
						if (c_int_parameter_n<6){
							int c_parameter_reg;					
					
							c_parameter_reg=c_parameter_registers[c_int_parameter_n];
							if (l<=last_register_parameter_index){
								if (c_int_parameter_n<2){
									if (c_int_parameter_n==0){
										if (n_extra_clean_b_register_parameters+reg_n==6){
											i_exg_r_r (HEAP_POINTER,REGISTER_D6);
											heap_pointer=REGISTER_D6;
											++reg_n;
											break;
										} else if (n_extra_clean_b_register_parameters+reg_n==5){
											i_exg_r_r (HEAP_POINTER,REGISTER_D5);
											heap_pointer=REGISTER_D5;
											++reg_n;
											break;											
										} else if ((used_clean_b_parameter_registers & (1<<6))==0){
											heap_pointer=REGISTER_D6;
											used_clean_b_parameter_registers |= 1<<6;
										} else if ((used_clean_b_parameter_registers & (1<<5))==0){
											heap_pointer=REGISTER_D5;
											used_clean_b_parameter_registers |= 1<<5;
										} else
											error_s (ccall_error_string,c_function_name);								
										i_move_r_r (HEAP_POINTER,heap_pointer);
									} else {
										if (n_extra_clean_b_register_parameters+reg_n==6){
											i_exg_r_r (A_STACK_POINTER,REGISTER_D6);
											a_stack_pointer=REGISTER_D6;
											++reg_n;
											break;
										} else if (n_extra_clean_b_register_parameters+reg_n==5){
											i_exg_r_r (A_STACK_POINTER,REGISTER_D5);
											a_stack_pointer=REGISTER_D5;
											++reg_n;
											break;											
										} else if ((used_clean_b_parameter_registers & (1<<5))==0){
											a_stack_pointer=REGISTER_D5;
											used_clean_b_parameter_registers |= 1<<5;
										} else if ((used_clean_b_parameter_registers & (1<<6))==0){
											a_stack_pointer=REGISTER_D6;
											used_clean_b_parameter_registers |= 1<<6;
										} else
											error_s (ccall_error_string,c_function_name);								
										i_move_r_r (A_STACK_POINTER,a_stack_pointer);
									}
								}
								i_move_r_r (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,c_parameter_reg);
								used_clean_b_parameter_registers &= ~ (1<<(n_extra_clean_b_register_parameters+reg_n));
								++reg_n;
							} else {
								if (c_int_parameter_n<2){
									if (c_int_parameter_n==0){
										if ((used_clean_b_parameter_registers & (1<<6))==0){
											heap_pointer=REGISTER_D6;
											used_clean_b_parameter_registers |= 1<<6;
										} else if ((used_clean_b_parameter_registers & (1<<5))==0){
											heap_pointer=REGISTER_D5;
											used_clean_b_parameter_registers |= 1<<5;
										} else
											error_s (ccall_error_string,c_function_name);								
										i_move_r_r (HEAP_POINTER,heap_pointer);
									} else {
										if ((used_clean_b_parameter_registers & (1<<5))==0){
											a_stack_pointer=REGISTER_D5;
											used_clean_b_parameter_registers |= 1<<5;
										} else if ((used_clean_b_parameter_registers & (1<<6))==0){
											a_stack_pointer=REGISTER_D6;
											used_clean_b_parameter_registers |= 1<<6;
										} else
											error_s (ccall_error_string,c_function_name);								
										i_move_r_r (A_STACK_POINTER,a_stack_pointer);
									}
								}
								b_o-=STACK_ELEMENT_SIZE;
								i_move_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,c_parameter_reg);
							}
						} else {
							if (l<=last_register_parameter_index){
								i_move_r_pd (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,B_STACK_POINTER);
								used_clean_b_parameter_registers &= ~ (1<<(n_extra_clean_b_register_parameters+reg_n));
								++reg_n;
							} else {
								b_o-=STACK_ELEMENT_SIZE;
								i_move_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,REGISTER_A0);
								i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
							}
							c_offset+=STACK_ELEMENT_SIZE;
						}
						break;
					}
					case 'r':
						--c_parameter_n;
						b_o-=8;
						if (--c_fp_parameter_n<8){
							i_fcvt2s_id_fr (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,c_fp_parameter_n);
							--n_c_fp_register_parameters;
						} else {
							/* xmm8 is a 64 bit linux ABI scratch register */
							i_fcvt2s_id_fr (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,8);
							i_fmoves_fr_id (8,-8,B_STACK_POINTER);
							i_sub_i_r (8,B_STACK_POINTER);
							c_offset+=8;
						}
						break;
					case 'R':
						--c_parameter_n;
						b_o-=8;
						if (--c_fp_parameter_n<8){
							i_fmove_id_fr (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,c_fp_parameter_n);
							--n_c_fp_register_parameters;
						} else {
							int temp_register;

							if ((c_parameter_n-n_c_fp_register_parameters)>2 || n_c_parameters<=2)
								temp_register=REGISTER_A1;
							else if ((used_clean_b_parameter_registers & 1)==0)
								temp_register=REGISTER_D0;
							else if ((used_clean_b_parameter_registers & 2)==0)
								temp_register=REGISTER_D1;
							else if ((used_clean_b_parameter_registers & 4)==0)
								temp_register=REGISTER_D2;
							else
								error_s (ccall_error_string,c_function_name);
	
							i_move_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,temp_register);
							i_move_r_pd (temp_register,B_STACK_POINTER);
							c_offset+=8;
						}
						break;
					case 'S':
					case 's':
					case 'A':
					{
						int offset,c_int_parameter_n;
				
 						offset = sl=='S' ? STACK_ELEMENT_SIZE : sl=='s' ? 2*STACK_ELEMENT_SIZE : 3*STACK_ELEMENT_SIZE;

						--c_parameter_n;
						c_int_parameter_n = c_parameter_n - n_c_fp_register_parameters;
						if (c_int_parameter_n<6){
							int c_parameter_reg;
					
							c_parameter_reg=c_parameter_registers[c_int_parameter_n];
							
							if (c_int_parameter_n<2){
								if (c_int_parameter_n==0){
									if ((used_clean_b_parameter_registers & (1<<6))==0){
										heap_pointer=REGISTER_D6;
										used_clean_b_parameter_registers |= 1<<6;
									} else if ((used_clean_b_parameter_registers & (1<<5))==0){
										heap_pointer=REGISTER_D5;
										used_clean_b_parameter_registers |= 1<<5;
									} else
										error_s (ccall_error_string,c_function_name);								
									i_move_r_r (HEAP_POINTER,heap_pointer);
								} else {
									if ((used_clean_b_parameter_registers & (1<<5))==0){
										a_stack_pointer=REGISTER_D5;
										used_clean_b_parameter_registers |= 1<<5;
									} else if ((used_clean_b_parameter_registers & (1<<6))==0){
										a_stack_pointer=REGISTER_D6;
										used_clean_b_parameter_registers |= 1<<6;
									} else
										error_s (ccall_error_string,c_function_name);								
									i_move_r_r (A_STACK_POINTER,a_stack_pointer);
								}
							}

							i_move_id_r (a_o,a_stack_pointer,c_parameter_reg);
							i_add_i_r (offset,c_parameter_reg);
						} else {
							i_move_id_r (a_o,a_stack_pointer,REGISTER_A0);
							i_add_i_r (offset,REGISTER_A0);
							i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
							c_offset+=STACK_ELEMENT_SIZE;
						}
						a_o+=STACK_ELEMENT_SIZE;
						break;
					}
					case 'F':
					case 'O':
					case '*':
					case ']':
						/* while (l>=0 && !(s[l]=='F' || s[l]=='O')) bug in watcom c */
						while (l>=0 && (s[l]!='F' && s[l]!='O'))
							--l;
						
						if (l<=last_register_parameter_index){
							int clean_b_reg_n,i;
							
							clean_b_reg_n=REGISTER_D0+n_extra_clean_b_register_parameters+reg_n;

							if (function_address_parameter=='O'){
								i_move_r_pd (clean_b_reg_n,B_STACK_POINTER);
								c_offset+=STACK_ELEMENT_SIZE;
							}
							
							++reg_n;

							function_address_reg=clean_b_reg_n;
							i=l;
							while (i+1<length && (s[i+1]=='*' || s[i+1]=='[')){
								int n;
								
								++i;
								n=0;
								
								if (s[i]=='['){
									++i;
									while (i<length && (unsigned)(s[i]-'0')<(unsigned)10){
										n=n*10+(s[i]-'0');
										++i;
									}
								}
								
								i_move_id_r (n,clean_b_reg_n,clean_b_reg_n);
							}
							break;
						}
					default:
						error_s (ccall_error_string,c_function_name);
				}
			}
		}

		if (!save_state_in_global_variables){
			if (a_stack_pointer==A_STACK_POINTER){
				a_stack_pointer = heap_pointer!=REGISTER_D5 ? REGISTER_D5 : REGISTER_D6;
				i_move_r_r (A_STACK_POINTER,a_stack_pointer);
			}
			if (heap_pointer==HEAP_POINTER){
				heap_pointer = a_stack_pointer!=REGISTER_D6 ? REGISTER_D6 : REGISTER_D5;
				i_move_r_r (HEAP_POINTER,heap_pointer);
			}
		}
#   ifndef THREAD64
		else {
			i_move_r_l (a_stack_pointer,saved_a_stack_p_label);
			i_lea_l_i_r (saved_heap_p_label,0,a_stack_pointer);
			i_move_r_id (heap_pointer,0,a_stack_pointer);
			i_move_r_id (REGISTER_D7,8,a_stack_pointer);
		}
#   endif

		if (!function_address_parameter)
			i_jsr_l (label,0);
		else
			i_jsr_r (function_address_reg);

#   ifdef THREAD64
		if (save_state_in_global_variables){
			if (tlsp_tls_index_label==NULL)
				tlsp_tls_index_label=enter_label (STRING_tlsp_tls_index,IMPORT_LABEL);
			if (pthread_getspecific_label==NULL)
				pthread_getspecific_label=enter_label (STRING_pthread_getspecific,IMPORT_LABEL);

			i_sub_i_r (16,B_STACK_POINTER);

			switch (result){
				case 'V':
					i_move_l_r (tlsp_tls_index_label,-7/*RDI*/);
					i_jsr_l (pthread_getspecific_label,0);
					i_move_r_r (REGISTER_D0,-4/*R9*/);
					break;
				case 'R':
					i_fmove_fr_id (0,0,B_STACK_POINTER);
					i_move_l_r (tlsp_tls_index_label,-7/*RDI*/);
					i_jsr_l (pthread_getspecific_label,0);
					i_move_r_r (REGISTER_D0,-4/*R9*/);
					i_fmove_id_fr (0,B_STACK_POINTER,0);
					break;
				default:
					i_move_r_id (REGISTER_D0,0,B_STACK_POINTER);
					i_move_l_r (tlsp_tls_index_label,-7/*RDI*/);
					i_jsr_l (pthread_getspecific_label,0);
					i_move_r_r (REGISTER_D0,-4/*R9*/);
					i_move_id_r (0,B_STACK_POINTER,REGISTER_D0);
			}
		}
#   endif
		
		if (c_offset_before_pushing_arguments-(b_result_offset+a_result_offset)==0)
			i_move_r_r (REGISTER_RBP,B_STACK_POINTER);
		else
			i_lea_id_r (c_offset_before_pushing_arguments-(b_result_offset+a_result_offset),REGISTER_RBP,B_STACK_POINTER);	

		if (!save_state_in_global_variables){
			i_move_r_r (a_stack_pointer,A_STACK_POINTER);
			i_move_r_r (heap_pointer,HEAP_POINTER);
			i_move_id_r (-16,REGISTER_RBP,-4/*R9*/);
		} else {
#   ifdef THREAD64
			i_move_id_r (SAVED_A_STACK_P_OFFSET,-4/*R9*/,A_STACK_POINTER);
			i_move_id_r (SAVED_R15_OFFSET,-4/*R9*/,REGISTER_D7);
			i_move_id_r (SAVED_HEAP_P_OFFSET,-4/*R9*/,-7/*RDI*/);
#   else
			i_lea_l_i_r (saved_heap_p_label,0,-7/*RDI*/);
			i_move_l_r (saved_a_stack_p_label,-6/*RSI*/);
			i_move_id_r (8,-7/*RDI*/,REGISTER_D7);
			i_move_id_r (0,-7/*RDI*/,-7/*RDI*/);
#   endif
		}
#  else /* for I486 && G_AI64 && ! (LINUX_ELF || MACHO_64) */
		{
		int c_offset_before_pushing_arguments,function_address_reg,c_parameter_n;
		
		c_offset_before_pushing_arguments=c_offset;

		c_parameter_n=((a_offset+b_offset+a_result_offset+b_result_offset)>>STACK_ELEMENT_LOG_SIZE)+n_clean_b_register_parameters;

		i_move_r_r (B_STACK_POINTER,REGISTER_RBP);
#   ifdef THREAD64
		if (!save_state_in_global_variables){
			if (c_parameter_n>=4 && (c_parameter_n & 1)!=0){
				i_sub_i_r (16+8,B_STACK_POINTER);
				i_move_r_id (-4/*R9*/,8,B_STACK_POINTER);
				i_or_i_r (8,B_STACK_POINTER);		
			} else {
				i_sub_i_r (16,B_STACK_POINTER);
				i_move_r_id (-4/*R9*/,0,B_STACK_POINTER);
				i_and_i_r (-16,B_STACK_POINTER);		
			}
		} else
#   endif
		if (c_parameter_n>=4 && (c_parameter_n & 1)!=0){
			i_sub_i_r (8,B_STACK_POINTER);
			i_or_i_r (8,B_STACK_POINTER);		
		} else {
			i_and_i_r (-16,B_STACK_POINTER);		
		}

		for (l=length-1; l>=first_pointer_result_index; --l){
			switch (s[l]){
				case 'I':
				case 'p':
					b_o-=STACK_ELEMENT_SIZE;
					if (--c_parameter_n<4)
						i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,REGISTER_A0-c_parameter_n);
					else {
						i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,REGISTER_A0);
						i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
						c_offset+=STACK_ELEMENT_SIZE;
					}
					break;
				case 'R':
					b_o-=8;
					if (--c_parameter_n<4)
						i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,REGISTER_A0-c_parameter_n);
					else {
						i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,REGISTER_A0);
						i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
						c_offset+=STACK_ELEMENT_SIZE;
					}
					break;
				case 'i':
				case 'r':
					--l;
				case 'S':
					if (--c_parameter_n<4)
						i_lea_id_r (a_o+c_offset_before_pushing_arguments,REGISTER_RBP,REGISTER_A0-c_parameter_n);
					else {
						i_lea_id_r (a_o+c_offset_before_pushing_arguments,REGISTER_RBP,REGISTER_A0);
						i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
						c_offset+=STACK_ELEMENT_SIZE;
					}
					a_o+=STACK_ELEMENT_SIZE;
					break;
				case 'V':
					break;
				default:
					error_s (ccall_error_string,c_function_name);
			}
		}
		
		{
			int last_register_parameter_index,reg_n;
			
			last_register_parameter_index=-1;
			
			reg_n=0;
			l=0;
			while (reg_n<n_clean_b_register_parameters && l<min_index){
				if (s[l]=='I' || s[l]=='p' || s[l]=='F' || s[l]=='O'){
					++reg_n;
					last_register_parameter_index=l;
				}
				++l;
			}
			
			reg_n=0;
			a_o=-a_offset;
			b_o=0;
			for (l=min_index-1; l>=0; --l){
				switch (s[l]){
					case 'I':
					case 'p':
						if (--c_parameter_n<4){
							if (l<=last_register_parameter_index){
								i_move_r_r (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,REGISTER_A0-c_parameter_n);
								++reg_n;
							} else {
								b_o-=STACK_ELEMENT_SIZE;
								i_move_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,REGISTER_A0-c_parameter_n);
							}
						} else {
							if (l<=last_register_parameter_index){
								i_move_r_pd (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,B_STACK_POINTER);
								++reg_n;
							} else {
								b_o-=STACK_ELEMENT_SIZE;
								i_move_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,REGISTER_A0);
								i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
							}
							c_offset+=STACK_ELEMENT_SIZE;
						}
						break;
					case 'r':
						b_o-=8;
						if (--c_parameter_n<4)
							i_fcvt2s_id_fr (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,c_parameter_n);
						else {
							/* xmm4 is a 64 bit windows ABI scratch register */
							i_fcvt2s_id_fr (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,4);
							i_fmoves_fr_id (4,-8,B_STACK_POINTER);
							i_sub_i_r (8,B_STACK_POINTER);
							c_offset+=8;
						}
						break;
					case 'R':
						b_o-=8;
						if (--c_parameter_n<4)
							i_fmove_id_fr (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,c_parameter_n);
						else {
							i_move_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_RBP,REGISTER_A0);
							i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
							c_offset+=8;
						}
						break;
					case 'S':
						if (--c_parameter_n<4){
							i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0-c_parameter_n);
							i_add_i_r (STACK_ELEMENT_SIZE,REGISTER_A0-c_parameter_n);
						} else {
							i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0);
							i_add_i_r (STACK_ELEMENT_SIZE,REGISTER_A0);
							i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
							c_offset+=STACK_ELEMENT_SIZE;
						}
						a_o+=STACK_ELEMENT_SIZE;
						break;
					case 's':
						if (--c_parameter_n<4){
							i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0-c_parameter_n);
							i_add_i_r (2*STACK_ELEMENT_SIZE,REGISTER_A0-c_parameter_n);							
						} else {
							i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0);
							i_add_i_r (2*STACK_ELEMENT_SIZE,REGISTER_A0);
							i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
							c_offset+=STACK_ELEMENT_SIZE;
						}
						a_o+=STACK_ELEMENT_SIZE;
						break;
					case 'A':
						if (--c_parameter_n<4){
							i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0-c_parameter_n);
							i_add_i_r (3*STACK_ELEMENT_SIZE,REGISTER_A0-c_parameter_n);
						} else {
							i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0);
							i_add_i_r (3*STACK_ELEMENT_SIZE,REGISTER_A0);
							i_move_r_pd (REGISTER_A0,B_STACK_POINTER);
							c_offset+=STACK_ELEMENT_SIZE;
						}
						a_o+=STACK_ELEMENT_SIZE;
						break;
					case 'F':
					case 'O':
					case '*':
					case ']':
						/* while (l>=0 && !(s[l]=='F' || s[l]=='O')) bug in watcom c */
						while (l>=0 && (s[l]!='F' && s[l]!='O'))
							--l;
						
						if (l<=last_register_parameter_index){
							int clean_b_reg_n,i;
							
							clean_b_reg_n=REGISTER_D0+n_extra_clean_b_register_parameters+reg_n;

							if (function_address_parameter=='O'){
								i_move_r_pd (clean_b_reg_n,B_STACK_POINTER);
								c_offset+=STACK_ELEMENT_SIZE;
							}
							
							++reg_n;

							function_address_reg=clean_b_reg_n;
							i=l;
							while (i+1<length && (s[i+1]=='*' || s[i+1]=='[')){
								int n;
								
								++i;
								n=0;
								
								if (s[i]=='['){
									++i;
									while (i<length && (unsigned)(s[i]-'0')<(unsigned)10){
										n=n*10+(s[i]-'0');
										++i;
									}
								}
								
								i_move_id_r (n,clean_b_reg_n,clean_b_reg_n);
							}
							break;
						}
					default:
						error_s (ccall_error_string,c_function_name);
				}
			}
		}

#   ifndef THREAD64
		if (save_state_in_global_variables){
			i_move_r_l (-6/*RSI*/,saved_a_stack_p_label);
			i_lea_l_i_r (saved_heap_p_label,0,-6/*RSI*/);
			i_move_r_id (-7/*RDI*/,  0,-6/*RSI*/);
			i_move_r_id (REGISTER_D7,8,-6/*RSI*/);
		}
#   endif

		i_sub_i_r (32,B_STACK_POINTER);
		if (!function_address_parameter)
			i_jsr_l (label,0);
		else
			i_jsr_r (function_address_reg);

		/* i_add_i_r (32,B_STACK_POINTER); */
		
		if (c_offset_before_pushing_arguments-(b_result_offset+a_result_offset)==0)
			i_move_r_r (REGISTER_RBP,B_STACK_POINTER);
		else
			i_lea_id_r (c_offset_before_pushing_arguments-(b_result_offset+a_result_offset),REGISTER_RBP,B_STACK_POINTER);	

#   ifdef THREAD64
		if (!save_state_in_global_variables)
			i_move_id_r (-16,REGISTER_RBP,-4/*R9*/);
		else {
			instruction_l_r (ILDTLSP,tlsp_tls_index_label,-4/*R9*/);

			i_move_id_r (SAVED_A_STACK_P_OFFSET,-4/*R9*/,A_STACK_POINTER);
			i_move_id_r (SAVED_R15_OFFSET,-4/*R9*/,REGISTER_D7);
			i_move_id_r (SAVED_HEAP_P_OFFSET,-4/*R9*/,-7/*RDI*/);
		}
#   else
		if (save_state_in_global_variables){
			i_lea_l_i_r (saved_heap_p_label,0,-7/*RDI*/);
			i_move_l_r (saved_a_stack_p_label,-6/*RSI*/);
			i_move_id_r (8,-7/*RDI*/,REGISTER_D7);
			i_move_id_r (0,-7/*RDI*/,-7/*RDI*/);
		}
#   endif
#  endif
		/* for I486 && G_AI64 */

		if (callee_pops_arguments)
			c_offset=c_offset_before_pushing_arguments;
		
		if (a_offset!=0)
			i_sub_i_r (a_offset,A_STACK_POINTER);
		/*
		if (c_offset-(b_result_offset+a_result_offset)!=0)
			i_add_i_r (c_offset-(b_result_offset+a_result_offset),B_STACK_POINTER);
		*/
		}

		for (l=length-1; l>=first_pointer_result_index; --l){
			switch (s[l]){
				case 'S':
					if (string_to_string_node_label==NULL)
						string_to_string_node_label=enter_string_to_string_node_label();
					i_move_pi_r (B_STACK_POINTER,REGISTER_A0);
					i_jsr_l (string_to_string_node_label,0);
					i_move_r_id (REGISTER_A0,0,A_STACK_POINTER);
					i_add_i_r (STACK_ELEMENT_SIZE,A_STACK_POINTER);
					break;
				case 'i':
					--l;
					if (int_array_to_node_label==NULL)
						int_array_to_node_label=enter_label ("int_array_to_node",IMPORT_LABEL);
					i_move_pi_r (B_STACK_POINTER,REGISTER_A0);
					i_jsr_l (int_array_to_node_label,0);
					i_move_r_id (REGISTER_A0,0,A_STACK_POINTER);
					i_add_i_r (STACK_ELEMENT_SIZE,A_STACK_POINTER);
					break;
				case 'r':
					--l;
					if (real_array_to_node_label==NULL)
						real_array_to_node_label=enter_label ("real_array_to_node",IMPORT_LABEL);
					i_move_pi_r (B_STACK_POINTER,REGISTER_A0);
					i_jsr_l (real_array_to_node_label,0);
					i_move_r_id (REGISTER_A0,0,A_STACK_POINTER);
					i_add_i_r (STACK_ELEMENT_SIZE,A_STACK_POINTER);
					break;
				case 'I':
				case 'p':
				case 'R':
				case 'V':
					break;
				default:
					error_s (ccall_error_string,c_function_name);
			}
		}
		
		b_o=0;
		for (l=first_pointer_result_index; l<length; ++l){
			switch (s[l]){
				case 'I':
					i_loadsqb_id_r (b_o,B_STACK_POINTER,REGISTER_RBP);
					i_move_r_id (REGISTER_RBP,b_o,B_STACK_POINTER);
					b_o+=STACK_ELEMENT_SIZE;
					break;
				case 'p':
					b_o+=STACK_ELEMENT_SIZE;
					break;
				case 'R':
					b_o+=8;
					break;
				case 'S':
				case 'V':
					break;
				case 'A':
					++l;
					break;
				default:
					error_s (ccall_error_string,c_function_name);
			}
		}

		switch (result){
			case 'I':
				i_loadsqb_r_r (REGISTER_D0,REGISTER_D0);
			case 'p':
				begin_new_basic_block();
				init_b_stack (1,i_vector);
				break;
			case 'R':
				begin_new_basic_block();
				init_b_stack (1,r_vector);
				break;
			case 'S':
				if (string_to_string_node_label==NULL)
					string_to_string_node_label=enter_string_to_string_node_label();

				i_move_r_r (REGISTER_D0,REGISTER_A0);
				i_jsr_l (string_to_string_node_label,0);

				begin_new_basic_block();
				init_a_stack (1);
				break;
			case 'A':
				i_move_r_r (REGISTER_D0,REGISTER_A0);
				if (s[min_index+2]=='i'){
					if (int_array_to_node_label==NULL)
						int_array_to_node_label=enter_label ("int_array_to_node",IMPORT_LABEL);
					i_jsr_l (int_array_to_node_label,0);
				} else if (s[min_index+2]=='r'){
					if (real_array_to_node_label==NULL)
						real_array_to_node_label=enter_label ("real_array_to_node",IMPORT_LABEL);
					i_jsr_l (real_array_to_node_label,0);
				}

				begin_new_basic_block();
				init_a_stack (1);
				break;
			case 'V':
				begin_new_basic_block();
				break;
			default:
				error_s (ccall_error_string,c_function_name);
		}
# endif

#endif
}

#endif

#define SMALL_VECTOR_SIZE 32
#define LOG_SMALL_VECTOR_SIZE 5
#define MASK_SMALL_VECTOR_SIZE 31

static char centry_error_string[]="Error in c entry of '%s'";

#ifdef G_POWER
extern struct instruction *last_instruction;
extern LABEL *INT_label,*BOOL_label,*CHAR_label,*REAL_label;
extern LABEL *cycle_in_spine_label,*reserve_label;
void code_jsr_from_c_to_clean (char *label_name);

static void load_constant_registers (void)
{
	/*
		lea	a5,__cycle__in__spine
		lea	int_reg,INT2
		lea	char_reg,CHAR2
		lea	real_reg,REAL2
		lea	bool_reg,BOOL2
	*/

	if (INT_label==NULL)
		INT_label=enter_label ("INT",IMPORT_LABEL | DATA_LABEL);
	i_lea_l_i_r (INT_label,2,INT_REGISTER);
	
	if (CHAR_label==NULL)
		CHAR_label=enter_label ("CHAR",IMPORT_LABEL | DATA_LABEL);
	i_lea_l_i_r (CHAR_label,2,CHAR_REGISTER);	

	if (REAL_label==NULL)
		REAL_label=enter_label ("REAL",IMPORT_LABEL | DATA_LABEL);
	i_lea_l_i_r (REAL_label,2,REAL_REGISTER);

	if (BOOL_label==NULL)
		BOOL_label=enter_label ("BOOL",IMPORT_LABEL | DATA_LABEL);
	i_lea_l_i_r (BOOL_label,2,BOOL_REGISTER);
	
	if (!parallel_flag){
		if (cycle_in_spine_label==NULL){
			cycle_in_spine_label=enter_label ("__cycle__in__spine",IMPORT_LABEL | NODE_ENTRY_LABEL);
			cycle_in_spine_label->label_arity=0;
			cycle_in_spine_label->label_descriptor=EMPTY_label;
		}
		i_lea_l_i_r (cycle_in_spine_label,0,REGISTER_A5);
	} else {
		if (reserve_label==NULL){
			reserve_label=enter_label ("__reserve",IMPORT_LABEL | NODE_ENTRY_LABEL);
			reserve_label->label_arity=0;
			reserve_label->label_descriptor=EMPTY_label;
		}
		i_lea_l_i_r (reserve_label,0,REGISTER_A5);
	}
}
#endif

static void save_registers_before_clean_call (void)
{
#if defined (I486)
# ifdef G_AI64
	i_sub_i_r (144,B_STACK_POINTER);

#  if defined (LINUX_ELF) || defined (MACH_O64)
#   ifndef THREAD64
	i_move_r_r (-6/*RSI*/,2/*R10*/);
#   endif
#  else
	i_move_r_id (-6/*RSI*/,136,B_STACK_POINTER);
#  endif
#  ifndef THREAD64
	i_move_l_r (saved_a_stack_p_label,-6/*RSI*/);
#  endif
#  if defined (LINUX_ELF) || defined (MACH_O64)
#   ifndef THREAD64
	i_move_r_r (-7/*RDI*/,3/*R11*/);
#   endif
#  else
	i_move_r_id (-7/*RDI*/,128,B_STACK_POINTER);
#  endif
#  ifndef THREAD64
	i_lea_l_i_r (saved_heap_p_label,0,-7/*RDI*/);
#  endif
	i_move_r_id ( 7/*R15*/,80,B_STACK_POINTER);
#  ifndef THREAD64
	i_move_id_r (8,-7/*RDI*/,REGISTER_D7);
	i_move_id_r (0,-7/*RDI*/,-7/*RDI*/);
#  endif
	i_move_r_id ( 1/*RBX*/,120,B_STACK_POINTER);
	i_move_r_id (-5/*RBP*/,112,B_STACK_POINTER);
	i_move_r_id ( 4/*R12*/,104,B_STACK_POINTER);
	i_move_r_id ( 5/*R13*/,96,B_STACK_POINTER);
	i_move_r_id ( 6/*R14*/,88,B_STACK_POINTER);
#  if ! (defined (LINUX_ELF) || defined (MACH_O64))
	{
		int i;
		/* to do: save all 128 bits, because calling convention has been changed */
		for (i=6; i<16; ++i)
			i_fmove_fr_id (i,(15-i)<<3,B_STACK_POINTER);
	}
#  endif
# else
	i_sub_i_r (20,B_STACK_POINTER);
#  ifndef THREAD32
	i_move_r_id (-4/*ESI*/,16,B_STACK_POINTER);
	i_move_l_r (saved_a_stack_p_label,-4/*ESI*/);

	i_move_r_id (-5/*EDI*/,12,B_STACK_POINTER);
	i_move_l_r (saved_heap_p_label,-5/*EDI*/);
#  else
	if (tlsp_tls_index_label==NULL)
		tlsp_tls_index_label=enter_label (STRING_tlsp_tls_index,IMPORT_LABEL);

	i_move_r_id (-5/*EDI*/,12,B_STACK_POINTER);
	instruction_l_r (ILDTLSP,tlsp_tls_index_label,-5/*EDI*/);

	i_move_r_id (-4/*ESI*/,16,B_STACK_POINTER);
	i_move_id_r (SAVED_A_STACK_P_OFFSET,-5/*EDI*/,-4/*ESI*/);
#  endif
	i_move_r_id (1/*EBX*/,8,B_STACK_POINTER);
	i_move_r_id (-1/*ECX*/,4,B_STACK_POINTER);
	i_move_r_id (-3/*EBP*/,0,B_STACK_POINTER);
# endif
#elif defined (ARM)
	i_sub_i_r (36,B_STACK_POINTER);
	i_move_r_id (REGISTER_D7,32,B_STACK_POINTER);
	i_lea_l_i_r (saved_a_stack_p_label,0,REGISTER_D6);
	i_move_r_id (A_STACK_POINTER,28,B_STACK_POINTER);
	i_move_id_r (0,REGISTER_D6,A_STACK_POINTER);
	i_lea_l_i_r (saved_heap_p_label,0,REGISTER_D6);
	i_move_r_id (HEAP_POINTER,24,B_STACK_POINTER);
	i_move_id_r (0,REGISTER_D6,HEAP_POINTER);
	i_move_r_id (REGISTER_D5,20,B_STACK_POINTER);
	i_move_id_r (4,REGISTER_D6,REGISTER_D5);
	i_move_r_id (REGISTER_A3,16,B_STACK_POINTER);
	i_move_r_id (REGISTER_A0,12,B_STACK_POINTER);
	i_move_r_id (REGISTER_A1,8,B_STACK_POINTER);
	i_move_r_id (REGISTER_A2,4,B_STACK_POINTER);
	i_move_r_id (REGISTER_D0,0,B_STACK_POINTER);
#elif defined (G_POWER)
	{
		int i,offset;
		
		i_sub_i_r (((32-13)<<2)+((32-14)<<3),B_STACK_POINTER);
		
		offset=0;
		for (i=13; i<32; ++i){
			i_move_r_id (i-24,offset,B_STACK_POINTER);
			offset+=4;
		}
		
		for (i=14; i<32; ++i){
			i_fmove_fr_id (i-14,offset,B_STACK_POINTER);
			offset+=8;
		}
	}

	i_lea_l_i_r (saved_a_stack_p_label,0,REGISTER_A3);
	i_move_id_r (0,REGISTER_A3,A_STACK_POINTER);
	i_lea_l_i_r (saved_heap_p_label,0,REGISTER_A3);
	i_move_id_r (0,REGISTER_A3,HEAP_POINTER);
	i_move_id_r (4,REGISTER_A3,REGISTER_D7);
#endif
}

static void restore_registers_after_clean_call (void)
{
#if defined (I486)
# ifdef G_AI64

#  ifdef THREAD64
	if (tlsp_tls_index_label==NULL)
		tlsp_tls_index_label=enter_label (STRING_tlsp_tls_index,IMPORT_LABEL);

	i_move_r_id (-6/*RSI*/,SAVED_A_STACK_P_OFFSET,-4/*R9*/);
	i_move_r_id (-7/*RDI*/,SAVED_HEAP_P_OFFSET,-4/*R9*/);
	i_move_r_id (REGISTER_D7,SAVED_R15_OFFSET,-4/*R9*/);
#  else
	i_move_r_l (-6/*RSI*/,saved_a_stack_p_label);
	i_lea_l_i_r (saved_heap_p_label,0,-6/*RSI*/);
	i_move_r_id (-7/*RDI*/,  0,-6/*RSI*/);
	i_move_r_id (REGISTER_D7,8,-6/*RSI*/);
#  endif
#  if ! (defined (LINUX_ELF) || defined (MACH_O64))
	i_move_id_r (136,B_STACK_POINTER,-6/*RSI*/);
	i_move_id_r (128,B_STACK_POINTER,-7/*RDI*/);
#  endif
	i_move_id_r ( 80,B_STACK_POINTER, 7/*R15*/);
	i_move_id_r (120,B_STACK_POINTER, 1/*RBX*/);
	i_move_id_r (112,B_STACK_POINTER,-5/*RBP*/);
	i_move_id_r (104,B_STACK_POINTER, 4/*R12*/);
	i_move_id_r ( 96,B_STACK_POINTER, 5/*R13*/);
	i_move_id_r ( 88,B_STACK_POINTER, 6/*R14*/);
#  if ! (defined (LINUX_ELF) || defined (MACH_O64))
	{
		int i;
		/* to do: save all 128 bits, because calling convention has been changed */		
		for (i=6; i<16; ++i)
			i_fmove_id_fr ((15-i)<<3,B_STACK_POINTER,i);
	}
#  endif
	i_add_i_r (144,B_STACK_POINTER);
# else
#  ifndef THREAD32
	i_move_r_l (-4/*ESI*/,saved_a_stack_p_label);
	i_move_id_r (16,B_STACK_POINTER,-4/*ESI*/);

	i_move_r_l (-5/*EDI*/,saved_heap_p_label);
	i_move_id_r (12,B_STACK_POINTER,-5/*EDI*/);	
#  else
	i_move_r_id (-4/*ESI*/,SAVED_A_STACK_P_OFFSET,-5/*EDI*/);
	i_move_id_r (16,B_STACK_POINTER,-4/*ESI*/);
	i_move_id_r (12,B_STACK_POINTER,-5/*EDI*/);		
#  endif
	i_move_id_r (8,B_STACK_POINTER,1/*EBX*/);
	i_move_id_r (4,B_STACK_POINTER,-1/*ECX*/);
	i_move_id_r (0,B_STACK_POINTER,-3/*EBP*/);
	i_add_i_r (20,B_STACK_POINTER);
# endif
#elif defined (ARM)
	i_lea_l_i_r (saved_a_stack_p_label,0,REGISTER_D6);
	i_move_r_id (A_STACK_POINTER,0,REGISTER_D6);
	i_move_id_r (28,B_STACK_POINTER,A_STACK_POINTER);
	i_lea_l_i_r (saved_heap_p_label,0,REGISTER_D6);
	i_move_r_id (HEAP_POINTER,0,REGISTER_D6);
	i_move_id_r (24,B_STACK_POINTER,HEAP_POINTER);
	i_move_r_id (REGISTER_D5,4,REGISTER_D6);
	i_move_id_r (20,B_STACK_POINTER,REGISTER_D5);
	i_move_id_r (16,B_STACK_POINTER,REGISTER_A3);
	i_move_id_r (12,B_STACK_POINTER,REGISTER_A0);
	i_move_id_r (8,B_STACK_POINTER,REGISTER_A1);
	i_move_id_r (4,B_STACK_POINTER,REGISTER_A2);
	i_move_id_r (0,B_STACK_POINTER,REGISTER_D0);
	i_add_i_r (32,B_STACK_POINTER);
#elif defined (G_POWER)
	i_lea_l_i_r (saved_a_stack_p_label,0,REGISTER_A3);
	i_move_r_id (A_STACK_POINTER,0,REGISTER_A3);
	i_lea_l_i_r (saved_heap_p_label,0,REGISTER_A3);
	i_move_r_id (HEAP_POINTER,0,REGISTER_A3);
	i_move_r_id (REGISTER_D7,4,REGISTER_A3);

	i_move_r_r (REGISTER_D0,C_PARAMETER_REGISTER_0);

	{
		int i,offset;
		
		offset=0;
		for (i=13; i<32; ++i){
			i_move_id_r (offset,B_STACK_POINTER,i-24);
			offset+=4;
		}
		
		for (i=14; i<32; ++i){
			i_fmove_id_fr (offset,B_STACK_POINTER,i-14);
			offset+=8;
		}

		i_add_i_r (offset,B_STACK_POINTER);
	}
#endif
}

#ifdef THREAD64
static void insert_loads_of_r9_rsi_rdi_and_r15_before_call (struct basic_block *block_with_call)
{
	/* hack to load r9, rsi, rdi and r15 before jmp or call */
# ifndef MACH_O64
	struct instruction *instruction1;
# endif
	struct instruction *instruction2,*instruction3,*instruction4,*jmp_or_call_instruction,*old_second_last_instruction;

# if !(defined (LINUX_ELF) || defined (MACH_O64))
	/* LDTLSP tlsp_tls_index_label,r9 */

	instruction1=(struct instruction*)fast_memory_allocate (sizeof (struct instruction)+2*sizeof (struct parameter));
	instruction1->instruction_icode=ILDTLSP;
	instruction1->instruction_arity=2;
	instruction1->instruction_parameters[0].parameter_type=P_LABEL;
	instruction1->instruction_parameters[0].parameter_data.l=tlsp_tls_index_label;
	instruction1->instruction_parameters[1].parameter_type=P_REGISTER;
	instruction1->instruction_parameters[1].parameter_data.i=-4/*R9*/;

	jmp_or_call_instruction=block_with_call->block_last_instruction;
	old_second_last_instruction=jmp_or_call_instruction->instruction_prev;

	if (old_second_last_instruction==NULL)
		block_with_call->block_instructions=instruction1;
	else
		old_second_last_instruction->instruction_next=instruction1;
	instruction1->instruction_prev=old_second_last_instruction;
# endif

	/* i_move_id_r (SAVED_A_STACK_P_OFFSET,R9,-6 */ /*RSI*/ /*); */

	instruction2=(struct instruction*)fast_memory_allocate (sizeof (struct instruction)+2*sizeof (struct parameter));
	instruction2->instruction_icode=IMOVE;
	instruction2->instruction_arity=2;
	instruction2->instruction_parameters[0].parameter_type=P_INDIRECT;
	instruction2->instruction_parameters[0].parameter_offset=SAVED_A_STACK_P_OFFSET;
	instruction2->instruction_parameters[0].parameter_data.i=-4/*R9*/;
	instruction2->instruction_parameters[1].parameter_type=P_REGISTER;
	instruction2->instruction_parameters[1].parameter_data.i=-6/*RSI*/;

# if !(defined (LINUX_ELF) || defined (MACH_O64))
	instruction1->instruction_next=instruction2;
	instruction2->instruction_prev=instruction1;
# else
	jmp_or_call_instruction=block_with_call->block_last_instruction;
	old_second_last_instruction=jmp_or_call_instruction->instruction_prev;

	if (old_second_last_instruction==NULL)
		block_with_call->block_instructions=instruction2;
	else
		old_second_last_instruction->instruction_next=instruction2;
	instruction2->instruction_prev=old_second_last_instruction;
# endif

	/* i_move_id_r (SAVED_R15_OFFSET,R9,REGISTER_D7); */

	instruction3=(struct instruction*)fast_memory_allocate (sizeof (struct instruction)+2*sizeof (struct parameter));
	instruction3->instruction_icode=IMOVE;
	instruction3->instruction_arity=2;
	instruction3->instruction_parameters[0].parameter_type=P_INDIRECT;
	instruction3->instruction_parameters[0].parameter_offset=SAVED_R15_OFFSET;
	instruction3->instruction_parameters[0].parameter_data.i=-4/*R9*/;
	instruction3->instruction_parameters[1].parameter_type=P_REGISTER;
	instruction3->instruction_parameters[1].parameter_data.i=REGISTER_D7;

	instruction2->instruction_next=instruction3;
	instruction3->instruction_prev=instruction2;

	/* i_move_id_r (SAVED_HEAP_P_OFFSET,R9,-7 */ /*RDI*/ /*); */

	instruction4=(struct instruction*)fast_memory_allocate (sizeof (struct instruction)+2*sizeof (struct parameter));
	instruction4->instruction_icode=IMOVE;
	instruction4->instruction_arity=2;
	instruction4->instruction_parameters[0].parameter_type=P_INDIRECT;
	instruction4->instruction_parameters[0].parameter_offset=SAVED_HEAP_P_OFFSET;
	instruction4->instruction_parameters[0].parameter_data.i=-4/*R9*/;
	instruction4->instruction_parameters[1].parameter_type=P_REGISTER;
	instruction4->instruction_parameters[1].parameter_data.i=-7 /*RDI*/;

	instruction3->instruction_next=instruction4;
	instruction4->instruction_prev=instruction3;

	instruction4->instruction_next=jmp_or_call_instruction;
	jmp_or_call_instruction->instruction_prev=instruction4;
}
#endif

#if defined (THREAD64) && (defined (LINUX_ELF) || defined (MACH_O64))
static void call_pthread_getspecific (int n_integer_parameters,int n_float_parameters)
{
	int float_parameter_n;

	if (tlsp_tls_index_label==NULL)
		tlsp_tls_index_label=enter_label (STRING_tlsp_tls_index,IMPORT_LABEL);
	if (pthread_getspecific_label==NULL)
		pthread_getspecific_label=enter_label (STRING_pthread_getspecific,IMPORT_LABEL);

	if (n_float_parameters>8)
		n_float_parameters=8;

	switch (n_integer_parameters){
		default: /* >=6 */
			i_move_r_r (-4/*R9 */, 4/*R12*/);
		case 5:
			i_move_r_r (-3/*R8 */, 7/*R15*/);
		case 4:
			i_move_r_r (-1/*RCX*/, 6/*R14*/);
		case 3:
			i_move_r_r (-2/*RDX*/, 5/*R13*/);
		case 2:
			i_move_r_r (-6/*RSI*/,-5/*RBP*/);
		case 1:
			i_move_r_r (-7/*RDI*/, 1/*RBX*/);
		case 0:
			break;
	}

	i_sub_i_r (8+(n_float_parameters<<3),B_STACK_POINTER);

	for (float_parameter_n=0; float_parameter_n<n_float_parameters; ++float_parameter_n)
		i_fmove_fr_id (float_parameter_n,float_parameter_n<<3,B_STACK_POINTER);

	i_move_l_r (tlsp_tls_index_label,-7/*RDI*/);
	i_jsr_l (pthread_getspecific_label,0);

	for (float_parameter_n=0; float_parameter_n<n_float_parameters; ++float_parameter_n)
		i_fmove_id_fr (float_parameter_n<<3,B_STACK_POINTER,float_parameter_n);

	i_move_r_r (REGISTER_D0,-4/*R9*/);

	i_add_i_r (8+(n_float_parameters<<3),B_STACK_POINTER);

	switch (n_integer_parameters){
		default: /* >=6 */
		case 5:
			i_move_r_r ( 7/*R15*/,-3/*R8 */);
		case 4:
			i_move_r_r ( 6/*R14*/,-1/*RCX*/);
		case 3:
			i_move_r_r ( 5/*R13*/,-2/*RDX*/);
		case 2:
			i_move_r_r (-5/*RBP*/, 3/*R11*/);
		case 1:
			i_move_r_r ( 1/*RBX*/, 2/*R10*/);
		case 0:
			break;
	}
}
#endif

#if defined (I486) || defined (ARM)
# ifdef G_AI64
#  define REGISTER_EBP_OR_RBP (-5)
# else
#  define REGISTER_EBP_OR_RBP (-3)
# endif
#endif

#if defined (G_AI64) && (defined (LINUX_ELF) || defined (MACH_O64))
static int centry_c_parameter_register_n[6] = {
	3 /*R11 was RDI*/,
	2 /*R10 was RSI*/,
	-2/*RDX*/,
	-1/*RCX*/,
	-3/*R8*/,
# ifndef THREAD64
	-4/*R9*/
# else
	4 /*R12*/
# endif
	};
#endif

void code_centry (char *c_function_name,char *clean_function_label,char *s,int length)
{
#if defined (I486) || defined (ARM) || defined (G_POWER)
	struct block_label *new_label;
	LABEL *label;
	int i,n,callee_pops_arguments,n_integer_and_float_parameters;
	int first_parameter_index,colon_index,first_result_index;
	int n_integer_parameters,n_integer_results,integer_c_function_result;
	int n_float_parameters,n_float_results,float_c_function_result;
	int n_string_or_array_parameters,n_string_or_array_results;
	int string_c_function_result,array_c_function_result,string_or_array_c_function_result;
	int float_parameter_or_result;
# ifdef THREAD64
	struct basic_block *block_with_call;
# endif
# ifdef ARM
#  ifndef G_A64
	INSTRUCTION_GRAPH register_arguments[4];
#  else
	INSTRUCTION_GRAPH register_arguments[6];
#  endif
	int n_pushed_register_result_pointer_parameters;
# endif

#if !defined (THREAD64)
	if (saved_heap_p_label==NULL)
		saved_heap_p_label=enter_label ("saved_heap_p",IMPORT_LABEL);
	if (saved_a_stack_p_label==NULL)
		saved_a_stack_p_label=enter_label ("saved_a_stack_p",IMPORT_LABEL);
#endif

	n_integer_parameters=0;
	n_float_parameters=0;
	n_string_or_array_parameters=0;
	n_integer_results=0;
	n_float_results=0;
	float_parameter_or_result=0;
	n_string_or_array_results=0;

	i=0;
	callee_pops_arguments=0;
	if (length>0 && s[0]=='P'){
		i=1;
		callee_pops_arguments=1;
	}

	integer_c_function_result=0;
	float_c_function_result=0;
	string_c_function_result=0;
	array_c_function_result=0;

	first_parameter_index=i;

	while (i<length){
		char c;
		
		c=s[i];
		if (c=='I')
			++n_integer_parameters;
#if defined (I486) || defined (ARM)
		else if (c=='R'){
			++n_float_parameters;
			float_parameter_or_result=1;
		} else if (c=='S')
			++n_string_or_array_parameters;
		else if (c=='A' && i+1<length){
			c=s[++i];
			if (c=='i')
				++n_string_or_array_parameters;				
			else if (c=='r'){
				++n_string_or_array_parameters;
				float_parameter_or_result=1;
			} else
				error_s (centry_error_string,c_function_name);				
		}
#endif
		else if (c==':'){
			colon_index=i;
			++i;

			if (i<length){
				c=s[i];
				if (c=='V')
					;
				else if (c=='I'){
					integer_c_function_result=1;
					++n_integer_results;
#if defined (I486) || defined (ARM)
				} else if (c=='R'){
					float_c_function_result=1;
					++n_float_results;
					float_parameter_or_result=1;
				} else if (c=='S'){
					string_c_function_result=1;
					++n_string_or_array_results;
				} else if (c=='A' && i+1<length){
					c=s[++i];
					++n_string_or_array_results;
					if (c=='i'){
						array_c_function_result=1;
					} else if (c=='r'){
						array_c_function_result=1;
						float_parameter_or_result=1;
					} else
						error_s (centry_error_string,c_function_name);
#endif
				} else
					error_s (centry_error_string,c_function_name);
				++i;
			}

			first_result_index=i;
			while (i<length){
				c=s[i];
				if (c=='I')
					++n_integer_results;
#if defined (I486) || defined (ARM)
				else if (c=='R'){
					++n_float_results;
					float_parameter_or_result=1;
				} else if (c=='S')
					++n_string_or_array_results;
				else if (c=='A' && i+1<length){
					c=s[++i];
					if (c=='i'){
						++n_string_or_array_results;						
					} else if (c=='r'){
						++n_string_or_array_results;
						float_parameter_or_result=1;
					} else
						error_s (centry_error_string,c_function_name);
				}
#endif
				else
					error_s (centry_error_string,c_function_name);
				++i;
			}
			break;
		} else
			error_s (centry_error_string,c_function_name);
		
		++i;
	}

	string_or_array_c_function_result=string_c_function_result+array_c_function_result;

#if defined (I486) || defined (ARM)
	if (n_integer_results==0 && n_float_results==0 && n_string_or_array_results==0)
#else
	if (n_integer_results!=1)
#endif
		error_s (centry_error_string,c_function_name);

#ifndef G_A64
	n_integer_and_float_parameters=n_integer_parameters+(n_float_parameters<<1);
#else
	n_integer_and_float_parameters=n_integer_parameters+n_float_parameters;
#endif

# if (defined (sparc) && !defined (SOLARIS)) || (defined (I486) && !defined (LINUX_ELF) && !defined (G_AI64)) || (defined (G_POWER) && !defined (LINUX_ELF)) || defined (MACH_O) || defined (MACH_O64)
	{
		char label_name [202];

#  if defined (G_POWER) && !defined (MACH_O)
		label_name[0]='.';
#  else
		label_name[0]='_';
#  endif
		strcpy (&label_name[1],c_function_name);
		
		label=enter_label (label_name,
#  ifdef ARM
							C_ENTRY_LABEL |
#  endif
							EXPORT_LABEL);

# if defined (G_POWER) && defined (MACH_O)
		if (dyld_stub_binding_helper_p_label==NULL)
			dyld_stub_binding_helper_p_label=enter_label ("dyld_stub_binding_helper",IMPORT_LABEL);
# endif
	}
# else
	label=enter_label (c_function_name,
#  ifdef ARM
						C_ENTRY_LABEL |
#  endif
						EXPORT_LABEL);
# endif
	
	new_label=fast_memory_allocate_type (struct block_label);
	new_label->block_label_label=label;
	new_label->block_label_next=NULL;

	label->label_a_stack_size=0;
	label->label_b_stack_size=0;
	label->label_vector=e_vector;
	label->label_flags |= REGISTERS_ALLOCATED;

	generate_code_for_previous_blocks (0);

	if (last_block->block_instructions!=NULL){
		begin_new_basic_block();
		
		last_block->block_begin_module=1;
		last_block->block_link_module=0;
	} else {
		release_a_stack();
		release_b_stack();
		
		if (!last_block->block_begin_module){
			last_block->block_begin_module=1;
			last_block->block_link_module=0;
		}
	}

#ifdef ARM
	n_pushed_register_result_pointer_parameters = 0;
	{
		int first_result_pointer_n,n_result_pointers;

		first_result_pointer_n = n_integer_and_float_parameters+n_string_or_array_parameters;
		if (first_result_pointer_n<4){
			int last_result_pointer_register_n;

			n_result_pointers = n_integer_results-integer_c_function_result+
								n_float_results-float_c_function_result+
								n_string_or_array_results-string_or_array_c_function_result;

			last_result_pointer_register_n = first_result_pointer_n+n_result_pointers;
			if (last_result_pointer_register_n > 4)
				last_result_pointer_register_n = 4;

			n_pushed_register_result_pointer_parameters = last_result_pointer_register_n - first_result_pointer_n;			
			if (n_pushed_register_result_pointer_parameters!=0){
				int register_n;
				
				i_sub_i_r (n_pushed_register_result_pointer_parameters<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
				for (register_n=first_result_pointer_n; register_n<last_result_pointer_register_n; ++register_n)
					i_move_r_id (REGISTER_D4-register_n,(register_n-first_result_pointer_n)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);			
			}
		}
	}
#endif

	save_registers_before_clean_call();

#if defined (THREAD64) && (defined (LINUX_ELF) || defined (MACH_O64))
	call_pthread_getspecific (n_integer_parameters+n_string_or_array_parameters,n_float_parameters);
#endif

#if defined (G_AI64)
	if (n_string_or_array_parameters!=0){
		int register_n;

		for (i=first_parameter_index,register_n=0; i<colon_index && register_n<4; ++i,++register_n){
			char c;

			c=s[i];
			if (c!='R'){
# if defined (LINUX_ELF) || defined (MACH_O64)
				i_move_r_id (centry_c_parameter_register_n[register_n],(18+1+register_n)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
# else
				i_move_r_id (REGISTER_A0-register_n,(18+1+register_n)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
# endif
				if (c=='A')
					++i;
			} else
				i_fmove_fr_id (register_n,(18+1+register_n)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);
		}
	}

	{
		int first_result_pointer_n,n_result_pointers;

		first_result_pointer_n = n_integer_and_float_parameters+n_string_or_array_parameters;
		if (first_result_pointer_n<4){
			int register_n;
			
			n_result_pointers = n_integer_results-integer_c_function_result+
								n_float_results-float_c_function_result+
								n_string_or_array_results-string_or_array_c_function_result;

			for (register_n=first_result_pointer_n; register_n<4 && register_n<first_result_pointer_n+n_result_pointers; ++register_n)
# if defined (LINUX_ELF) || defined (MACH_O64)
				i_move_r_id (centry_c_parameter_register_n[register_n],(18+1+register_n)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);				
# else
				i_move_r_id (REGISTER_A0-register_n,(18+1+register_n)<<STACK_ELEMENT_LOG_SIZE,B_STACK_POINTER);				
# endif
		}
	}
#endif

#if defined (I486) || defined (ARM)
	if (n_string_or_array_parameters!=0){
		int i,offset;

# ifdef THREAD64
#  if !(defined (LINUX_ELF) || defined (MACH_O64))
		instruction_l_r (ILDTLSP,tlsp_tls_index_label,-4/*R9*/);
#  endif
		i_move_id_r (SAVED_A_STACK_P_OFFSET,-4/*R9*/,A_STACK_POINTER);
		i_move_id_r (SAVED_R15_OFFSET,-4/*R9*/,REGISTER_D7);
		i_move_id_r (SAVED_HEAP_P_OFFSET,-4/*R9*/,-7/*RDI*/);
# endif

# if defined (G_A64)
		offset=((18+1+n_integer_parameters+n_string_or_array_parameters)<<STACK_ELEMENT_LOG_SIZE)+(n_float_parameters<<3);
# else
#  ifdef ARM
		offset=36+(n_float_parameters<<3);
		if (n_integer_parameters+n_string_or_array_parameters>4)
			offset += ((n_integer_parameters+n_string_or_array_parameters-4)<<STACK_ELEMENT_LOG_SIZE);
#  else
		offset=24+((n_integer_parameters+n_string_or_array_parameters)<<STACK_ELEMENT_LOG_SIZE)+(n_float_parameters<<3);
#  endif
# endif

# ifdef ARM
		{
		int integer_string_or_array_parameter_n;
			
		integer_string_or_array_parameter_n = n_integer_parameters+n_string_or_array_parameters-1;
# endif

		for (i=colon_index-1; i>=first_parameter_index; --i){
			char c;

			c=s[i];
			if (c=='I'){
				offset-=STACK_ELEMENT_SIZE;
# ifdef ARM
				--integer_string_or_array_parameter_n;
# endif
			} else if (c=='R')
				offset-=8;
			else if (c=='S'){
				if (string_to_string_node_label==NULL)
					string_to_string_node_label=enter_string_to_string_node_label();
				offset-=STACK_ELEMENT_SIZE;
# ifdef ARM
				if (integer_string_or_array_parameter_n<4)
					i_move_r_r (REGISTER_D4-integer_string_or_array_parameter_n,REGISTER_A0);
				else
					i_move_id_r (offset,B_STACK_POINTER,REGISTER_A0);
				--integer_string_or_array_parameter_n;
				i_jsr_l_idu (string_to_string_node_label,-4);
# else
				i_move_id_r (offset,B_STACK_POINTER,REGISTER_A0);
				i_jsr_l (string_to_string_node_label,0);
# endif
				i_move_r_id (REGISTER_A0,0,A_STACK_POINTER);
				i_add_i_r (STACK_ELEMENT_SIZE,A_STACK_POINTER);
			} else if (c=='i'){
				--i;
				if (int_array_to_node_label==NULL)
					int_array_to_node_label=enter_label ("int_array_to_node",IMPORT_LABEL);
				offset-=STACK_ELEMENT_SIZE;
# ifdef ARM
				if (integer_string_or_array_parameter_n<4)
					i_move_r_r (REGISTER_D4-integer_string_or_array_parameter_n,REGISTER_A0);
				else
					i_move_id_r (offset,B_STACK_POINTER,REGISTER_A0);
				--integer_string_or_array_parameter_n;
				i_jsr_l_idu (int_array_to_node_label,-4);
# else
				i_move_id_r (offset,B_STACK_POINTER,REGISTER_A0);
				i_jsr_l (int_array_to_node_label,0);
# endif
				i_move_r_id (REGISTER_A0,0,A_STACK_POINTER);
				i_add_i_r (STACK_ELEMENT_SIZE,A_STACK_POINTER);
			} else if (c=='r'){
				--i;
				if (real_array_to_node_label==NULL)
					real_array_to_node_label=enter_label ("real_array_to_node",IMPORT_LABEL);
				offset-=STACK_ELEMENT_SIZE;
# ifdef ARM
				if (integer_string_or_array_parameter_n<4)
					i_move_r_r (REGISTER_D4-integer_string_or_array_parameter_n,REGISTER_A0);
				else
					i_move_id_r (offset,B_STACK_POINTER,REGISTER_A0);
				--integer_string_or_array_parameter_n;
				i_jsr_l_idu (real_array_to_node_label,-4);
# else
				i_move_id_r (offset,B_STACK_POINTER,REGISTER_A0);
				i_jsr_l (real_array_to_node_label,0);
# endif
				i_move_r_id (REGISTER_A0,0,A_STACK_POINTER);
				i_add_i_r (STACK_ELEMENT_SIZE,A_STACK_POINTER);
			} else
				break;
		}
	}

# ifdef ARM
	}
# endif

#endif

	if (last_block->block_labels==NULL)
		last_block->block_labels=new_label;
	else
		last_block_label->block_label_next=new_label;
	last_block_label=new_label;

	begin_new_basic_block();

	last_block->block_begin_module=0;
	last_block->block_link_module=1;

	reachable=1;
	
	init_a_stack (0);
#ifdef ARM
	if (n_integer_parameters>0){
# ifndef G_A64
		init_b_stack (5,i_i_i_i_i_vector);
# else
		init_b_stack (7,i_i_i_i_i_i_i_vector);
# endif
		register_arguments[0] = s_pop_b();
		register_arguments[1] = s_pop_b();
		register_arguments[2] = s_pop_b();
		register_arguments[3] = s_pop_b();
# ifdef G_A64
		register_arguments[4] = s_pop_b();
		register_arguments[5] = s_pop_b();
# endif
		s_pop_b();
	} else
#endif
	init_b_stack (0,e_vector);

#if defined (I486)
	if (n_string_or_array_parameters!=0){
		int i,offset;

# if defined (G_A64)
		offset=18+1+(n_integer_and_float_parameters+n_string_or_array_parameters-1);
# else
		offset=5+1+(n_integer_and_float_parameters+n_string_or_array_parameters-1);
# endif

		for (i=colon_index-1; i>=first_parameter_index; --i){
			char c;

			c=s[i];
			if (c=='I')
				s_push_b (s_get_b (offset));
			else if (c=='R'){
				s_push_b (s_get_b (offset));
# if !defined (G_A64)
				s_push_b (s_get_b (offset));
# endif
			} else if (c=='S'){
				--offset;
			} else if (c=='i' || c=='r'){
				--i;
				--offset;
			} else
				error ("error in centry");
		}
	} else
#endif
#ifndef ARM
		for (n=0; n<n_integer_and_float_parameters; ++n)
# ifdef G_POWER
			s_push_b (g_g_register (C_PARAMETER_REGISTER_0+((n_integer_parameters-1)-n)));
# else
#  ifdef G_AI64
#   if defined (LINUX_ELF) || defined (MACH_O64)
			if (n>=n_integer_and_float_parameters-6){
#   else
			if (n>=n_integer_and_float_parameters-4){
#   endif
				int register_n;

				register_n = (n_integer_and_float_parameters-1)-n;
				if (s[first_parameter_index+register_n]!='R')
#   if defined (LINUX_ELF) || defined (MACH_O64)
				{
					if ((unsigned)register_n>=6u)
						error ("error in centry");

					register_n = centry_c_parameter_register_n[register_n];
					s_push_b (g_g_register (register_n));
				}
#   else
					s_push_b (g_g_register (REGISTER_A0-register_n));
#   endif
				else
					s_push_b (g_fromf (g_fregister (register_n)));
			} else
#   if defined (LINUX_ELF) || defined (MACH_O64)
				s_push_b (s_get_b (18+1+(n_integer_and_float_parameters-6-1)));
#   else
				s_push_b (s_get_b (18+1+4+(n_integer_and_float_parameters-4-1)));
#   endif
#  else
			s_push_b (s_get_b (5+1+(n_integer_and_float_parameters-1)));
#  endif
# endif
#endif

#ifdef ARM
	{
		int integer_string_or_array_parameter_n,offset,i;

		integer_string_or_array_parameter_n = n_integer_parameters+n_string_or_array_parameters-1;
		offset = 5+(n_integer_and_float_parameters+n_string_or_array_parameters-1);

		for (i=colon_index-1; i>=first_parameter_index; --i){
			char c;

			c=s[i];
			if (c=='I'){
				if (integer_string_or_array_parameter_n<4)
					s_push_b (register_arguments[integer_string_or_array_parameter_n]);				
				else
					s_push_b (s_get_b (offset));					
				--integer_string_or_array_parameter_n;
			} else if (c=='R')
				;
			else if (c=='S'){
				--integer_string_or_array_parameter_n;
				--offset;
			} else if (c=='i' || c=='r'){
				--i;
				--integer_string_or_array_parameter_n;
				--offset;
			} else
				break;
		}
	}
#endif

	{
	ULONG *vector_p;
	static ULONG small_vector;
	
	if (n_integer_and_float_parameters+1<=SMALL_VECTOR_SIZE){
		small_vector=0;
		vector_p=&small_vector;
	} else {
		int n_ulongs;
		
		n_ulongs=(n_integer_and_float_parameters+1+SMALL_VECTOR_SIZE-1)>>LOG_SMALL_VECTOR_SIZE;
		vector_p=(ULONG*)fast_memory_allocate (n_ulongs * sizeof (ULONG));
		
		for (i=0; i<n_ulongs; ++i)
			vector_p[i]=0;
	}

	if (n_float_parameters!=0){
		int i,offset;

		i=first_parameter_index;
		offset=0;

		while (i<length){
			char c;
			
			c=s[i];
			if (c=='I')
				++offset;
			else if (c=='R'){
				vector_p[offset>>LOG_SMALL_VECTOR_SIZE] |= (1<< (offset & MASK_SMALL_VECTOR_SIZE));
				++offset;
#ifndef G_A64
				vector_p[offset>>LOG_SMALL_VECTOR_SIZE] |= (1<< (offset & MASK_SMALL_VECTOR_SIZE));
				++offset;
#endif
			} else if (c=='S')
				;
			else if (c=='A')
				++i;
			else
				break;
			++i;
		}
	}

#ifdef THREAD64
	block_with_call=last_block;
#endif

	code_d (n_string_or_array_parameters,n_integer_and_float_parameters,vector_p);

#ifdef G_POWER
	load_constant_registers();
	code_jsr_from_c_to_clean (clean_function_label);
#else
	code_jsr (clean_function_label);
#endif

	{
		int result_pointer_parameter_offset,n_data_results_registers,n_float_results_registers,n_string_or_array_results_registers;

#ifdef G_AI64
# if defined (LINUX_ELF) || defined (MACH_O64)
		result_pointer_parameter_offset=((18+1+n_integer_and_float_parameters+n_string_or_array_parameters-6)<<STACK_ELEMENT_LOG_SIZE);
# else
		result_pointer_parameter_offset=((18+1+4+n_integer_and_float_parameters+n_string_or_array_parameters-4)<<STACK_ELEMENT_LOG_SIZE);
# endif
#else
# ifdef ARM
		result_pointer_parameter_offset=36+(n_float_parameters<<3);
		if (n_integer_parameters+n_string_or_array_parameters>4)
			result_pointer_parameter_offset += ((n_integer_parameters+n_string_or_array_parameters-4)<<STACK_ELEMENT_LOG_SIZE);
# else
		result_pointer_parameter_offset=20+4+((n_integer_and_float_parameters+n_string_or_array_parameters)<<STACK_ELEMENT_LOG_SIZE);
# endif
#endif
		if (n_integer_results-integer_c_function_result>N_DATA_PARAMETER_REGISTERS)
			result_pointer_parameter_offset+=(n_integer_results-integer_c_function_result-N_DATA_PARAMETER_REGISTERS)<<STACK_ELEMENT_LOG_SIZE;
		if (n_float_results-float_c_function_result>N_FLOAT_PARAMETER_REGISTERS)
			result_pointer_parameter_offset+=(n_float_results-float_c_function_result-N_FLOAT_PARAMETER_REGISTERS)<<3;

		n_data_results_registers=n_integer_results;
		if (n_data_results_registers>N_DATA_PARAMETER_REGISTERS)
			n_data_results_registers=N_DATA_PARAMETER_REGISTERS;

		n_float_results_registers=n_float_results;
		if (n_float_results_registers>N_FLOAT_PARAMETER_REGISTERS)
			n_float_results_registers=N_FLOAT_PARAMETER_REGISTERS;

		n_string_or_array_results_registers=n_string_or_array_results;
		if (n_string_or_array_results_registers>N_ADDRESS_PARAMETER_REGISTERS)
			n_string_or_array_results_registers=N_ADDRESS_PARAMETER_REGISTERS;
		
		{
			int i,data_result_n,float_result_n,result_offset,string_or_array_result_n;

			float_result_n=float_c_function_result;
			data_result_n=integer_c_function_result;
			string_or_array_result_n=string_or_array_c_function_result;

			i=first_result_index;
			result_offset=0;

			while (i<length){
				int c;
				
				i_move_id_r (result_pointer_parameter_offset,B_STACK_POINTER,REGISTER_EBP_OR_RBP);
				result_pointer_parameter_offset+=STACK_ELEMENT_SIZE;

				c=s[i];
				if (c=='I'){
					if (data_result_n<n_data_results_registers)
						i_move_r_id (n_data_results_registers-1-data_result_n,0,REGISTER_EBP_OR_RBP);
					else {
						i_move_id_r (result_offset,B_STACK_POINTER,REGISTER_D0+integer_c_function_result);
						i_move_r_id (REGISTER_D0+integer_c_function_result,0,REGISTER_EBP_OR_RBP);
						result_offset+=STACK_ELEMENT_SIZE;
					}
					++data_result_n;
				} else if (c=='R'){
					if (float_result_n<n_float_results_registers)
						i_fmove_fr_id (n_float_results_registers-1-float_result_n,0,REGISTER_EBP_OR_RBP);
					else {
						i_fmove_id_fr (result_offset,B_STACK_POINTER,float_c_function_result);
						i_fmove_fr_id (float_c_function_result,0,REGISTER_EBP_OR_RBP);
						result_offset+=8;
					}
					++float_result_n;
				} else if (c=='S'){
					int reg_n;
					
					if (string_or_array_result_n<n_string_or_array_results_registers)
						reg_n=REGISTER_A0-(n_string_or_array_results_registers-1-string_or_array_result_n);
					else {
						reg_n=REGISTER_A0-string_or_array_c_function_result;
						i_sub_i_r (4,A_STACK_POINTER);
						i_move_id_r (0,A_STACK_POINTER,reg_n);
					}
					i_add_i_r (STACK_ELEMENT_SIZE,reg_n);
					i_move_r_id (reg_n,0,REGISTER_EBP_OR_RBP);
					++string_or_array_result_n;
				} else if (c=='A'){
					int reg_n;
					
					++i;
					if (string_or_array_result_n<n_string_or_array_results_registers)
						reg_n=REGISTER_A0-(n_string_or_array_results_registers-1-string_or_array_result_n);
					else {
						reg_n=REGISTER_A0-string_or_array_c_function_result;
						i_sub_i_r (4,A_STACK_POINTER);
						i_move_id_r (0,A_STACK_POINTER,reg_n);
					}
					i_add_i_r (STACK_ELEMENT_SIZE*3,reg_n);
					i_move_r_id (reg_n,0,REGISTER_EBP_OR_RBP);
					++string_or_array_result_n;
				} else
					error ("error in centry");
				++i;
			}
		}

# if defined (I486) && !defined (G_AI64)
		if (float_parameter_or_result){
			int freg_n;

			for (freg_n=float_c_function_result; freg_n<8; ++freg_n){
		 		i_word_i (0xdd);
				i_word_i (0xc0+freg_n); /* ffree */
			}
		}
# endif
		
		if (n_integer_results>N_DATA_PARAMETER_REGISTERS || n_float_results>N_FLOAT_PARAMETER_REGISTERS){
			int offset;

			if (n_integer_results>N_DATA_PARAMETER_REGISTERS)
				offset=(n_integer_results-N_DATA_PARAMETER_REGISTERS)<<STACK_ELEMENT_LOG_SIZE;
			else
				offset=0;
			if (n_float_results>N_FLOAT_PARAMETER_REGISTERS)
				offset+=(n_float_results-N_FLOAT_PARAMETER_REGISTERS)<<3;
			i_add_i_r (offset,B_STACK_POINTER);
		}

		if (integer_c_function_result){
#ifdef ARM
			if (n_data_results_registers-1!=REGISTER_D4)
				i_move_r_r (n_data_results_registers-1,REGISTER_D4);		
#else
			if (n_data_results_registers>1)
				i_move_r_r (n_data_results_registers-1,0);
#endif
		} else if (string_c_function_result)
#ifdef ARM
			i_lea_id_r (STACK_ELEMENT_SIZE,REGISTER_A0,REGISTER_D4);
#else
			i_lea_id_r (STACK_ELEMENT_SIZE,REGISTER_A0,REGISTER_D0);
#endif
		else if (array_c_function_result)
#ifdef ARM
			i_lea_id_r (STACK_ELEMENT_SIZE*3,REGISTER_A0,REGISTER_D4);
#else
			i_lea_id_r (STACK_ELEMENT_SIZE*3,REGISTER_A0,REGISTER_D0);
#endif
	}

	if (!float_c_function_result)
		code_o (0,integer_c_function_result+string_or_array_c_function_result,i_vector);
	else
#ifdef G_A64
		code_o (0,float_c_function_result,r_vector);
#else
		code_o (0,float_c_function_result<<1,r_vector);
#endif

	restore_registers_after_clean_call();

	{
		int b_offset,a_stack_size,b_stack_size;
		
		a_stack_size=0;
		b_stack_size=string_or_array_c_function_result+integer_c_function_result;
#ifdef G_A64
		b_stack_size+=float_c_function_result;
#else
		b_stack_size+=float_c_function_result<<1;
#endif

#if ! (defined (sparc))
		b_offset=0;
#else
		b_offset=4;
#endif
		b_offset+=end_basic_block_with_registers_and_return_b_stack_offset (a_stack_size,b_stack_size,
							float_c_function_result ? r_vector : i_vector,N_ADDRESS_PARAMETER_REGISTERS);

# ifdef THREAD64
		if (n_string_or_array_parameters==0)
			insert_loads_of_r9_rsi_rdi_and_r15_before_call (block_with_call);
# endif

#if ! (defined (sparc) || defined (G_POWER))
		if (b_offset!=0)
			if (b_offset>0)
				i_add_i_r (b_offset,B_STACK_POINTER);
			else
				i_sub_i_r (-b_offset,B_STACK_POINTER);
# ifdef I486
		if (callee_pops_arguments && n_integer_and_float_parameters+n_string_or_array_parameters>0)
			i_rts_i ((n_integer_and_float_parameters+n_string_or_array_parameters)<<2);
		else
# endif

#ifdef ARM
		if (n_pushed_register_result_pointer_parameters!=0)
			i_rts_i ((n_pushed_register_result_pointer_parameters+1)<<STACK_ELEMENT_LOG_SIZE);
		else
#endif
		i_rts();
#else
# ifdef G_POWER
		if (b_offset!=0)
			if (b_offset>0)
				i_add_i_r (b_offset,B_STACK_POINTER);
			else
				i_sub_i_r (-b_offset,B_STACK_POINTER);
		i_rts_c();
# else
		i_rts (b_offset-4,b_offset);
# endif
#endif
		reachable=0;
		
		begin_new_basic_block();
	}

	}
#endif
}

void code_load_i (CleanInt offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_pop_b ();
	graph_2=g_load_id (offset,graph_1);
	
	s_push_b (graph_2);
}

void code_load_si16 (CleanInt offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_pop_b ();
	graph_2=g_load_des_id (offset,graph_1);

	s_push_b (graph_2);
}

#ifdef G_A64
void code_load_si32 (CleanInt offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_pop_b ();
	graph_2=g_load_sqb_id (offset,graph_1);

	s_push_b (graph_2);
}
#endif

void code_load_ui8 (CleanInt offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_pop_b ();
	graph_2=g_load_b_id (offset,graph_1);

	s_push_b (graph_2);
}

void code_new_int_reducer (char label_name[],int a_offset)
{
	LABEL *reducer_label;
	INSTRUCTION_GRAPH graph_1,graph_2;

#ifdef RESERVE_NEW_REDUCER
	INSTRUCTION_GRAPH graph_3;
	LABEL *node_entry_label;
#endif
	
	if (new_int_reducer_label==NULL)
		new_int_reducer_label=enter_label ("new_int_reducer",IMPORT_LABEL);
	
	reducer_label=enter_label (label_name,0);

	graph_1=s_get_a (a_offset);
	graph_2=g_lea (reducer_label);

#ifdef RESERVE_NEW_REDUCER
	if (EMPTY_label==NULL)
		EMPTY_label=enter_label ("EMPTY",IMPORT_LABEL | DATA_LABEL);
	
	switch (graph_1->instruction_code){
		case GFILL:
			graph_3=graph_1->instruction_parameters[1].p;
			if (graph_3->instruction_code==GLEA){
				node_entry_label=graph_3->instruction_parameters[0].l;
				if (node_entry_label->label_flags & NODE_ENTRY_LABEL){
					char cycle_in_spine_label_n [64];
					LABEL *cycle_label_n;
					int n_arguments;
					
					n_arguments=node_entry_label->label_arity;
					
					sprintf (cycle_in_spine_label_n,"_c%d",n_arguments);
					cycle_label_n=enter_label (cycle_in_spine_label_n,NODE_ENTRY_LABEL | IMPORT_LABEL);
					cycle_label_n->label_arity=n_arguments;
					cycle_label_n->label_descriptor=EMPTY_label;

					graph_1->instruction_parameters[1].p=g_lea (cycle_label_n);
					break;
				}
			}
			graph_3=NULL;
			break;
		case GCREATE:
			graph_3=graph_1->instruction_parameters[0].p;
			if (graph_3->instruction_code==GLEA){
				node_entry_label=graph_3->instruction_parameters[0].l;
				if (node_entry_label->label_flags & NODE_ENTRY_LABEL){
					char cycle_in_spine_label_n [64];
					LABEL *cycle_label_n;
					int n_arguments;
					
					n_arguments=node_entry_label->label_arity;
					
					sprintf (cycle_in_spine_label_n,"_c%d",n_arguments);
					cycle_label_n=enter_label (cycle_in_spine_label_n,NODE_ENTRY_LABEL | IMPORT_LABEL);
					cycle_label_n->label_arity=n_arguments;
					cycle_label_n->label_descriptor=EMPTY_label;

					graph_1->instruction_parameters[0].p=g_lea (cycle_label_n);
					break;
				}
			}
		default:
			graph_3=NULL;
	}

	if (graph_3==NULL)
		error ("error: argument of new_int_reducer is not a closure");
#endif
	
	s_push_a (graph_1);

	s_push_b (NULL);
	s_push_b (graph_2);

#ifdef RESERVE_NEW_REDUCER
	s_push_b (graph_3);
	insert_basic_block (JSR_BLOCK,1,2+1,i_i_i_vector,new_int_reducer_label);
#else
	insert_basic_block (JSR_BLOCK,1,1+1,i_i_vector,new_int_reducer_label);
#endif
}

void code_set_defer (int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	LABEL *node_entry_label;

	if (EMPTY_label==NULL)
		EMPTY_label=enter_label ("EMPTY",IMPORT_LABEL | DATA_LABEL);

	graph_1=s_get_a (a_offset);
	
	switch (graph_1->instruction_code){
		case GFILL:
			graph_2=graph_1->instruction_parameters[1].p;
			if (graph_2->instruction_code==GLEA){
				node_entry_label=graph_2->instruction_parameters[0].l;
				if (node_entry_label->label_flags & NODE_ENTRY_LABEL){
					LABEL *label;
#ifdef RESERVE_NEW_REDUCER
					label=new_local_label (DEFERED_LABEL | NODE_ENTRY_LABEL);
#else
					label=new_local_label (DEFERED_LABEL);
#endif
					label->label_arity=node_entry_label->label_arity;
					label->label_descriptor=node_entry_label;

					graph_1->instruction_parameters[1].p=g_lea (label);
					return;
				}
			}
			break;
		case GCREATE:
			graph_2=graph_1->instruction_parameters[0].p;
			if (graph_2->instruction_code==GLEA){
				node_entry_label=graph_2->instruction_parameters[0].l;
				if (node_entry_label->label_flags & NODE_ENTRY_LABEL){
					LABEL *label;
					
#ifdef RESERVE_NEW_REDUCER
					label=new_local_label (DEFERED_LABEL | NODE_ENTRY_LABEL);
#else
					label=new_local_label (DEFERED_LABEL);
#endif
					label->label_arity=node_entry_label->label_arity;
					label->label_descriptor=node_entry_label;
					
					graph_1->instruction_parameters[0].p=g_lea (label);
					return;
				}
			}
	}

	error ("error: argument of set_defer is not a closure");
}

void code_channelP (int a_offset)
{
	INSTRUCTION_GRAPH graph_1;
		
	if (channelP_label==NULL)
		channelP_label=enter_label ("channelP",IMPORT_LABEL);

	graph_1=s_get_a (a_offset);
	
	s_push_a (graph_1);
	s_push_b (NULL);
	insert_basic_block (JSR_BLOCK,1,0+1,i_vector,channelP_label);
		
	init_b_stack (1,i_vector);
}

void code_stop_reducer (VOID)
{
	if (stop_reducer_label==NULL)
		stop_reducer_label=enter_label ("stop_reducer",IMPORT_LABEL);

	end_basic_block_with_registers (0,0,e_vector);

	i_jmp_l (stop_reducer_label,0);

	reachable=0;

	begin_new_basic_block();	
}

void code_send_graph (char descriptor_name[],int a_offset_1,int a_offset_2)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	LABEL *descriptor_label;

	if (send_graph_label==NULL)
		send_graph_label=enter_label ("send_graph",IMPORT_LABEL);

	descriptor_label=enter_label (descriptor_name,0);

	graph_1=g_lea (descriptor_label);
	graph_2=s_get_a (a_offset_1);
	graph_3=s_get_a (a_offset_2);

	s_push_a (graph_2);
	s_push_a (graph_3);

	s_push_b (NULL);
	s_push_b (graph_1);
	insert_basic_block (JSR_BLOCK,2,1+1,i_i_vector,send_graph_label);
}

void code_send_request (int a_offset)
{
	INSTRUCTION_GRAPH graph_1;
	
	if (send_request_label==NULL)
		send_request_label=enter_label ("send_request",IMPORT_LABEL);
	
	graph_1=s_get_a (a_offset);
	
	s_push_a (graph_1);
	
	s_push_b (NULL);
	insert_basic_block (JSR_BLOCK,1,0+1,e_vector,send_request_label);
}

void code_set_continue (int a_offset)
{
	LABEL *reducer_label;
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	if (new_int_reducer_label==NULL)
		new_int_reducer_label=enter_label ("new_int_reducer",IMPORT_LABEL);
	
	reducer_label=enter_label ("__nf__reducer",0);
	
	graph_1=s_get_a (a_offset);
	graph_2=g_lea (reducer_label);
	
	s_push_a (graph_1);
	
	s_push_b (NULL);
	s_push_b (graph_2);
	
	insert_basic_block (JSR_BLOCK,1,1+1,i_i_vector,new_int_reducer_label);
}

void code_copy_graph (int a_offset)
{
	INSTRUCTION_GRAPH graph_1;
	
	if (copy_graph_label==NULL)
		copy_graph_label=enter_label ("copy_graph",IMPORT_LABEL);
	
	graph_1=s_get_a (a_offset);
	s_push_a (graph_1);

	s_push_b (NULL);
	insert_basic_block (JSR_BLOCK,1,0+1,e_vector,copy_graph_label);
	
	init_a_stack (1);
}

void code_create_channel (char *label_name)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	LABEL *label;
	
	if (CHANNEL_label==NULL)
		CHANNEL_label=enter_label ("CHANNEL",DATA_LABEL);
	if (create_channel_label==NULL)
		create_channel_label=enter_label ("create_channel",IMPORT_LABEL);
	
	label=enter_label (label_name,NODE_ENTRY_LABEL);
	label->label_arity=1;
	label->label_descriptor=CHANNEL_label;
	
	graph_1=s_pop_b();
	graph_2=g_lea (label);

	s_push_b (NULL);
	s_push_b (graph_1);
	s_push_b (graph_2);
	
	insert_basic_block (JSR_BLOCK,0,2+1,i_i_i_vector,create_channel_label);
	
	init_a_stack (1);
}

void code_currentP (void)
{
	if (currentP_label==NULL)
		currentP_label=enter_label ("currentP",IMPORT_LABEL);

	s_push_b (NULL);
	insert_basic_block (JSR_BLOCK,0,0+1,i_vector,currentP_label);
		
	init_b_stack (1,i_vector);
}

void code_new_ext_reducer (char descriptor_name[],int a_offset)
{
#pragma unused (descriptor_name,a_offset)
/*
	LABEL *descriptor_label;
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	if (new_ext_reducer_label==NULL)
		new_ext_reducer_label=enter_label ("new_ext_reducer",IMPORT_LABEL);
	
	descriptor_label=enter_label (descriptor_name,0);
	
	graph_1=s_get_a (a_offset);
	graph_2=g_lea (descriptor_label);

	s_push_a (graph_1);
	
	s_push_b (NULL);
	s_push_b (graph_2);
		
	insert_basic_block (JSR_BLOCK,1,1+1,i_i_vector,new_ext_reducer_label);
*/
}

void code_newP (void)
{
	if (newP_label==NULL)
		newP_label=enter_label ("newP",IMPORT_LABEL);

	s_push_b (NULL);
	insert_basic_block (JSR_BLOCK,0,0+1,i_vector,newP_label);
		
	init_b_stack (1,i_vector);
}

void code_parallel (VOID)
{
}

void code_pause (VOID)
{
	error ("ABC instruction 'pause' not implemented");
}

void code_randomP (void)
{
	if (randomP_label==NULL)
		randomP_label=enter_label ("randomP",IMPORT_LABEL);

	s_push_b (NULL);
	insert_basic_block (JSR_BLOCK,0,0+1,i_vector,randomP_label);
		
	init_b_stack (1,i_vector);
}

void code_suspend (VOID)
{
	if (suspend_label==NULL)
		suspend_label=enter_label ("suspend",IMPORT_LABEL);

	s_push_b (NULL);
	insert_basic_block (JSR_BLOCK,0,0+1,i_vector,suspend_label);
}

void code_add_args (int source_offset,int n_arguments,int destination_offset)
{
#	pragma unused (source_offset,n_arguments,destination_offset)

	error ("ABC instruction 'add_args' not implemented");
}

void code_dummy (VOID)
{
}

extern LABEL *cat_string_label;

void code_catS (int source_offset_1,int source_offset_2,int destination_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	if (cat_string_label==NULL)
#if defined (G_AI64) && defined (LINUX)
    if (rts_got_flag)
		cat_string_label=enter_label ("cat_string",IMPORT_LABEL | USE_GOT_LABEL);
	else
#endif
		cat_string_label=enter_label ("cat_string",IMPORT_LABEL);
	
	graph_1=s_get_a (source_offset_1);
	graph_2=s_get_a (source_offset_2);
	graph_3=s_get_a (destination_offset);
	
	s_push_a (graph_3);
	s_push_a (graph_2);
	s_push_a (graph_1);

	s_push_b (NULL);

	insert_basic_block (JSR_BLOCK,3,0+1,e_vector,cat_string_label);
}

void init_cginstructions (void)
{
	if (check_stack){
		if (parallel_flag){
			realloc_0_label=enter_label ("realloc_0",IMPORT_LABEL);
			realloc_1_label=enter_label ("realloc_1",IMPORT_LABEL);
			realloc_2_label=enter_label ("realloc_2",IMPORT_LABEL);
			realloc_3_label=enter_label ("realloc_3",IMPORT_LABEL);
		} else {
			stack_overflow_label=enter_label ("stack_overflow",IMPORT_LABEL);
			stack_overflow_label->label_id=next_label_id++;
		}
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
			end_a_stack_label=enter_label ("end_a_stack",IMPORT_LABEL);
			end_a_stack_label->label_id=next_label_id++;
			end_b_stack_label=enter_label ("end_b_stack",IMPORT_LABEL);
			end_b_stack_label->label_id=next_label_id++;
#endif
	}

	if (parallel_flag){
		schedule_0_label=enter_label ("schedule_0",IMPORT_LABEL);
		schedule_1_label=enter_label ("schedule_1",IMPORT_LABEL);
		schedule_2_label=enter_label ("schedule_2",IMPORT_LABEL);
		schedule_3_label=enter_label ("schedule_3",IMPORT_LABEL);
		schedule_eval_label=enter_label ("schedule_eval",IMPORT_LABEL);
	}

	profile_function_label=NULL;
	profile_flag=PROFILE_NORMAL;

#if defined (G_POWER) || defined (I486) || defined (ARM)
	profile_l_label=NULL;
	profile_l2_label=NULL;
	profile_n_label=NULL;
	profile_n2_label=NULL;
	profile_s_label=NULL;
	profile_s2_label=NULL;
	profile_r_label=NULL;
	profile_t_label=NULL;
# if defined (G_POWER) || (defined (ARM) && !defined (G_A64))
	profile_ti_label=NULL;
# endif
#endif
#if ((defined (I486) || defined (ARM)) && !defined (THREAD64)) || defined (G_POWER)
	saved_heap_p_label=NULL;
	saved_a_stack_p_label=NULL;
#endif
#ifdef MACH_O
	dyld_stub_binding_helper_p_label=NULL;
#endif
}
