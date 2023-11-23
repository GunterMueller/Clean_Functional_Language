definition module backendinterface

import frontend, backend

backEndInterface :: !{#Char} [{#Char}] !ListTypesOption !{#Char} !PredefinedSymbols !FrontEndSyntaxTree !Int
							  !*Heaps !*File !*File !*Files
					-> (!Bool,!*Heaps,!*File,!*File,!*Files)

addStrictnessFromBackEnd :: Int {#Char} *BackEnd SymbolType -> (Bool, SymbolType, *BackEnd)
