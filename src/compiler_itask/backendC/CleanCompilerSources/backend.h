/* version info */

// Version number use Apple's numbering in the version resource
// see <http://developer.apple.com/documentation/mac/Toolbox/Toolbox-487.html>
// major 8 bits, example 2 = 0x02
// minor 4+4 bits, example 1.1 = 0x11
// development stage: 0x20 development, 0x40 alpha, 0x60 beta, 0x80 release
// revision level

// increment this for every release
# define	kBEVersionCurrent				0x02116000

// change this to the same value as kBEVersionCurrent if the new release is
// not upward compatible (for example when a function is added)
# define	kBEVersionOldestDefinition		0x02100401

// change this to the same value as kBEVersionCurrent if the new release is
// not downward compatible (for example when a function is removed)
# define	kBEVersionOldestImplementation	0x02100401


# define	kBEDebug	1

/* pointer types */

Clean (:: CPtr (:== Int))

Clean (:: *UWorld :== Int)

typedef struct BackEnd *BackEnd;
Clean (:: *BackEnd (:== CPtr))

typedef struct symbol *BESymbolP;
Clean (:: BESymbolP (:== CPtr))

typedef struct type_symbol *BETypeSymbolP;
Clean (:: BETypeSymbolP (:== CPtr))

typedef struct type_node *BETypeNodeP;
Clean (:: BETypeNodeP (:== CPtr))

typedef struct type_arg *BETypeArgP;
Clean (:: BETypeArgP (:== CPtr))

typedef struct type_alt *BETypeAltP;
Clean (:: BETypeAltP (:== CPtr))

typedef struct node *BENodeP;
Clean (:: BENodeP (:== CPtr))

typedef struct arg *BEArgP;
Clean (:: BEArgP (:== CPtr))

typedef struct rule_alt *BERuleAltP;
Clean (:: BERuleAltP (:== CPtr))

typedef struct imp_rule *BEImpRuleP;
Clean (:: BEImpRuleP (:== CPtr))

typedef struct constructor_list *BEConstructorListP;
Clean (:: BEConstructorListP (:== CPtr))

typedef struct field_list *BEFieldListP;
Clean (:: BEFieldListP (:== CPtr))

typedef struct node_id *BENodeIdP;
Clean (:: BENodeIdP (:== CPtr))

typedef struct node_def *BENodeDefP;
Clean (:: BENodeDefP (:== CPtr))

typedef struct strict_node_id *BEStrictNodeIdP;
Clean (:: BEStrictNodeIdP (:== CPtr))

typedef struct parameter *BECodeParameterP;
Clean (:: BECodeParameterP (:== CPtr))

typedef struct code_block *BECodeBlockP;
Clean (:: BECodeBlockP (:== CPtr))

typedef struct string_list *BEStringListP;
Clean (:: BEStringListP (:== CPtr))

typedef struct node_id_list_element *BENodeIdListP;
Clean (:: BENodeIdListP (:== CPtr))

typedef struct node_id_ref_count_list *BENodeIdRefCountListP;
Clean (:: BENodeIdRefCountListP (:== CPtr))

/* constants */
/*
# define	kIclModuleIndex			0
*/
# define	kPredefinedModuleIndex	1

/* enum types */
typedef int	BEAnnotation;
Clean (:: BEAnnotation :== Int)
enum {
	BENoAnnot, BEStrictAnnot
};

typedef int	BEAttribution;
Clean (:: BEAttribution :== Int)
enum {
	BENoUniAttr, BENotUniqueAttr, BEUniqueAttr, BEExistsAttr, BEUniqueVariable, BEFirstUniVarNumber
};

typedef int	BESymbKind;
Clean (:: BESymbKind :== Int)
enum {
	BERationalDenot,
	BEIntDenot, BEBoolDenot, BECharDenot, BERealDenot,
	BEIntegerDenot,
	BEStringDenot,
	BETupleSymb,
	BEConsSymb, BEJustSymb, BENilSymb, BENoneSymb,
	BEApplySymb, BEIfSymb, BEFailSymb
};

typedef int	BETypeSymbKind;
Clean (:: BETypeSymbKind :== Int)
enum {
	BEIntType, BEBoolType, BECharType, BERealType,
	BEFileType, BEWorldType, BEProcIdType, BERedIdType,
	BEFunType, BEArrayType, BEStrictArrayType, BEUnboxedArrayType, BEPackedArrayType,
	BEListType, BEMaybeType, BETupleType,
	BEDynamicType, BEApplyType
};

typedef int BEArrayFunKind;
Clean (::BEArrayFunKind :== Int)
enum {
	BECreateArrayFun, BEArraySelectFun, BEUnqArraySelectFun, BEArrayUpdateFun,
	BEArrayReplaceFun, BEArraySizeFun, BEUnqArraySizeFun,
	BE_CreateArrayFun,BE_UnqArraySelectFun,BE_UnqArraySelectNextFun,BE_UnqArraySelectLastFun,
	BE_ArrayUpdateFun,
	BENoArrayFun 
};

typedef int	BESelectorKind;
Clean (::BESelectorKind :== Int)
enum {
	BESelectorDummy, BESelector, BESelector_U, BESelector_F, BESelector_L, BESelector_N
};

typedef int BESpecialIdentIndex;
Clean (::BESpecialIdentIndex :== Int)
enum {
	BESpecialIdentStdMisc, BESpecialIdentAbort, BESpecialIdentUndef,
	BESpecialIdentStdBool, BESpecialIdentAnd, BESpecialIdentOr,
	BESpecialIdentPrelude, BESpecialIdentSeq,

	BESpecialIdentCount
};
/* functions */

void BEGetVersion (int *current, int *oldestDefinition, int *oldestImplementation);
Clean (BEGetVersion :: (Int, Int, Int))

BackEnd BEInit (int argc);
Clean (BEInit :: Int UWorld -> (BackEnd, UWorld))

void BECloseFiles (void);
Clean (BECloseFiles :: BackEnd -> BackEnd)

void BEFree (BackEnd backEnd);
Clean (BEFree :: BackEnd UWorld -> UWorld)

void BEArg (CleanString arg);
Clean (BEArg :: String BackEnd -> BackEnd)

void BEDeclareModules (int nModules);
Clean (BEDeclareModules :: Int BackEnd -> BackEnd)

void BEBindSpecialModule (BESpecialIdentIndex index, int moduleIndex);
Clean (BEBindSpecialModule :: BESpecialIdentIndex Int BackEnd -> BackEnd)

void BEBindSpecialFunction (BESpecialIdentIndex index, int functionIndex, int moduleIndex);
Clean (BEBindSpecialFunction :: BESpecialIdentIndex Int Int BackEnd -> BackEnd)

void BEBindSpecialType (int special_type_n,int type_index,int module_index);
Clean (BEBindSpecialType :: Int Int Int BackEnd -> BackEnd)

BESymbolP BESpecialArrayFunctionSymbol (BEArrayFunKind arrayFunKind, int functionIndex, int moduleIndex);
Clean (BESpecialArrayFunctionSymbol :: BEArrayFunKind Int Int BackEnd -> (BESymbolP, BackEnd))

BESymbolP BEDictionarySelectFunSymbol (void);
Clean (BEDictionarySelectFunSymbol :: BackEnd -> (BESymbolP, BackEnd))

BESymbolP BEDictionaryUpdateFunSymbol (void);
Clean (BEDictionaryUpdateFunSymbol :: BackEnd -> (BESymbolP, BackEnd))

BESymbolP BEFunctionSymbol (int functionIndex, int moduleIndex);
Clean (BEFunctionSymbol :: Int Int BackEnd -> (BESymbolP, BackEnd))

BESymbolP BEConstructorSymbol (int constructorIndex, int moduleIndex);
Clean (BEConstructorSymbol :: Int Int BackEnd -> (BESymbolP, BackEnd))

BESymbolP BEFieldSymbol (int fieldIndex, int moduleIndex);
Clean (BEFieldSymbol :: Int Int BackEnd -> (BESymbolP, BackEnd))

BETypeSymbolP BETypeSymbol (int typeIndex, int moduleIndex);
Clean (BETypeSymbol :: Int Int BackEnd -> (BETypeSymbolP, BackEnd))

BETypeSymbolP BETypeSymbolNoMark (int typeIndex, int moduleIndex);
Clean (BETypeSymbolNoMark :: Int Int BackEnd -> (BETypeSymbolP, BackEnd))

BETypeSymbolP BEExternalTypeSymbol (int typeIndex, int moduleIndex);
Clean (BEExternalTypeSymbol :: Int Int BackEnd -> (BETypeSymbolP, BackEnd))

BESymbolP BEDontCareDefinitionSymbol (void);
Clean (BEDontCareDefinitionSymbol :: BackEnd -> (BESymbolP, BackEnd))

BETypeSymbolP BEDontCareTypeDefinitionSymbol (void);
Clean (BEDontCareTypeDefinitionSymbol :: BackEnd -> (BETypeSymbolP, BackEnd))

BESymbolP BEBoolSymbol (int value);
Clean (BEBoolSymbol :: Bool BackEnd -> (BESymbolP, BackEnd))

BESymbolP BELiteralSymbol (BESymbKind kind, CleanString value);
Clean (BELiteralSymbol :: BESymbKind String BackEnd -> (BESymbolP, BackEnd))

void BEPredefineListConstructorSymbol (int constructorIndex, int moduleIndex, BESymbKind symbolKind,int head_strictness,int tail_strictness);
Clean (BEPredefineListConstructorSymbol :: Int Int BESymbKind Int Int BackEnd -> BackEnd)

void BEPredefineMaybeConstructorSymbol (int constructorIndex, int moduleIndex, BESymbKind symbolKind,int head_strictness);
Clean (BEPredefineMaybeConstructorSymbol :: Int Int BESymbKind Int BackEnd -> BackEnd)

void BEPredefineListTypeSymbol (int typeIndex, int moduleIndex, BETypeSymbKind symbolKind,int head_strictness,int tail_strictness);
Clean (BEPredefineListTypeSymbol :: Int Int BETypeSymbKind Int Int BackEnd -> BackEnd)

void BEPredefineMaybeTypeSymbol (int typeIndex, int moduleIndex, int head_strictness);
Clean (BEPredefineMaybeTypeSymbol :: Int Int Int BackEnd -> BackEnd)

void BEAdjustStrictListConsInstance (int functionIndex, int moduleIndex);
Clean (BEAdjustStrictListConsInstance :: Int Int BackEnd -> BackEnd)

void BEAdjustStrictJustInstance (int functionIndex, int moduleIndex);
Clean (BEAdjustStrictJustInstance :: Int Int BackEnd -> BackEnd)

void BEAdjustUnboxedListDeconsInstance (int functionIndex, int moduleIndex);
Clean (BEAdjustUnboxedListDeconsInstance :: Int Int BackEnd -> BackEnd)

void BEAdjustUnboxedFromJustInstance (int functionIndex, int moduleIndex);
Clean (BEAdjustUnboxedFromJustInstance :: Int Int BackEnd -> BackEnd)

void BEAdjustOverloadedNilFunction (int functionIndex,int moduleIndex);
Clean (BEAdjustOverloadedNilFunction :: Int Int BackEnd -> BackEnd)

void BEAdjustOverloadedNoneFunction (int functionIndex,int moduleIndex);
Clean (BEAdjustOverloadedNoneFunction :: Int Int BackEnd -> BackEnd)

BESymbolP BEOverloadedConsSymbol (int constructorIndex,int moduleIndex,int deconsIndex,int deconsModuleIndex);
Clean (BEOverloadedConsSymbol :: Int Int Int Int BackEnd -> (BESymbolP,BackEnd))

BENodeP BEOverloadedPushNode (int arity,BESymbolP symbol,BEArgP arguments,BENodeIdListP nodeIds,BENodeP decons_node);
Clean (BEOverloadedPushNode :: Int BESymbolP BEArgP BENodeIdListP BENodeP BackEnd -> (BENodeP, BackEnd))

void BEPredefineConstructorSymbol (int arity, int constructorIndex, int moduleIndex, BESymbKind symbolKind);
Clean (BEPredefineConstructorSymbol :: Int Int Int BESymbKind BackEnd -> BackEnd)

void BEPredefineTypeSymbol (int arity, int typeIndex, int moduleIndex, BETypeSymbKind symbolKind);
Clean (BEPredefineTypeSymbol :: Int Int Int BETypeSymbKind BackEnd -> BackEnd)

BESymbolP BEBasicSymbol (BESymbKind kind);
Clean (BEBasicSymbol :: Int BackEnd -> (BESymbolP, BackEnd))

BETypeSymbolP BEBasicTypeSymbol (BETypeSymbKind kind);
Clean (BEBasicTypeSymbol :: Int BackEnd -> (BETypeSymbolP, BackEnd))

BETypeNodeP BEVar0TypeNode (BEAnnotation annotation, BEAttribution attribution);
Clean (BEVar0TypeNode :: BEAnnotation BEAttribution BackEnd -> (BETypeNodeP, BackEnd))

BETypeNodeP BEVarNTypeNode (BEAnnotation annotation, BEAttribution attribution, int argument_n);
Clean (BEVarNTypeNode :: BEAnnotation BEAttribution Int BackEnd -> (BETypeNodeP, BackEnd))

BETypeNodeP BESymbolTypeNode (BEAnnotation annotation, BEAttribution attribution, BETypeSymbolP symbol, BETypeArgP args);
Clean (BESymbolTypeNode :: BEAnnotation BEAttribution BETypeSymbolP BETypeArgP BackEnd -> (BETypeNodeP, BackEnd))

BETypeArgP BENoTypeArgs (void);
Clean (BENoTypeArgs :: BackEnd -> (BETypeArgP, BackEnd))

BETypeArgP BETypeArgs (BETypeNodeP node, BETypeArgP nextArgs);
Clean (BETypeArgs :: BETypeNodeP BETypeArgP BackEnd -> (BETypeArgP, BackEnd))

BETypeAltP BETypeAlt (BESymbolP lhs_symbol, BETypeArgP lhs_arguments, BETypeNodeP rhs);
Clean (BETypeAlt :: BESymbolP BETypeArgP BETypeNodeP BackEnd -> (BETypeAltP, BackEnd))

BENodeP BENormalNode (BESymbolP symbol, BEArgP args);
Clean (BENormalNode :: BESymbolP BEArgP BackEnd -> (BENodeP, BackEnd))

BENodeP BEMatchNode (int arity, BESymbolP symbol, BENodeP node);
Clean (BEMatchNode :: Int BESymbolP BENodeP BackEnd -> (BENodeP, BackEnd))

BENodeP BETupleSelectNode (int arity, int index, BENodeP node);
Clean (BETupleSelectNode :: Int Int BENodeP BackEnd -> (BENodeP, BackEnd))

BENodeP BEIfNode (BENodeP cond, BENodeP then, BENodeP elsje);
Clean (BEIfNode :: BENodeP BENodeP BENodeP BackEnd -> (BENodeP, BackEnd))

BENodeP BEGuardNode (BENodeP cond, BENodeDefP thenNodeDefs, BEStrictNodeIdP thenStricts, BENodeP then, BENodeDefP elseNodeDefs, BEStrictNodeIdP elseStricts, BENodeP elsje);
Clean (BEGuardNode :: BENodeP BENodeDefP BEStrictNodeIdP BENodeP BENodeDefP  BEStrictNodeIdP BENodeP BackEnd -> (BENodeP, BackEnd))

void BESetNodeDefRefCounts (BENodeP lhs);
Clean (BESetNodeDefRefCounts :: BENodeP BackEnd -> BackEnd)

void BEAddNodeIdsRefCounts (int sequenceNumber, BESymbolP symbol, BENodeIdListP nodeIds);
Clean (BEAddNodeIdsRefCounts :: Int BESymbolP BENodeIdListP BackEnd -> BackEnd)

BENodeP BESwitchNode (BENodeIdP nodeId, BEArgP caseNode);
Clean (BESwitchNode :: BENodeIdP BEArgP BackEnd -> (BENodeP, BackEnd))

BENodeP BECaseNode (int symbolArity, BESymbolP symbol, BENodeDefP nodeDefs, BEStrictNodeIdP strictNodeIds, BENodeP node);
Clean (BECaseNode :: Int BESymbolP BENodeDefP BEStrictNodeIdP BENodeP BackEnd -> (BENodeP, BackEnd))

BENodeP BEOverloadedCaseNode (BENodeP case_node,BENodeP equal_node,BENodeP from_integer_node);
Clean (BEOverloadedCaseNode :: BENodeP BENodeP BENodeP BackEnd -> (BENodeP, BackEnd))

void BEEnterLocalScope (void);
Clean (BEEnterLocalScope :: BackEnd -> BackEnd)

void BELeaveLocalScope (BENodeP node);
Clean (BELeaveLocalScope :: BENodeP BackEnd -> BackEnd)

BENodeP BEPushNode (int arity, BESymbolP symbol, BEArgP arguments, BENodeIdListP nodeIds);
Clean (BEPushNode :: Int BESymbolP BEArgP BENodeIdListP BackEnd -> (BENodeP, BackEnd))

BENodeP BEDefaultNode (BENodeDefP nodeDefs, BEStrictNodeIdP strictNodeIds, BENodeP node);
Clean (BEDefaultNode :: BENodeDefP BEStrictNodeIdP BENodeP BackEnd -> (BENodeP, BackEnd))

BENodeP BESelectorNode (BESelectorKind selectorKind, BESymbolP fieldSymbol, BEArgP args);
Clean (BESelectorNode :: BESelectorKind BESymbolP BEArgP BackEnd -> (BENodeP, BackEnd))

BENodeP BEUpdateNode (BEArgP args);
Clean (BEUpdateNode :: BEArgP BackEnd -> (BENodeP, BackEnd))

BENodeP BENodeIdNode (BENodeIdP nodeId, BEArgP args);
Clean (BENodeIdNode :: BENodeIdP BEArgP BackEnd -> (BENodeP, BackEnd))

BEArgP BENoArgs (void);
Clean (BENoArgs :: BackEnd -> (BEArgP, BackEnd))

BEArgP BEArgs (BENodeP node, BEArgP nextArgs);
Clean (BEArgs :: BENodeP BEArgP BackEnd -> (BEArgP, BackEnd))

BERuleAltP BERuleAlt (int line, BENodeDefP lhsDefs, BENodeP lhs, BENodeDefP rhsDefs, BEStrictNodeIdP lhsStrictNodeIds, BENodeP rhs);
Clean (BERuleAlt :: Int BENodeDefP BENodeP BENodeDefP BEStrictNodeIdP BENodeP BackEnd -> (BERuleAltP, BackEnd))

# define	BELhsNodeId	0
# define	BERhsNodeId	1
void BEDeclareNodeId (int sequenceNumber, int lhsOrRhs, CleanString name);
Clean (BEDeclareNodeId :: Int Int String BackEnd -> BackEnd)

BENodeIdP BENodeId (int sequenceNumber);
Clean (BENodeId :: Int BackEnd -> (BENodeIdP, BackEnd))

BENodeIdP BEWildCardNodeId (void);
Clean (BEWildCardNodeId :: BackEnd -> (BENodeIdP, BackEnd))

BENodeDefP BENodeDefList (int sequenceNumber, BENodeP node, BENodeDefP nodeDefs);
Clean (BENodeDefList :: Int BENodeP BENodeDefP BackEnd -> (BENodeDefP, BackEnd))

BENodeDefP BENoNodeDefs (void);
Clean (BENoNodeDefs :: BackEnd -> (BENodeDefP, BackEnd))

BEStrictNodeIdP BEStrictNodeIdList (BENodeIdP nodeId, BEStrictNodeIdP strictNodeIds);
Clean (BEStrictNodeIdList :: BENodeIdP BEStrictNodeIdP BackEnd -> (BEStrictNodeIdP, BackEnd))

BEStrictNodeIdP BENoStrictNodeIds (void);
Clean (BENoStrictNodeIds :: BackEnd -> (BEStrictNodeIdP, BackEnd))

# define	BEIsNotACaf	0
# define	BEIsACaf	1
BEImpRuleP BERule (int functionIndex, int isCaf, BETypeAltP type, BERuleAltP alts);
Clean (BERule :: Int Int BETypeAltP BERuleAltP BackEnd -> (BEImpRuleP, BackEnd))

void BEDeclareRuleType (int functionIndex, int moduleIndex, CleanString name);
Clean (BEDeclareRuleType :: Int Int String BackEnd -> BackEnd)

void BEDefineRuleType (int functionIndex, int moduleIndex, BETypeAltP typeAlt);
Clean (BEDefineRuleType :: Int Int BETypeAltP BackEnd -> BackEnd)

void BEDefineRuleTypeWithCode (int functionIndex, int moduleIndex, BETypeAltP typeAlt, BECodeBlockP codeBlock);
Clean (BEDefineRuleTypeWithCode :: Int Int BETypeAltP BECodeBlockP BackEnd -> BackEnd)

void BEAdjustArrayFunction (BEArrayFunKind arrayFunKind, int functionIndex, int moduleIndex);
Clean (BEAdjustArrayFunction :: BEArrayFunKind Int Int BackEnd -> BackEnd)

BEImpRuleP BENoRules (void);
Clean (BENoRules :: BackEnd -> (BEImpRuleP, BackEnd))

BEImpRuleP BERules (BEImpRuleP rule, BEImpRuleP rules);
Clean (BERules :: BEImpRuleP BEImpRuleP BackEnd -> (BEImpRuleP, BackEnd))

void BEDefineAlgebraicType (BETypeSymbolP symbol, BEAttribution attribution, BEConstructorListP constructors);
Clean (BEDefineAlgebraicType:: BETypeSymbolP BEAttribution BEConstructorListP BackEnd -> BackEnd)

void BEDefineExtensibleAlgebraicType (BETypeSymbolP symbol, BEAttribution attribution, BEConstructorListP constructors);
Clean (BEDefineExtensibleAlgebraicType:: BETypeSymbolP BEAttribution BEConstructorListP BackEnd -> BackEnd)

void BEDefineRecordType (BETypeSymbolP symbol, BEAttribution attribution, int moduleIndex, int constructorIndex, BETypeArgP constructor_args, int is_boxed_record, BEFieldListP fields);
Clean (BEDefineRecordType :: BETypeSymbolP BEAttribution Int Int BETypeArgP Int BEFieldListP BackEnd -> BackEnd)

void BEAbstractType (BETypeSymbolP symbol);
Clean (BEAbstractType :: BETypeSymbolP BackEnd -> BackEnd)

BEConstructorListP BENoConstructors (void);
Clean (BENoConstructors:: BackEnd -> (BEConstructorListP, BackEnd))

BEConstructorListP BEConstructorList (BESymbolP symbol_p, BETypeArgP type_args, BEConstructorListP constructors);
Clean (BEConstructorList:: BESymbolP BETypeArgP BEConstructorListP BackEnd -> (BEConstructorListP, BackEnd))

BEFieldListP BEFieldList (int fieldIndex, int moduleIndex, CleanString name, BETypeNodeP type, BEFieldListP next_fields);
Clean (BEFieldList :: Int Int String BETypeNodeP BEFieldListP BackEnd -> (BEFieldListP, BackEnd))

void BESetMemberTypeOfField (int fieldIndex, int moduleIndex, BETypeAltP typeAlt);
Clean (BESetMemberTypeOfField :: Int Int BETypeAltP BackEnd -> BackEnd)

int BESetDictionaryFieldOfMember (int function_index, int field_index, int field_module_index);
Clean (BESetDictionaryFieldOfMember :: Int Int Int BackEnd -> (Int,BackEnd))

void BESetInstanceFunctionOfFunction (int function_index,int instance_function_index);
Clean (BESetInstanceFunctionOfFunction :: Int Int BackEnd -> BackEnd)

BEFieldListP BENoFields (void);
Clean (BENoFields:: BackEnd -> (BEFieldListP, BackEnd))

void BEDeclareConstructor (int constructorIndex, int moduleIndex, CleanString name);
Clean (BEDeclareConstructor:: Int Int String BackEnd -> BackEnd)

void BEDeclareType (int typeIndex, int moduleIndex, CleanString name);
Clean (BEDeclareType:: Int Int String BackEnd -> BackEnd)

void BEDeclareFunction (CleanString name, int arity, int functionIndex, int ancestor);
Clean (BEDeclareFunction :: String Int Int Int BackEnd -> BackEnd)

void BEStartFunction (int functionIndex);
Clean (BEStartFunction :: Int BackEnd -> BackEnd)

BERuleAltP BECodeAlt (int line, BENodeDefP lhsDefs, BENodeP lhs, BECodeBlockP codeBlock);
Clean (BECodeAlt:: Int BENodeDefP BENodeP BECodeBlockP BackEnd -> (BERuleAltP, BackEnd))

BEStringListP BEStringList (CleanString cleanString, BEStringListP strings);
Clean (BEStringList:: String BEStringListP BackEnd -> (BEStringListP, BackEnd))

BEStringListP BENoStrings (void);
Clean (BENoStrings:: BackEnd -> (BEStringListP, BackEnd))

BECodeParameterP BECodeParameterList (CleanString location, BENodeIdP nodeId, BECodeParameterP parameters);
Clean (BECodeParameterList:: String BENodeIdP BECodeParameterP BackEnd -> (BECodeParameterP, BackEnd))

BECodeParameterP BENoCodeParameters (void);
Clean (BENoCodeParameters:: BackEnd -> (BECodeParameterP, BackEnd))

BENodeIdListP BENodeIdList (BENodeIdP nodeId, BENodeIdListP nids);
Clean (BENodeIdList:: BENodeIdP BENodeIdListP BackEnd -> (BENodeIdListP, BackEnd))

BENodeIdListP BENoNodeIds (void);
Clean (BENoNodeIds:: BackEnd -> (BENodeIdListP, BackEnd))

BECodeBlockP BEAbcCodeBlock (int inlineFlag, BEStringListP instructions);
Clean (BEAbcCodeBlock:: Bool BEStringListP BackEnd -> (BECodeBlockP, BackEnd))

BECodeBlockP BEAnyCodeBlock (BECodeParameterP inParams, BECodeParameterP outParams, BEStringListP instructions);
Clean (BEAnyCodeBlock:: BECodeParameterP BECodeParameterP BEStringListP BackEnd -> (BECodeBlockP, BackEnd))

void BEDeclareIclModule (CleanString name, CleanString modificationTime, int nFunctions, int nTypes, int nConstructors, int nFields);
Clean (BEDeclareIclModule ::  String String Int Int Int Int BackEnd -> BackEnd)

void BEDeclareDclModule (int moduleIndex, CleanString name, CleanString modificationTime, int systemModule, int nFunctions, int nTypes, int nConstructors, int nFields);
Clean (BEDeclareDclModule :: Int String String Bool Int Int Int Int BackEnd -> BackEnd)

void BEDeclarePredefinedModule (int nTypes, int nConstructors);
Clean (BEDeclarePredefinedModule :: Int Int BackEnd -> BackEnd)

void BEDefineRules (BEImpRuleP rules);
Clean (BEDefineRules :: BEImpRuleP BackEnd -> BackEnd)

int BEParseCommandArgs (void);
Clean (BEParseCommandArgs :: BackEnd -> (Int, BackEnd))

int BEGenerateStatesAndOptimise (void);
Clean (BEGenerateStatesAndOptimise :: BackEnd -> (Int, BackEnd))

int BEGenerateCode (CleanString outputFile);
Clean (BEGenerateCode :: String BackEnd -> (Bool, BackEnd))

void BEExportType (int isDictionary, int typeIndex);
Clean (BEExportType :: Bool Int BackEnd -> BackEnd)

void BEExportConstructor (int constructorIndex);
Clean (BEExportConstructor :: Int BackEnd -> BackEnd)

void BEExportField (int isDictionaryField, int fieldIndex);
Clean (BEExportField :: Bool Int BackEnd -> BackEnd)

void BEExportFunction (int functionIndex);
Clean (BEExportFunction :: Int BackEnd -> BackEnd)

void BEDefineImportedObjsAndLibs (BEStringListP objs, BEStringListP libs);
Clean (BEDefineImportedObjsAndLibs :: BEStringListP BEStringListP BackEnd -> BackEnd)

void BEInsertForeignExport (BESymbolP symbol_p,int stdcall);
Clean (BEInsertForeignExport :: BESymbolP Int BackEnd -> BackEnd)

void BESetMainDclModuleN (int main_dcl_module_n_parameter);
Clean (BESetMainDclModuleN :: Int BackEnd -> BackEnd)

void BEStrictPositions (int functionIndex, int *bits, int **positions);
Clean (BEStrictPositions :: Int BackEnd -> (Int, Int, BackEnd))

int BEGetIntFromArray  (int index, int *ints);

// temporary hack
void BEDeclareDynamicTypeSymbol (int typeIndex, int moduleIndex);
Clean (BEDeclareDynamicTypeSymbol :: Int Int BackEnd -> BackEnd)

BETypeSymbolP BEDynamicTempTypeSymbol (void);
Clean (BEDynamicTempTypeSymbol :: BackEnd -> (BETypeSymbolP, BackEnd))

void BESetABCFile (void *a0);
Clean (BESetABCFile :: Int BackEnd -> BackEnd);

void BESetStdErrorFile (void *a0);
Clean (BESetStdErrorFile :: Int BackEnd -> BackEnd);
