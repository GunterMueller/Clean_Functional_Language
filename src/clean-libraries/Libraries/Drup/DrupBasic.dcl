definition module DrupBasic

:: Read a = Read !a !Int !.File | Fail !.File

:: Write = Write !Int !.File

:: Chunk a = {chunk :: !.Pointer}

:: Pointer

writeCons :: !Int !Int !*Write -> *Write
writeBool :: !Bool !*Write -> *Write
writeChar :: !Char !*Write -> *Write
writeInt :: !Int !*Write -> *Write
writeReal :: !Real !*Write -> *Write
writeChunk :: !.(Chunk .a) !*Write -> *Write

readFile :: !*File -> *File
writeFile :: !*File -> *File
positionFile :: !*File -> *Write
seekFile :: !Int !*File -> *File

readCons :: !Int !Int !*Write -> *Read .Bool
readBool :: !*Write -> *Read .Bool
readChar :: !*Write -> *Read .Char
readInt :: !*Write -> *Read .Int
readReal :: !*Write -> *Read .Real
readChunk :: !*Write -> *Read .(Chunk .a)

newChunk :: !*File -> (!Chunk .a, !*File)
rootChunk :: !String !*World -> (!Bool, !Chunk .a, !*File, !*World)
getChunk :: !(*Write -> *Read .a) !(Chunk .a) !*File -> (!.a, !*File)
putChunk :: !(.a -> .(*Write -> *Write)) !(Chunk .a) !.a !*File -> *File

