/*
	File: 	cgcalc.c
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
#include "cgconst.h"

#include "cgcalc.h"

#include "cgstack.h"

#define MAX(a,b) ((a)>(b)?(a):(b))

enum { R_NOMODE=0, R_AREGISTER, R_DREGISTER, R_MEMORY, R_IMMEDIATE };

#undef PRINT_DEBUG

static void calculate_dyadic_commutative_operator (INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs;
	int l_aregs,r_aregs,l_dregs,r_dregs;	
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
	
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	
	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;
	
	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
		
	r_aregs=MAX (graph_2->u_aregs,graph_2->i_aregs+graph_1->u_aregs);
	r_dregs=MAX (graph_2->u_dregs,graph_2->i_dregs+graph_1->u_dregs);
	
	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;
		
	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;
	
	if (graph->instruction_d_min_a_cost<=0){
		++i_dregs;
			
		if (l_dregs<i_dregs)
			l_dregs=i_dregs;
		if (r_dregs<i_dregs)
			r_dregs=i_dregs;
	
		graph->order_mode=R_DREGISTER;
	} else {
		++i_aregs;
		
		if (l_aregs<i_aregs)
			l_aregs=i_aregs;
		if (r_aregs<i_aregs)
			r_aregs=i_aregs;
	
		graph->order_mode=R_AREGISTER;
	}

	if (AD_REG_WEIGHT (l_aregs,l_dregs) < AD_REG_WEIGHT (r_aregs,r_dregs)){
		graph->u_aregs=l_aregs;
		graph->u_dregs=l_dregs;
		graph->order_left=1;
	} else {
		graph->u_aregs=r_aregs;
		graph->u_dregs=r_dregs;
		graph->order_left=0;
	}
		
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	
	graph->order_alterable=graph->node_count<=1;
#ifdef PRINT_DEBUG
	printf ("GADD ud=%d id=%d ua=%d ia=%d\n",
			graph->u_dregs,graph->i_dregs,graph->u_aregs,graph->i_aregs);
#endif
}

static void calculate_dyadic_commutative_data_operator (INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs;
	int l_aregs,r_aregs,l_dregs,r_dregs;	
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
	
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	
	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;
	
	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
		
	r_aregs=MAX (graph_2->u_aregs,graph_2->i_aregs+graph_1->u_aregs);
	r_dregs=MAX (graph_2->u_dregs,graph_2->i_dregs+graph_1->u_dregs);
	
	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;
		
	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;
	
	if (graph_1->order_mode==R_AREGISTER && graph_2->order_mode==R_AREGISTER){
		if (l_dregs<i_dregs+2)
			l_dregs=i_dregs+2;
		if (r_dregs<i_dregs+2)
			r_dregs=i_dregs+2;
	} else {
		if (l_dregs<i_dregs+1)
			l_dregs=i_dregs+1;
		if (r_dregs<i_dregs+1)
			r_dregs=i_dregs+1;
	}
	
	if (graph->instruction_d_min_a_cost<=0){
		++i_dregs;
		graph->order_mode=R_DREGISTER;
	} else {
		++i_aregs;
	
		if (l_aregs<i_aregs)
			l_aregs=i_aregs;
		if (r_aregs<i_aregs)
			r_aregs=i_aregs;
	
		graph->order_mode=R_AREGISTER;
	}
	
	if (AD_REG_WEIGHT (l_aregs,l_dregs) < AD_REG_WEIGHT (r_aregs,r_dregs)){
		graph->u_aregs=l_aregs;
		graph->u_dregs=l_dregs;
		graph->order_left=1;
	} else {
		graph->u_aregs=r_aregs;
		graph->u_dregs=r_dregs;
		graph->order_left=0;
	}
		
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	
	graph->order_alterable=graph->node_count<=1;
	return;
}

static void calculate_eor_operator (INSTRUCTION_GRAPH graph)
{
	register INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs;
	int l_aregs,r_aregs,l_dregs,r_dregs;	
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
	
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	
	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;
	
	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
		
	r_aregs=MAX (graph_2->u_aregs,graph_2->i_aregs+graph_1->u_aregs);
	r_dregs=MAX (graph_2->u_dregs,graph_2->i_dregs+graph_1->u_dregs);
	
	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;
		
	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;
	
	if ((graph_1->order_mode==R_AREGISTER || graph_1->order_mode==R_MEMORY)
		&& (graph_2->order_mode==R_AREGISTER || graph_2->order_mode==R_MEMORY))
	{
		if (l_dregs<i_dregs+2)
			l_dregs=i_dregs+2;
		if (r_dregs<i_dregs+2)
			r_dregs=i_dregs+2;
	} else {
		if (l_dregs<i_dregs+1)
			l_dregs=i_dregs+1;
		if (r_dregs<i_dregs+1)
			r_dregs=i_dregs+1;
	}
	
	if (graph->instruction_d_min_a_cost<=0){
		++i_dregs;
		graph->order_mode=R_DREGISTER;
	} else {
		++i_aregs;
	
		if (l_aregs<i_aregs)
			l_aregs=i_aregs;
		if (r_aregs<i_aregs)
			r_aregs=i_aregs;
	
		graph->order_mode=R_AREGISTER;
	}
	
	if (AD_REG_WEIGHT (l_aregs,l_dregs) < AD_REG_WEIGHT (r_aregs,r_dregs)){
		graph->u_aregs=l_aregs;
		graph->u_dregs=l_dregs;
		graph->order_left=1;
	} else {
		graph->u_aregs=r_aregs;
		graph->u_dregs=r_dregs;
		graph->order_left=0;
	}
		
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	
	graph->order_alterable=graph->node_count<=1;
}

#if defined (I486) || (defined (ARM) && !defined (G_A64))
static void calculate_mulud_operator (INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs,l_aregs,r_aregs,l_dregs,r_dregs;	

	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
	
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	
	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;
	
	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
		
	r_aregs=MAX (graph_2->u_aregs,graph_2->i_aregs+graph_1->u_aregs);
	r_dregs=MAX (graph_2->u_dregs,graph_2->i_dregs+graph_1->u_dregs);
	
	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;
		
	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;
	
	i_dregs+=2;

	if (l_dregs<i_dregs)
		l_dregs=i_dregs;
	if (r_dregs<i_dregs)
		r_dregs=i_dregs;
	
	graph->order_mode=R_DREGISTER;
	
	if (AD_REG_WEIGHT (l_aregs,l_dregs) < AD_REG_WEIGHT (r_aregs,r_dregs)){
		graph->u_aregs=l_aregs;
		graph->u_dregs=l_dregs;
		graph->order_left=1;
	} else {
		graph->u_aregs=r_aregs;
		graph->u_dregs=r_dregs;
		graph->order_left=0;
	}
	
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	
	graph->order_alterable=0;
}
#endif

#if defined (I486) || defined (ARM)
static void calculate_divdu_operator (INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	int i_aregs,i_dregs,aregs,dregs;

	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
	graph_3=graph->instruction_parameters[2].p;
	
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	calculate_graph_register_uses (graph_3);
	
	i_aregs=graph_1->i_aregs+graph_2->i_aregs+graph_3->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs+graph_3->i_dregs;
	
	aregs=MAX (	MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs),
				graph_1->i_aregs+graph_2->i_aregs+graph_3->u_aregs);
	dregs=MAX (	MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs),
				graph_1->i_dregs+graph_2->i_dregs+graph_3->u_dregs);
	
	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;
		
	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;

	if (graph_3->order_mode==R_DREGISTER)
		i_dregs-=graph_3->order_alterable;
	else
		i_aregs-=graph_3->order_alterable;
	
	i_dregs+=2;

	if (dregs<i_dregs)
		dregs=i_dregs;

	graph->order_mode=R_DREGISTER;
	
	graph->u_aregs=aregs;
	graph->u_dregs=dregs;
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	
	graph->order_alterable=0;
}
#endif

static void calculate_dyadic_float_operator (INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs;
	int l_aregs,r_aregs,l_dregs,r_dregs;	
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
	
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	
	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;
	
	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
		
	r_aregs=MAX (graph_2->u_aregs,graph_2->i_aregs+graph_1->u_aregs);
	r_dregs=MAX (graph_2->u_dregs,graph_2->i_dregs+graph_1->u_dregs);
	
	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;
		
	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;
				
	++i_dregs;
			
	if (l_dregs<i_dregs)
		l_dregs=i_dregs;
	if (r_dregs<i_dregs)
		r_dregs=i_dregs;

	if (AD_REG_WEIGHT (l_aregs,l_dregs) < AD_REG_WEIGHT (r_aregs,r_dregs)){
		graph->u_aregs=l_aregs;
		graph->u_dregs=l_dregs;
		graph->order_left=1;
	} else {
		graph->u_aregs=r_aregs;
		graph->u_dregs=r_dregs;
		graph->order_left=0;
	}
	
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
		
	graph->order_mode=R_DREGISTER;
	graph->order_alterable=graph->node_count<=1;;
	
#ifdef PRINT_DEBUG
	printf ("dyadic_float_operator ud=%d id=%d ua=%d ia=%d\n",
			graph->u_dregs,graph->i_dregs,graph->u_aregs,graph->i_aregs);
#endif
}

static void calculate_compare_descriptor_indirect (	register INSTRUCTION_GRAPH graph,
													register INSTRUCTION_GRAPH graph_1)
{
	calculate_graph_register_uses (graph_1);
	
	graph->u_dregs=graph_1->u_dregs;
	graph->u_aregs=graph_1->u_aregs;
	graph->i_aregs=graph_1->i_aregs;
	graph->i_dregs=graph_1->i_dregs;
	
	if (graph_1->order_mode==R_DREGISTER)
		graph->i_dregs-=graph_1->order_alterable;
	else
		graph->i_aregs-=graph_1->order_alterable;
		
	if (graph->u_dregs<graph->i_dregs+1)
		graph->u_dregs=graph->i_dregs+1;

	if (graph->instruction_d_min_a_cost<=0){
		++graph->i_dregs;
		graph->order_mode=R_DREGISTER;
	} else {
		++graph->i_aregs;
		if (graph->u_aregs<graph->i_aregs)
			graph->u_aregs=graph->i_aregs;
		graph->order_mode=R_AREGISTER;
	}
	
	graph->order_alterable=graph->node_count<=1;
}

static void calculate_compare_operator (INSTRUCTION_GRAPH graph)
{
	register INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs,l_aregs,r_aregs,l_dregs,r_dregs;
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;

	if (graph_1->instruction_code==GLOAD_DES_ID && graph_1->node_count==1
		&& graph_2->instruction_code==GLOAD_DES_I && graph_2->node_count==1){
		calculate_compare_descriptor_indirect (graph,graph_1->instruction_parameters[1].p);
		return;
	}
	
	if (graph_2->instruction_code==GLOAD_DES_ID && graph_2->node_count==1
		&& graph_1->instruction_code==GLOAD_DES_I && graph_1->node_count==1){
		calculate_compare_descriptor_indirect (graph,graph_2->instruction_parameters[1].p);
		return;
	}
		
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	
	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;
	
	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
		
	r_aregs=MAX (graph_2->u_aregs,graph_2->i_aregs+graph_1->u_aregs);
	r_dregs=MAX (graph_2->u_dregs,graph_2->i_dregs+graph_1->u_dregs);
	
	if ((graph_1->order_mode==R_MEMORY && graph_2->order_mode==R_MEMORY
		 && !graph_1->order_alterable && !graph_2->order_alterable)
		|| (graph_1->order_mode==R_IMMEDIATE && graph_2->order_mode==R_IMMEDIATE))
	{
		if (l_dregs<i_dregs+1)
			l_dregs=i_dregs+1;
		if (r_dregs<i_dregs+1)
			r_dregs=i_dregs+1;
	}
	
	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;
		
	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;

	if (l_dregs<i_dregs+1)
		l_dregs=i_dregs+1;
	if (r_dregs<i_dregs+1)
		r_dregs=i_dregs+1;
		
	if (graph->instruction_d_min_a_cost<=0){
		++i_dregs;
		graph->order_mode=R_DREGISTER;
	} else {
		++i_aregs;
		
		if (l_aregs<i_aregs)
			l_aregs=i_aregs;
		if (r_aregs<i_aregs)
			r_aregs=i_aregs;
	
		graph->order_mode=R_AREGISTER;
	}
	
	if (AD_REG_WEIGHT (l_aregs,l_dregs) < AD_REG_WEIGHT (r_aregs,r_dregs)){
		graph->u_aregs=l_aregs;
		graph->u_dregs=l_dregs;
		graph->order_left=1;
	} else {
		graph->u_aregs=r_aregs;
		graph->u_dregs=r_dregs;
		graph->order_left=0;
	}
		
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	
	graph->order_alterable=graph->node_count<=1;
}

static void calculate_dyadic_non_commutative_operator (INSTRUCTION_GRAPH graph)
{
	register INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs;
	int l_aregs,r_aregs,l_dregs,r_dregs;	
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
	
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	
	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;
	
	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
		
	r_aregs=MAX (graph_2->u_aregs,graph_2->i_aregs+graph_1->u_aregs);
	r_dregs=MAX (graph_2->u_dregs,graph_2->i_dregs+graph_1->u_dregs);
		
	if (graph->instruction_d_min_a_cost<=0){
		++i_dregs;
			
		if (!(graph_2->order_mode==R_DREGISTER && graph_2->order_alterable)){
			if (l_dregs<i_dregs)
				l_dregs=i_dregs;
			if (r_dregs<i_dregs)
				r_dregs=i_dregs;
		}
		
		graph->order_mode=R_DREGISTER;
	} else {
		++i_aregs;
		
		if (!(graph_2->order_mode!=R_DREGISTER && graph_2->order_alterable)){
			if (l_aregs<i_aregs)
				l_aregs=i_aregs;
			if (r_aregs<i_aregs)
				r_aregs=i_aregs;
		}
		
		graph->order_mode=R_AREGISTER;
	}
	
	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;
		
	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;
				
	if (AD_REG_WEIGHT (l_aregs,l_dregs) < AD_REG_WEIGHT (r_aregs,r_dregs)){
		graph->u_aregs=l_aregs;
		graph->u_dregs=l_dregs;
		graph->order_left=1;
	} else {
		graph->u_aregs=r_aregs;
		graph->u_dregs=r_dregs;
		graph->order_left=0;
	}
		
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	
	graph->order_alterable=graph->node_count<=1;
}

static void calculate_dyadic_non_commutative_data_operator (INSTRUCTION_GRAPH graph)
{
	register INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs;
	int l_aregs,r_aregs,l_dregs,r_dregs;	
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
	
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	
	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;
	
	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
		
	r_aregs=MAX (graph_2->u_aregs,graph_2->i_aregs+graph_1->u_aregs);
	r_dregs=MAX (graph_2->u_dregs,graph_2->i_dregs+graph_1->u_dregs);
	
	if (!(graph_2->order_mode==R_DREGISTER && graph_2->order_alterable 
		  && graph_1->order_mode!=R_AREGISTER)){
		if (graph_2->order_mode==R_AREGISTER){
			if (l_dregs<i_dregs+2)
				l_dregs=i_dregs+2;
			if (r_dregs<i_dregs+2)
				r_dregs=i_dregs+2;
		} else {
			if (l_dregs<i_dregs+1)
				l_dregs=i_dregs+1;
			if (r_dregs<i_dregs+1)
				r_dregs=i_dregs+1;
		}
	}
	
	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;
		
	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;
		
	if (graph->instruction_d_min_a_cost<=0){
		++i_dregs;		
		graph->order_mode=R_DREGISTER;
	} else {
		++i_aregs;
		
		if (l_aregs<i_aregs)
			l_aregs=i_aregs;
		if (r_aregs<i_aregs)
			r_aregs=i_aregs;

		graph->order_mode=R_AREGISTER;
	}
				
	if (AD_REG_WEIGHT (l_aregs,l_dregs) < AD_REG_WEIGHT (r_aregs,r_dregs)){
		graph->u_aregs=l_aregs;
		graph->u_dregs=l_dregs;
		graph->order_left=1;
	} else {
		graph->u_aregs=r_aregs;
		graph->u_dregs=r_dregs;
		graph->order_left=0;
	}
		
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	
	graph->order_alterable=graph->node_count<=1;
	return;
}

static void calculate_rem_operator (INSTRUCTION_GRAPH graph)
{
	register INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs;
	int l_aregs,r_aregs,l_dregs,r_dregs;	
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
	
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	
	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;
	
	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
		
	r_aregs=MAX (graph_2->u_aregs,graph_2->i_aregs+graph_1->u_aregs);
	r_dregs=MAX (graph_2->u_dregs,graph_2->i_dregs+graph_1->u_dregs);
	
	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;
		
	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;
		
	if (l_dregs<i_dregs+2)
		l_dregs=i_dregs+2;
	if (r_dregs<i_dregs+2)
		r_dregs=i_dregs+2;
		
	if (graph->instruction_d_min_a_cost<=0){
		++i_dregs;		
		graph->order_mode=R_DREGISTER;
	} else {
		++i_aregs;
		
		if (l_aregs<i_aregs)
			l_aregs=i_aregs;
		if (r_aregs<i_aregs)
			r_aregs=i_aregs;

		graph->order_mode=R_AREGISTER;
	}
				
	if (AD_REG_WEIGHT (l_aregs,l_dregs) < AD_REG_WEIGHT (r_aregs,r_dregs)){
		graph->u_aregs=l_aregs;
		graph->u_dregs=l_dregs;
		graph->order_left=1;
	} else {
		graph->u_aregs=r_aregs;
		graph->u_dregs=r_dregs;
		graph->order_left=0;
	}
		
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	
	graph->order_alterable=graph->node_count<=1;
	return;
}

static void calculate_shift_operator (INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs;
	int l_aregs,r_aregs,l_dregs,r_dregs;	
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
	
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	
	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;
	
	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
		
	r_aregs=MAX (graph_2->u_aregs,graph_2->i_aregs+graph_1->u_aregs);
	r_dregs=MAX (graph_2->u_dregs,graph_2->i_dregs+graph_1->u_dregs);
	
	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;
		
	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;
	
	if (graph_1->order_mode==R_IMMEDIATE 
		|| (graph_1->order_mode==R_DREGISTER && !graph_1->order_alterable)){
		if (l_dregs<i_dregs+1)
			l_dregs=i_dregs+1;
		if (r_dregs<i_dregs+1)
			r_dregs=i_dregs+1;
	} else {
		if (l_dregs<i_dregs+2)
			l_dregs=i_dregs+2;
		if (r_dregs<i_dregs+2)
			r_dregs=i_dregs+2;
	}
		
	if (graph->instruction_d_min_a_cost<=0){
		++i_dregs;		
		graph->order_mode=R_DREGISTER;
	} else {
		++i_aregs;
		
		if (l_aregs<i_aregs)
			l_aregs=i_aregs;
		if (r_aregs<i_aregs)
			r_aregs=i_aregs;

		graph->order_mode=R_AREGISTER;
	}
				
	if (AD_REG_WEIGHT (l_aregs,l_dregs) < AD_REG_WEIGHT (r_aregs,r_dregs)){
		graph->u_aregs=l_aregs;
		graph->u_dregs=l_dregs;
		graph->order_left=1;
	} else {
		graph->u_aregs=r_aregs;
		graph->u_dregs=r_dregs;
		graph->order_left=0;
	}
		
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	
	graph->order_alterable=graph->node_count<=1;
#ifdef PRINT_DEBUG
	printf ("shift_operator ud=%d id=%d ua=%d ia=%d\n",
							graph->u_dregs,graph->i_dregs,graph->u_aregs,graph->i_aregs);
#endif

}

static void calculate_arguments (INSTRUCTION_GRAPH graph,int *i_aregs_p,int *i_dregs_p,int *u_aregs_p,int *u_dregs_p)
{
	int i_aregs,i_dregs,u_aregs,u_dregs,n_arguments;
	register int argument_number;
	char *argument_evaluated;
	
	i_aregs=*i_aregs_p;
	i_dregs=*i_dregs_p;
	u_aregs=*u_aregs_p;
	u_dregs=*u_dregs_p;
	
	n_arguments=graph->inode_arity;
	
	for (argument_number=0; argument_number<n_arguments; ++argument_number){
		INSTRUCTION_GRAPH a_graph;
		
		a_graph=graph->instruction_parameters[argument_number].p;
		
		if (a_graph!=NULL)
			calculate_graph_register_uses (a_graph);
	}
	
	argument_evaluated=(char*)memory_allocate (sizeof (char) * n_arguments);
	
	for (argument_number=0; argument_number<n_arguments; ++argument_number)
		argument_evaluated[argument_number]=
			(graph->instruction_parameters[argument_number].p==NULL);
	
	for (;;){
		register int first_argument_number;
		register INSTRUCTION_GRAPH a_graph_1;
		
		first_argument_number=0;
		while (first_argument_number<n_arguments && argument_evaluated[first_argument_number])
			++first_argument_number;
		
		if (first_argument_number>=n_arguments)
			break;
			
		a_graph_1=graph->instruction_parameters[first_argument_number].p;
		
		for (argument_number=first_argument_number+1; argument_number<n_arguments; ++argument_number){
			if (!argument_evaluated[argument_number]){
				INSTRUCTION_GRAPH a_graph_2;
				int i1,i2,u1,u2;
				int a,d;
				
				a_graph_2=graph->instruction_parameters[argument_number].p;
				
				a=a_graph_1->i_aregs; d=a_graph_1->i_dregs; i1=AD_REG_WEIGHT (a,d);
				a=a_graph_2->i_aregs; d=a_graph_2->i_dregs; i2=AD_REG_WEIGHT (a,d);
				
				a=a_graph_1->u_aregs; d=a_graph_1->u_dregs; u1=AD_REG_WEIGHT (a,d);
				a=a_graph_2->u_aregs; d=a_graph_2->u_dregs; u2=AD_REG_WEIGHT (a,d);
				
				if (i1<0){
					if (i2<0 && (u2<u1 || (u1==u2 && i2<i1))){
						first_argument_number=argument_number;
						a_graph_1=a_graph_2;
					}
				} else if (i1==0){
					if (i2<0 || (i2==0 && u2<u1)){
						first_argument_number=argument_number;
						a_graph_1=a_graph_2;
					}
				} else {
					if (i2<=0 || (u2-i2>u1-i1 || (u2-i2==u1-i1 && u2<u1))){
						first_argument_number=argument_number;
						a_graph_1=a_graph_2;
					}
				}
			}
		}
		
		if (a_graph_1->u_aregs+i_aregs > u_aregs)
			u_aregs=a_graph_1->u_aregs+i_aregs;
		if (a_graph_1->u_dregs+i_dregs > u_dregs)
			u_dregs=a_graph_1->u_dregs+i_dregs;
			
		i_aregs+=a_graph_1->i_aregs;
		i_dregs+=a_graph_1->i_dregs;
		
		argument_evaluated[first_argument_number]=1;
	}
	
	memory_free (argument_evaluated);
	
	*i_aregs_p=i_aregs;
	*i_dregs_p=i_dregs;
	*u_aregs_p=u_aregs;
	*u_dregs_p=u_dregs;
}

static void calculate_create_r_operator (INSTRUCTION_GRAPH graph)
{
	int i_aregs,i_dregs,u_aregs,u_dregs;
	INSTRUCTION_GRAPH a_graph;
	
	a_graph=graph->instruction_parameters[0].p;
	calculate_graph_register_uses (a_graph);
	
	u_aregs=a_graph->u_aregs;
	u_dregs=a_graph->u_dregs;
	i_aregs=a_graph->i_aregs;
	i_dregs=a_graph->i_dregs;
	
	if (graph->instruction_d_min_a_cost<=0){
		++i_dregs;
		if (i_dregs>u_dregs)
			u_dregs=i_dregs;
		graph->order_mode=R_DREGISTER;
	} else {
		++i_aregs;
		if (i_aregs>u_aregs)
			u_aregs=i_aregs;
		graph->order_mode=R_AREGISTER;
	}
	
	if (a_graph->order_mode==R_DREGISTER)
		i_dregs-=a_graph->order_alterable;
	else
		i_aregs-=a_graph->order_alterable;
	
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	graph->u_aregs=u_aregs;
	graph->u_dregs=u_dregs;
	
	graph->order_alterable=graph->node_count<=1;
}

static void calculate_create_operator (INSTRUCTION_GRAPH graph)
{
	register int argument_number;
	int i_aregs,i_dregs,u_aregs,u_dregs;
	
	i_aregs=0;
	i_dregs=0;
	u_aregs=0;
	u_dregs=0;

	calculate_arguments (graph,&i_aregs,&i_dregs,&u_aregs,&u_dregs);
	
	if (graph->instruction_d_min_a_cost<=0){
		++i_dregs;
		if (i_dregs>u_dregs)
			u_dregs=i_dregs;
		graph->order_mode=R_DREGISTER;
	} else {
		++i_aregs;
		if (i_aregs>u_aregs)
			u_aregs=i_aregs;
		graph->order_mode=R_AREGISTER;
	}
	
	for (argument_number=0; argument_number<graph->inode_arity; ++argument_number){
		register INSTRUCTION_GRAPH a_graph;
		
		a_graph=graph->instruction_parameters[argument_number].p;
		
		if (a_graph!=NULL)
			if (a_graph->order_mode==R_DREGISTER)
				i_dregs-=a_graph->order_alterable;
			else
				i_aregs-=a_graph->order_alterable;
	}
	
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	graph->u_aregs=u_aregs;
	graph->u_dregs=u_dregs;
	
	graph->order_alterable=graph->node_count<=1;
}

static void calculate_fill_r_operator (register INSTRUCTION_GRAPH graph)
{
	int i_aregs,i_dregs,u_aregs,u_dregs;
	INSTRUCTION_GRAPH a_graph;
	
	a_graph=graph->instruction_parameters[0].p;
	if (a_graph->instruction_code==GCREATE && a_graph->node_count==1){
		/* overwrite fill_r node with create_r node */
		
		graph->instruction_code=GCREATE_R;
		graph->instruction_parameters[0]=graph->instruction_parameters[1];
		graph->instruction_parameters[1]=graph->instruction_parameters[2];
		graph->inode_arity=2;
		
		calculate_create_r_operator (graph);
		return;
	}
	
	calculate_graph_register_uses (a_graph);
	
	u_aregs=a_graph->u_aregs;
	u_dregs=a_graph->u_dregs;
	i_aregs=a_graph->i_aregs;
	i_dregs=a_graph->i_dregs;

	a_graph=graph->instruction_parameters[1].p;
	calculate_graph_register_uses (a_graph);
	
	if (a_graph->u_aregs+i_aregs > u_aregs)
		u_aregs=a_graph->u_aregs+i_aregs;
	if (a_graph->u_dregs+i_dregs > u_dregs)
		u_dregs=a_graph->u_dregs+i_dregs;
	i_aregs+=a_graph->i_aregs;
	i_dregs+=a_graph->i_dregs;
	
	if (graph->instruction_d_min_a_cost<=0){
		++i_dregs;
		if (i_dregs>u_dregs)
			u_dregs=i_dregs;
		graph->order_mode=R_DREGISTER;
	} else {
		++i_aregs;
		if (i_aregs>u_aregs)
			u_aregs=i_aregs;
		graph->order_mode=R_AREGISTER;
	}
	
	a_graph=graph->instruction_parameters[0].p;
	if (a_graph->order_mode==R_DREGISTER)
		i_dregs-=a_graph->order_alterable;
	else
		i_aregs-=a_graph->order_alterable;

	a_graph=graph->instruction_parameters[1].p;
	if (a_graph->order_mode==R_DREGISTER)
		i_dregs-=a_graph->order_alterable;
	else
		i_aregs-=a_graph->order_alterable;
	
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	graph->u_aregs=u_aregs;
	graph->u_dregs=u_dregs;
		
	graph->order_alterable=graph->node_count<=1;
}

static void calculate_fill_operator (register INSTRUCTION_GRAPH graph)
{
	int argument_number,i_aregs,i_dregs,u_aregs,u_dregs;
	INSTRUCTION_GRAPH graph_0;
#ifdef G_POWER
	int r;
#endif
	
	graph_0=graph->instruction_parameters[0].p;
	if (graph_0->instruction_code==GCREATE && graph_0->node_count==1
		&& (graph->inode_arity>3
			|| (graph->inode_arity>1 
				&& (graph->instruction_parameters[1].p->instruction_code==GLOAD_DES_I
					|| graph->instruction_parameters[1].p->instruction_code==GLOAD_DES_ID
#ifdef G_POWER
					|| (graph->instruction_parameters[1].p->instruction_code==GGREGISTER
						&& (r=graph->instruction_parameters[1].p->instruction_parameters[0].i)==INT_REGISTER
							|| r==CHAR_REGISTER || r==REAL_REGISTER || r==BOOL_REGISTER
							)
#endif
					))))
	{
		/* overwrite fill node with create node */
		
		graph->instruction_code=GCREATE;
		for (argument_number=1; argument_number<graph->inode_arity; ++argument_number)
			graph->instruction_parameters[argument_number-1]=
				graph->instruction_parameters[argument_number];
				
		--graph->inode_arity;
		
		calculate_create_operator (graph);
		return;
	}
	
	i_aregs=0;
	i_dregs=0;
	u_aregs=0;
	u_dregs=0;
	
	calculate_arguments (graph,&i_aregs,&i_dregs,&u_aregs,&u_dregs);
	
	if (graph->instruction_d_min_a_cost<=0){
		++i_dregs;
		if (i_dregs>u_dregs)
			u_dregs=i_dregs;
		graph->order_mode=R_DREGISTER;
	} else {
		++i_aregs;
		if (i_aregs>u_aregs)
			u_aregs=i_aregs;
		graph->order_mode=R_AREGISTER;
	}
	
	for (argument_number=0; argument_number<graph->inode_arity; ++argument_number){
		register INSTRUCTION_GRAPH a_graph;
		
		a_graph=graph->instruction_parameters[argument_number].p;
		
		if (a_graph!=NULL)
			if (a_graph->order_mode==R_DREGISTER)
				i_dregs-=a_graph->order_alterable;
			else
				i_aregs-=a_graph->order_alterable;
	}
	
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	graph->u_aregs=u_aregs;
	graph->u_dregs=u_dregs;
		
	graph->order_alterable=graph->node_count<=1;
}

static void calculate_movemi_operator (INSTRUCTION_GRAPH graph)
{
	register INSTRUCTION_GRAPH movem_graph,graph_2;
	register int i_dregs,i_aregs,u_dregs,u_aregs;
	register int argument_number;
	int arity;
	
	movem_graph=graph->instruction_parameters[0].p;
	if (movem_graph->order_mode!=R_NOMODE)
		return;
	
	graph_2=movem_graph->instruction_parameters[1].p;
	
	calculate_graph_register_uses (graph_2);
	
	i_dregs=graph_2->i_dregs;
	i_aregs=graph_2->i_aregs;
	u_dregs=graph_2->u_dregs;
	u_aregs=graph_2->u_aregs;
	
	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;
	
	++i_aregs;
	if (u_aregs<i_aregs)
		u_aregs=i_aregs;
	
	arity=movem_graph->inode_arity;
	
	for (argument_number=0; argument_number<arity; ++argument_number){
		register INSTRUCTION_GRAPH a_graph;
		
		if (argument_number==arity-1)
			--i_aregs;
		
		a_graph=movem_graph->instruction_parameters[2+argument_number].p;
		if (a_graph!=NULL)
			if (a_graph->instruction_parameters[1].i==0
				?	a_graph->instruction_d_min_a_cost<=0
				:	is_d_register (a_graph->instruction_parameters[1].i>>1))
			{
				++i_dregs;
				if (u_dregs<i_dregs)
					u_dregs=i_dregs;
			} else {
				++i_aregs;
				if (u_aregs<i_aregs)
					u_aregs=i_aregs;
			}
	}
	
	for (argument_number=0; argument_number<arity; ++argument_number){
		register INSTRUCTION_GRAPH a_graph;
		
		a_graph=movem_graph->instruction_parameters[2+argument_number].p;
		if (a_graph!=NULL){
			a_graph->i_dregs=i_dregs;
			a_graph->i_aregs=i_aregs;
			a_graph->u_dregs=u_dregs;
			a_graph->u_aregs=u_aregs;
			if (a_graph->instruction_parameters[1].i==0
				?	a_graph->instruction_d_min_a_cost<=0
				:	is_d_register (a_graph->instruction_parameters[1].i>>1)
			)
				a_graph->order_mode=R_DREGISTER;
			else
				a_graph->order_mode=R_AREGISTER;
			a_graph->order_alterable=a_graph->node_count<=1;
		}
	}
}

static void calculate_copy_operator (register INSTRUCTION_GRAPH graph)
{
	register INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs;
	int l_aregs,l_dregs;	
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
		
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	
	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;
	
	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
		
	i_aregs-=graph_1->order_alterable;
	i_aregs-=graph_2->order_alterable;
	
	graph->u_aregs=l_aregs;
	graph->u_dregs=l_dregs;		
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	
	graph->order_alterable=graph->node_count<=1;
	return;
}

static void calculate_cnot_operator (register INSTRUCTION_GRAPH graph)
{
	register INSTRUCTION_GRAPH graph_1;
	
	graph_1=graph->instruction_parameters[0].p;
	
	calculate_graph_register_uses (graph_1);
	
	graph->u_aregs=graph_1->u_aregs;
	graph->u_dregs=graph_1->u_dregs;
	graph->i_aregs=graph_1->i_aregs;
	graph->i_dregs=graph_1->i_dregs;
	
	if (graph_1->order_mode==R_DREGISTER)
		graph->i_dregs-=graph_1->order_alterable;
	else
		graph->i_aregs-=graph_1->order_alterable;
	
	if (graph->u_dregs<graph->i_dregs+1)
		graph->u_dregs=graph->i_dregs+1;
	
	if (graph->instruction_d_min_a_cost<=0){
		++graph->i_dregs;
		graph->order_mode=R_DREGISTER;
	} else {
		++graph->i_aregs;
		if (graph->u_aregs<graph->i_aregs)
			graph->u_aregs=graph->i_aregs;
		graph->order_mode=R_AREGISTER;
	}
	
	graph->order_alterable=graph->node_count<=1;
}

#if defined (I486) || defined (ARM)
static void calculate_clzb_operator (register INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH graph_1;
	
	graph_1=graph->instruction_parameters[0].p;
	
	calculate_graph_register_uses (graph_1);
	
	graph->u_aregs=graph_1->u_aregs;
	graph->u_dregs=graph_1->u_dregs;
	graph->i_aregs=graph_1->i_aregs;
	graph->i_dregs=graph_1->i_dregs;

	if (graph_1->order_mode==R_IMMEDIATE){
		if (graph->instruction_d_min_a_cost<=0){
			++graph->i_dregs;
			if (graph->u_dregs<graph->i_dregs+1)
				graph->u_dregs=graph->i_dregs+1;
			graph->order_mode=R_DREGISTER;
		} else {
			++graph->i_aregs;
			if (graph->u_aregs<graph->i_aregs+1)
				graph->u_aregs=graph->i_aregs+1;
			graph->order_mode=R_AREGISTER;
		}
	} else {
		if (graph->instruction_d_min_a_cost<=0){
			++graph->i_dregs;
			if (graph->i_dregs>graph->u_dregs)
				graph->u_dregs=graph->i_dregs;
			graph->order_mode=R_DREGISTER;
		} else {
			++graph->i_aregs;
			if (graph->i_aregs>graph->u_aregs)
				graph->u_aregs=graph->i_aregs;
			graph->order_mode=R_AREGISTER;
		}

		if (graph_1->order_mode==R_DREGISTER)
			graph->i_dregs-=graph_1->order_alterable;
		else
			graph->i_aregs-=graph_1->order_alterable;
	}
	
	graph->order_alterable=graph->node_count<=1;
}
#endif

static void calculate_load_x_operator (register INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs,l_aregs,l_dregs,r_aregs,r_dregs;

	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[2].p;
	
	calculate_graph_register_uses (graph_1);
	
	if (graph_2==NULL){
		switch (graph_1->order_mode){
			case R_AREGISTER:
				graph->u_dregs=graph_1->u_dregs;
				graph->u_aregs=graph_1->u_aregs;
				graph->i_aregs=graph_1->i_aregs;
				graph->i_dregs=graph_1->i_dregs;
				graph->order_alterable=graph_1->order_alterable;
				break;
			case R_DREGISTER:
				graph->u_dregs=graph_1->u_dregs;
				graph->u_aregs=MAX (graph_1->u_aregs,1+graph_1->i_aregs);				
				graph->i_dregs=graph_1->i_dregs-graph_1->order_alterable;
				graph->i_aregs=graph_1->i_aregs+1;
				graph->order_alterable=1;
				break;
			case R_MEMORY:
			case R_IMMEDIATE:
			{
				int i_aregs=graph_1->i_aregs+1-graph_1->order_alterable;
				graph->u_dregs=graph_1->u_dregs;
				graph->u_aregs=MAX (graph_1->u_aregs,i_aregs);
				graph->i_dregs=graph_1->i_dregs;
				graph->i_aregs=i_aregs;
				graph->order_alterable=1;
			}
		}
				
		graph->order_mode=R_MEMORY;
		return;
	}
	
	calculate_graph_register_uses (graph_2);

	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;

	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);

	r_aregs=MAX (graph_2->u_aregs,graph_2->i_aregs+graph_1->u_aregs);
	r_dregs=MAX (graph_2->u_dregs,graph_2->i_dregs+graph_1->u_dregs);

	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;

	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;
	
	++i_aregs;
	if (l_aregs<i_aregs)
		l_aregs=i_aregs;
	if (r_aregs<i_aregs)
		r_aregs=i_aregs;

	if (AD_REG_WEIGHT (l_aregs,l_dregs) < AD_REG_WEIGHT (r_aregs,r_dregs)){
		graph->u_aregs=l_aregs;
		graph->u_dregs=l_dregs;
		graph->order_left=1;
	} else {
		graph->u_aregs=r_aregs;
		graph->u_dregs=r_dregs;
		graph->order_left=0;
	}

	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;

	graph->order_alterable=1;
	graph->order_mode=R_MEMORY;
}

static int graph_order (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2)
{
	int i1,i2,u1,u2;
	int a,d;
	
	a=graph_1->i_aregs; d=graph_1->i_dregs; i1=AD_REG_WEIGHT (a,d); 
	a=graph_2->i_aregs; d=graph_2->i_dregs; i2=AD_REG_WEIGHT (a,d);
				
	a=graph_1->u_aregs; d=graph_1->u_dregs; u1=AD_REG_WEIGHT (a,d);
	a=graph_2->u_aregs; d=graph_2->u_dregs; u2=AD_REG_WEIGHT (a,d);
				
	if (i1<0)
		return i2<0 && (u2<u1 || (u1==u2 && i2<i1));
	else if (i1==0)
		return i2<0 || (i2==0 && u2<u1);
	else 
		return i2<=0 || (u2-i2>u1-i1 || (u2-i2==u1-i1 && u2<u1));
}

static void calculate_store_x_operator (INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,select_graph;
	INSTRUCTION_GRAPH graph_1_before_reorder,graph_2_before_reorder,graph_3_before_reorder;
	int i_aregs,i_dregs,u_aregs,u_dregs;
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
	graph_3=graph->instruction_parameters[3].p;
	select_graph=graph->instruction_parameters[4].p;
	
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	if (graph_3!=NULL)
		calculate_graph_register_uses (graph_3);

	i_aregs=0;
	i_dregs=0;
	u_aregs=0;
	u_dregs=0;
	
	while (select_graph!=NULL){
		switch (select_graph->instruction_code){
			case GLOAD_X:
			case GLOAD_B_X:
#ifdef G_A64
			case GLOAD_S_X:
#endif
				if (graph_2==select_graph->instruction_parameters[0].p
					/* */ && select_graph!=graph_1 /* added 18-5-1999 */
				){
					calculate_graph_register_uses (select_graph);

					if (select_graph->u_aregs+i_aregs > u_aregs)
						u_aregs=select_graph->u_aregs+i_aregs;
					if (select_graph->u_dregs+i_dregs > u_dregs)
						u_dregs=select_graph->u_dregs+i_dregs;
					
					i_aregs+=select_graph->i_aregs;
					i_dregs+=select_graph->i_dregs;
					
					if (select_graph->order_mode==R_DREGISTER)
						i_dregs-=select_graph->order_alterable;
					else
						i_aregs-=select_graph->order_alterable;

					if (select_graph->instruction_d_min_a_cost<=0)
						++i_dregs;
					else
						++i_aregs;
				}
				
				select_graph=select_graph->instruction_parameters[3].p;			
				break;
			case GFLOAD_X:
#if defined (I486) || defined (ARM)
			case GFLOAD_S_X:
#endif
			case GREGISTER:
			case GFREGISTER:
			case GGREGISTER:
				select_graph=select_graph->instruction_parameters[3].p;
				break;
#if defined (G_A64)
			case GFROMF:
				select_graph=select_graph->instruction_parameters[0].p;
				break;
#endif
			default:
				internal_error_in_function ("calculate_store_x_operator");
		}
	}
	
	graph_1_before_reorder=graph_1;
	graph_2_before_reorder=graph_2;
	graph_3_before_reorder=graph_3;
	
	if (graph_3==NULL){
		if (graph_order (graph_1,graph_2))
			graph->order_left=1;
		else {
			INSTRUCTION_GRAPH c_graph_1;
			
			c_graph_1=graph_1;
			graph_1=graph_2;
			graph_2=c_graph_1;
			
			graph->order_left=0;
		}
	} else {
		int order;
		
		if (graph_order (graph_1,graph_2)){
			if (graph_order (graph_1,graph_3)){
				order=0;
			} else {
				INSTRUCTION_GRAPH c_graph_1;
			
				c_graph_1=graph_1;
				graph_1=graph_3;
				graph_3=c_graph_1;

				order=4;
			}
		} else {
			if (graph_order (graph_2,graph_3)){
				INSTRUCTION_GRAPH c_graph_1;
			
				c_graph_1=graph_1;
				graph_1=graph_2;
				graph_2=c_graph_1;

				order=2;
			} else {
				INSTRUCTION_GRAPH c_graph_1;
			
				c_graph_1=graph_1;
				graph_1=graph_3;
				graph_3=c_graph_1;

				order=4;
			}
		}

		if (graph_order (graph_2,graph_3)){
			INSTRUCTION_GRAPH c_graph_2;
			
			c_graph_2=graph_2;
			graph_2=graph_3;
			graph_3=c_graph_2;
	
			++order;
		}
		
		graph->order_left=order;
	}

	if (graph_1->u_aregs+i_aregs > u_aregs)
		u_aregs=graph_1->u_aregs+i_aregs;
	if (graph_1->u_dregs+i_dregs > u_dregs)
		u_dregs=graph_1->u_dregs+i_dregs;

	i_aregs+=graph_1->i_aregs;
	i_dregs+=graph_1->i_dregs;

	if (graph_2->u_aregs+i_aregs > u_aregs)
		u_aregs=graph_2->u_aregs+i_aregs;
	if (graph_2->u_dregs+i_dregs > u_dregs)
		u_dregs=graph_2->u_dregs+i_dregs;

	i_aregs+=graph_2->i_aregs;
	i_dregs+=graph_2->i_dregs;

	if (graph_3!=NULL){
		if (graph_3->u_aregs+i_aregs > u_aregs)
			u_aregs=graph_3->u_aregs+i_aregs;
		if (graph_3->u_dregs+i_dregs > u_dregs)
			u_dregs=graph_3->u_dregs+i_dregs;
	
		i_aregs+=graph_3->i_aregs;
		i_dregs+=graph_3->i_dregs;
	}

	if (graph_1_before_reorder->order_mode==R_DREGISTER)
		i_dregs-=graph_1_before_reorder->order_alterable;
	else {
		i_aregs-=graph_1_before_reorder->order_alterable;
		if (graph_1_before_reorder->order_mode==R_MEMORY && u_dregs<i_dregs+1)
			u_dregs=i_dregs+1;
	}

	if (graph_3_before_reorder!=NULL){
		if (graph_3_before_reorder->order_mode==R_DREGISTER)
			i_dregs-=graph_3_before_reorder->order_alterable;
		else
			i_aregs-=graph_3_before_reorder->order_alterable;
	}

	graph->order_alterable=graph_2_before_reorder->order_alterable;
	if (graph_2_before_reorder->order_alterable)
		if (graph_2_before_reorder->order_mode==R_DREGISTER)
			--i_dregs;
		else
			--i_aregs;

	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	graph->u_aregs=u_aregs;
	graph->u_dregs=u_dregs;

	graph->order_mode=R_AREGISTER;
}

static void calculate_monadic_float_operator (register INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH graph_1;
	
	graph_1=graph->instruction_parameters[0].p;
	
	calculate_graph_register_uses (graph_1);
	
	graph->u_aregs=graph_1->u_aregs;
	graph->u_dregs=graph_1->u_dregs;
	graph->i_aregs=graph_1->i_aregs;
	graph->i_dregs=graph_1->i_dregs;
	
	if (graph_1->order_mode==R_DREGISTER)
		graph->i_dregs-=graph_1->order_alterable;
	else
		graph->i_aregs-=graph_1->order_alterable;
	
	graph->order_mode=R_DREGISTER;
	graph->order_alterable=0;
}

static void calculate_fload_id_operator (register INSTRUCTION_GRAPH graph)
{
	register INSTRUCTION_GRAPH graph_1;
	
	graph_1=graph->instruction_parameters[1].p;
	
	calculate_graph_register_uses (graph_1);
	
	graph->u_aregs=graph_1->u_aregs;
	graph->u_dregs=graph_1->u_dregs;
	graph->i_aregs=graph_1->i_aregs;
	graph->i_dregs=graph_1->i_dregs;
	
	if (graph_1->order_mode==R_DREGISTER)
		graph->i_dregs-=graph_1->order_alterable;
	else
		graph->i_aregs-=graph_1->order_alterable;
	
	graph->order_mode=R_DREGISTER;
	graph->order_alterable=0;
}

static void calculate_fstore_operator (register INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH a_graph;
	
	a_graph=graph->instruction_parameters[2].p;
	
	calculate_graph_register_uses (a_graph);
	
	graph->u_dregs=a_graph->u_dregs;
	graph->u_aregs=a_graph->u_aregs;
	graph->i_aregs=a_graph->i_aregs;
	graph->i_dregs=a_graph->i_dregs;
	
	if (a_graph->order_alterable)
		if (a_graph->order_mode==R_DREGISTER)
			--graph->i_dregs;
		else
			--graph->i_aregs;

	graph->order_mode=R_DREGISTER;
	graph->order_alterable=0;
}

static void calculate_fload_x_operator (INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs,l_aregs,l_dregs,r_aregs,r_dregs;
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[2].p;
	
	calculate_graph_register_uses (graph_1);

	if (graph_2==NULL){
		switch (graph_1->order_mode){
			case R_AREGISTER:
				graph->u_dregs=graph_1->u_dregs;
				graph->u_aregs=graph_1->u_aregs;
				graph->i_aregs=graph_1->i_aregs;
				graph->i_dregs=graph_1->i_dregs;
				graph->order_alterable=graph_1->order_alterable;
				break;
			case R_DREGISTER:
				graph->u_dregs=graph_1->u_dregs;
				graph->u_aregs=MAX (graph_1->u_aregs,1+graph_1->i_aregs);				
				graph->i_dregs=graph_1->i_dregs-graph_1->order_alterable;
				graph->i_aregs=graph_1->i_aregs+1;
				graph->order_alterable=1;
				break;
			case R_MEMORY:
			case R_IMMEDIATE:
			{
				int i_aregs=graph_1->i_aregs+1-graph_1->order_alterable;
				graph->u_dregs=graph_1->u_dregs;
				graph->u_aregs=MAX (graph_1->u_aregs,i_aregs);
				graph->i_dregs=graph_1->i_dregs;
				graph->i_aregs=i_aregs;
				graph->order_alterable=1;
			}
		}
				
		graph->order_mode=R_MEMORY;
		return;
	}

	calculate_graph_register_uses (graph_2);

	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;

	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);

	r_aregs=MAX (graph_2->u_aregs,graph_2->i_aregs+graph_1->u_aregs);
	r_dregs=MAX (graph_2->u_dregs,graph_2->i_dregs+graph_1->u_dregs);

	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;

	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;
		
	++i_aregs;
	if (l_aregs<i_aregs)	
		l_aregs=i_aregs;
	if (r_aregs<i_aregs)
		r_aregs=i_aregs;

	if (AD_REG_WEIGHT (l_aregs,l_dregs) < AD_REG_WEIGHT (r_aregs,r_dregs)){
		graph->u_aregs=l_aregs;
		graph->u_dregs=l_dregs;
		graph->order_left=1;
	} else {
		graph->u_aregs=r_aregs;
		graph->u_dregs=r_dregs;
		graph->order_left=0;
	}

	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;

	graph->order_mode=R_MEMORY;
	graph->order_alterable=1;

#ifdef PRINT_DEBUG
	printf ("GFLOAD_X ud=%d id=%d ua=%d ia=%d\n",
					graph->u_dregs,graph->i_dregs,graph->u_aregs,graph->i_aregs);
#endif
}

static void calculate_fstore_x_operator (INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,select_graph;
	INSTRUCTION_GRAPH graph_1_before_reorder,graph_2_before_reorder,graph_3_before_reorder;
	int i_aregs,i_dregs,u_aregs,u_dregs;
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
	graph_3=graph->instruction_parameters[3].p;
	select_graph=graph->instruction_parameters[4].p;
	
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	if (graph_3!=NULL)
		calculate_graph_register_uses (graph_3);

	i_aregs=0;
	i_dregs=0;
	u_aregs=0;
	u_dregs=0;
	
	while (select_graph!=NULL){
		switch (select_graph->instruction_code){
			case GFLOAD_X:
#if defined (I486) || defined (ARM)
			case GFLOAD_S_X:
#endif
				if (graph_2==select_graph->instruction_parameters[0].p){
					calculate_graph_register_uses (select_graph);

					if (select_graph->u_aregs+i_aregs > u_aregs)
						u_aregs=select_graph->u_aregs+i_aregs;
					if (select_graph->u_dregs+i_dregs > u_dregs)
						u_dregs=select_graph->u_dregs+i_dregs;

					i_aregs+=select_graph->i_aregs;
					i_dregs+=select_graph->i_dregs;
		
					if (select_graph->order_mode==R_DREGISTER)
						i_dregs-=select_graph->order_alterable;
					else
						i_aregs-=select_graph->order_alterable;
#ifdef PRINT_DEBUG
					printf ("GFLOAD_X in GFSTORE_X ud=%d id=%d ua=%d ia=%d\n",select_graph->u_dregs,select_graph->i_dregs,select_graph->u_aregs,select_graph->i_aregs);
#endif
				}
				
				select_graph=select_graph->instruction_parameters[3].p;			
				break;
			case GLOAD_X:
			case GLOAD_B_X:
#ifdef G_A64
			case GLOAD_S_X:
#endif
			case GREGISTER:
			case GFREGISTER:
				select_graph=select_graph->instruction_parameters[3].p;
				break;
			default:
				internal_error_in_function ("calculate_fstore_x_operator");
		}
	}
	
	graph_1_before_reorder=graph_1;
	graph_2_before_reorder=graph_2;
	graph_3_before_reorder=graph_3;

	if (graph_3==NULL){
		if (graph_order (graph_1,graph_2))
			graph->order_left=1;
		else {
			INSTRUCTION_GRAPH c_graph_1;
			
			c_graph_1=graph_1;
			graph_1=graph_2;
			graph_2=c_graph_1;
			
			graph->order_left=0;
		}
	} else {
		int order;
		
		if (graph_order (graph_1,graph_2)){
			if (graph_order (graph_1,graph_3)){
				order=0;
			} else {
				INSTRUCTION_GRAPH c_graph_1;
			
				c_graph_1=graph_1;
				graph_1=graph_3;
				graph_3=c_graph_1;

				order=4;
			}
		} else {
			if (graph_order (graph_2,graph_3)){
				INSTRUCTION_GRAPH c_graph_1;
			
				c_graph_1=graph_1;
				graph_1=graph_2;
				graph_2=c_graph_1;

				order=2;
			} else {
				INSTRUCTION_GRAPH c_graph_1;
			
				c_graph_1=graph_1;
				graph_1=graph_3;
				graph_3=c_graph_1;

				order=4;
			}
		}

		if (graph_order (graph_2,graph_3)){
			INSTRUCTION_GRAPH c_graph_2;
			
			c_graph_2=graph_2;
			graph_2=graph_3;
			graph_3=c_graph_2;
	
			++order;
		}
		
		graph->order_left=order;
	}

	if (graph_1->u_aregs+i_aregs > u_aregs)
		u_aregs=graph_1->u_aregs+i_aregs;
	if (graph_1->u_dregs+i_dregs > u_dregs)
		u_dregs=graph_1->u_dregs+i_dregs;

	i_aregs+=graph_1->i_aregs;
	i_dregs+=graph_1->i_dregs;

	if (graph_2->u_aregs+i_aregs > u_aregs)
		u_aregs=graph_2->u_aregs+i_aregs;
	if (graph_2->u_dregs+i_dregs > u_dregs)
		u_dregs=graph_2->u_dregs+i_dregs;

	i_aregs+=graph_2->i_aregs;
	i_dregs+=graph_2->i_dregs;

	if (graph_3!=NULL){
		if (graph_3->u_aregs+i_aregs > u_aregs)
			u_aregs=graph_3->u_aregs+i_aregs;
		if (graph_3->u_dregs+i_dregs > u_dregs)
			u_dregs=graph_3->u_dregs+i_dregs;
	
		i_aregs+=graph_3->i_aregs;
		i_dregs+=graph_3->i_dregs;
	}

	if (graph_1_before_reorder->order_mode==R_DREGISTER)
		i_dregs-=graph_1_before_reorder->order_alterable;
	else
		i_aregs-=graph_1_before_reorder->order_alterable;

	if (graph_3_before_reorder!=NULL){
		if (graph_3_before_reorder->order_mode==R_DREGISTER)
			i_dregs-=graph_3_before_reorder->order_alterable;
		else
			i_aregs-=graph_3_before_reorder->order_alterable;
	}

	graph->order_alterable=graph_2_before_reorder->order_alterable;
	if (graph_2_before_reorder->order_alterable)
		if (graph_2_before_reorder->order_mode==R_DREGISTER)
			--i_dregs;
		else
			--i_aregs;

	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	graph->u_aregs=u_aregs;
	graph->u_dregs=u_dregs;

	graph->order_mode=R_AREGISTER;
#ifdef PRINT_DEBUG
	printf ("GFSTORE_X ud=%d id=%d ua=%d ia=%d\n",graph->u_dregs,graph->i_dregs,graph->u_aregs,graph->i_aregs);
#endif
}

static void calculate_fstore_r_operator (register INSTRUCTION_GRAPH graph)
{
	register INSTRUCTION_GRAPH a_graph;
	
	a_graph=graph->instruction_parameters[1].p;
	
	calculate_graph_register_uses (a_graph);
	
	graph->u_dregs=a_graph->u_dregs;
	graph->u_aregs=a_graph->u_aregs;
	graph->i_aregs=a_graph->i_aregs;
	graph->i_dregs=a_graph->i_dregs;
	
	if (a_graph->order_alterable)
		if (a_graph->order_mode==R_DREGISTER)
			--graph->i_dregs;
		else
			--graph->i_aregs;

	graph->order_mode=R_DREGISTER;
	graph->order_alterable=0;
#ifdef PRINT_DEBUG
	printf ("GFSTORE_R ud=%d id=%d ua=%d ia=%d\n",graph->u_dregs,graph->i_dregs,graph->u_aregs,graph->i_aregs);
#endif
}

static void calculate_bounds_operator (INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	int i_aregs,i_dregs;
	int l_aregs,r_aregs,l_dregs,r_dregs;	
	
	graph_1=graph->instruction_parameters[0].p;
	graph_2=graph->instruction_parameters[1].p;
	
	calculate_graph_register_uses (graph_1);
	calculate_graph_register_uses (graph_2);
	
	i_aregs=graph_1->i_aregs+graph_2->i_aregs;
	i_dregs=graph_1->i_dregs+graph_2->i_dregs;
	
	l_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
	l_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
		
	r_aregs=MAX (graph_2->u_aregs,graph_2->i_aregs+graph_1->u_aregs);
	r_dregs=MAX (graph_2->u_dregs,graph_2->i_dregs+graph_1->u_dregs);

	if (graph_1->order_mode!=R_AREGISTER){
		if (l_aregs<i_aregs+1)
			l_aregs=i_aregs+1;
		if (r_aregs<i_aregs+1)
			r_aregs=i_aregs+1;
	}
	
	if (graph_1->order_mode==R_DREGISTER)
		i_dregs-=graph_1->order_alterable;
	else
		i_aregs-=graph_1->order_alterable;
	
	if (graph_2->order_mode==R_DREGISTER)
		i_dregs-=graph_2->order_alterable;
	else
		i_aregs-=graph_2->order_alterable;

	if (l_dregs<i_dregs+1)
		l_dregs=i_dregs+1;
	if (r_dregs<i_dregs+1)
		r_dregs=i_dregs+1;
	
	++i_dregs;
	graph->order_mode=R_DREGISTER;
	
	if (AD_REG_WEIGHT (l_aregs,l_dregs) < AD_REG_WEIGHT (r_aregs,r_dregs)){
		graph->u_aregs=l_aregs;
		graph->u_dregs=l_dregs;
		graph->order_left=1;
	} else {
		graph->u_aregs=r_aregs;
		graph->u_dregs=r_dregs;
		graph->order_left=0;
	}
		
	graph->i_aregs=i_aregs;
	graph->i_dregs=i_dregs;
	
	graph->order_alterable=graph->node_count<=1;
}

void calculate_graph_register_uses (INSTRUCTION_GRAPH graph)
{
	if (graph->order_mode!=R_NOMODE)
		return;
	
	switch (graph->instruction_code){
		case GLOAD:
		{
			if (graph->instruction_d_min_a_cost<=0){
				graph->u_aregs=graph->i_aregs=0;
				if (graph->node_count<=1){
					graph->u_dregs=graph->i_dregs=0;
					graph->order_mode=R_MEMORY;
				} else {
					graph->u_dregs=graph->i_dregs=1;
					graph->order_mode=R_DREGISTER;
				}
			} else {
				graph->u_dregs=graph->i_dregs=0;
				if (graph->node_count<=1){
					graph->u_aregs=graph->i_aregs=0;
					graph->order_mode=R_MEMORY;
				} else {
					graph->u_aregs=graph->i_aregs=1;
					graph->order_mode=R_AREGISTER;
				}
			}
			graph->order_alterable=0;
			return;
		}
		case GGREGISTER:
		{
			graph->u_aregs=0;
			graph->u_dregs=0;
			graph->i_aregs=0;
			graph->i_dregs=0;
			graph->order_alterable=0;
			if (is_d_register (graph->instruction_parameters[0].i))
				graph->order_mode=R_DREGISTER;
			else
				graph->order_mode=R_AREGISTER;
			return;
		}
		case GREGISTER:
		{
			graph->u_aregs=0;
			graph->u_dregs=0;
			graph->i_aregs=0;
			graph->i_dregs=0;
			if (is_d_register (graph->instruction_parameters[0].i))
				graph->order_mode=R_DREGISTER;
			else
				graph->order_mode=R_AREGISTER;
			graph->order_alterable=graph->node_count<=1;
			return;
		}
		case GLOAD_I:
			if (graph->node_count>1){
				if (graph->instruction_d_min_a_cost<=0){
					graph->u_aregs=graph->i_aregs=0;
					graph->u_dregs=graph->i_dregs=1;
					graph->order_mode=R_DREGISTER;
				} else {
					graph->u_dregs=graph->i_dregs=0;
					graph->u_aregs=graph->i_aregs=1;
					graph->order_mode=R_AREGISTER;
				}
			} else {
				graph->u_aregs=graph->i_aregs=graph->u_dregs=graph->i_dregs=0;
				graph->order_mode=R_IMMEDIATE;
			}
			graph->order_alterable=0;
			return;
		case GLOAD_DES_I:
			if (graph->node_count>1){
				if (graph->instruction_d_min_a_cost<0){
					graph->u_aregs=graph->i_aregs=0;
					graph->u_dregs=graph->i_dregs=1;
					graph->order_mode=R_DREGISTER;
				} else {
					graph->u_dregs=graph->i_dregs=0;
					graph->u_aregs=graph->i_aregs=1;
					graph->order_mode=R_AREGISTER;
				}
			} else {
				graph->u_aregs=graph->i_aregs=graph->u_dregs=graph->i_dregs=0;
				graph->order_mode=R_IMMEDIATE;
			}
			graph->order_alterable=0;
			return;
		case GLEA:
			if (graph->instruction_d_min_a_cost<0){
				graph->u_dregs=1;
				graph->i_dregs=1;
				graph->u_aregs=1;
				graph->i_aregs=0;
				graph->order_mode=R_DREGISTER;
			} else {
				graph->u_dregs=0;
				graph->i_dregs=0;
				graph->u_aregs=1;
				graph->i_aregs=1;
				graph->order_mode=R_AREGISTER;
			}
			graph->order_alterable=graph->node_count<=1;
			return;
		case GLOAD_ID:
		{
			INSTRUCTION_GRAPH graph_1;
			
			graph_1=graph->instruction_parameters[1].p;
			
			calculate_graph_register_uses (graph_1);

			switch (graph_1->order_mode){
				case R_AREGISTER:
					graph->u_dregs=graph_1->u_dregs;
					graph->u_aregs=graph_1->u_aregs;
					graph->i_aregs=graph_1->i_aregs;
					graph->i_dregs=graph_1->i_dregs;
					graph->order_alterable=graph_1->order_alterable;
					break;
				case R_DREGISTER:
					graph->u_dregs=graph_1->u_dregs;
					graph->u_aregs=MAX (graph_1->u_aregs,1+graph_1->i_aregs);				
					graph->i_dregs=graph_1->i_dregs-graph_1->order_alterable;
					graph->i_aregs=graph_1->i_aregs+1;
					graph->order_alterable=1;
					break;
				case R_MEMORY:
				case R_IMMEDIATE:
				{
					int i_aregs=graph_1->i_aregs+1-graph_1->order_alterable;
					graph->u_dregs=graph_1->u_dregs;
					graph->u_aregs=MAX (graph_1->u_aregs,i_aregs);
					graph->i_dregs=graph_1->i_dregs;
					graph->i_aregs=i_aregs;
					graph->order_alterable=1;
				}
			}
	
			graph->order_mode=R_MEMORY;
			
			return;
		}
		case GLOAD_B_ID:
		{
			INSTRUCTION_GRAPH graph_1;
			
			graph_1=graph->instruction_parameters[1].p;
			
			calculate_graph_register_uses (graph_1);
			
			graph->u_dregs=graph_1->u_dregs;
			graph->u_aregs=graph_1->u_aregs;
			graph->i_aregs=graph_1->i_aregs;
			graph->i_dregs=graph_1->i_dregs;
			
			if (graph_1->order_mode==R_DREGISTER)
				graph->i_dregs-=graph_1->order_alterable;
			else
				graph->i_aregs-=graph_1->order_alterable;

			if (graph->i_dregs+1 > graph->u_dregs)
				graph->u_dregs=graph->i_dregs+1;
					
			if (graph_1->instruction_d_min_a_cost<=0){
				++graph->i_dregs;
				graph->order_mode=R_DREGISTER;
			} else {
				if (graph->i_aregs+1 > graph->u_aregs)
					graph->u_aregs=graph->i_aregs+1;
				++graph->i_aregs;
				graph->order_mode=R_AREGISTER;
			}
			graph->order_alterable=1;
			
			return;
		}
		case GLOAD_DES_ID:
#ifdef G_A64
		case GLOAD_SQB_ID:
#endif
		{
			INSTRUCTION_GRAPH graph_1;
			
			graph_1=graph->instruction_parameters[1].p;
			
			calculate_graph_register_uses (graph_1);
			
			graph->u_dregs=graph_1->u_dregs;
			graph->u_aregs=graph_1->u_aregs;
			graph->i_aregs=graph_1->i_aregs;
			graph->i_dregs=graph_1->i_dregs;
			
			if (graph_1->order_mode==R_DREGISTER)
				graph->i_dregs-=graph_1->order_alterable;
			else
				graph->i_aregs-=graph_1->order_alterable;

			if (graph_1->instruction_d_min_a_cost<0){
				if (graph->i_dregs+1 > graph->u_dregs)
					graph->u_dregs=graph->i_dregs+1;
				++graph->i_dregs;
				graph->order_mode=R_DREGISTER;
			} else {
				if (graph->i_aregs+1 > graph->u_aregs)
					graph->u_aregs=graph->i_aregs+1;
				++graph->i_aregs;
				graph->order_mode=R_AREGISTER;
			}
			graph->order_alterable=1;
			
			return;
		}
		case GLOAD_X:
		case GLOAD_B_X:
#ifdef G_A64
		case GLOAD_S_X:
#endif
			calculate_load_x_operator (graph);
			return;
		case GSTORE:
		{
			INSTRUCTION_GRAPH load_graph,a_graph;
			
			a_graph=graph->instruction_parameters[2].p;
			load_graph=graph->instruction_parameters[3].p;
			
			calculate_graph_register_uses (a_graph);
			
			graph->u_dregs=a_graph->u_dregs;
			graph->u_aregs=a_graph->u_aregs;
			graph->i_aregs=a_graph->i_aregs;
			graph->i_dregs=a_graph->i_dregs;
			
			if (a_graph->order_alterable)
				if (a_graph->order_mode==R_DREGISTER)
					--graph->i_dregs;
				else
					--graph->i_aregs;
			
			if (load_graph!=NULL && load_graph->node_count>0 && load_graph->instruction_code==GLOAD){
				if (load_graph->instruction_d_min_a_cost<=0){
					++graph->i_dregs;
					if (graph->i_dregs>graph->u_dregs)
						graph->u_dregs=graph->i_dregs;
				} else {
					++graph->i_aregs;
					if (graph->i_aregs>graph->u_aregs)
						graph->u_aregs=graph->i_aregs;
				}
			}
			return;
		}
		case GSTORE_X:
		case GSTORE_B_X:
#ifdef G_A64
		case GSTORE_S_X:
#endif
			calculate_store_x_operator (graph);
			return;
		case GBEFORE:
		case GBEFORE0:
		{
			INSTRUCTION_GRAPH graph_1;
			int i;

			graph_1=graph->instruction_parameters[0].p;
			
			calculate_graph_register_uses (graph_1);
			
			graph->u_dregs=graph_1->u_dregs;
			graph->u_aregs=graph_1->u_aregs;
			graph->i_aregs=graph_1->i_aregs;
			graph->i_dregs=graph_1->i_dregs;
			
			for (i=1; i<graph->inode_arity; ++i){
				INSTRUCTION_GRAPH graph_2;

				graph_2=graph->instruction_parameters[i].p;

				if (graph_2->instruction_d_min_a_cost<=0){
					++graph->i_dregs;
					if (graph->i_dregs>graph->u_dregs)
						graph->u_dregs=graph->i_dregs;
				} else {
					++graph->i_aregs;
					if (graph->i_aregs>graph->u_aregs)
						graph->u_aregs=graph->i_aregs;
				}
			}
			
			graph->order_alterable=graph_1->order_alterable;
			graph->order_mode=graph_1->order_mode;
			return;
		}
		case GKEEP:
		case GFKEEP:
		{
			INSTRUCTION_GRAPH graph_1,graph_2;

			graph_1=graph->instruction_parameters[0].p;
			graph_2=graph->instruction_parameters[1].p;
			
			calculate_graph_register_uses (graph_1);
			calculate_graph_register_uses (graph_2);
			
			/* de volgende berekening is onnauwkeurig : */
			
			graph->u_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
			graph->u_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
		
			graph->i_aregs=graph_1->i_aregs+graph_2->i_aregs;
			graph->i_dregs=graph_1->i_dregs+graph_2->i_dregs;

			if (graph_1->order_mode==R_DREGISTER)
				graph->i_dregs-=graph_1->order_alterable;
			else
				graph->i_aregs-=graph_1->order_alterable;
	
			graph->order_mode=graph_2->order_mode;
			graph->order_alterable=graph_2->order_alterable;
			return;
		}
		case GSTORE_R:
		{
			INSTRUCTION_GRAPH a_graph,register_graph;
			int register_number;
			
			register_number=graph->instruction_parameters[0].i;
			a_graph=graph->instruction_parameters[1].p;
			
			calculate_graph_register_uses (a_graph);
			
			graph->u_dregs=a_graph->u_dregs;
			graph->u_aregs=a_graph->u_aregs;
			graph->i_aregs=a_graph->i_aregs;
			graph->i_dregs=a_graph->i_dregs;
			
			if (a_graph->order_alterable)
				if (a_graph->order_mode==R_DREGISTER)
					--graph->i_dregs;
				else
					--graph->i_aregs;
			
			register_graph=NULL;
			
			if (is_d_register (register_number)){
				++graph->i_dregs;
				if (graph->i_dregs>graph->u_dregs)
					graph->u_dregs=graph->i_dregs;
			
				if ((unsigned) d_reg_num (register_number) < (unsigned) N_DATA_PARAMETER_REGISTERS)
					register_graph=global_block.block_graph_d_register_parameter_node[d_reg_num (register_number)];
			} else {
				++graph->i_aregs;
				if (graph->i_aregs>graph->u_aregs)
					graph->u_aregs=graph->i_aregs;
			
				if ((unsigned) a_reg_num (register_number) < (unsigned) N_ADDRESS_PARAMETER_REGISTERS)
					register_graph=global_block.block_graph_a_register_parameter_node[a_reg_num (register_number)];
			}
			
			if (register_graph!=NULL && register_graph->node_count>0){
				if (register_graph->instruction_d_min_a_cost<=0){
					++graph->i_dregs;
					if (graph->i_dregs>graph->u_dregs)
						graph->u_dregs=graph->i_dregs;
				} else {
					++graph->i_aregs;
					if (graph->i_aregs>graph->u_aregs)
						graph->u_aregs=graph->i_aregs;
				}
			}

#ifdef PRINT_DEBUG
			printf ("GSTORE_R reg=%d ud=%d id=%d ua=%d ia=%d\n",register_number,
							graph->u_dregs,graph->i_dregs,graph->u_aregs,graph->i_aregs);
#endif
			
			return;
		}
		case GADD:
		case GADD_O:
			calculate_dyadic_commutative_operator (graph);
			return;
		case GAND:
		case GOR:
		case GMUL:
		case GMUL_O:
#if defined (G_POWER) || (defined (ARM) && defined (G_A64))
		case GUMULH:
#endif
			calculate_dyadic_commutative_data_operator (graph);
			return;
		case GCMP_EQ:
		case GCMP_GT:
		case GCMP_GTU:
		case GCMP_LT:
		case GCMP_LTU:
			calculate_compare_operator (graph);
			return;
		case GSUB:
		case GSUB_O:
			calculate_dyadic_non_commutative_operator (graph);
			return;
		case GDIV:
#if defined (I486) || defined (ARM) || defined (G_POWER)
		case GDIVU:
#endif
#if defined (I486) || defined (ARM)
		case GFLOORDIV:
		case GMOD:
#endif
			calculate_dyadic_non_commutative_data_operator (graph);
			return;
		case GREM:
#if defined (I486) || defined (ARM)
		case GREMU:
#endif
			calculate_rem_operator (graph);
			return;
		case GLSL:
		case GLSR:
		case GASR:
#if defined (I486) || defined (ARM)
		case GROTL:
		case GROTR:
#endif
			calculate_shift_operator (graph);
			return;
		case GCREATE:
		case GCREATE_U:
			calculate_create_operator (graph);
			return;
		case GCREATE_R:
			calculate_create_r_operator (graph);
			return;
		case GFILL_R:
			calculate_fill_r_operator (graph);
			return;
		case GFILL:
			calculate_fill_operator (graph);
			return;
		case GEOR:
			calculate_eor_operator (graph);
			return;
		case GCNOT:
		case GNEG:
#if defined (I486) || defined (ARM) || defined (G_POWER)
		case GNOT:
#endif
			calculate_cnot_operator (graph);
			return;
#if defined (I486) || defined (ARM)
		case GCLZB:
			calculate_clzb_operator (graph);
			return;
#endif
		case GMOVEMI:
			calculate_movemi_operator (graph);
			return;
		case GCOPY:
			calculate_copy_operator (graph);
			return;
		case GFADD:
		case GFDIV:
		case GFMUL:
		case GFREM:
		case GFSUB:
			calculate_dyadic_float_operator (graph);
			return;
		case GFCMP_EQ:
		case GFCMP_GT:
		case GFCMP_LT:
			calculate_dyadic_commutative_data_operator (graph);
			return;
		case GFCOS:
		case GFSIN:
		case GFTAN:
		case GFATAN:
		case GFSQRT:
		case GFNEG:
		case GFABS:
#ifdef M68000
		case GFASIN:
		case GFACOS:
		case GFLN:
		case GFLOG10:
		case GFEXP:
#endif
			calculate_monadic_float_operator (graph);
			return;
		case GFLOAD_ID:
			calculate_fload_id_operator (graph);
			return;
		case GFSTORE:
			calculate_fstore_operator (graph);
			return;
		case GFLOAD_X:
#if defined (I486) || defined (ARM)
		case GFLOAD_S_X:
#endif
			calculate_fload_x_operator (graph);
			return;
		case GFSTORE_X:
#if defined (I486) || defined (ARM)
		case GFSTORE_S_X:
#endif
			calculate_fstore_x_operator (graph);
			return;
		case GFSTORE_R:
			calculate_fstore_r_operator (graph);
			return;
		case GFLOAD:
		case GFLOAD_I:
		case GFREGISTER:
			graph->u_aregs=graph->i_aregs=0;
			graph->u_dregs=graph->i_dregs=0;
			graph->order_mode=R_DREGISTER;
			graph->order_alterable=0;
			return;
		case GFITOR:
		case GFRTOI:
			graph->u_aregs=graph->i_aregs=0;
			graph->u_dregs=graph->i_dregs=0;
			graph->order_mode=R_DREGISTER;
			graph->order_alterable=0;
			return;
		case GALLOCATE:
#ifdef G_A64
		case GFROMF:
		case GTOF:
		{
			INSTRUCTION_GRAPH graph_1;

			graph_1=graph->instruction_parameters[0].p;
			
			calculate_graph_register_uses (graph_1);
						
			graph->u_dregs=graph_1->u_dregs;
			graph->u_aregs=graph_1->u_aregs;
			graph->i_aregs=graph_1->i_aregs;
			graph->i_dregs=graph_1->i_dregs;

			graph->order_mode=graph_1->order_mode;
			graph->order_alterable=graph_1->order_alterable;
			return;
		}	
#else
		case GFJOIN:
		case GFHIGH:
		case GFLOW:
#endif
		case GFMOVEMI:
			graph->u_aregs=graph->i_aregs=0;
			graph->u_dregs=graph->i_dregs=0;
			graph->order_mode=R_DREGISTER;
			graph->order_alterable=0;
			return;
		case GBOUNDS:
			calculate_bounds_operator (graph);
			return;
		case GINDIRECTION:
		case GTEST_O:
		{
			INSTRUCTION_GRAPH graph_1;

			graph_1=graph->instruction_parameters[0].p;
			
			calculate_graph_register_uses (graph_1);
						
			graph->u_dregs=graph_1->u_dregs;
			graph->u_aregs=graph_1->u_aregs;
			graph->i_aregs=graph_1->i_aregs;
			graph->i_dregs=graph_1->i_dregs;
			
			graph->order_mode=graph_1->order_mode;
			graph->order_alterable=graph_1->order_alterable;
			return;
		}
		case GEXIT_IF:
		{
			INSTRUCTION_GRAPH graph_1,graph_2;

			graph_1=graph->instruction_parameters[1].p;
			graph_2=graph->instruction_parameters[2].p;
			
			calculate_graph_register_uses (graph_1);
			calculate_graph_register_uses (graph_2);
			
			/* de volgende berekening is onnauwkeurig : */
			
			graph->u_aregs=MAX (graph_1->u_aregs,graph_1->i_aregs+graph_2->u_aregs);
			graph->u_dregs=MAX (graph_1->u_dregs,graph_1->i_dregs+graph_2->u_dregs);
			
			graph->i_aregs=graph_1->i_aregs+graph_2->i_aregs;
			graph->i_dregs=graph_1->i_dregs+graph_2->i_dregs;
			
			if (graph_1->order_mode==R_DREGISTER)
				graph->i_dregs-=graph_1->order_alterable;
			else
				graph->i_aregs-=graph_1->order_alterable;
			
			graph->order_mode=graph_2->order_mode;
			graph->order_alterable=graph_2->order_alterable;
			return;
		}
#if defined (I486) || defined (ARM)
		case GRESULT0:
		case GRESULT1:
		{
			INSTRUCTION_GRAPH graph_0;

			graph_0=graph->instruction_parameters[0].p;
			if (graph_0->order_mode==R_NOMODE)
# if defined (I486) || (defined (ARM) && !defined (G_A64))
				if (graph_0->instruction_code==GMULUD)
					calculate_mulud_operator (graph_0);
				else
# endif
				if (
# ifdef I486
							graph_0->instruction_code==GDIVDU ||
# endif
							graph_0->instruction_code==GADDDU ||
							graph_0->instruction_code==GSUBDU)
				{
					calculate_divdu_operator (graph_0);
				} else
					internal_error_in_function ("calculate_graph_register_uses");

			graph->order_mode=R_DREGISTER;
			graph->u_aregs=graph_0->u_aregs;
			graph->u_dregs=graph_0->u_dregs;
			graph->i_aregs=graph_0->i_aregs;
			graph->i_dregs=graph_0->i_dregs;

			graph->order_alterable=graph->node_count<=1;		
			return;
		}
#endif
#if defined (I486) && !defined (G_AI64)
		case GFRESULT0:
		case GFRESULT1:
		{
			INSTRUCTION_GRAPH graph_0;

			graph_0=graph->instruction_parameters[0].p;
			if (graph_0->order_mode==R_NOMODE){
				INSTRUCTION_GRAPH graph_1;
				int i_dregs,u_dregs;

				/* GFSINCOS */

				graph_1=graph_0->instruction_parameters[0].p;
				
				calculate_graph_register_uses (graph_1);

				u_dregs=graph_1->u_dregs;
				i_dregs=graph_1->i_dregs;

				graph_0->u_aregs=graph_1->u_aregs;
				graph_0->i_aregs=graph_1->i_aregs;
				
				if (graph_1->order_mode==R_DREGISTER)
					i_dregs-=graph_1->order_alterable;
				else
					graph_0->i_aregs-=graph_1->order_alterable;
				
				i_dregs+=2;

				if (u_dregs<i_dregs)
					u_dregs=i_dregs;

				graph_0->i_dregs=i_dregs;
				graph_0->u_dregs=u_dregs;

				graph_0->order_mode=R_DREGISTER;
				graph_0->order_alterable=0;
			}

			graph->order_mode=R_DREGISTER;
			graph->u_aregs=graph_0->u_aregs;
			graph->u_dregs=graph_0->u_dregs;
			graph->i_aregs=graph_0->i_aregs;
			graph->i_dregs=graph_0->i_dregs;

			graph->order_alterable=graph->node_count<=1;			
			return;
		}
#endif
		default:
			/* printf ("%d\n",graph->instruction_code); */
			internal_error_in_function ("calculate_graph_register_uses");
	}
}

static void count_gstore_x_node (INSTRUCTION_GRAPH graph)
{
	INSTRUCTION_GRAPH low_graph,high_graph,h_store_x_graph;
	
	/* optime store_x for reals */
	
	low_graph=graph->instruction_parameters[0].p;
#ifndef G_A64
	if (low_graph->instruction_code==GFLOW){
		h_store_x_graph=graph->instruction_parameters[1].p;
		if (h_store_x_graph!=NULL
			&&	h_store_x_graph->instruction_code==GSTORE_X
			&& graph->instruction_parameters[3].p==h_store_x_graph->instruction_parameters[3].p
			&& graph->instruction_parameters[2].i==h_store_x_graph->instruction_parameters[2].i+(4<<2))
		{
			high_graph=h_store_x_graph->instruction_parameters[0].p;
			if (high_graph->instruction_code==GFHIGH
				&& high_graph->instruction_parameters[0].p==low_graph->instruction_parameters[0].p)
			{
				graph->instruction_code=GFSTORE_X;
				graph->instruction_parameters[0].p=low_graph->instruction_parameters[0].p;
				graph->instruction_parameters[1].p=h_store_x_graph->instruction_parameters[1].p;
				graph->instruction_parameters[2].i-=4<<2;
			}
		}
	}
#endif
	
	if (++graph->node_count==1){
		count_graph (graph->instruction_parameters[0].p);
		count_graph (graph->instruction_parameters[1].p);
		if (graph->instruction_parameters[3].p!=NULL)
			count_graph (graph->instruction_parameters[3].p);
	}
}

void count_graph (INSTRUCTION_GRAPH graph)
{
	switch (graph->instruction_code){
		case GADD:
		case GADD_O:
		case GAND:
		case GCMP_EQ:
		case GCMP_GT:
		case GCMP_GTU:
		case GCMP_LT:
		case GCMP_LTU:
		case GDIV:
#if defined (I486) || defined (ARM) || defined (G_POWER)
		case GDIVU:
#endif
#if defined (I486) || defined (ARM)
		case GFLOORDIV:
		case GMOD:
#endif
		case GFADD:
		case GFCMP_EQ:
		case GFCMP_GT:
		case GFCMP_LT:
		case GFDIV:
#ifndef G_A64
		case GFJOIN:
#endif
		case GFMUL:
		case GFREM:
		case GFSUB:
		case GLSL:
		case GLSR:
		case GREM:
#if defined (I486) || defined (ARM)
		case GREMU:
#endif
		case GMUL:
		case GMUL_O:
		case GOR:
		case GSUB:
		case GSUB_O:
		case GEOR:
		case GASR:
#if defined (I486) || defined (ARM)
		case GROTL:
		case GROTR:
#endif
		case GCOPY:
		case GBOUNDS:
#if defined (G_POWER) || (defined (ARM) && defined (G_A64))
		case GUMULH:
#endif
#if defined (I486) || (defined (ARM) && !defined (G_A64))
		case GMULUD:
#endif
			if (++graph->node_count==1){
				count_graph (graph->instruction_parameters[0].p);
				count_graph (graph->instruction_parameters[1].p);
			}
			break;
#ifdef G_A64
		case GFROMF:
		case GTOF:
#endif
		case GCNOT:
#ifndef G_A64
		case GFHIGH:
#endif
		case GFITOR:
#ifndef G_A64
		case GFLOW:
#endif
		case GFRTOI:
		case GFCOS:
		case GFSIN:
		case GFTAN:
		case GFATAN:
		case GFSQRT:
		case GFNEG:
		case GFABS:
#ifdef M68000
		case GFASIN:
		case GFACOS:
		case GFLN:
		case GFLOG10:
		case GFEXP:
#endif
		case GNEG:
#if defined (I486) || defined (ARM) || defined (G_POWER)
		case GNOT:
#endif
		case GBEFORE0:
		case GTEST_O:
#if defined (I486) || defined (ARM)
		case GRESULT0:
		case GRESULT1:
#endif
#if defined (I486) && !defined (G_AI64)
		case GFRESULT0:
		case GFRESULT1:
		case GFSINCOS:
#endif
#if defined (I486) || defined (ARM)
		case GCLZB:
#endif
			if (++graph->node_count==1)
				count_graph (graph->instruction_parameters[0].p);
			break;
		case GALLOCATE:
		case GCREATE_R:
		case GCREATE:
		case GCREATE_U:
		case GFILL_R:
		case GFILL:
		case GBEFORE:
		{
			int n;
			
			if (++graph->node_count==1){
				for (n=0; n<graph->inode_arity; ++n)
					if (graph->instruction_parameters[n].p!=NULL)
						count_graph (graph->instruction_parameters[n].p);
			}
			break;
		}
		case GMOVEM:
			if (++graph->node_count==1)
				count_graph (graph->instruction_parameters[1].p);
			break;
		case GMOVEMI:
		case GFMOVEMI:
			if (++graph->node_count==1)
				count_graph (graph->instruction_parameters[0].p);
			break;
		case GFLOAD_ID:
		case GLOAD_ID:
		case GLOAD_B_ID:
		case GLOAD_DES_ID:
#ifdef G_A64
		case GLOAD_SQB_ID:
#endif
			if (++graph->node_count==1)
				count_graph (graph->instruction_parameters[1].p);
			break;
		case GFSTORE:
		case GSTORE:
			if (++graph->node_count==1)
				count_graph (graph->instruction_parameters[2].p);
			break;
		case GSTORE_R:
		case GFSTORE_R:
			if (++graph->node_count==1)
				count_graph (graph->instruction_parameters[1].p);
			break;
		case GLOAD_X:
		case GLOAD_B_X:
		case GFLOAD_X:
#ifdef G_A64
		case GLOAD_S_X:
#endif
#if defined (I486) || defined (ARM)
		case GFLOAD_S_X:
#endif
			if (++graph->node_count==1){
				count_graph (graph->instruction_parameters[0].p);
				if (graph->instruction_parameters[2].p!=NULL)
					count_graph (graph->instruction_parameters[2].p);
			}
			break;
		case GSTORE_X:
		case GSTORE_B_X:
#ifdef G_A64
		case GSTORE_S_X:
#endif
			count_gstore_x_node (graph);
			break;
		case GFSTORE_X:
#if defined (I486) || defined (ARM)
		case GFSTORE_S_X:
#endif
			if (++graph->node_count==1){
				count_graph (graph->instruction_parameters[0].p);
				count_graph (graph->instruction_parameters[1].p);
				if (graph->instruction_parameters[3].p!=NULL)
					count_graph (graph->instruction_parameters[3].p);
			}
			break;
		case GKEEP:
		case GFKEEP:
			if (++graph->node_count==1){
				count_graph (graph->instruction_parameters[0].p);
				count_graph (graph->instruction_parameters[1].p);
			}
			break;
		case GEXIT_IF:
			if (++graph->node_count==1){
				count_graph (graph->instruction_parameters[1].p);
				count_graph (graph->instruction_parameters[2].p);
			}
			break;
		case GFLOAD:
		case GFLOAD_I:
		case GFREGISTER:
		case GGREGISTER:
		case GLEA:
		case GLOAD:
		case GLOAD_I:
		case GLOAD_DES_I:
		case GREGISTER:
			++graph->node_count;
			break;
#if defined (I486) || defined (ARM)
		case GADDDU:
		case GSUBDU:
# ifdef I486
		case GDIVDU:
# endif
			if (++graph->node_count==1){
				count_graph (graph->instruction_parameters[0].p);
				count_graph (graph->instruction_parameters[1].p);
				count_graph (graph->instruction_parameters[2].p);
			}
			break;
#endif
		default:
			internal_error_in_function ("count_graph");
	}
}

void mark_graph_2 (register INSTRUCTION_GRAPH graph)
{
	switch (graph->instruction_code){
		case GADD:
		case GADD_O:
		case GAND:
		case GCMP_EQ:
		case GCMP_GT:
		case GCMP_GTU:
		case GCMP_LT:
		case GCMP_LTU:
		case GDIV:
#if defined (I486) || defined (ARM) || defined (G_POWER)
		case GDIVU:
#endif
#if defined (I486) || defined (ARM)
		case GFLOORDIV:
		case GMOD:
#endif
		case GFADD:
		case GFCMP_EQ:
		case GFCMP_GT:
		case GFCMP_LT:
		case GFDIV:
#ifndef G_A64
		case GFJOIN:
#endif
		case GFMUL:
		case GFREM:
		case GFSUB:
		case GLSL:
		case GLSR:
		case GREM:
#if defined (I486) || defined (ARM)
		case GREMU:
#endif
		case GMUL:
		case GMUL_O:
		case GOR:
		case GSUB:
		case GSUB_O:
		case GEOR:
		case GASR:
#if defined (I486) || defined (ARM)
		case GROTL:
		case GROTR:
#endif
		case GCOPY:
		case GBOUNDS:
#if defined (G_POWER) || (defined (ARM) && defined (G_A64))
		case GUMULH:
#endif
#if defined (I486) || (defined (ARM) && !defined (G_A64))
		case GMULUD:
#endif
			if (graph->node_mark<2){
				graph->node_mark=2;
				mark_graph_2 (graph->instruction_parameters[0].p);
				mark_graph_2 (graph->instruction_parameters[1].p);
			}
			break;
#ifdef G_A64
		case GFROMF:
		case GTOF:
#endif
		case GCNOT:
#ifndef G_A64
		case GFHIGH:
#endif
		case GFITOR:
#ifndef G_A64
		case GFLOW:
#endif
		case GFRTOI:
		case GFCOS:
		case GFSIN:
		case GFTAN:
		case GFATAN:
		case GFSQRT:
		case GFNEG:
		case GFABS:
#ifdef M68000
		case GFASIN:
		case GFACOS:
		case GFLN:
		case GFLOG10:
		case GFEXP:
#endif
		case GNEG:
#if defined (I486) || defined (ARM) || defined (G_POWER)
		case GNOT:
#endif
		case GBEFORE0:
		case GTEST_O:
#if defined (I486) || defined (ARM)
		case GRESULT0:
		case GRESULT1:
#endif
#if defined (I486) && !defined (G_AI64)
		case GFRESULT0:
		case GFRESULT1:
		case GFSINCOS:
#endif
#if defined (I486) || defined (ARM)
		case GCLZB:
#endif
			if (graph->node_mark<2){
				graph->node_mark=2;
				mark_graph_2 (graph->instruction_parameters[0].p);
			}
			break;
		case GALLOCATE:
		case GCREATE_R:
		case GCREATE:
		case GCREATE_U:
		case GFILL_R:
		case GFILL:
		case GBEFORE:
		{
			int n;
			
			if (graph->node_mark<2){
				graph->node_mark=2;
				for (n=0; n<graph->inode_arity; ++n)
					if (graph->instruction_parameters[n].p!=NULL)
						mark_graph_2 (graph->instruction_parameters[n].p);
			}
			break;
		}
		case GMOVEM:
			if (graph->node_mark<2){
				graph->node_mark=2;
				mark_graph_2 (graph->instruction_parameters[1].p);
			}
			break;
		case GMOVEMI:
		case GFMOVEMI:
			if (graph->node_mark<2){
				graph->node_mark=2;
				mark_graph_2 (graph->instruction_parameters[0].p);
			}
			break;
		case GFLOAD_ID:
		case GLOAD_ID:
		case GLOAD_B_ID:
		case GLOAD_DES_ID:
#ifdef G_A64
		case GLOAD_SQB_ID:
#endif
			if (graph->node_mark<2){
				graph->node_mark=2;
				mark_graph_2 (graph->instruction_parameters[1].p);
			}
			break;
		case GFSTORE:
		case GSTORE:
			if (graph->node_mark<2){
				graph->node_mark=2;
				mark_graph_2 (graph->instruction_parameters[2].p);
			}
			break;
		case GSTORE_R:
			if (graph->node_mark<2){
				graph->node_mark=2;
				mark_graph_2 (graph->instruction_parameters[1].p);
			}
			break;
		case GLOAD_X:
		case GLOAD_B_X:
		case GFLOAD_X:
#ifdef G_A64
		case GLOAD_S_X:
#endif
#if defined (I486) || defined (ARM)
		case GFLOAD_S_X:
#endif
			if (graph->node_mark<2){
				graph->node_mark=2;
				mark_graph_2 (graph->instruction_parameters[0].p);
				if (graph->instruction_parameters[2].p)
					mark_graph_2 (graph->instruction_parameters[2].p);
			}
			break;
		case GSTORE_X:
		case GSTORE_B_X:
#ifdef G_A64
		case GSTORE_S_X:
#endif
		case GFSTORE_X:
#if defined (I486) || defined (ARM)
		case GFSTORE_S_X:
#endif
			if (graph->node_mark<2){
				graph->node_mark=2;
				mark_graph_2 (graph->instruction_parameters[0].p);
				mark_graph_2 (graph->instruction_parameters[1].p);
				if (graph->instruction_parameters[3].p)
					mark_graph_2 (graph->instruction_parameters[3].p);
			}
			break;
		case GKEEP:
		case GFKEEP:
			if (graph->node_mark<2){
				graph->node_mark=2;
				mark_graph_2 (graph->instruction_parameters[0].p);
				mark_graph_2 (graph->instruction_parameters[1].p);
			}
			break;
		case GEXIT_IF:
			if (graph->node_mark<2){
				graph->node_mark=2;
				mark_graph_2 (graph->instruction_parameters[1].p);
				mark_graph_2 (graph->instruction_parameters[2].p);
			}
			break;
		case GFLOAD:
		case GFLOAD_I:
		case GFREGISTER:
		case GGREGISTER:
		case GLEA:
		case GLOAD:
		case GLOAD_I:
		case GLOAD_DES_I:
		case GREGISTER:
			graph->node_mark=2;
			break;
#if defined (I486) || defined (ARM)
		case GADDDU:
		case GSUBDU:
# ifdef I486
		case GDIVDU:
# endif
			if (graph->node_mark<2){
				graph->node_mark=2;
				mark_graph_2 (graph->instruction_parameters[0].p);
				mark_graph_2 (graph->instruction_parameters[1].p);
				mark_graph_2 (graph->instruction_parameters[2].p);
			}
			break;
#endif
		default:
			internal_error_in_function ("mark_graph_2");
	}
}

void mark_graph_1 (register INSTRUCTION_GRAPH graph)
{
	switch (graph->instruction_code){
		case GADD:
		case GADD_O:
		case GAND:
		case GCMP_EQ:
		case GCMP_GT:
		case GCMP_GTU:
		case GCMP_LT:
		case GCMP_LTU:
		case GDIV:
#if defined (I486) || defined (ARM) || defined (G_POWER)
		case GDIVU:
#endif
#if defined (I486) || defined (ARM)
		case GFLOORDIV:
		case GMOD:
#endif
		case GFADD:
		case GFCMP_EQ:
		case GFCMP_GT:
		case GFCMP_LT:
		case GFDIV:
#ifndef G_A64
		case GFJOIN:
#endif
		case GFMUL:
		case GFREM:
		case GFSUB:
		case GLSL:
		case GLSR:
		case GREM:
#if defined (I486) || defined (ARM)
		case GREMU:
#endif
		case GMUL:
		case GMUL_O:
		case GOR:
		case GSUB:
		case GSUB_O:
		case GEOR:
		case GASR:
#if defined (I486) || defined (ARM)
		case GROTL:
		case GROTR:
#endif
		case GCOPY:
		case GBOUNDS:
#if defined (G_POWER) || (defined (ARM) && defined (G_A64))
		case GUMULH:
#endif
#if defined (I486) || (defined (ARM) && !defined (G_A64))
		case GMULUD:
#endif
			if (!graph->node_mark){
				graph->node_mark=1;
				mark_graph_2 (graph->instruction_parameters[0].p);
				mark_graph_2 (graph->instruction_parameters[1].p);
			}
			break;
#ifdef G_A64
		case GFROMF:
		case GTOF:
#endif
		case GCNOT:
		case GFITOR:
		case GFRTOI:
		case GFCOS:
		case GFSIN:
		case GFTAN:
		case GFATAN:
		case GFSQRT:
		case GFNEG:
		case GFABS:
#ifdef M68000
		case GFASIN:
		case GFACOS:
		case GFLN:
		case GFLOG10:
		case GFEXP:
#endif
		case GNEG:
#if defined (I486) || defined (ARM) || defined (G_POWER)
		case GNOT:
#endif
		case GBEFORE0:
		case GTEST_O:
#if defined (I486) || defined (ARM)
		case GRESULT0:
		case GRESULT1:
#endif
#if defined (I486) && !defined (G_AI64)
		case GFRESULT0:
		case GFRESULT1:
		case GFSINCOS:
#endif
#if defined (I486) || defined (ARM)
		case GCLZB:
#endif
			if (!graph->node_mark){
				graph->node_mark=1;
				mark_graph_2 (graph->instruction_parameters[0].p);
			}
			break;
		case GALLOCATE:
		case GCREATE_R:
		case GCREATE:
		case GCREATE_U:
		case GFILL_R:
		case GFILL:
		case GBEFORE:
		{
			int n;
			
			if (!graph->node_mark){
				graph->node_mark=1;
				for (n=0; n<graph->inode_arity; ++n)
					if (graph->instruction_parameters[n].p!=NULL)
						mark_graph_2 (graph->instruction_parameters[n].p);
			}
			break;
		}
		case GMOVEM:
			if (!graph->node_mark){
				graph->node_mark=1;
				mark_graph_2 (graph->instruction_parameters[1].p);
			}
			break;
		case GMOVEMI:
		case GFMOVEMI:
			if (!graph->node_mark){
				graph->node_mark=1;
				mark_graph_2 (graph->instruction_parameters[0].p);
			}
			break;
		case GFLOAD_ID:
		case GLOAD_ID:
		case GLOAD_B_ID:
		case GLOAD_DES_ID:
#ifdef G_A64
		case GLOAD_SQB_ID:
#endif
			if (!graph->node_mark){
				graph->node_mark=1;
				mark_graph_2 (graph->instruction_parameters[1].p);
			}
			break;
		case GFSTORE:
		case GSTORE:
			if (!graph->node_mark){
				graph->node_mark=1;
				mark_graph_2 (graph->instruction_parameters[2].p);
			}
			break;
		case GLOAD_X:
		case GLOAD_B_X:
		case GFLOAD_X:
#ifdef G_A64
		case GLOAD_S_X:
#endif
#if defined (I486) || defined (ARM)
		case GFLOAD_S_X:
#endif
			if (!graph->node_mark){
				graph->node_mark=1;
				mark_graph_2 (graph->instruction_parameters[0].p);
				if (graph->instruction_parameters[2].p)
					mark_graph_2 (graph->instruction_parameters[2].p);
			}
			break;
		case GSTORE_X:
		case GSTORE_B_X:
#ifdef G_A64
		case GSTORE_S_X:
#endif
		case GFSTORE_X:
#if defined (I486) || defined (ARM)
		case GFSTORE_S_X:
#endif
			if (!graph->node_mark){
				graph->node_mark=1;
				mark_graph_2 (graph->instruction_parameters[0].p);
				mark_graph_2 (graph->instruction_parameters[1].p);
				if (graph->instruction_parameters[3].p)
					mark_graph_2 (graph->instruction_parameters[3].p);
			}
			break;
		case GSTORE_R:
			if (!graph->node_mark){
				graph->node_mark=1;
				mark_graph_2 (graph->instruction_parameters[1].p);
			}
			break;
		case GKEEP:
		case GFKEEP:
			if (!graph->node_mark){
				graph->node_mark=1;
				mark_graph_2 (graph->instruction_parameters[0].p);
				mark_graph_2 (graph->instruction_parameters[1].p);
			}
			break;
		case GEXIT_IF:
			if (!graph->node_mark){
				graph->node_mark=1;
				mark_graph_2 (graph->instruction_parameters[1].p);
				mark_graph_2 (graph->instruction_parameters[2].p);
			}
			break;
		case GFLOAD:
		case GFLOAD_I:
		case GFREGISTER:
		case GGREGISTER:
		case GLEA:
		case GLOAD:
		case GLOAD_I:
		case GLOAD_DES_I:
		case GREGISTER:
			if (!graph->node_mark)
				graph->node_mark=1;
			break;
#ifndef G_A64
		case GFHIGH:
		case GFLOW:
			if (!graph->node_mark){
				graph->node_mark=1;
				mark_graph_1 (graph->instruction_parameters[0].p);
			}
			break;
#endif
#ifdef I486
		case GDIVDU:
			if (!graph->node_mark){
				graph->node_mark=1;
				mark_graph_2 (graph->instruction_parameters[0].p);
				mark_graph_2 (graph->instruction_parameters[1].p);
				mark_graph_2 (graph->instruction_parameters[2].p);
			}
			break;
#endif
		default:
			internal_error_in_function ("mark_graph_1");
	}
}

void mark_and_count_graph (INSTRUCTION_GRAPH graph)
{
	mark_graph_2 (graph);
	count_graph (graph);
}
