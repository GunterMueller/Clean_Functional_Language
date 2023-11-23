implementation module DrupBasic

import _SystemDrup
import StdClass, StdInt, StdBool, StdInt, StdChar, StdFile, StdArray, StdMisc, StdString
(<<-) x y :== x
//import WrapDebug

:: Pointer = !{offset :: !Int}

SIZE_CHAR :== 1
SIZE_INT :== IF_INT_64_OR_32 8 4
SIZE_REAL :== 8

NO_OFFSET :== -1

writeCons :: !Int !Int !*Write -> *Write
writeCons i n acc
	| n < 2 = acc
	| n < 256 = writeChar (toChar i) acc
	| otherwise = writeInt i acc

writeBool :: !Bool !*Write -> *Write
writeBool b acc = writeChar (if b '\255' '\0') acc
	
writeChar :: !Char !*Write -> *Write
writeChar c (Write left file)
	| left >= SIZE_CHAR || left < 0 = Write (left - SIZE_CHAR) (fwritec c file) <<- ("wc", c, left)
	| otherwise = writeChar c (writeNext left file) <<- ("wc next", c, left)
	
writeInt :: !Int !*Write -> *Write
writeInt i (Write left file)
	| left >= SIZE_INT || left < 0 = Write (left - SIZE_INT) (fwritei i file) <<- ("wi", i, left) 
	| otherwise = writeInt i (writeNext left file) <<- ("wi next", i, left) 

writeReal :: !Real !*Write -> *Write
writeReal r (Write left file)
	| left >= SIZE_REAL || left < 0 = Write (left - SIZE_REAL) (fwriter r file) <<- ("wr", r, left) 
	| otherwise = writeReal r (writeNext left file) <<- ("wr next", r, left) 

writeChunk :: !.(Chunk .a) !*Write -> *Write
writeChunk {chunk={offset}} acc = writeInt offset acc

writeNext left file
	# (Write current file) = positionFile file
	  file = readFile file
	  file = seekFile (current + left) file
	  (ok, next, file) = freadi file
	| not ok = abort "Cannot retrieve offset to next block"
	| next == NO_OFFSET
		# file = writeFile file
		  (Write position file) = positionFile file
		  file = seekFile (current + left) file <<- ("new offset", position)
		  file = fwritei position file
		  file = seekFile position file
		  file = fwritei 0 file
		= Write -1 file
	# file = seekFile next file <<- ("next offset", next)
	  (ok, size, file) = freadi file
	| not ok = abort "Cannot retrieve size of next block"
	# file = writeFile file <<- ("next size", size)
	  file = seekFile (next + SIZE_INT) file
	= Write size file

readFile :: !*File -> *File
readFile file
	# (ok, file) = unsafeReopen file FReadData
	| ok = file
	= abort "Cannot reopen file for reading"

writeFile :: !*File -> *File
writeFile file
	# (ok, file) = unsafeReopen file FAppendData
	| ok = file
	= abort "Cannot reopen file for writing"

positionFile :: !*File -> *Write
positionFile file
	# (position, file) = fposition file
	= Write position file

seekFile :: !Int !*File -> *File
seekFile position file
	# (ok, file) = fseek file position FSeekSet
	| ok = file
	= abort "Cannot seek in file" <<- ("cannot seek", position)

readCons :: !Int !Int !*Write -> *Read .Bool
readCons i n acc
	| n < 2 = case acc of Write left file -> Read True left file
	= case acc of
		Write left file
			# (Write position file) = positionFile file
			  (Read x left` file) = if (n < 256)
			  						(mapRead toInt (readChar (Write left file)))
			  						(readInt (Write left file))
			| x == i = Read True left` file
			# file = seekFile position file
			= Read False left file

readBool :: !*Write -> *Read .Bool
readBool acc = mapRead toBool (readChar acc)
where
	toBool '\0' = False
	toBool _ = True

readChar :: !*Write -> *Read .Char
readChar (Write left file)
	| left < SIZE_CHAR = readChar (readNext left file)
	# (ok, c, file) = freadc file
	| ok = Read (unsafeTypeCast c) (left - SIZE_CHAR) file
	= Fail file

readInt :: !*Write -> *Read .Int
readInt (Write left file)
	| left < SIZE_INT = readInt (readNext left file)
	# (ok, i, file) = freadi file
	| ok = Read (unsafeTypeCast i) (left - SIZE_INT) file
	= Fail file

readReal :: !*Write -> *Read .Real
readReal (Write left file)
	| left < SIZE_REAL = readReal (readNext left file)
	# (ok, r, file) = freadr file
	| ok = Read (unsafeTypeCast r) (left - SIZE_REAL) file
	= Fail file

readChunk :: !*Write -> *Read .(Chunk .a)
readChunk acc = case readInt acc of
	Read x left file -> Read {chunk = {offset = x}} left file
	Fail file -> Fail file

mapRead f read :== case read of
	Read x left file -> Read (f x) left file
	Fail file -> Fail file

readNext left file
	# (position, file) = fposition file
	  file = seekFile (position + left) file
	  (ok, next, file) = freadi file
	| not ok = abort "Cannot read offset to next block"
	| next == NO_OFFSET <<- ("next offset", next) = abort "No next block to read from"
	# file = seekFile next file
	  (ok, size, file) = freadi file
	| not ok = abort "Cannot read size of next block" 
	= Write size file <<- ("next size", size)

newChunk :: !*File -> (!Chunk .a, !*File)
newChunk file = ({chunk = {offset = NO_OFFSET}}, file)

rootChunk :: !String !*World -> (!Bool, !Chunk .a, !*File, !*World)
rootChunk filename world
	# (ok, file, world) = fopen filename FAppendData world
	| not ok = abort ("Cannot open the file named `" +++ filename +++ "' for writing")
	# (Write position file) = positionFile file
	| position <> 0 = (True, {chunk = {offset = 0}}, readFile file, world)
	# file = fwritei 0 file
	  file = fwritei NO_OFFSET file
	= (False, {chunk = {offset = 0}}, readFile file, world)

getChunk :: !(*Write -> *Read .a) !(Chunk .a) !*File -> (!.a, !*File)
getChunk read chunk=:{chunk={offset=NO_OFFSET}} file = (abort "chunk default value", file)
getChunk read chunk=:{chunk={offset}} file
	# file = seekFile offset file <<- ("offset", offset)
	  (ok, size, file) = freadi file
	| not ok = abort "Cannot read chunk size"
	= case read (Write size file) <<- ("size", size) of
		Read value _ file -> (value, file) <<- ("Read", value)
		Fail file -> abort "cannot deserialize chunk"

putChunk :: !(.a -> .(*Write -> *Write)) !(Chunk .a) !.a !*File -> *File
putChunk write chunk=:{chunk={offset=NO_OFFSET}} value file
	# file = writeFile file
	  (position, file) = fposition file
	  file = replaceChunk chunk position file
	  file = fwritei 0 file
	  (Write left file) = write value (Write -1 file) <<- ("create", value, "at", position)
	  file = fwritei NO_OFFSET file
	  file = seekFile position file
	  file = fwritei (-1 - left) file
	= readFile file <<- ("grown", -1 - left, "from", position)
putChunk write {chunk={offset}} value file
	# file = seekFile offset file
	  (ok, size, file) = freadi file
	| not ok = abort "Cannot retrieve chunk size"
	# file = writeFile file
	  file = seekFile (offset + SIZE_INT) file
	  (Write left file) = write value (Write size file) <<- ("update", value, "at", offset, "size", size)
	| left >= 0 = readFile file
	# size` = -1 - left
	  file = fwritei NO_OFFSET file  
	  (position, file) = fposition file
	  file = seekFile (position - size` - SIZE_INT - SIZE_INT) file
	  file = fwritei size` file <<- ("grown", size`, "at", position - size` - SIZE_INT - SIZE_INT)
	= readFile file

replaceChunk {chunk} offset env
	# (_, env) = replace (unsafeTypeCast chunk) offset env
	= env
where
	replace :: !*Pointer !Int !*env -> (!*Pointer, !*env)
	replace pointer offset env = ({pointer & offset = offset}, env)

