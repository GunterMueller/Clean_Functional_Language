/*
** Program: Clean Prover System
** Module:  GoalPath (.icl)
** 
** Author:  Maarten de Mol
** Created: 18 December 2000
*/

implementation module 
	GoalPath

import 
	StdEnv,
	StdIO,
	CoreTypes,
	ProveTypes,
	Heaps,
	Operate,
	Tactics
	, RWSDebug

// -------------------------------------------------------------------------------------------------------------------------------------------------
wipeGoalPath :: !ProofTreePtr !*CHeaps -> *CHeaps
// -------------------------------------------------------------------------------------------------------------------------------------------------
wipeGoalPath ptr heaps
	# (proof, heaps)						= readPointer ptr heaps
	= wipe ptr proof heaps
	where
		wipe :: !ProofTreePtr !ProofTree !*CHeaps -> *CHeaps
		wipe ptr (ProofNode Nothing tactic next) heaps
			= uwalk wipeGoalPath next heaps
		wipe ptr (ProofNode (Just goal) tactic next) heaps
			# heaps							= writePointer ptr (ProofNode Nothing tactic next) heaps
			= uwalk wipeGoalPath next heaps
		wipe _ _ heaps
			= heaps 

/*
// -------------------------------------------------------------------------------------------------------------------------------------------------
updateGoalPath :: !TheoremPtr !Theorem ![TheoremPtr] !*CHeaps !*CProject -> (!*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
updateGoalPath theorem_ptr theorem all_theorems heaps prj
	# proof									= theorem.thProof
	# initial_goal							= {glToProve = theorem.thInitial, glHypotheses = [], glExprVars = [], glPropVars = [], glNewHypNum = 0}
	= update_ptr proof.pTree (Just initial_goal) heaps prj
	where
		update_ptr :: !ProofTreePtr !(Maybe Goal) !*CHeaps !*CProject -> (!*CHeaps, !*CProject)
		update_ptr tree_ptr goal heaps prj
			# (tree, heaps)					= readPointer tree_ptr heaps
			= update tree_ptr tree goal heaps prj
		
		update :: !ProofTreePtr !ProofTree !(Maybe Goal) !*CHeaps !*CProject -> (!*CHeaps, !*CProject)
		update tree_ptr (ProofNode Nothing tactic next) (Just goal) heaps prj
			# heaps							= writePointer tree_ptr (ProofNode (Just goal) tactic next) heaps
			= continue tactic next goal heaps prj
		update tree_ptr (ProofNode (Just goal) tactic next) _ heaps prj
			= continue tactic next goal heaps prj
		update _ (ProofLeaf _) _ heaps prj
			= (heaps, prj)
		
		updates :: ![ProofTreePtr] ![ProofTree] ![Maybe Goal] !*CHeaps !*CProject -> (!*CHeaps, !*CProject)
		updates [tree_ptr:tree_ptrs] [tree:trees] [mb_goal:mb_goals] heaps prj
			# (heaps, prj)					= update tree_ptr tree mb_goal heaps prj
			= updates tree_ptrs trees mb_goals heaps prj
		updates _ _ _ heaps prj
			= (heaps, prj)
		
		continue :: !TacticId ![ProofTreePtr] !Goal !*CHeaps !*CProject -> (!*CHeaps, !*CProject)
		continue tactic next goal heaps prj
			# (next_trees, heaps)			= readPointers next heaps
			# have_to_apply					= check_proofs next_trees
			| not have_to_apply				= updates next next_trees (repeatn (length next) Nothing) heaps prj
			# (error, goals, heaps, prj)	= apply tactic ptr goal heaps prj
			| isError error					= (heaps, prj)
			= updates next next_trees (map Just goals) heaps prj
		
		check_proofs :: ![ProofTree] -> !Bool
		check_proofs [ProofNode Nothing _ _:_]
			= True
		check_proofs [_:trees]
			= check_proofs trees
		check_proofs []
			= False
*/

// -------------------------------------------------------------------------------------------------------------------------------------------------
undoProofSteps :: !Int !Proof !*CHeaps -> (!Error, !Proof, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
undoProofSteps count proof heaps
	| isEmpty proof.pLeafs					= (pushError (X_ApplyTactic "Undo" "Undo on a finished proof is ambiguous.") OK, EmptyProof, heaps)
	| count < 1								= (OK, proof, heaps)
	# (error, path, heaps)					= get_path_ptr proof.pTree proof.pCurrentLeaf heaps
	| isError error							= (error, proof, heaps)
	# nr_tactics_on_path					= length path
	# go_to_ptr								= case count > nr_tactics_on_path of
												True	-> proof.pTree
												False	-> path !! (nr_tactics_on_path - count)
	# to_be_removed							= [proof.pCurrentLeaf: drop (1 + nr_tactics_on_path - count) path]
	# (go_to, heaps)						= readPointer go_to_ptr heaps
	= goToProofStep go_to_ptr go_to to_be_removed proof heaps
	where
		get_path_ptr :: !ProofTreePtr !ProofTreePtr !*CHeaps -> (!Error, ![ProofTreePtr], !*CHeaps)
		get_path_ptr now dst heaps
			| now == dst					= (OK, [], heaps)
			# (proof_node, heaps)			= readPointer now heaps
			= get_path now proof_node dst heaps
		
		get_path_ptrs :: ![ProofTreePtr] !ProofTreePtr !*CHeaps -> (!Error, ![ProofTreePtr], !*CHeaps)
		get_path_ptrs [now:nows] dst heaps
			# (error, path, heaps)			= get_path_ptr now dst heaps
			| isError error					= get_path_ptrs nows dst heaps
			= (OK, path, heaps)
		get_path_ptrs [] dst heaps
			= (pushError (X_Internal "Could not reconstruct path to current goal") OK, DummyValue, heaps)
		
		get_path :: !ProofTreePtr !ProofTree !ProofTreePtr !*CHeaps -> (!Error, ![ProofTreePtr], !*CHeaps)
		get_path now (ProofLeaf goal) dst heaps
			= (pushError (X_Internal "Could not reconstruct path to current goal") OK, DummyValue, heaps)
		get_path now (ProofNode mb_goal tactic children) dst heaps
			# (error, path, heaps)			= get_path_ptrs children dst heaps
			| isError error					= (error, DummyValue, heaps)
			= (OK, [now:path], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
goToProofStep :: !ProofTreePtr !ProofTree ![ProofTreePtr] !Proof !*CHeaps -> (!Error, !Proof, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
goToProofStep go_to (ProofLeaf goal) to_be_removed proof heaps
	= (OK, proof, heaps)
goToProofStep go_to (ProofNode Nothing tactic children) to_be_removed proof heaps
	= (pushError (X_Internal "Error: cannot undo if no intermediate goals have been stored") OK, proof, heaps)
goToProofStep go_to (ProofNode (Just goal) tactic children) to_be_removed proof heaps
	# heaps									= writePointer go_to (ProofLeaf goal) heaps
	# (new_leafs, heaps)					= findLeafs proof.pTree [] heaps
	# proof									= {proof	& pLeafs			= new_leafs
														, pCurrentLeaf		= go_to
														, pCurrentGoal		= goal
														, pFoldedNodes		= removeMembers proof.pFoldedNodes [go_to:to_be_removed]
											  }
	= (OK, proof, heaps)
	where
		findLeafs :: !ProofTreePtr ![ProofTreePtr] !*CHeaps -> (![ProofTreePtr], !*CHeaps)
		findLeafs ptr leafs heaps
			# (tree, heaps)					= readPointer ptr heaps
			= findLeafsInTree ptr tree leafs heaps
		
		findLeafsInTree :: !ProofTreePtr !ProofTree ![ProofTreePtr] !*CHeaps -> (![ProofTreePtr], !*CHeaps)
		findLeafsInTree ptr (ProofLeaf goal) leafs heaps
			= (leafs ++ [ptr], heaps)
		findLeafsInTree ptr (ProofNode mb_goal tactic children) leafs heaps
			= findMultipleLeafs children leafs heaps
		
		findMultipleLeafs :: ![ProofTreePtr] ![ProofTreePtr] !*CHeaps -> (![ProofTreePtr], !*CHeaps)
		findMultipleLeafs [ptr:ptrs] leafs heaps
			# (leafs, heaps)				= findLeafs ptr leafs heaps
			= findMultipleLeafs ptrs leafs heaps
		findMultipleLeafs [] leafs heaps
			= (leafs, heaps)

/*
// -------------------------------------------------------------------------------------------------------------------------------------------------
findDependencies :: !Proof !*CHeaps -> (![TheoremPtr], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
findDependencies proof heaps
	= find_ptr proof.pTree [] heaps
	where
		find_ptr :: !ProofTreePtr ![TheoremPtr] !*CHeaps -> (![TheoremPtr], !*CHeaps)
		find_ptr ptr passed heaps
			# (proof_node, heaps)			= readPointer ptr heaps
			= find ptr proof_node passed heaps
		
		find_ptrs :: ![ProofTreePtr] ![TheoremPtr] !*CHeaps -> (![TheoremPtr], !*CHeaps)
		find_ptrs [ptr:ptrs] passed heaps
			# (passed, heaps)				= find_ptr ptr passed heaps
			= find_ptrs ptrs passed heaps
		find_ptrs [] passed heaps
			= (passed, heaps)
		
		find :: !ProofTreePtr !ProofTree ![TheoremPtr] !*CHeaps -> (![TheoremPtr], !*CHeaps)
		find ptr (ProofNode mb_goal tactic children) passed heaps
			# passed						= updateDependencies passed tactic
			= find_ptrs children passed heaps
		find ptr (ProofLeaf goal) passed heaps
			= (passed, heaps)
*/