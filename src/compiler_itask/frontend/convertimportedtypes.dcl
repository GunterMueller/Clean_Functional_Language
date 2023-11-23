definition module convertimportedtypes

import syntax

convertIclModule :: !Int !Int !Int !{#CommonDefs} !*{#{#CheckedTypeDef}} !ImportedConstructors !*VarHeap !*TypeHeaps !*GenericHeap
									 -> (!{#Bool},!*{#{#CheckedTypeDef}},!ImportedConstructors,!*VarHeap,!*TypeHeaps,!*GenericHeap)

mark_imported_class :: !Int !Int !Int {#CommonDefs} !ImportedConstructors !*VarHeap
												-> (!ImportedConstructors,!*VarHeap)

convertDclModule :: !Int !{# DclModule} !{# CommonDefs} !*{#{# CheckedTypeDef}} !ImportedConstructors !*VarHeap !*TypeHeaps
													-> (!*{#{# CheckedTypeDef}},!ImportedConstructors,!*VarHeap,!*TypeHeaps)

convertMemberTypesAndImportedTypeSpecifications
	:: !Int !Int !NumberSet !{#DclModule} !{#{#FunType}} !{#CommonDefs} !ImportedConstructors !ImportedFunctions !*{#{#CheckedTypeDef}}
		!*TypeHeaps !*VarHeap -> (!*TypeHeaps, !*VarHeap)
