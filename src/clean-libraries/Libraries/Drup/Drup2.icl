implementation module Drup2

import DrupGeneric, StdMaybe
import Drup
import StdString

:: Drup2 a = {
	root :: !Chunk .(Mapping a),
	mapping :: !.Mapping a,
	drup :: !.Drup}

:: Mapping a = Empty | Mapping !String !(Chunk a) !(Mapping a)

openDrup2 :: !String !*World -> (!*Drup2 a, !*World) | write{|*|}, read{|*|} a
openDrup2 filename world
	# (root, drup, world) = openDrup filename (Just empty) world
	  (mapping, drup) = chunkValue root drup
	= ({root = root, mapping = mapping, drup = drup}, world)

closeDrup2 :: !*(Drup2 a) !*World -> *World | write{|*|} a
closeDrup2 {root, mapping, drup} world
	# drup = updateChunk root mapping drup
	= closeDrup drup world

storeDrup2 :: !String !.a !*(Drup2 .a) -> *Drup2 .a | write{|*|} a
storeDrup2 ident value d2=:{mapping, drup}
	# (maybe, mapping) = lookup ident mapping
	  (chunk, drup) = case maybe of	
	  					Just c -> (c, drup)
	  					_ -> chunk drup
	  drup = updateChunk chunk value drup
	= {d2 & mapping = insert ident chunk mapping, drup = drup}

loadDrup2 :: !String !*(Drup2 .a) -> (!*Maybe .a, !*Drup2 .a) | read{|*|} a
loadDrup2 ident d2=:{mapping, drup}
	# (maybe, mapping) = lookup ident mapping
	= case maybe of
		Just chunk
			# (value, drup) = chunkValue chunk drup
			-> (Just value, {d2 & mapping = insert ident chunk mapping, drup = drup})
		_ -> (Nothing, {d2 & mapping = mapping, drup = drup})


lookup :: !String !u:(Mapping .a) -> (!*Maybe (Chunk .a), !u:Mapping .a)
lookup ident (Mapping i c ms)
	| ident == i = (Just c, ms)
	# (maybe, ms`) = lookup ident ms
	= (maybe, Mapping i c ms`)
lookup _ _ = (Nothing, Empty)

insert :: !String !(Chunk .a) !u:(Mapping .a) -> u:Mapping .a
insert ident chunk ms = Mapping ident chunk ms

empty :: *Mapping .a
empty = Empty

derive write Mapping
derive read Mapping
