implementation module DataFile

import StdMaybe, DrupGeneric
import Drup, DrupBasic
import StdString

:: DataFile = {
	root :: !Chunk .Mapping,
	mapping :: !.Mapping,
	drup :: !.Drup}

:: Mapping = Empty | Mapping !String !Pointer !Mapping

openDataFile :: !String !*World -> (!*DataFile, !*World)
openDataFile filename world
	# (root, drup, world) = openDrup filename (Just empty) world
	  (mapping, drup) = chunkValue root drup
	= ({root = root, mapping = mapping, drup = drup}, world)

closeDataFile :: !*DataFile !*World -> *World
closeDataFile {root, mapping, drup} world
	# drup = updateChunk root mapping drup
	= closeDrup drup world

storeDataFile :: !String !.a !*DataFile -> *DataFile | write{|*|} a
storeDataFile ident value d3=:{mapping, drup}
	# (maybe, mapping) = lookup ident mapping
	  ({chunk}, drup) = case maybe of	
	  					Just c -> ({chunk = c}, drup)
	  					_ -> chunk drup
	  drup = unsafeUpdateChunk chunk value drup
	= {d3 & mapping = insert ident chunk mapping, drup = drup}

loadDataFile :: !String !*DataFile -> (!*Maybe .a, !*DataFile) | read{|*|} a
loadDataFile ident d3=:{mapping, drup}
	# (maybe, mapping) = lookup ident mapping
	= case maybe of
		Just chunk
			# (value, drup) = unsafeChunkValue chunk drup
			-> (Just value, {d3 & mapping = insert ident chunk mapping, drup = drup})
		_ -> (Nothing, {d3 & mapping = mapping, drup = drup})

lookup :: !String !u:Mapping -> (!*Maybe Pointer, !u:Mapping)
lookup ident (Mapping i c ms)
	| ident == i = (Just c, ms)
	# (maybe, ms`) = lookup ident ms
	= (maybe, Mapping i c ms`)
lookup _ _ = (Nothing, Empty)

removeDataFile :: !String !*DataFile -> *DataFile
removeDataFile ident d3=:{mapping}
	# (_, mapping) = lookup ident mapping
	= {d3 & mapping = mapping}

insert :: !String !Pointer !u:Mapping -> u:Mapping
insert ident chunk ms = Mapping ident chunk ms

empty :: *Mapping
empty = Empty

derive write Mapping
derive read Mapping
