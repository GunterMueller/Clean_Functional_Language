extern void calculate_graph_register_uses (INSTRUCTION_GRAPH graph);
extern void count_graph (INSTRUCTION_GRAPH graph);
extern void mark_graph_1 (INSTRUCTION_GRAPH graph);
extern void mark_graph_2 (INSTRUCTION_GRAPH graph);
extern void mark_and_count_graph (INSTRUCTION_GRAPH graph);

#ifdef I486
/* #	define A_FACTOR 2 */
/* #	define D_FACTOR 2 */
#	define AD_REG_WEIGHT(n_a_regs,n_d_regs) ((n_a_regs)+(n_d_regs))
#elif defined (ARM)
/* #	define A_FACTOR 5 */
/* #	define D_FACTOR 3 */
#	define AD_REG_WEIGHT(n_a_regs,n_d_regs) ((((n_a_regs)<<2)+(n_a_regs))+((n_d_regs)+(n_d_regs)+(n_d_regs)))
#else
/* #	define A_FACTOR 7 */
/* #	define D_FACTOR 3 */
#	define AD_REG_WEIGHT(n_a_regs,n_d_regs) ((((n_a_regs)<<3)-(n_a_regs))+((n_d_regs)+(n_d_regs)+(n_d_regs)))
#endif
