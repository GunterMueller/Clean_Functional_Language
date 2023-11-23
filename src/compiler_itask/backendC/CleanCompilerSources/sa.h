
extern Bool DoStrictExportChecks;
extern Bool DoStrictRelated;

extern void StrictnessAnalysis (ImpMod imod);
extern int init_strictness_analysis (ImpMod imod);
extern void do_strictness_analysis (void);
extern void finish_strictness_analysis (void);
extern int StrictnessAnalysisConvertRules (ImpRuleS *rules);
extern void StrictnessAnalysisForRule (SymbDef sdef);
extern void free_unused_sa_blocks (void);

#if SA_RECOGNIZES_ABORT_AND_UNDEF
extern char *StdMiscId;
extern SymbDef abort_symb_def,undef_symb_def;
#endif

extern SymbDef scc_dependency_list;
