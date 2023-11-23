/*
** Program: Clean Prover System
** Module:  Heaps (.icl)
** 
** Author:  Maarten de Mol
** Created: 26 October 2000
*/

implementation module 
	Heaps

import
	StdEnv,
	CoreTypes,
	LTypes,
	ProveTypes
	, RWSDebug

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CHeaps =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ heapCExprVars				:: !.Heap CExprVarDef
	, heapCPropVars				:: !.Heap CPropVarDef
	, heapCTypeVars				:: !.Heap CTypeVarDef
	, heapLetDefs				:: !.Heap LLetDef
	, heapShared				:: !.Heap CShared
	, numShared					:: !Int
	, heapProofTrees			:: !.Heap ProofTree
	, heapHypotheses			:: !.Heap Hypothesis
	, heapSections				:: !.Heap Section
	, heapTheorems				:: !.Heap Theorem
	, heapModules				:: !.Heap CModule
	}
instance DummyValue CHeaps
where
	DummyValue =	{ heapCExprVars		= newHeap
					, heapCPropVars		= newHeap
					, heapCTypeVars		= newHeap
					, heapLetDefs		= newHeap
					, heapShared		= newHeap
					, numShared			= 0
					, heapProofTrees	= newHeap
					, heapHypotheses	= newHeap
					, heapSections		= newHeap
					, heapTheorems		= newHeap
					, heapModules		= newHeap
					}

// -------------------------------------------------------------------------------------------------------------------------------------------------
class Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	newPointer					:: 			!a		!*CHeaps -> (!Ptr a, !*CHeaps)
	readPointer					:: !(Ptr a)			!*CHeaps -> (!a, !*CHeaps)
	writePointer				:: !(Ptr a)	!a		!*CHeaps -> *CHeaps
	
	getPointerName				:: !(Ptr a)			!*CHeaps -> (!CName, !*CHeaps)
	changePointerName			:: !(Ptr a) !CName	!*CHeaps -> *CHeaps
	wipePointerInfo				:: !(Ptr a)			!*CHeaps -> *CHeaps















// -------------------------------------------------------------------------------------------------------------------------------------------------
newPointers :: ![a] !*CHeaps -> (![Ptr a], !*CHeaps) | Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
newPointers values heaps
	= umap newPointer values heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
readPointers :: ![Ptr a] !*CHeaps -> (![a], !*CHeaps) | Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
readPointers ptrs heaps
	= umap readPointer ptrs heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
writePointers :: ![Ptr a] ![a] !*CHeaps -> *CHeaps | Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
writePointers [ptr:ptrs] [value:values] heaps
	= writePointers ptrs values (writePointer ptr value heaps)
writePointers _ _ heaps
	= heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
getPointerNames :: ![Ptr a] !*CHeaps -> (![CName], !*CHeaps) | Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
getPointerNames ptrs heaps
	= umap getPointerName ptrs heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
changePointerNames :: ![Ptr a] ![CName] !*CHeaps -> *CHeaps | Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
changePointerNames [ptr:ptrs] [name:names] heaps
	= changePointerNames ptrs names (changePointerName ptr name heaps)
changePointerNames _ _ heaps
	= heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
wipePointerInfos :: ![Ptr a] !*CHeaps -> *CHeaps | Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
wipePointerInfos ptrs heaps
	= uwalk wipePointerInfo ptrs heaps













// -------------------------------------------------------------------------------------------------------------------------------------------------
setExprVarInfo :: !CExprVarPtr !CExprVarInfo !*CHeaps -> *CHeaps
// -------------------------------------------------------------------------------------------------------------------------------------------------
setExprVarInfo ptr info heaps
	# (var, heaps)					= readPointer ptr heaps
	# var							= {var & evarInfo = info}
	= writePointer ptr var heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
setExprVarInfos :: ![CExprVarPtr] ![CExprVarInfo] !*CHeaps -> *CHeaps
// -------------------------------------------------------------------------------------------------------------------------------------------------
setExprVarInfos [ptr:ptrs] [info:infos] heaps
	= setExprVarInfos ptrs infos (setExprVarInfo ptr info heaps)
setExprVarInfos _ _ heaps
	= heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
setPropVarInfo :: !CPropVarPtr !CPropVarInfo !*CHeaps -> *CHeaps
// -------------------------------------------------------------------------------------------------------------------------------------------------
setPropVarInfo ptr info heaps
	# (var, heaps)					= readPointer ptr heaps
	# var							= {var & pvarInfo = info}
	= writePointer ptr var heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
setPropVarInfos :: ![CPropVarPtr] ![CPropVarInfo] !*CHeaps -> *CHeaps
// -------------------------------------------------------------------------------------------------------------------------------------------------
setPropVarInfos [ptr:ptrs] [info:infos] heaps
	= setPropVarInfos ptrs infos (setPropVarInfo ptr info heaps)
setPropVarInfos _ _ heaps
	= heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
setTypeVarInfo :: !CTypeVarPtr !CTypeVarInfo !*CHeaps -> *CHeaps
// -------------------------------------------------------------------------------------------------------------------------------------------------
setTypeVarInfo ptr info heaps
	# (var, heaps)					= readPointer ptr heaps
	# var							= {var & tvarInfo = info}
	= writePointer ptr var heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
setTypeVarInfos :: ![CTypeVarPtr] ![CTypeVarInfo] !*CHeaps -> *CHeaps
// -------------------------------------------------------------------------------------------------------------------------------------------------
setTypeVarInfos [ptr:ptrs] [info:infos] heaps
	= setTypeVarInfos ptrs infos (setTypeVarInfo ptr info heaps)
setTypeVarInfos _ _ heaps
	= heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
setPassedInfo :: !CSharedPtr !Bool !*CHeaps -> *CHeaps
// -------------------------------------------------------------------------------------------------------------------------------------------------
setPassedInfo ptr bool heaps
	# (shared, heaps)				= readPointer ptr heaps
	# shared						= {shared & shPassed = bool}
	# heaps							= writePointer ptr shared heaps
	= heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
setPassedInfos :: ![CSharedPtr] !Bool !*CHeaps -> *CHeaps
// -------------------------------------------------------------------------------------------------------------------------------------------------
setPassedInfos [ptr:ptrs] bool heaps
	# heaps							= setPassedInfo ptr bool heaps
	# heaps							= setPassedInfos ptrs bool heaps
	= heaps
setPassedInfos [] bool heaps
	= heaps















// -------------------------------------------------------------------------------------------------------------------------------------------------
instance Pointer CExprVarDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	newPointer var heaps
		# (ptr, heap)				= newPtr var heaps.heapCExprVars
		= (ptr, {heaps & heapCExprVars = heap})
	readPointer ptr heaps
		# (var, heap)				= readPtr ptr heaps.heapCExprVars
		= (var, {heaps & heapCExprVars = heap})
	writePointer ptr var heaps
		# heap						= writePtr ptr var heaps.heapCExprVars
		= {heaps & heapCExprVars = heap}
	getPointerName ptr heaps
		# (var, heap)				= readPointer ptr heaps
		= (var.evarName, heap)
	changePointerName ptr name heaps
		# (var, heaps)				= readPointer ptr heaps
		# var						= {var & evarName = name}
		= writePointer ptr var heaps
	wipePointerInfo ptr heaps
		# (var, heaps)				= readPointer ptr heaps
		# var						= {var & evarInfo = EVar_Nothing}
		= writePointer ptr var heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance Pointer CPropVarDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	newPointer var heaps
		# (ptr, heap)				= newPtr var heaps.heapCPropVars
		= (ptr, {heaps & heapCPropVars = heap})
	readPointer ptr heaps
		# (var, heap)				= readPtr ptr heaps.heapCPropVars
		= (var, {heaps & heapCPropVars = heap})
	writePointer ptr var heaps
		# heap						= writePtr ptr var heaps.heapCPropVars
		= {heaps & heapCPropVars = heap}
	getPointerName ptr heaps
		# (var, heap)				= readPointer ptr heaps
		= (var.pvarName, heap)
	changePointerName ptr name heaps
		# (var, heaps)				= readPointer ptr heaps
		# var						= {var & pvarName = name}
		= writePointer ptr var heaps
	wipePointerInfo ptr heaps
		# (var, heaps)				= readPointer ptr heaps
		# var						= {var & pvarInfo = PVar_Nothing}
		= writePointer ptr var heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance Pointer CTypeVarDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	newPointer var heaps
		# (ptr, heap)				= newPtr var heaps.heapCTypeVars
		= (ptr, {heaps & heapCTypeVars = heap})
	readPointer ptr heaps
		# (var, heap)				= readPtr ptr heaps.heapCTypeVars
		= (var, {heaps & heapCTypeVars = heap})
	writePointer ptr var heaps
		# heap						= writePtr ptr var heaps.heapCTypeVars
		= {heaps & heapCTypeVars = heap}
	getPointerName ptr heaps
		# (var, heap)				= readPointer ptr heaps
		= (var.tvarName, heap)
	changePointerName ptr name heaps
		# (var, heaps)				= readPointer ptr heaps
		# var						= {var & tvarName = name}
		= writePointer ptr var heaps
	wipePointerInfo ptr heaps
		# (var, heaps)				= readPointer ptr heaps
		# var						= {var & tvarInfo = TVar_Nothing}
		= writePointer ptr var heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance Pointer LLetDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	newPointer def heaps
		# (ptr, heap)				= newPtr def heaps.heapLetDefs
		= (ptr, {heaps & heapLetDefs = heap})
	readPointer ptr heaps
		# (def, heap)				= readPtr ptr heaps.heapLetDefs
		= (def, {heaps & heapLetDefs = heap})
	writePointer ptr def heaps
		# heap						= writePtr ptr def heaps.heapLetDefs
		= {heaps & heapLetDefs = heap}
	getPointerName ptr heaps
		= abort "getPointerName is not defined for LLetDefPtr"
	changePointerName ptr name heaps
		= abort "changePointerName is not defined for LLetDefPtr"
	wipePointerInfo ptr heaps
		= abort "wipePointerInfo is not defined for LLetDefPtr"

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance Pointer CShared
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	newPointer shared heaps
		# (new_num, heaps)			= heaps!numShared
		# shared					= {shared & shName = "s" +++ toString new_num}
		# (ptr, heap)				= newPtr shared heaps.heapShared
		= (ptr, {heaps & heapShared = heap, numShared = new_num+1})
	readPointer ptr heaps
		# (shared, heap)			= readPtr ptr heaps.heapShared
		= (shared, {heaps & heapShared = heap})
	writePointer ptr shared heaps
		# heap						= writePtr ptr shared heaps.heapShared
		= {heaps & heapShared = heap}
	getPointerName ptr heaps
		# (shared, heap)			= readPointer ptr heaps
		= (shared.shName, heap)
	changePointerName ptr name heaps
		# (shared, heaps)			= readPointer ptr heaps
		# shared					= {shared & shName = name}
		= writePointer ptr shared heaps
	wipePointerInfo ptr heaps
		= undef

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance Pointer ProofTree
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	newPointer proof_tree heaps
		# (ptr, heap)				= newPtr proof_tree heaps.heapProofTrees
		= (ptr, {heaps & heapProofTrees = heap})
	readPointer ptr heaps
		# (proof_tree, heap)		= readPtr ptr heaps.heapProofTrees
		= (proof_tree, {heaps & heapProofTrees = heap})
	writePointer ptr proof_tree heaps
		# heap						= writePtr ptr proof_tree heaps.heapProofTrees
		= {heaps & heapProofTrees = heap}
	getPointerName ptr heaps
		= undef
	changePointerName ptr name heaps
		= undef
	wipePointerInfo ptr heaps
		= undef

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance Pointer Hypothesis
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	newPointer hyp heaps
		# (ptr, heap)				= newPtr hyp heaps.heapHypotheses
		= (ptr, {heaps & heapHypotheses = heap})
	readPointer ptr heaps
		# (hyp, heap)				= readPtr ptr heaps.heapHypotheses
		= (hyp, {heaps & heapHypotheses = heap})
	writePointer ptr hyp heaps
		# heap						= writePtr ptr hyp heaps.heapHypotheses
		= {heaps & heapHypotheses = heap}
	getPointerName ptr heaps
		# (hyp, heap)				= readPtr ptr heaps.heapHypotheses
		= (hyp.hypName, {heaps & heapHypotheses = heap})
	changePointerName ptr name heaps
		= undef
	wipePointerInfo ptr heaps
		= undef

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance Pointer Section
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	newPointer section heaps
		# (ptr, heap)				= newPtr section heaps.heapSections
		= (ptr, {heaps & heapSections = heap})
	readPointer ptr heaps
		# (section, heap)			= readPtr ptr heaps.heapSections
		= (section, {heaps & heapSections = heap})
	writePointer ptr section heaps
		# heap						= writePtr ptr section heaps.heapSections
		= {heaps & heapSections = heap}
	getPointerName ptr heaps
		# (section, heap)			= readPointer ptr heaps
		= (section.seName, heap)
	changePointerName ptr name heaps
		# (section, heaps)			= readPointer ptr heaps
		# section					= {section & seName = name}
		= writePointer ptr section heaps
	wipePointerInfo ptr heaps
		= undef

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance Pointer Theorem
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	newPointer theorem heaps
		# (ptr, heap)				= newPtr theorem heaps.heapTheorems
		= (ptr, {heaps & heapTheorems = heap})
	readPointer ptr heaps
		# (theorem, heap)			= readPtr ptr heaps.heapTheorems
		= (theorem, {heaps & heapTheorems = heap})
	writePointer ptr theorem heaps
		# heap						= writePtr ptr theorem heaps.heapTheorems
		= {heaps & heapTheorems = heap}
	getPointerName ptr heaps
		# (theorem, heap)			= readPointer ptr heaps
		= (theorem.thName, heap)
	changePointerName ptr name heaps
		# (theorem, heaps)			= readPointer ptr heaps
		# theorem					= {theorem & thName = name}
		= writePointer ptr theorem heaps
	wipePointerInfo ptr heaps
		= undef

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance Pointer CModule
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	newPointer mod heaps
		# (ptr, heap)				= newPtr mod heaps.heapModules
		= (ptr, {heaps & heapModules = heap})
	readPointer ptr heaps
		# (mod, heap)				= readPtr ptr heaps.heapModules
		= (mod, {heaps & heapModules = heap})
	writePointer ptr mod heaps
		# heap						= writePtr ptr mod heaps.heapModules
		= {heaps & heapModules = heap}
	getPointerName ptr heaps
		| isNilPtr ptr				= ("_Predefined", heaps)
		# (mod, heap)				= readPointer ptr heaps
		= (mod.pmName, heap)
	changePointerName ptr name heaps
		# (mod, heaps)				= readPointer ptr heaps
		# mod						= {mod & pmName = name}
		= writePointer ptr mod heaps
	wipePointerInfo ptr heaps
		= undef


















// -------------------------------------------------------------------------------------------------------------------------------------------------
class ReflexivePointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	readReflexivePointer	:: !(Ptr a) !*CHeaps -> (!Maybe (Ptr a), !*CHeaps)
	writeReflexivePointer	:: !(Ptr a) !(Ptr a) !*CHeaps -> *CHeaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance ReflexivePointer CExprVarDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	readReflexivePointer ptr heaps
		# (var, heaps)				= readPointer ptr heaps
		= (check var.evarInfo, heaps) 
		where
			check (EVar_Fresh ptr)	= Just ptr
			check other				= Nothing
	writeReflexivePointer ptr1 ptr2 heaps
		# (var, heaps)				= readPointer ptr1 heaps
		# var						= {var & evarInfo = EVar_Fresh ptr2}
		= writePointer ptr1 var heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance ReflexivePointer CPropVarDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	readReflexivePointer ptr heaps
		# (var, heaps)				= readPointer ptr heaps
		= (check var.pvarInfo, heaps) 
		where
			check (PVar_Fresh ptr)	= Just ptr
			check other				= Nothing
	writeReflexivePointer ptr1 ptr2 heaps
		# (var, heaps)				= readPointer ptr1 heaps
		# var						= {var & pvarInfo = PVar_Fresh ptr2}
		= writePointer ptr1 var heaps






















// -------------------------------------------------------------------------------------------------------------------------------------------------
findNamedPointers :: ![CName] ![Ptr a] !*CHeaps -> (![Ptr a], !*CHeaps) | Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
findNamedPointers names [ptr:ptrs] heaps
	# (name, heaps)					= getPointerName ptr heaps
	# (ptrs, heaps)					= findNamedPointers names ptrs heaps
	| isMember name names			= ([ptr:ptrs], heaps)
	= (ptrs, heaps)
findNamedPointers names [] heaps
	= ([], heaps)






















// =================================================================================================================================================
// Returns TRUE when the expression may still be reduced but is not shared already.
// -------------------------------------------------------------------------------------------------------------------------------------------------
sharable :: !CExprH -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
sharable (CShared ptr)							= False
sharable (ptr @@# [])							= False
sharable (expr @# [])							= sharable expr
sharable ((CDataConsPtr _ _) @@# exprs)			= or (map sharable exprs)
sharable (CBasicValue (CBasicArray exprs))		= or (map sharable exprs)
sharable (CBasicValue _)						= False
sharable (CCode _ _)							= False
sharable CBottom								= False
sharable _										= True

// =================================================================================================================================================
// If the input is (DataCons x1 ... xn), all sharable x1 will be shared.
// The shared expression will be overwritten with (DataCons ptr1 ... ptrn).
// The result is that the returned expression as a whole is no longer sharable (and will thus be copied).
// -------------------------------------------------------------------------------------------------------------------------------------------------
unshareCons :: !CSharedPtr !CShared !*CHeaps -> (!CExprH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
unshareCons ptr shared heaps
	= unshare_cons ptr shared shared.shExpr heaps
	where
		unshare_cons :: !CSharedPtr !CShared !CExprH !*CHeaps -> (!CExprH, !*CHeaps)
		unshare_cons ptr shared expr=:(consptr @@# args) heaps
			| ptrKind consptr <> CDataCons	= (expr, heaps)
			# (args, heaps)					= introduce_sharing args heaps
			# expr							= consptr @@# args
			# shared						= {shared & shExpr = expr}
			# heaps							= writePointer ptr shared heaps
			= (expr, heaps)
		unshare_cons ptr shared expr heaps
			= (expr, heaps)

		introduce_sharing :: ![CExprH] !*CHeaps -> (![CExprH], !*CHeaps)
		introduce_sharing [] heaps
			= ([], heaps)
		introduce_sharing [expr:exprs] heaps
			#! (exprs, heaps)				= introduce_sharing exprs heaps
			| not (sharable expr)			= ([expr:exprs], heaps)
			# shared						= {shName = "@", shExpr = expr, shPassed = False}
			# (ptr, heaps)					= newPointer shared heaps
			= ([CShared ptr: exprs], heaps)

// =================================================================================================================================================
// Shares a list of expressions. Uses given names.
// -------------------------------------------------------------------------------------------------------------------------------------------------
share :: ![CExprH] ![CName] !*CHeaps -> (![CExprH], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
share [] [] heaps
	= ([], heaps)
share [expr:exprs] [name:names] heaps
	# (exprs, heaps)						= share exprs names heaps
	| not (sharable expr)					= ([expr:exprs], heaps)
	# shared								= {shName = "@" +++ name, shExpr = expr, shPassed = False}
	# (ptr, heaps)							= newPointer shared heaps
	= ([CShared ptr: exprs], heaps)

// =================================================================================================================================================
// Shares a list of expressions. Uses empty names.
// -------------------------------------------------------------------------------------------------------------------------------------------------
shareI :: ![CExprH] !*CHeaps -> (![CExprH], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
shareI [] heaps
	= ([], heaps)
shareI [expr:exprs] heaps
	# (exprs, heaps)						= shareI exprs heaps
	| not (sharable expr)					= ([expr:exprs], heaps)
	# shared								= {shName = "@", shExpr = expr, shPassed = False}
	# (ptr, heaps)							= newPointer shared heaps
	= ([CShared ptr: exprs], heaps)













// returns False if recursive sharing was found
// -------------------------------------------------------------------------------------------------------------------------------------------------
class unshare a :: !a !*CHeaps -> (!Bool, !a, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare [a] | unshare a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare [x:xs] heaps
		# (ok1, x, heaps)				= unshare x heaps
		# (ok2, xs, heaps)				= unshare xs heaps
		= (ok1 && ok2, [x:xs], heaps)
	unshare [] heaps
		= (True, [], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (Maybe a) | unshare a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare (Just x) heaps
		# (ok, x, heaps)				= unshare x heaps
		= (ok, Just x, heaps)
	unshare Nothing heaps
		= (True, Nothing, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare pattern heaps
		# (ok, result, heaps)			= unshare pattern.atpResult heaps
		= (ok, {pattern & atpResult = result}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare pattern heaps
		# (ok, result, heaps)			= unshare pattern.bapResult heaps
		= (ok, {pattern & bapResult = result}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare (CBasicArray exprs) heaps
		# (ok, exprs, heaps)			= unshare exprs heaps
		= (ok, CBasicArray exprs, heaps)
	unshare other heaps
		= (True, other, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare (CAlgPatterns type patterns) heaps
		# (ok, patterns, heaps)			= unshare patterns heaps
		= (ok, CAlgPatterns type patterns, heaps)
	unshare (CBasicPatterns type patterns) heaps
		# (ok, patterns, heaps)			= unshare patterns heaps
		= (ok, CBasicPatterns type patterns, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare (CExprVar ptr) heaps
		= (True, CExprVar ptr, heaps)
	unshare (CShared ptr) heaps
		# (shared, heaps)				= readPointer ptr heaps
		| shared.shPassed				= (False, CShared ptr, heaps)
		# shared						= {shared & shPassed = True}
		# heaps							= writePointer ptr shared heaps
		# (ok, expr, heaps)				= unshare shared.shExpr heaps
		# shared						= {shared & shExpr = expr, shPassed = False}
		# heaps							= writePointer ptr shared heaps
		= (ok, expr, heaps)
	unshare (expr @# exprs) heaps
		#! (ok1, expr, heaps)			= unshare expr heaps
		#! (ok2, exprs, heaps)			= unshare exprs heaps
		= (ok1 && ok2, expr @# exprs, heaps)
	unshare (ptr @@# exprs) heaps
		#! (ok, exprs, heaps)			= unshare exprs heaps
		= (ok, ptr @@# exprs, heaps)
	unshare (CLet strict lets expr) heaps
		#! (ok1, expr, heaps)			= unshare expr heaps
		# (vars, exprs)					= unzip lets
		#! (ok2, exprs, heaps)			= unshare exprs heaps
		# lets						 	= zip2 vars exprs
		= (ok1 && ok2, CLet strict lets expr, heaps)
	unshare (CCase expr patterns def) heaps
		#! (ok1, expr, heaps)			= unshare expr heaps
		#! (ok2, patterns, heaps)		= unshare patterns heaps
		#! (ok3, def, heaps)			= unshare def heaps
		= (ok1 && ok2 && ok3, CCase expr patterns def, heaps)
	unshare (CBasicValue value) heaps
		#! (ok, value, heaps)			= unshare value heaps
		= (ok, CBasicValue value, heaps)
	unshare (CCode type cod) heaps
		= (True, CCode type cod, heaps)
	unshare CBottom heaps
		= (True, CBottom, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare CTrue heaps
		= (True, CTrue, heaps)
	unshare CFalse heaps
		= (True, CFalse, heaps)
	unshare (CPropVar ptr) heaps
		= (True, CPropVar ptr, heaps)
	unshare (CNot p) heaps
		# (ok, p, heaps)				= unshare p heaps
		= (ok, CNot p, heaps)
	unshare (CAnd p q) heaps
		# (ok1, p, heaps)				= unshare p heaps
		# (ok2, q, heaps)				= unshare q heaps
		= (ok1 && ok2, CAnd p q, heaps)
	unshare (COr p q) heaps
		# (ok1, p, heaps)				= unshare p heaps
		# (ok2, q, heaps)				= unshare q heaps
		= (ok1 && ok2, COr p q, heaps)
	unshare (CImplies p q) heaps
		# (ok1, p, heaps)				= unshare p heaps
		# (ok2, q, heaps)				= unshare q heaps
		= (ok1 && ok2, CImplies p q, heaps)
	unshare (CIff p q) heaps
		# (ok1, p, heaps)				= unshare p heaps
		# (ok2, q, heaps)				= unshare q heaps
		= (ok1 && ok2, CIff p q, heaps)
	unshare (CExprForall var p) heaps
		# (ok, p, heaps)				= unshare p heaps
		= (ok, CExprForall var p, heaps)
	unshare (CExprExists var p) heaps
		# (ok, p, heaps)				= unshare p heaps
		= (ok, CExprExists var p, heaps)
	unshare (CPropForall var p) heaps
		# (ok, p, heaps)				= unshare p heaps
		= (ok, CPropForall var p, heaps)
	unshare (CEqual e1 e2) heaps
		# (ok1, e1, heaps)				= unshare e1 heaps
		# (ok2, e2, heaps)				= unshare e2 heaps
		= (ok1 && ok2, CEqual e1 e2, heaps)
	unshare (CPredicate ptr exprs) heaps
		# (ok, exprs, heaps)			= unshare exprs heaps
		= (ok, CPredicate ptr exprs, heaps)




















// -------------------------------------------------------------------------------------------------------------------------------------------------
class freshSharing a :: ![(CSharedPtr, CSharedPtr)] !a !*CHeaps -> (![(CSharedPtr, CSharedPtr)], !a, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshSharing [a] | freshSharing a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshSharing passed [x:xs] heaps
		# (passed, x, heaps)				= freshSharing passed x heaps
		# (passed, xs, heaps)				= freshSharing passed xs heaps
		= (passed, [x:xs], heaps)
	freshSharing passed [] heaps
		= (passed, [], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshSharing (Maybe a) | freshSharing a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshSharing passed (Just x) heaps
		# (passed, x, heaps)				= freshSharing passed x heaps
		= (passed, Just x, heaps)
	freshSharing passed Nothing heaps
		= (passed, Nothing, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshSharing (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshSharing passed pattern heaps
		# (passed, expr, heaps)				= freshSharing passed pattern.atpResult heaps
		# pattern							= {pattern & atpResult = expr}
		= (passed, pattern, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshSharing (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshSharing passed pattern heaps
		# (passed, expr, heaps)				= freshSharing passed pattern.bapResult heaps
		# pattern							= {pattern & bapResult = expr}
		= (passed, pattern, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshSharing (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshSharing passed (CBasicArray exprs) heaps
		# (passed, exprs, heaps)			= freshSharing passed exprs heaps
		= (passed, CBasicArray exprs, heaps)
	freshSharing passed other heaps
		= (passed, other, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshSharing (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshSharing passed (CAlgPatterns type patterns) heaps
		# (passed, patterns, heaps)			= freshSharing passed patterns heaps
		= (passed, CAlgPatterns type patterns, heaps)
	freshSharing passed (CBasicPatterns type patterns) heaps
		# (passed, patterns, heaps)			= freshSharing passed patterns heaps
		= (passed, CBasicPatterns type patterns, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshSharing (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshSharing passed (CExprVar ptr) heaps
		= (passed, CExprVar ptr, heaps)
	freshSharing passed (CShared ptr) heaps
		= fresh passed passed ptr heaps
		where
			fresh passed [(old_ptr, new_ptr):passed_ptrs] ptr heaps
				| ptr == old_ptr			= (passed, CShared new_ptr, heaps)
				= fresh passed passed_ptrs ptr heaps
			fresh passed [] ptr heaps
				# (shared, heaps)			= readPointer ptr heaps
				# (new_ptr, heaps)			= newPointer shared heaps
				# passed					= [(ptr,new_ptr):passed]
				# (passed, expr, heaps)		= freshSharing passed shared.shExpr heaps
				# shared					= {shared & shExpr = expr}
				# heaps						= writePointer new_ptr shared heaps
				= (passed, CShared new_ptr, heaps)
	freshSharing passed (expr @# exprs) heaps
		# (passed, expr, heaps)				= freshSharing passed expr heaps
		# (passed, exprs, heaps)			= freshSharing passed exprs heaps
		= (passed, expr @# exprs, heaps)
	freshSharing passed (ptr @@# exprs) heaps
		# (passed, exprs, heaps)			= freshSharing passed exprs heaps
		= (passed, ptr @@# exprs, heaps)
	freshSharing passed (CLet strict lets expr) heaps
		# (vars, exprs)						= unzip lets
		# (passed, exprs, heaps)			= freshSharing passed exprs heaps
		# lets								= zip2 vars exprs
		# (passed, expr, heaps)				= freshSharing passed expr heaps
		= (passed, CLet strict lets expr, heaps)
	freshSharing passed (CCase expr patterns def) heaps
		# (passed, expr, heaps)				= freshSharing passed expr heaps
		# (passed, patterns, heaps)			= freshSharing passed patterns heaps
		# (passed, def, heaps)				= freshSharing passed def heaps
		= (passed, CCase expr patterns def, heaps)
	freshSharing passed (CBasicValue value) heaps
		# (passed, value, heaps)			= freshSharing passed value heaps
		= (passed, CBasicValue value, heaps)
	freshSharing passed (CCode codetype codecontents) heaps
		= (passed, CCode codetype codecontents, heaps)
	freshSharing passed CBottom heaps
		= (passed, CBottom, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
FreshSharing :: !a !*CHeaps -> (!a, !*CHeaps) | freshSharing a
// -------------------------------------------------------------------------------------------------------------------------------------------------
FreshSharing x heaps
	# (old_num, heaps)						= heaps!numShared
	# (_, x, heaps)							= freshSharing [] x heaps
	# heaps									= {heaps & numShared = old_num}
	= (x, heaps)

/*
// =================================================================================================================================================
// [a=b, b=c, c=d, d=expr] a       becomes [a=b, b=c, c=d, d=expr] d
// [a=b, b=a] a                    becomes [a=b, b=a] _|_
// [a=b, b=c, c=b] a               becomes [a=b, b=c, c=b] _|_
// =================================================================================================================================================
allProductive :: !CExprH !*CEnv -> (!CExprH, !*CEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
allProductive expr heaps
	# (expr, passed, heaps)					= all_productive expr [] heaps
	= (expr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
class all_productive a :: !a [!CExprInfoPtr] !*CEnv -> (!a, [!CExprInfoPtr], !*CEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance all_productive [a] | all_productive a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	all_productive [x:xs] passed heaps
		# (x, passed, heaps)					= all_productive x passed heaps
		# (xs, passed, heaps)					= all_productive xs passed heaps
		= ([x:xs], passed, heaps)
	all_productive [] passed heaps
		= ([], passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance all_productive (Maybe a) | all_productive a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	all_productive (Just x) passed heaps
		# (x, passed, heaps)					= all_productive x passed heaps
		= (Just x, passed, heaps)
	all_productive Nothing passed heaps
		= (Nothing, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance all_productive (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	all_productive pattern passed heaps
		# (result, passed, heaps)				= all_productive pattern.atpResult passed heaps
		= ({pattern & atpResult = result}, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance all_productive (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	all_productive pattern passed heaps
		# (result, passed, heaps)				= all_productive pattern.bapResult passed heaps
		= ({pattern & bapResult = result}, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance all_productive (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	all_productive (CBasicArray exprs) passed heaps
		# (exprs, passed, heaps)				= all_productive exprs passed heaps
		= (CBasicArray exprs, passed, heaps)
	all_productive other passed heaps
		= (other, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance all_productive (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	all_productive (CAlgPatterns type patterns) passed heaps
		# (patterns, passed, heaps)			= all_productive patterns passed heaps
		= (CAlgPatterns type patterns, passed, heaps)
	all_productive (CBasicPatterns type patterns) passed heaps
		# (patterns, passed, heaps)			= all_productive patterns passed heaps
		= (CBasicPatterns type patterns, passed, heaps)
	all_productive (CDynPatterns patterns) passed heaps
		# (patterns, passed, heaps)			= all_productive patterns passed heaps
		= (CDynPatterns patterns, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance all_productive (CDynPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	all_productive pattern passed heaps
		# (rhs, passed, heaps)				= all_productive pattern.dtpRhs passed heaps
		= ({pattern & dtpRhs = rhs}, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance all_productive (CDynamic HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	all_productive dyn passed heaps
		# (expr, passed, heaps)				= all_productive dyn.dynExpr passed heaps
		= ({dyn & dynExpr = expr}, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance all_productive (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	all_productive (CExprVar id) passed heaps
		= (CExprVar id, passed, heaps)
	all_productive (CEnvExpr ptr) passed heaps
		| isMember ptr passed				= (CEnvExpr ptr, passed, heaps)
		# (cycle, newptr, heaps)				= follow_chain ptr [ptr] heaps
		| cycle								= (CBottom, passed, heaps)
		# (info, heaps)						= readExprInfo newptr heaps
		| isNothing info.eiExpr				= (CEnvExpr newptr, passed, heaps)
		# expr								= fromJust info.eiExpr
		# (expr, passed, heaps)				= all_productive expr [newptr:passed] heaps
		# info								= {info & eiExpr = Just expr}
		# heaps								= writeExprInfo newptr info heaps
		= (CEnvExpr newptr, passed, heaps)
		where
			follow_chain ptr forbidden heaps
				# (info, heaps)				= readExprInfo ptr heaps
				# (ok, newptr)				= get_ptr info.eiExpr
				| not ok					= (False, ptr, heaps)
				| isMember newptr forbidden	= (True, nilPtr, heaps)				// cycle detected
				= follow_chain newptr [newptr:forbidden] heaps
				
			get_ptr (Just (CEnvExpr ptr))	= (True, ptr)
			get_ptr other					= (False, nilPtr)
	all_productive (expr @# exprs) passed heaps
		#! (expr, passed, heaps)				= all_productive expr passed heaps
		#! (exprs, passed, heaps)				= all_productive exprs passed heaps
		= (expr @# exprs, passed, heaps)
	all_productive (@@# ptr strictargs exprs) passed heaps
		#! (exprs, passed, heaps)				= all_productive exprs passed heaps
		= (@@# ptr strictargs exprs, passed, heaps)
	all_productive (CLet strict lets expr) passed heaps
		#! (expr, passed, heaps)				= all_productive expr passed heaps
		# (vars, exprs)						= unzip lets
		#! (exprs, passed, heaps)				= all_productive exprs passed heaps
		# lets								= zip2 vars exprs
		= (CLet strict lets expr, passed, heaps)
	all_productive (CCase expr patterns def) passed heaps
		#! (expr, passed, heaps)				= all_productive expr passed heaps
		#! (patterns, passed, heaps)			= all_productive patterns passed heaps
		#! (def, passed, heaps)				= all_productive def passed heaps
		= (CCase expr patterns def, passed, heaps)
	all_productive (CBasicValue value) passed heaps
		#! (value, passed, heaps)				= all_productive value passed heaps
		= (CBasicValue value, passed, heaps)
	all_productive (CCode type cod) passed heaps
		= (CCode type cod, passed, heaps)
	all_productive (CDynamicExpr dyn) passed heaps
		#! (dyn, passed, heaps)				= all_productive dyn passed heaps
		= (CDynamicExpr dyn, passed, heaps)
	all_productive CBottom passed heaps
		= (CBottom, passed, heaps)




























// =================================================================================================================================================
// Fills in all sharing when the target is a basic value, code or bottom
// -------------------------------------------------------------------------------------------------------------------------------------------------
removeBasicSharing :: !CExprH !*CEnv -> (!CExprH, !*CEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
removeBasicSharing expr heaps
	# (expr, passed, heaps)						= unshare expr [] heaps
	= (expr, heaps)

// =================================================================================================================================================
// Returns TRUE when the expression may still be reduced but is not shared already.
// -------------------------------------------------------------------------------------------------------------------------------------------------
sharable :: !CExprH -> !Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
sharable (CEnvExpr ptr)
	= False
sharable (@@# (CDataConsPtr _ _) _ exprs)
	= or (map sharable exprs)
sharable (CBasicValue (CBasicArray exprs))
	= or (map sharable exprs)
sharable (CBasicValue _)
	= False
sharable (CCode _ _)
	= False
sharable (CDynamicExpr _)
	= False
sharable CBottom
	= False
sharable _
	= True

// -------------------------------------------------------------------------------------------------------------------------------------------------
class unshare a :: !a ![!Ptr CExprInfo] !*CEnv -> (!a, ![!Ptr CExprInfo], !*CEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare [a] | unshare a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare [x:xs] passed heaps
		# (x, passed, heaps)					= unshare x passed heaps
		# (xs, passed, heaps)					= unshare xs passed heaps
		= ([x:xs], passed, heaps)
	unshare [] passed heaps
		= ([], passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (Maybe a) | unshare a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare (Just x) passed heaps
		# (x, passed, heaps)					= unshare x passed heaps
		= (Just x, passed, heaps)
	unshare Nothing passed heaps
		= (Nothing, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare pattern passed heaps
		# (result, passed, heaps)				= unshare pattern.atpResult passed heaps
		= ({pattern & atpResult = result}, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare pattern passed heaps
		# (result, passed, heaps)				= unshare pattern.bapResult passed heaps
		= ({pattern & bapResult = result}, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare (CBasicArray exprs) passed heaps
		# (exprs, passed, heaps)				= unshare exprs passed heaps
		= (CBasicArray exprs, passed, heaps)
	unshare other passed heaps
		= (other, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare (CAlgPatterns type patterns) passed heaps
		# (patterns, passed, heaps)			= unshare patterns passed heaps
		= (CAlgPatterns type patterns, passed, heaps)
	unshare (CBasicPatterns type patterns) passed heaps
		# (patterns, passed, heaps)			= unshare patterns passed heaps
		= (CBasicPatterns type patterns, passed, heaps)
	unshare (CDynPatterns patterns) passed heaps
		# (patterns, passed, heaps)			= unshare patterns passed heaps
		= (CDynPatterns patterns, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (CDynamic HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare dyn passed heaps
		# (expr, passed, heaps)				= unshare dyn.dynExpr passed heaps
		= ({dyn & dynExpr = expr}, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (CDynPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare pattern passed heaps
		# (rhs, passed, heaps)				= unshare pattern.dtpRhs passed heaps
		= ({pattern & dtpRhs = rhs}, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unshare (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unshare (CExprVar id) passed heaps
		= (CExprVar id, passed, heaps)
	unshare (CEnvExpr ptr) passed heaps
		| isMember ptr passed				= (CEnvExpr ptr, passed, heaps)
		# (info, heaps)						= readExprInfo ptr heaps
		| isNothing info.eiExpr				= (CEnvExpr ptr, [ptr:passed], heaps)
		# expr								= fromJust info.eiExpr
		# (expr, passed, heaps)				= unshare expr [ptr:passed] heaps
		| not (sharable expr)				= (expr, passed, heaps)
		# info								= {info & eiExpr = Just expr}
		# heaps								= writeExprInfo ptr info heaps
		= (CEnvExpr ptr, passed, heaps)
	unshare (expr @# exprs) passed heaps
		#! (expr, passed, heaps)				= unshare expr passed heaps
		#! (exprs, passed, heaps)				= unshare exprs passed heaps
		= (expr @# exprs, passed, heaps)
	unshare (@@# ptr strictargs exprs) passed heaps
		#! (exprs, passed, heaps)				= unshare exprs passed heaps
		= (@@# ptr strictargs exprs, passed, heaps)
	unshare (CLet strict lets expr) passed heaps
		#! (expr, passed, heaps)				= unshare expr passed heaps
		# (vars, exprs)						= unzip lets
		#! (exprs, passed, heaps)				= unshare exprs passed heaps
		# lets								= zip2 vars exprs
		= (CLet strict lets expr, passed, heaps)
	unshare (CCase expr patterns def) passed heaps
		#! (expr, passed, heaps)				= unshare expr passed heaps
		#! (patterns, passed, heaps)			= unshare patterns passed heaps
		#! (def, passed, heaps)				= unshare def passed heaps
		= (CCase expr patterns def, passed, heaps)
	unshare (CBasicValue value) passed heaps
		#! (value, passed, heaps)				= unshare value passed heaps
		= (CBasicValue value, passed, heaps)
	unshare (CCode type cod) passed heaps
		= (CCode type cod, passed, heaps)
	unshare (CDynamicExpr dyn) passed heaps
		#! (dyn, passed, heaps)				= unshare dyn passed heaps
		= (CDynamicExpr dyn, passed, heaps)
	unshare CBottom passed heaps
		= (CBottom, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
compactEnv :: !CExprH !*CEnv -> (!CExprH, !*CEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
compactEnv expr heaps
	#! (expr, heaps)						= allProductive expr heaps
	#! (expr, heaps)						= removeBasicSharing expr heaps
	= (expr, heaps)
*/