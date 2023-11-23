/*
	module owner: Ronny Wichers Schreur
*/

/*
	Implementation of the algorithm to determine type equivalences.
*/
definition module TypeEquivalences

from type_io_read import :: TIO_CommonDefs, :: LibraryInstanceTypeReference
from StdMaybe import :: Maybe

:: TypeEquivalences

:: Replacement a =
	{	frm :: a
	,	to :: a
	}

newTypeEquivalences :: .TypeEquivalences

addTypeEquivalences ::
	!Int				// number of library instance
	!Int				// number of type table
	!{#Char}			// string table
	!{#TIO_CommonDefs}	// definitions from one library instance
	!*TypeEquivalences
	-> *TypeEquivalences

getTypeEquivalences :: !Int u:TypeEquivalences
	-> ([Replacement LibraryInstanceTypeReference], u:TypeEquivalences)

setTypeSymbols :: [({#Char}, (Int, Int))] LibraryInstanceTypeReference *TypeEquivalences
	-> *TypeEquivalences

getTypeSymbols :: LibraryInstanceTypeReference u:TypeEquivalences
	-> (Maybe [({#Char}, (Int, Int))], u:TypeEquivalences)
