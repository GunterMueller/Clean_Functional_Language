definition module mergecases

import syntax, checksupport

mergeExplicitCasePatterns :: !CasePatterns !*VarHeap !*ExpressionHeap !*ErrorAdmin
						-> *(!CasePatterns,!*VarHeap,!*ExpressionHeap,!*ErrorAdmin)

mergeCases :: !(!Expression, !Position) ![(Expression, Position)] !*VarHeap !*ExpressionHeap !*ErrorAdmin
								   -> *(!(!Expression, !Position),!*VarHeap,!*ExpressionHeap,!*ErrorAdmin)
