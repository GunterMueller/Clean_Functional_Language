
extern void InitGlobalSymbols (void);

extern Args NewArgument (NodeP pattern);
extern NodeP NewNode (SymbolP symb, Args args, int arity);
extern NodeP NewSelectorNode (SymbolP symb, Args args, int arity);
extern NodeP NewNodeIdNode (NodeIdP node_id);
extern NodeP NewUpdateNode (SymbDef sdef,Args args,int arity);
extern NodeP NewNodeByKind (NodeKind nodeKind, SymbolP symb, Args args, int arity);

extern NodeIdP NewNodeId (void);
extern SymbolP NewSymbol (SymbKind symbolKind);

extern NodeDefs NewNodeDef (NodeId nid, Node node);

extern SymbDef MakeNewSymbolDefinition (char *module, char *name, int arity, SDefKind kind);

extern SymbolP	TrueSymbol, FalseSymbol, TupleSymbol,
				ApplySymbol, ApplyTypeSymbol, SelectSymbols[],
				FailSymbol, IfSymbol;

extern	SymbolP	TupleTypeSymbols [];

void clear_p_at_node_tree (void);
void store_p_at_node (NodeP annoted_node,NodeP at_node);
NodeP *get_p_at_node_p (NodeP annoted_node);
NodeP get_p_at_node (NodeP annoted_node);
