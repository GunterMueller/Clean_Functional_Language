implementation module Table

// Table.icl: implements lookup table that can be inverted

import StdClass, StdArray, StdFunc
import StdMaybe, StdInt
import UtilOptions
import UtilStrictLists

instance fromString Int where fromString s = toInt s

instance toString (l,r) | toString l & toString r
where
	toString (l,r) = toString l +++ " $$$ " +++ toString r

instance fromString (l,r) | fromString l & fromString r
where
	fromString s
		# (l,r) = dosplit "" s
		= (fromString l,fromString r)
	where
		dosplit l r
			| size r <= 5
				= (l+++r,"")
			| r%(0,4) == " $$$ "
				= (l,r%(5,size r - 1))
			= dosplit (l+++r%(0,0)) (r%(1,size r - 1))

Entry :: OptionsTableEntry (k,v) | fromString, toString k & fromString,toString v
Entry = SimpleOption "Entry" id const

Table :: a b -> .OptionsTable (List (a,b)) | fromString , toString a & fromString , toString b;
Table a b = {ListOption "Table" Entry (a,b) id const}

WriteTable :: k v (Table k v) -> [Option] | fromString , toString k & fromString , toString v
WriteTable k v table = PutOptions (Table k v) (ListToStrictList table)

ReadTable :: k v !.[Option] -> Table k v | fromString , toString k & fromString , toString v
ReadTable k v options
	# table = ListToStrictList []
	# table = GetOptions (Table k v) options table
	# table = StrictListToList table
	= table

:: Table key value :== [(key, value)]

tableNew :: Table key value
tableNew
  = []
  
tableInsert :: !(key, value) !(Table key value) -> Table key value
tableInsert (key, value) table
  = [ (key, value) : table ]

tableRemove :: !key !(Table key value) -> Table key value | Eq key
tableRemove removeKey table
  = [ entry \\ entry=:(key, _) <- table | key <> removeKey ]
 
tableLookup :: !key !(Table key value) -> [value] | Eq key
tableLookup lookupKey table
  = [ value \\ (key, value) <- table | key == lookupKey ]

tableInvert :: !(Table key value) -> Table value key | Eq value
tableInvert table
  = [ (value, key) \\ (key, value) <- table ]

tableKeys :: !(Table key value) -> [key]
tableKeys table
  = [ key \\ (key, _) <- table ]
