implementation module backend;

:: CPtr :== Int;
:: *UWorld :== Int;
:: *BackEnd :== CPtr;
:: BESymbolP :== CPtr;
:: BETypeSymbolP :== CPtr;
:: BETypeNodeP :== CPtr;
:: BETypeArgP :== CPtr;
:: BETypeAltP :== CPtr;
:: BENodeP :== CPtr;
:: BEArgP :== CPtr;
:: BERuleAltP :== CPtr;
:: BEImpRuleP :== CPtr;
:: BEConstructorListP :== CPtr;
:: BEFieldListP :== CPtr;
:: BENodeIdP :== CPtr;
:: BENodeDefP :== CPtr;
:: BEStrictNodeIdP :== CPtr;
:: BECodeParameterP :== CPtr;
:: BECodeBlockP :== CPtr;
:: BEStringListP :== CPtr;
:: BENodeIdListP :== CPtr;
:: BENodeIdRefCountListP :== CPtr;
:: BEAnnotation :== Int;
:: BEAttribution :== Int;
:: BESymbKind :== Int;
:: BETypeSymbKind :== Int;
:: BEArrayFunKind :== Int;
:: BESelectorKind :== Int;
:: BESpecialIdentIndex :== Int;

BEGetVersion :: (!Int,!Int,!Int);
BEGetVersion  = code {
	ccall BEGetVersion ":VIII"
}
// void BEGetVersion (int* current,int* oldestDefinition,int* oldestImplementation);

BEInit :: !Int !UWorld -> (!BackEnd,!UWorld);
BEInit a0 a1 = code {
	ccall BEInit "I:p:p"
}
// BackEnd BEInit (int argc);

BECloseFiles :: !BackEnd -> BackEnd;
BECloseFiles a0 = code {
	ccall BECloseFiles ":V:p"
}
// void BECloseFiles ();

BEFree :: !BackEnd !UWorld -> UWorld;
BEFree a0 a1 = code {
	ccall BEFree "p:V:p"
}
// void BEFree (BackEnd backEnd);

BEArg :: !String !BackEnd -> BackEnd;
BEArg a0 a1 = code {
	ccall BEArg "S:V:p"
}
// void BEArg (CleanString arg);

BEDeclareModules :: !Int !BackEnd -> BackEnd;
BEDeclareModules a0 a1 = code {
	ccall BEDeclareModules "I:V:p"
}
// void BEDeclareModules (int nModules);

BEBindSpecialModule :: !BESpecialIdentIndex !Int !BackEnd -> BackEnd;
BEBindSpecialModule a0 a1 a2 = code {
	ccall BEBindSpecialModule "II:V:p"
}
// void BEBindSpecialModule (BESpecialIdentIndex index,int moduleIndex);

BEBindSpecialFunction :: !BESpecialIdentIndex !Int !Int !BackEnd -> BackEnd;
BEBindSpecialFunction a0 a1 a2 a3 = code {
	ccall BEBindSpecialFunction "III:V:p"
}
// void BEBindSpecialFunction (BESpecialIdentIndex index,int functionIndex,int moduleIndex);

BEBindSpecialType :: !Int !Int !Int !BackEnd -> BackEnd;
BEBindSpecialType a0 a1 a2 a3 = code {
	ccall BEBindSpecialType "III:V:p"
}
// void BEBindSpecialType (int special_type_n,int type_index,int module_index);

BESpecialArrayFunctionSymbol :: !BEArrayFunKind !Int !Int !BackEnd -> (!BESymbolP,!BackEnd);
BESpecialArrayFunctionSymbol a0 a1 a2 a3 = code {
	ccall BESpecialArrayFunctionSymbol "III:p:p"
}
// BESymbolP BESpecialArrayFunctionSymbol (BEArrayFunKind arrayFunKind,int functionIndex,int moduleIndex);

BEDictionarySelectFunSymbol :: !BackEnd -> (!BESymbolP,!BackEnd);
BEDictionarySelectFunSymbol a0 = code {
	ccall BEDictionarySelectFunSymbol ":p:p"
}
// BESymbolP BEDictionarySelectFunSymbol ();

BEDictionaryUpdateFunSymbol :: !BackEnd -> (!BESymbolP,!BackEnd);
BEDictionaryUpdateFunSymbol a0 = code {
	ccall BEDictionaryUpdateFunSymbol ":p:p"
}
// BESymbolP BEDictionaryUpdateFunSymbol ();

BEFunctionSymbol :: !Int !Int !BackEnd -> (!BESymbolP,!BackEnd);
BEFunctionSymbol a0 a1 a2 = code {
	ccall BEFunctionSymbol "II:p:p"
}
// BESymbolP BEFunctionSymbol (int functionIndex,int moduleIndex);

BEConstructorSymbol :: !Int !Int !BackEnd -> (!BESymbolP,!BackEnd);
BEConstructorSymbol a0 a1 a2 = code {
	ccall BEConstructorSymbol "II:p:p"
}
// BESymbolP BEConstructorSymbol (int constructorIndex,int moduleIndex);

BEFieldSymbol :: !Int !Int !BackEnd -> (!BESymbolP,!BackEnd);
BEFieldSymbol a0 a1 a2 = code {
	ccall BEFieldSymbol "II:p:p"
}
// BESymbolP BEFieldSymbol (int fieldIndex,int moduleIndex);

BETypeSymbol :: !Int !Int !BackEnd -> (!BETypeSymbolP,!BackEnd);
BETypeSymbol a0 a1 a2 = code {
	ccall BETypeSymbol "II:p:p"
}
// BETypeSymbolP BETypeSymbol (int typeIndex,int moduleIndex);

BETypeSymbolNoMark :: !Int !Int !BackEnd -> (!BETypeSymbolP,!BackEnd);
BETypeSymbolNoMark a0 a1 a2 = code {
	ccall BETypeSymbolNoMark "II:p:p"
}
// BETypeSymbolP BETypeSymbolNoMark (int typeIndex,int moduleIndex);

BEExternalTypeSymbol :: !Int !Int !BackEnd -> (!BETypeSymbolP,!BackEnd);
BEExternalTypeSymbol a0 a1 a2 = code {
	ccall BEExternalTypeSymbol "II:p:p"
}
// BETypeSymbolP BEExternalTypeSymbol (int typeIndex,int moduleIndex);

BEDontCareDefinitionSymbol :: !BackEnd -> (!BESymbolP,!BackEnd);
BEDontCareDefinitionSymbol a0 = code {
	ccall BEDontCareDefinitionSymbol ":p:p"
}
// BESymbolP BEDontCareDefinitionSymbol ();

BEDontCareTypeDefinitionSymbol :: !BackEnd -> (!BETypeSymbolP,!BackEnd);
BEDontCareTypeDefinitionSymbol a0 = code {
	ccall BEDontCareTypeDefinitionSymbol ":p:p"
}
// BETypeSymbolP BEDontCareTypeDefinitionSymbol ();

BEBoolSymbol :: !Bool !BackEnd -> (!BESymbolP,!BackEnd);
BEBoolSymbol a0 a1 = code {
	ccall BEBoolSymbol "I:p:p"
}
// BESymbolP BEBoolSymbol (int value);

BELiteralSymbol :: !BESymbKind !String !BackEnd -> (!BESymbolP,!BackEnd);
BELiteralSymbol a0 a1 a2 = code {
	ccall BELiteralSymbol "IS:p:p"
}
// BESymbolP BELiteralSymbol (BESymbKind kind,CleanString value);

BEPredefineListConstructorSymbol :: !Int !Int !BESymbKind !Int !Int !BackEnd -> BackEnd;
BEPredefineListConstructorSymbol a0 a1 a2 a3 a4 a5 = code {
	ccall BEPredefineListConstructorSymbol "IIIII:V:p"
}
// void BEPredefineListConstructorSymbol (int constructorIndex,int moduleIndex,BESymbKind symbolKind,int head_strictness,int tail_strictness);

BEPredefineMaybeConstructorSymbol :: !Int !Int !BESymbKind !Int !BackEnd -> BackEnd;
BEPredefineMaybeConstructorSymbol a0 a1 a2 a3 a4 = code {
	ccall BEPredefineMaybeConstructorSymbol "IIII:V:p"
}
// void BEPredefineMaybeConstructorSymbol (int constructorIndex, int moduleIndex, BESymbKind symbolKind,int head_strictness);

BEPredefineListTypeSymbol :: !Int !Int !BETypeSymbKind !Int !Int !BackEnd -> BackEnd;
BEPredefineListTypeSymbol a0 a1 a2 a3 a4 a5 = code {
	ccall BEPredefineListTypeSymbol "IIIII:V:p"
}
// void BEPredefineListTypeSymbol (int typeIndex,int moduleIndex,BETypeSymbKind symbolKind,int head_strictness,int tail_strictness);

BEPredefineMaybeTypeSymbol :: !Int !Int !Int !BackEnd -> BackEnd;
BEPredefineMaybeTypeSymbol a0 a1 a2 a3 = code {
	ccall BEPredefineMaybeTypeSymbol "III:V:p"
}
// void BEPredefineMaybeTypeSymbol (int typeIndex,int moduleIndex,int head_strictness);

BEAdjustStrictListConsInstance :: !Int !Int !BackEnd -> BackEnd;
BEAdjustStrictListConsInstance a0 a1 a2 = code {
	ccall BEAdjustStrictListConsInstance "II:V:p"
}
// void BEAdjustStrictListConsInstance (int functionIndex,int moduleIndex);

BEAdjustStrictJustInstance :: !Int !Int !BackEnd -> BackEnd;
BEAdjustStrictJustInstance a0 a1 a2 = code {
	ccall BEAdjustStrictJustInstance "II:V:p"
}
// void BEAdjustStrictJustInstance (int functionIndex, int moduleIndex);

BEAdjustUnboxedListDeconsInstance :: !Int !Int !BackEnd -> BackEnd;
BEAdjustUnboxedListDeconsInstance a0 a1 a2 = code {
	ccall BEAdjustUnboxedListDeconsInstance "II:V:p"
}
// void BEAdjustUnboxedListDeconsInstance (int functionIndex,int moduleIndex);

BEAdjustUnboxedFromJustInstance :: !Int !Int !BackEnd -> BackEnd;
BEAdjustUnboxedFromJustInstance a0 a1 a2 = code {
	ccall BEAdjustUnboxedFromJustInstance "II:V:p"
}
// void BEAdjustUnboxedFromJustInstance (int functionIndex, int moduleIndex);

BEAdjustOverloadedNilFunction :: !Int !Int !BackEnd -> BackEnd;
BEAdjustOverloadedNilFunction a0 a1 a2 = code {
	ccall BEAdjustOverloadedNilFunction "II:V:p"
}
// void BEAdjustOverloadedNilFunction (int functionIndex,int moduleIndex);

BEAdjustOverloadedNoneFunction :: !Int !Int !BackEnd -> BackEnd;
BEAdjustOverloadedNoneFunction a0 a1 a2 = code {
	ccall BEAdjustOverloadedNoneFunction "II:V:p"
}
// void BEAdjustOverloadedNoneFunction (int functionIndex,int moduleIndex);

BEOverloadedConsSymbol :: !Int !Int !Int !Int !BackEnd -> (!BESymbolP,!BackEnd);
BEOverloadedConsSymbol a0 a1 a2 a3 a4 = code {
	ccall BEOverloadedConsSymbol "IIII:p:p"
}
// BESymbolP BEOverloadedConsSymbol (int constructorIndex,int moduleIndex,int deconsIndex,int deconsModuleIndex);

BEOverloadedPushNode :: !Int !BESymbolP !BEArgP !BENodeIdListP !BENodeP !BackEnd -> (!BENodeP,!BackEnd);
BEOverloadedPushNode a0 a1 a2 a3 a4 a5 = code {
	ccall BEOverloadedPushNode "Ipppp:p:p"
}
// BENodeP BEOverloadedPushNode (int arity,BESymbolP symbol,BEArgP arguments,BENodeIdListP nodeIds,BENodeP decons_node);

BEPredefineConstructorSymbol :: !Int !Int !Int !BESymbKind !BackEnd -> BackEnd;
BEPredefineConstructorSymbol a0 a1 a2 a3 a4 = code {
	ccall BEPredefineConstructorSymbol "IIII:V:p"
}
// void BEPredefineConstructorSymbol (int arity,int constructorIndex,int moduleIndex,BESymbKind symbolKind);

BEPredefineTypeSymbol :: !Int !Int !Int !BETypeSymbKind !BackEnd -> BackEnd;
BEPredefineTypeSymbol a0 a1 a2 a3 a4 = code {
	ccall BEPredefineTypeSymbol "IIII:V:p"
}
// void BEPredefineTypeSymbol (int arity,int typeIndex,int moduleIndex,BETypeSymbKind symbolKind);

BEBasicSymbol :: !Int !BackEnd -> (!BESymbolP,!BackEnd);
BEBasicSymbol a0 a1 = code {
	ccall BEBasicSymbol "I:p:p"
}
// BESymbolP BEBasicSymbol (BESymbKind kind);

BEBasicTypeSymbol :: !Int !BackEnd -> (!BETypeSymbolP,!BackEnd);
BEBasicTypeSymbol a0 a1 = code {
	ccall BEBasicTypeSymbol "I:p:p"
}
// BETypeSymbolP BEBasicTypeSymbol (BETypeSymbKind kind);

BEVar0TypeNode :: !BEAnnotation !BEAttribution !BackEnd -> (!BETypeNodeP,!BackEnd);
BEVar0TypeNode a0 a1 a2 = code {
	ccall BEVar0TypeNode "II:p:p"
}
// BETypeNodeP BEVar0TypeNode (BEAnnotation annotation,BEAttribution attribution);

BEVarNTypeNode :: !BEAnnotation !BEAttribution !Int !BackEnd -> (!BETypeNodeP,!BackEnd);
BEVarNTypeNode a0 a1 a2 a3 = code {
	ccall BEVarNTypeNode "III:p:p"
}
// BETypeNodeP BEVarNTypeNode (BEAnnotation annotation,BEAttribution attribution,int argument_n);

BESymbolTypeNode :: !BEAnnotation !BEAttribution !BETypeSymbolP !BETypeArgP !BackEnd -> (!BETypeNodeP,!BackEnd);
BESymbolTypeNode a0 a1 a2 a3 a4 = code {
	ccall BESymbolTypeNode "IIpp:p:p"
}
// BETypeNodeP BESymbolTypeNode (BEAnnotation annotation,BEAttribution attribution,BETypeSymbolP symbol,BETypeArgP args);

BENoTypeArgs :: !BackEnd -> (!BETypeArgP,!BackEnd);
BENoTypeArgs a0 = code {
	ccall BENoTypeArgs ":p:p"
}
// BETypeArgP BENoTypeArgs ();

BETypeArgs :: !BETypeNodeP !BETypeArgP !BackEnd -> (!BETypeArgP,!BackEnd);
BETypeArgs a0 a1 a2 = code {
	ccall BETypeArgs "pp:p:p"
}
// BETypeArgP BETypeArgs (BETypeNodeP node,BETypeArgP nextArgs);

BETypeAlt :: !BESymbolP !BETypeArgP !BETypeNodeP !BackEnd -> (!BETypeAltP,!BackEnd);
BETypeAlt a0 a1 a2 a3 = code {
	ccall BETypeAlt "ppp:p:p"
}
// BETypeAltP BETypeAlt (BESymbolP lhs_symbol,BETypeArgP lhs_arguments,BETypeNodeP rhs);

BENormalNode :: !BESymbolP !BEArgP !BackEnd -> (!BENodeP,!BackEnd);
BENormalNode a0 a1 a2 = code {
	ccall BENormalNode "pp:p:p"
}
// BENodeP BENormalNode (BESymbolP symbol,BEArgP args);

BEMatchNode :: !Int !BESymbolP !BENodeP !BackEnd -> (!BENodeP,!BackEnd);
BEMatchNode a0 a1 a2 a3 = code {
	ccall BEMatchNode "Ipp:p:p"
}
// BENodeP BEMatchNode (int arity,BESymbolP symbol,BENodeP node);

BETupleSelectNode :: !Int !Int !BENodeP !BackEnd -> (!BENodeP,!BackEnd);
BETupleSelectNode a0 a1 a2 a3 = code {
	ccall BETupleSelectNode "IIp:p:p"
}
// BENodeP BETupleSelectNode (int arity,int index,BENodeP node);

BEIfNode :: !BENodeP !BENodeP !BENodeP !BackEnd -> (!BENodeP,!BackEnd);
BEIfNode a0 a1 a2 a3 = code {
	ccall BEIfNode "ppp:p:p"
}
// BENodeP BEIfNode (BENodeP cond,BENodeP then,BENodeP elsje);

BEGuardNode :: !BENodeP !BENodeDefP !BEStrictNodeIdP !BENodeP !BENodeDefP !BEStrictNodeIdP !BENodeP !BackEnd -> (!BENodeP,!BackEnd);
BEGuardNode a0 a1 a2 a3 a4 a5 a6 a7 = code {
	ccall BEGuardNode "ppppppp:p:p"
}
// BENodeP BEGuardNode (BENodeP cond,BENodeDefP thenNodeDefs,BEStrictNodeIdP thenStricts,BENodeP then,BENodeDefP elseNodeDefs,BEStrictNodeIdP elseStricts,BENodeP elsje);

BESetNodeDefRefCounts :: !BENodeP !BackEnd -> BackEnd;
BESetNodeDefRefCounts a0 a1 = code {
	ccall BESetNodeDefRefCounts "p:V:p"
}
// void BESetNodeDefRefCounts (BENodeP lhs);

BEAddNodeIdsRefCounts :: !Int !BESymbolP !BENodeIdListP !BackEnd -> BackEnd;
BEAddNodeIdsRefCounts a0 a1 a2 a3 = code {
	ccall BEAddNodeIdsRefCounts "Ipp:V:p"
}
// void BEAddNodeIdsRefCounts (int sequenceNumber,BESymbolP symbol,BENodeIdListP nodeIds);

BESwitchNode :: !BENodeIdP !BEArgP !BackEnd -> (!BENodeP,!BackEnd);
BESwitchNode a0 a1 a2 = code {
	ccall BESwitchNode "pp:p:p"
}
// BENodeP BESwitchNode (BENodeIdP nodeId,BEArgP caseNode);

BECaseNode :: !Int !BESymbolP !BENodeDefP !BEStrictNodeIdP !BENodeP !BackEnd -> (!BENodeP,!BackEnd);
BECaseNode a0 a1 a2 a3 a4 a5 = code {
	ccall BECaseNode "Ipppp:p:p"
}
// BENodeP BECaseNode (int symbolArity,BESymbolP symbol,BENodeDefP nodeDefs,BEStrictNodeIdP strictNodeIds,BENodeP node);

BEOverloadedCaseNode :: !BENodeP !BENodeP !BENodeP !BackEnd -> (!BENodeP,!BackEnd);
BEOverloadedCaseNode a0 a1 a2 a3 = code {
	ccall BEOverloadedCaseNode "ppp:p:p"
}
// BENodeP BEOverloadedCaseNode (BENodeP case_node,BENodeP equal_node,BENodeP from_integer_node);

BEEnterLocalScope :: !BackEnd -> BackEnd;
BEEnterLocalScope a0 = code {
	ccall BEEnterLocalScope ":V:p"
}
// void BEEnterLocalScope ();

BELeaveLocalScope :: !BENodeP !BackEnd -> BackEnd;
BELeaveLocalScope a0 a1 = code {
	ccall BELeaveLocalScope "p:V:p"
}
// void BELeaveLocalScope (BENodeP node);

BEPushNode :: !Int !BESymbolP !BEArgP !BENodeIdListP !BackEnd -> (!BENodeP,!BackEnd);
BEPushNode a0 a1 a2 a3 a4 = code {
	ccall BEPushNode "Ippp:p:p"
}
// BENodeP BEPushNode (int arity,BESymbolP symbol,BEArgP arguments,BENodeIdListP nodeIds);

BEDefaultNode :: !BENodeDefP !BEStrictNodeIdP !BENodeP !BackEnd -> (!BENodeP,!BackEnd);
BEDefaultNode a0 a1 a2 a3 = code {
	ccall BEDefaultNode "ppp:p:p"
}
// BENodeP BEDefaultNode (BENodeDefP nodeDefs,BEStrictNodeIdP strictNodeIds,BENodeP node);

BESelectorNode :: !BESelectorKind !BESymbolP !BEArgP !BackEnd -> (!BENodeP,!BackEnd);
BESelectorNode a0 a1 a2 a3 = code {
	ccall BESelectorNode "Ipp:p:p"
}
// BENodeP BESelectorNode (BESelectorKind selectorKind,BESymbolP fieldSymbol,BEArgP args);

BEUpdateNode :: !BEArgP !BackEnd -> (!BENodeP,!BackEnd);
BEUpdateNode a0 a1 = code {
	ccall BEUpdateNode "p:p:p"
}
// BENodeP BEUpdateNode (BEArgP args);

BENodeIdNode :: !BENodeIdP !BEArgP !BackEnd -> (!BENodeP,!BackEnd);
BENodeIdNode a0 a1 a2 = code {
	ccall BENodeIdNode "pp:p:p"
}
// BENodeP BENodeIdNode (BENodeIdP nodeId,BEArgP args);

BENoArgs :: !BackEnd -> (!BEArgP,!BackEnd);
BENoArgs a0 = code {
	ccall BENoArgs ":p:p"
}
// BEArgP BENoArgs ();

BEArgs :: !BENodeP !BEArgP !BackEnd -> (!BEArgP,!BackEnd);
BEArgs a0 a1 a2 = code {
	ccall BEArgs "pp:p:p"
}
// BEArgP BEArgs (BENodeP node,BEArgP nextArgs);

BERuleAlt :: !Int !BENodeDefP !BENodeP !BENodeDefP !BEStrictNodeIdP !BENodeP !BackEnd -> (!BERuleAltP,!BackEnd);
BERuleAlt a0 a1 a2 a3 a4 a5 a6 = code {
	ccall BERuleAlt "Ippppp:p:p"
}
// BERuleAltP BERuleAlt (int line,BENodeDefP lhsDefs,BENodeP lhs,BENodeDefP rhsDefs,BEStrictNodeIdP lhsStrictNodeIds,BENodeP rhs);

BEDeclareNodeId :: !Int !Int !String !BackEnd -> BackEnd;
BEDeclareNodeId a0 a1 a2 a3 = code {
	ccall BEDeclareNodeId "IIS:V:p"
}
// void BEDeclareNodeId (int sequenceNumber,int lhsOrRhs,CleanString name);

BENodeId :: !Int !BackEnd -> (!BENodeIdP,!BackEnd);
BENodeId a0 a1 = code {
	ccall BENodeId "I:p:p"
}
// BENodeIdP BENodeId (int sequenceNumber);

BEWildCardNodeId :: !BackEnd -> (!BENodeIdP,!BackEnd);
BEWildCardNodeId a0 = code {
	ccall BEWildCardNodeId ":p:p"
}
// BENodeIdP BEWildCardNodeId ();

BENodeDefList :: !Int !BENodeP !BENodeDefP !BackEnd -> (!BENodeDefP,!BackEnd);
BENodeDefList a0 a1 a2 a3 = code {
	ccall BENodeDefList "Ipp:p:p"
}
// BENodeDefP BENodeDefList (int sequenceNumber,BENodeP node,BENodeDefP nodeDefs);

BENoNodeDefs :: !BackEnd -> (!BENodeDefP,!BackEnd);
BENoNodeDefs a0 = code {
	ccall BENoNodeDefs ":p:p"
}
// BENodeDefP BENoNodeDefs ();

BEStrictNodeIdList :: !BENodeIdP !BEStrictNodeIdP !BackEnd -> (!BEStrictNodeIdP,!BackEnd);
BEStrictNodeIdList a0 a1 a2 = code {
	ccall BEStrictNodeIdList "pp:p:p"
}
// BEStrictNodeIdP BEStrictNodeIdList (BENodeIdP nodeId,BEStrictNodeIdP strictNodeIds);

BENoStrictNodeIds :: !BackEnd -> (!BEStrictNodeIdP,!BackEnd);
BENoStrictNodeIds a0 = code {
	ccall BENoStrictNodeIds ":p:p"
}
// BEStrictNodeIdP BENoStrictNodeIds ();

BERule :: !Int !Int !BETypeAltP !BERuleAltP !BackEnd -> (!BEImpRuleP,!BackEnd);
BERule a0 a1 a2 a3 a4 = code {
	ccall BERule "IIpp:p:p"
}
// BEImpRuleP BERule (int functionIndex,int isCaf,BETypeAltP type,BERuleAltP alts);

BEDeclareRuleType :: !Int !Int !String !BackEnd -> BackEnd;
BEDeclareRuleType a0 a1 a2 a3 = code {
	ccall BEDeclareRuleType "IIS:V:p"
}
// void BEDeclareRuleType (int functionIndex,int moduleIndex,CleanString name);

BEDefineRuleType :: !Int !Int !BETypeAltP !BackEnd -> BackEnd;
BEDefineRuleType a0 a1 a2 a3 = code {
	ccall BEDefineRuleType "IIp:V:p"
}
// void BEDefineRuleType (int functionIndex,int moduleIndex,BETypeAltP typeAlt);

BEDefineRuleTypeWithCode :: !Int !Int !BETypeAltP !BECodeBlockP !BackEnd -> BackEnd;
BEDefineRuleTypeWithCode a0 a1 a2 a3 a4 = code {
	ccall BEDefineRuleTypeWithCode "IIpp:V:p"
}
// void BEDefineRuleTypeWithCode (int functionIndex,int moduleIndex,BETypeAltP typeAlt,BECodeBlockP codeBlock);

BEAdjustArrayFunction :: !BEArrayFunKind !Int !Int !BackEnd -> BackEnd;
BEAdjustArrayFunction a0 a1 a2 a3 = code {
	ccall BEAdjustArrayFunction "III:V:p"
}
// void BEAdjustArrayFunction (BEArrayFunKind arrayFunKind,int functionIndex,int moduleIndex);

BENoRules :: !BackEnd -> (!BEImpRuleP,!BackEnd);
BENoRules a0 = code {
	ccall BENoRules ":p:p"
}
// BEImpRuleP BENoRules ();

BERules :: !BEImpRuleP !BEImpRuleP !BackEnd -> (!BEImpRuleP,!BackEnd);
BERules a0 a1 a2 = code {
	ccall BERules "pp:p:p"
}
// BEImpRuleP BERules (BEImpRuleP rule,BEImpRuleP rules);

BEDefineAlgebraicType :: !BETypeSymbolP !BEAttribution !BEConstructorListP !BackEnd -> BackEnd;
BEDefineAlgebraicType a0 a1 a2 a3 = code {
	ccall BEDefineAlgebraicType "pIp:V:p"
}
// void BEDefineAlgebraicType (BETypeSymbolP symbol,BEAttribution attribution,BEConstructorListP constructors);

BEDefineExtensibleAlgebraicType :: !BETypeSymbolP !BEAttribution !BEConstructorListP !BackEnd -> BackEnd;
BEDefineExtensibleAlgebraicType a0 a1 a2 a3 = code {
	ccall BEDefineExtensibleAlgebraicType "pIp:V:p"
}
// void BEDefineExtensibleAlgebraicType (BETypeSymbolP symbol,BEAttribution attribution,BEConstructorListP constructors);

BEDefineRecordType :: !BETypeSymbolP !BEAttribution !Int !Int !BETypeArgP !Int !BEFieldListP !BackEnd -> BackEnd;
BEDefineRecordType a0 a1 a2 a3 a4 a5 a6 a7 = code {
	ccall BEDefineRecordType "pIIIpIp:V:p"
}
// void BEDefineRecordType (BETypeSymbolP symbol,BEAttribution attribution,int moduleIndex,int constructorIndex,BETypeArgP constructor_args,int is_boxed_record,BEFieldListP fields);

BEAbstractType :: !BETypeSymbolP !BackEnd -> BackEnd;
BEAbstractType a0 a1 = code {
	ccall BEAbstractType "p:V:p"
}
// void BEAbstractType (BETypeSymbolP symbol);

BENoConstructors :: !BackEnd -> (!BEConstructorListP,!BackEnd);
BENoConstructors a0 = code {
	ccall BENoConstructors ":p:p"
}
// BEConstructorListP BENoConstructors ();

BEConstructorList :: !BESymbolP !BETypeArgP !BEConstructorListP !BackEnd -> (!BEConstructorListP,!BackEnd);
BEConstructorList a0 a1 a2 a3 = code {
	ccall BEConstructorList "ppp:p:p"
}
// BEConstructorListP BEConstructorList (BESymbolP symbol_p,BETypeArgP type_args,BEConstructorListP constructors);

BEFieldList :: !Int !Int !String !BETypeNodeP !BEFieldListP !BackEnd -> (!BEFieldListP,!BackEnd);
BEFieldList a0 a1 a2 a3 a4 a5 = code {
	ccall BEFieldList "IISpp:p:p"
}
// BEFieldListP BEFieldList (int fieldIndex,int moduleIndex,CleanString name,BETypeNodeP type,BEFieldListP next_fields);

BESetMemberTypeOfField :: !Int !Int !BETypeAltP !BackEnd -> BackEnd;
BESetMemberTypeOfField a0 a1 a2 a3 = code {
	ccall BESetMemberTypeOfField "IIp:V:p"
}
// void BESetMemberTypeOfField (int fieldIndex,int moduleIndex,BETypeAltP typeAlt);

BESetDictionaryFieldOfMember :: !Int !Int !Int !BackEnd -> (!Int,!BackEnd);
BESetDictionaryFieldOfMember a0 a1 a2 a3 = code {
	ccall BESetDictionaryFieldOfMember "III:I:p"
}
// int BESetDictionaryFieldOfMember (int function_index,int field_index,int field_module_index);

BESetInstanceFunctionOfFunction :: !Int !Int !BackEnd -> BackEnd;
BESetInstanceFunctionOfFunction a0 a1 a2 = code {
	ccall BESetInstanceFunctionOfFunction "II:V:p"
}
// void BESetInstanceFunctionOfFunction (int function_index,int instance_function_index);

BENoFields :: !BackEnd -> (!BEFieldListP,!BackEnd);
BENoFields a0 = code {
	ccall BENoFields ":p:p"
}
// BEFieldListP BENoFields ();

BEDeclareConstructor :: !Int !Int !String !BackEnd -> BackEnd;
BEDeclareConstructor a0 a1 a2 a3 = code {
	ccall BEDeclareConstructor "IIS:V:p"
}
// void BEDeclareConstructor (int constructorIndex,int moduleIndex,CleanString name);

BEDeclareType :: !Int !Int !String !BackEnd -> BackEnd;
BEDeclareType a0 a1 a2 a3 = code {
	ccall BEDeclareType "IIS:V:p"
}
// void BEDeclareType (int typeIndex,int moduleIndex,CleanString name);

BEDeclareFunction :: !String !Int !Int !Int !BackEnd -> BackEnd;
BEDeclareFunction a0 a1 a2 a3 a4 = code {
	ccall BEDeclareFunction "SIII:V:p"
}
// void BEDeclareFunction (CleanString name,int arity,int functionIndex,int ancestor);

BEStartFunction :: !Int !BackEnd -> BackEnd;
BEStartFunction a0 a1 = code {
	ccall BEStartFunction "I:V:p"
}
// void BEStartFunction (int functionIndex);

BECodeAlt :: !Int !BENodeDefP !BENodeP !BECodeBlockP !BackEnd -> (!BERuleAltP,!BackEnd);
BECodeAlt a0 a1 a2 a3 a4 = code {
	ccall BECodeAlt "Ippp:p:p"
}
// BERuleAltP BECodeAlt (int line,BENodeDefP lhsDefs,BENodeP lhs,BECodeBlockP codeBlock);

BEStringList :: !String !BEStringListP !BackEnd -> (!BEStringListP,!BackEnd);
BEStringList a0 a1 a2 = code {
	ccall BEStringList "Sp:p:p"
}
// BEStringListP BEStringList (CleanString cleanString,BEStringListP strings);

BENoStrings :: !BackEnd -> (!BEStringListP,!BackEnd);
BENoStrings a0 = code {
	ccall BENoStrings ":p:p"
}
// BEStringListP BENoStrings ();

BECodeParameterList :: !String !BENodeIdP !BECodeParameterP !BackEnd -> (!BECodeParameterP,!BackEnd);
BECodeParameterList a0 a1 a2 a3 = code {
	ccall BECodeParameterList "Spp:p:p"
}
// BECodeParameterP BECodeParameterList (CleanString location,BENodeIdP nodeId,BECodeParameterP parameters);

BENoCodeParameters :: !BackEnd -> (!BECodeParameterP,!BackEnd);
BENoCodeParameters a0 = code {
	ccall BENoCodeParameters ":p:p"
}
// BECodeParameterP BENoCodeParameters ();

BENodeIdList :: !BENodeIdP !BENodeIdListP !BackEnd -> (!BENodeIdListP,!BackEnd);
BENodeIdList a0 a1 a2 = code {
	ccall BENodeIdList "pp:p:p"
}
// BENodeIdListP BENodeIdList (BENodeIdP nodeId,BENodeIdListP nids);

BENoNodeIds :: !BackEnd -> (!BENodeIdListP,!BackEnd);
BENoNodeIds a0 = code {
	ccall BENoNodeIds ":p:p"
}
// BENodeIdListP BENoNodeIds ();

BEAbcCodeBlock :: !Bool !BEStringListP !BackEnd -> (!BECodeBlockP,!BackEnd);
BEAbcCodeBlock a0 a1 a2 = code {
	ccall BEAbcCodeBlock "Ip:p:p"
}
// BECodeBlockP BEAbcCodeBlock (int inlineFlag,BEStringListP instructions);

BEAnyCodeBlock :: !BECodeParameterP !BECodeParameterP !BEStringListP !BackEnd -> (!BECodeBlockP,!BackEnd);
BEAnyCodeBlock a0 a1 a2 a3 = code {
	ccall BEAnyCodeBlock "ppp:p:p"
}
// BECodeBlockP BEAnyCodeBlock (BECodeParameterP inParams,BECodeParameterP outParams,BEStringListP instructions);

BEDeclareIclModule :: !String !String !Int !Int !Int !Int !BackEnd -> BackEnd;
BEDeclareIclModule a0 a1 a2 a3 a4 a5 a6 = code {
	ccall BEDeclareIclModule "SSIIII:V:p"
}
// void BEDeclareIclModule (CleanString name,CleanString modificationTime,int nFunctions,int nTypes,int nConstructors,int nFields);

BEDeclareDclModule :: !Int !String !String !Bool !Int !Int !Int !Int !BackEnd -> BackEnd;
BEDeclareDclModule a0 a1 a2 a3 a4 a5 a6 a7 a8 = code {
	ccall BEDeclareDclModule "ISSIIIII:V:p"
}
// void BEDeclareDclModule (int moduleIndex,CleanString name,CleanString modificationTime,int systemModule,int nFunctions,int nTypes,int nConstructors,int nFields);

BEDeclarePredefinedModule :: !Int !Int !BackEnd -> BackEnd;
BEDeclarePredefinedModule a0 a1 a2 = code {
	ccall BEDeclarePredefinedModule "II:V:p"
}
// void BEDeclarePredefinedModule (int nTypes,int nConstructors);

BEDefineRules :: !BEImpRuleP !BackEnd -> BackEnd;
BEDefineRules a0 a1 = code {
	ccall BEDefineRules "p:V:p"
}
// void BEDefineRules (BEImpRuleP rules);

BEParseCommandArgs :: !BackEnd -> (!Int,!BackEnd);
BEParseCommandArgs a0 = code {
	ccall BEParseCommandArgs ":I:p"
}
// int BEParseCommandArgs (void);

BEGenerateStatesAndOptimise :: !BackEnd -> (!Int,!BackEnd);
BEGenerateStatesAndOptimise a0 = code {
	ccall BEGenerateStatesAndOptimise ":I:p"
}
// int BEGenerateStatesAndOptimise (void);

BEGenerateCode :: !String !BackEnd -> (!Bool,!BackEnd);
BEGenerateCode a0 a1 = code {
	ccall BEGenerateCode "S:I:p"
}
// int BEGenerateCode (CleanString outputFile);

BEExportType :: !Bool !Int !BackEnd -> BackEnd;
BEExportType a0 a1 a2 = code {
	ccall BEExportType "II:V:p"
}
// void BEExportType (int isDictionary,int typeIndex);

BEExportConstructor :: !Int !BackEnd -> BackEnd;
BEExportConstructor a0 a1 = code {
	ccall BEExportConstructor "I:V:p"
}
// void BEExportConstructor (int constructorIndex);

BEExportField :: !Bool !Int !BackEnd -> BackEnd;
BEExportField a0 a1 a2 = code {
	ccall BEExportField "II:V:p"
}
// void BEExportField (int isDictionaryField,int fieldIndex);

BEExportFunction :: !Int !BackEnd -> BackEnd;
BEExportFunction a0 a1 = code {
	ccall BEExportFunction "I:V:p"
}
// void BEExportFunction (int functionIndex);

BEDefineImportedObjsAndLibs :: !BEStringListP !BEStringListP !BackEnd -> BackEnd;
BEDefineImportedObjsAndLibs a0 a1 a2 = code {
	ccall BEDefineImportedObjsAndLibs "pp:V:p"
}
// void BEDefineImportedObjsAndLibs (BEStringListP objs,BEStringListP libs);

BEInsertForeignExport :: !BESymbolP !Int !BackEnd -> BackEnd;
BEInsertForeignExport a0 a1 a2 = code {
	ccall BEInsertForeignExport "pI:V:p"
}
// void BEInsertForeignExport (BESymbolP symbol_p,int stdcall);

BESetMainDclModuleN :: !Int !BackEnd -> BackEnd;
BESetMainDclModuleN a0 a1 = code {
	ccall BESetMainDclModuleN "I:V:p"
}
// void BESetMainDclModuleN (int main_dcl_module_n_parameter);

BEStrictPositions :: !Int !BackEnd -> (!Int,!Int,!BackEnd);
BEStrictPositions a0 a1 = code {
	ccall BEStrictPositions "I:VIp:p"
}
// void BEStrictPositions (int functionIndex,int* bits,int** positions);

BEGetIntFromArray :: !Int !Int -> Int;
BEGetIntFromArray a0 a1 = code {
	ccall BEGetIntFromArray "Ip:I"
}
// int BEGetIntFromArray (int index,int* ints);

BEDeclareDynamicTypeSymbol :: !Int !Int !BackEnd -> BackEnd;
BEDeclareDynamicTypeSymbol a0 a1 a2 = code {
	ccall BEDeclareDynamicTypeSymbol "II:V:p"
}
// void BEDeclareDynamicTypeSymbol (int typeIndex,int moduleIndex);

BEDynamicTempTypeSymbol :: !BackEnd -> (!BETypeSymbolP,!BackEnd);
BEDynamicTempTypeSymbol a0 = code {
	ccall BEDynamicTempTypeSymbol ":p:p"
}
// BETypeSymbolP BEDynamicTempTypeSymbol ();
kBEVersionCurrent:==0x02116000;
kBEVersionOldestDefinition:==0x02100401;
kBEVersionOldestImplementation:==0x02100401;
kBEDebug:==1;
kPredefinedModuleIndex:==1;
BENoAnnot:==0;
BEStrictAnnot:==1;
BENoUniAttr:==0;
BENotUniqueAttr:==1;
BEUniqueAttr:==2;
BEExistsAttr:==3;
BEUniqueVariable:==4;
BEFirstUniVarNumber:==5;
BERationalDenot:==0;
BEIntDenot:==1;
BEBoolDenot:==2;
BECharDenot:==3;
BERealDenot:==4;
BEIntegerDenot:==5;
BEStringDenot:==6;
BETupleSymb:==7;
BEConsSymb:==8;
BEJustSymb:==9;
BENilSymb:==10;
BENoneSymb:==11;
BEApplySymb:==12;
BEIfSymb:==13;
BEFailSymb:==14;
BEIntType:==0;
BEBoolType:==1;
BECharType:==2;
BERealType:==3;
BEFileType:==4;
BEWorldType:==5;
BEProcIdType:==6;
BERedIdType:==7;
BEFunType:==8;
BEArrayType:==9;
BEStrictArrayType:==10;
BEUnboxedArrayType:==11;
BEPackedArrayType:==12;
BEListType:==13;
BEMaybeType:==14;
BETupleType:==15;
BEDynamicType:==16;
BEApplyType:==17;
BECreateArrayFun:==0;
BEArraySelectFun:==1;
BEUnqArraySelectFun:==2;
BEArrayUpdateFun:==3;
BEArrayReplaceFun:==4;
BEArraySizeFun:==5;
BEUnqArraySizeFun:==6;
BE_CreateArrayFun:==7;
BE_UnqArraySelectFun:==8;
BE_UnqArraySelectNextFun:==9;
BE_UnqArraySelectLastFun:==10;
BE_ArrayUpdateFun:==11;
BENoArrayFun:==12;
BESelectorDummy:==0;
BESelector:==1;
BESelector_U:==2;
BESelector_F:==3;
BESelector_L:==4;
BESelector_N:==5;
BESpecialIdentStdMisc:==0;
BESpecialIdentAbort:==1;
BESpecialIdentUndef:==2;
BESpecialIdentStdBool:==3;
BESpecialIdentAnd:==4;
BESpecialIdentOr:==5;
BESpecialIdentPrelude:==6;
BESpecialIdentSeq:==7;
BESpecialIdentCount:==8;
BELhsNodeId:==0;
BERhsNodeId:==1;
BEIsNotACaf:==0;
BEIsACaf:==1;

BESetABCFile :: !Int !BackEnd -> BackEnd;
BESetABCFile a0 a1 = code {
	ccall BESetABCFile "p:V:p"
}
// void BESetABCFile (void *a0);

BESetStdErrorFile :: !Int !BackEnd -> BackEnd;
BESetStdErrorFile a0 a1 = code {
	ccall BESetStdErrorFile "p:V:p"
}
// void BESetStdErrorFile (void *a0);
