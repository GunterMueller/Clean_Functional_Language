module TestDrup

import StdEnv, Drup, GenCompress, Drup2, DataFile, DrupDefault
//import code from "printStackNow.o"

Start world
//    | setSize 256 == 0 = undef
//	# world = testWrite 1 [1..500000] world
	# world = testWriteRead2 1 ["Hello", "world"] world
//	# world = decomp "test.txt" [1..125000] world
//	# world = testUnsafeUpdate 1 ['A'..'Z'] world
//	# world = testWriteRead 1 [1..10] world
//	# world = testWriteRead 1 "Hello world" world
//	# world = testSharedUpdate 1 ['A'..'H'] ['A'..'I'] world
//	# world = testKeepSharing 1 ['A'..'H'] ['A'..'I'] ['A'..'Z'] world
	= world
/*
setSize :: !Int -> Int
setSize _ = code inline {
		ccall stackPrintSize "I:I"
	}
*/
decomp filename xs world
	# (ok, file, world) = fopen filename FWriteData world
	  file = writeBV 0 (compress xs) file
	  (ok, world) = fclose file world
	= world
where
	writeBV i a file
		| i >= size a = file
		= writeBV (i + 1) a (fwritei a.[i] file)

derive default []
derive bimap (,), Maybe


testWrite :: !Int !a !*World -> *World | ==, write{|*|}, default{|*|} a
testWrite number u world
	# (c, db, world) = openDrup filename maybeDefault world
	  db = updateChunk c u db
	= closeDrup db world
where
	string = toString number
	filename = "test" +++ string +++ "Write.txt"	

testWriteRead2 :: !Int !a !*World -> *World | ==, write{|*|}, read{|*|} a
testWriteRead2 number u world
	# (db, world) = openDrup2 filename world
	  db = storeDrup2 (toString number) u db
	  (x, db) = loadDrup2 (toString number) db
	  world = closeDrup2 db world
	  (db, world) = openDrup2 filename world
	  (y, db) = loadDrup2 (toString number) db
	#!world = closeDrup2 db world
	| x == Just u && y == Just u = world
	= abort ("test " +++ string +++ " of reading something written failed")
where
	string = toString number
	filename = "test" +++ string +++ "ReadWrite2.txt"	

testWriteRead3 :: !Int !a !*World -> *World | ==, write{|*|}, read{|*|} a
testWriteRead3 number u world
	# (db, world) = openDataFile filename world
	  db = storeDataFile (toString number) u db
	  (x, db) = loadDataFile (toString number) db
	  world = closeDataFile db world
	  (db, world) = openDataFile filename world
	  (y, db) = loadDataFile (toString number) db
	#!world = closeDataFile db world
	| x == Just u && y == Just u = world
	= abort ("test " +++ string +++ " of reading something written failed")
where
	string = toString number
	filename = "test" +++ string +++ "ReadWrite3.txt"	

testWriteRead :: !Int !a !*World -> *World | ==, write{|*|}, read{|*|} a
testWriteRead number u world
	# (c, db, world) = openDrup filename Nothing world
	  db = updateChunk c u db
	  (x, db) = chunkValue c db
	  world = closeDrup db world
	  (c, db, world) = openDrup filename Nothing world
	  (y, db) = chunkValue c db
	#!world = closeDrup db world
	| x == u && y == u = world
	= abort ("test " +++ string +++ " of reading something written failed")
where
	string = toString number
	filename = "test" +++ string +++ "ReadWrite.txt"	

testSharedUpdate :: !Int !a !a !*World -> *World | ==, write{|*|}, read{|*|} a
testSharedUpdate number u1 u2 world
	# (c, db, world) = openDrup filename Nothing world
	  (x, db) = chunk db
	  db = updateChunk x u1 db
	  db = updateChunk c (x, x) db
	  db = updateChunk x u1 db
	  world = closeDrup db world
	  (c, db, world) = openDrup filename Nothing world
	  ((c1, c2), db) = chunkValue c db
	  db = updateChunk c1 u2 db
	  (y, db) = chunkValue c2 db
	#!world = closeDrup db world
	| y == u2 = world
	= abort ("test " +++ string +++ " of shared update failed")
where
	string = toString number
	filename = "test" +++ string +++ "SharedUpdate.txt"	

testKeepSharing :: !Int !a !a !a !*World -> *World | ==, write{|*|}, read{|*|} a
testKeepSharing number u1 u2 u3 world
	# (c, db, world) = openDrup filename Nothing world
	  (x, db) = chunk db
	  db = updateChunk x u1 db
	  db = updateChunk c (x, x) db
	  world = closeDrup db world
	  (c, db, world) = openDrup filename Nothing world
	  ((c1, c2), db) = chunkValue c db
	  db = updateChunk c1 u2 db
	  db = updateChunk c1 u3 db
	  (y, db) = chunkValue c2 db
	#!world = closeDrup db world
	| y == u3 = world
	= abort ("test " +++ string +++ " of keep sharing failed")
where
	string = toString number
	filename = "test" +++ string +++ "KeepSharing.txt"	

testUnsafeUpdate :: !Int !a !*World -> *World | ==, write{|*|}, read{|*|} a
testUnsafeUpdate number u1 world
	# (c, db, world) = openDrup filename Nothing world
	  c` = id` c
	  db = updateChunk c` u1 db
	  (x, db) = chunkValue c db
	#!world = closeDrup db world
	| x == u1 = world
	= abort ("test " +++ string +++ " of unsafe update failed")
where
	string = toString number
	filename = "test" +++ string +++ "UnsafeUpdate.txt"	
	id` :: !(Chunk a) -> Chunk a
	id` x = x
/*
instance == Dynamic where
	(==) (x :: String) (y :: String) = x == y
	(==) (x :: Int) (y :: Int) = x == y
	(==) _ _ = False
*/