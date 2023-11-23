definition module Table

// implements lookup table that can be inverted

from StdClass import class Eq
from StdMaybe import :: Maybe

// The type Table represents lookup tables. 

:: Table key value

tableNew		::											Table key value
tableInsert		:: !(key, value)	!(Table key value)	->	Table key value
tableRemove		:: !key				!(Table key value)	->	Table key value	| Eq key
tableLookup		:: !key				!(Table key value)	->	[value]			| Eq key
tableInvert		:: 					!(Table key value)	->	Table value key | Eq value
tableKeys		:: 					!(Table key value)	->	[key]

// tableNew:	creates an empty table
// tableInsert:	inserts one entry into the table
// tableRemove:	removes all entries with the given key
// tableLookup:	finds all entries with the given key
// tableInvert:	inverts the table, so that you can use the values as keys
// tableKeys:	returns all the keys in the table

import UtilOptions

WriteTable		:: k v (Table k v) -> [Option] | fromString , toString k & fromString , toString v
ReadTable		:: k v !.[Option] -> Table k v | fromString , toString k & fromString , toString v
