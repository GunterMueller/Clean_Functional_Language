implementation module Drup

import DrupGeneric, StdMaybe
import _SystemDrup, DrupBasic
import StdBool, StdMisc, StdFile, StdString, StdEnum, StdList

:: Drup = !{file :: !.File}

openDrup :: !String !(Maybe .a) !*World -> (!Chunk .a, !*Drup, !*World) | write{|*|} a
openDrup name maybe world 
	# (exists, chunk, file, world) = rootChunk name world
	| exists = (chunk, {file = file}, world)
	= case maybe of
		Just value -> (chunk, {file = putChunk write{|*|} chunk value file}, world)
		_ -> (chunk, {file = file}, world)

closeDrup :: !*Drup !*World -> *World
closeDrup {file} world
	# (ok, world) = fclose file world
	| not ok = abort "Cannot close the file"
	= world

chunk :: !*Drup -> (!Chunk .a, !*Drup)
chunk db=:{file} 
	# (chunk, file) = newChunk file
	= (chunk, {db & file = file})

chunkValue :: !(Chunk .a) !*Drup -> (!.a, !*Drup) | read{|*|} a
chunkValue chunk db=:{file}
	# (value, file) = getChunk read{|*|} chunk file
	= (value, {db & file = file})

updateChunk :: !(Chunk .a) !.a !*Drup -> *Drup | write{|*|} a
updateChunk chunk value db=:{file}
	# file = putChunk write{|*|} chunk value file
	= {db & file = file}

unsafeChunkValue :: !Pointer !*Drup -> (!.a, !*Drup) | read{|*|} a
unsafeChunkValue chunk db=:{file}
	# (value, file) = getChunk read{|*|} {chunk = chunk} file
	= (value, {db & file = file})

unsafeUpdateChunk :: !Pointer !.a !*Drup -> *Drup | write{|*|} a
unsafeUpdateChunk chunk value db=:{file}
	# file = putChunk write{|*|} {chunk = chunk} value file
	= {db & file = file}

write{|{}|} write_a x acc = writeArray write_a x acc
write{|{!}|} write_a x acc = writeArray write_a x acc
write{|String|} x acc = writeArray writeChar x acc

read{|{}|} read_a acc = readArray read_a acc
read{|{!}|} read_a acc = readArray read_a acc
read{|String|} acc = readArray readChar acc

writeArray write_a array acc :== foldl f (writeInt s acc) (fromArray array`)
where
	(s, array`) = usize array
	f acc elem = write_a elem acc

readArray :: (*Write -> *Read .e) *Write -> *Read *(a .e) | Array a e
readArray read_a acc = case readInt acc of
	Read s left file -> foldl f (Read (unsafeCreateArray s) left file) [0..s - 1]
	Fail file -> Fail file
where
	f (Read array left file) i = case read_a (Write left file) of 
		Read x left file -> (Read {array & [i] = x} left file)
		Fail file -> Fail file
	f acc _ = acc
