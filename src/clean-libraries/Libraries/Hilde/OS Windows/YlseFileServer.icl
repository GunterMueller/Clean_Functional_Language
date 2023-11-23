implementation module YlseFileServer

import YlseServer
import StdMisc, StdBool, StdString, StdFile, StdArray, StdList, StdDynamicFileIO, Windows, FamkeKernel
from DynID import EXTENSION_USER_DYNAMIC

FILENAME_ESCAPE :== '%'

:: FileServer =
	{	root	:: !String
	}

instance YlseServer FileServer
where
	ylseExistFile path st=:{root} famke
		# (ok, file, famke) = fopen (makePath root path +++ "." +++ EXTENSION_USER_DYNAMIC) FReadData famke
		| not ok = (False, st, famke)
		# (_, famke) = fclose file famke
		= (True, st, famke)

	ylseReadFile path st=:{root} famke
		# (ok, d, famke) = readDynamic (makePath root path +++ "." +++ EXTENSION_USER_DYNAMIC) famke
		| not ok = (Nothing, st, famke)
		= (Just d, st, famke)

	ylseWriteFile path d st=:{root} famke
		# (ok, famke) = writeDynamic (makePath root path +++ "." +++ EXTENSION_USER_DYNAMIC) d famke
		= (ok, st, famke)

	ylseRemoveFile path st=:{root} famke
		# (ok, famke) = DeleteFile (makePath root path +++ "." +++ EXTENSION_USER_DYNAMIC) famke
		= (ok, st, famke)

	ylseMakeFolder path st=:{root} famke
		# (ok, famke) = CreateDirectory (makePath root path) famke
		= (ok, st, famke)

	ylseListFolder path st=:{root} famke
		# (ok, h, data, famke) = FindFirstFile (makePath root path +++ "\\*.*") famke
		| not ok = (Nothing, st, famke)
		= list h [data] famke
	where
		list h ds famke
			# (ok, data, famke) = FindNextFile h famke
			| ok = list h [data:ds] famke
			# (ok, famke) = FindClose h famke
			| not ok = (Nothing, st, famke)
			= (Just (valid ds), st, famke)
		where
			valid [{cFileName=name, dwFileAttributes}:ds]
				| dwFileAttributes bitand FILE_ATTRIBUTE_DIRECTORY <> 0
					| name == "." || name == ".." = valid ds
					= [fromFilename name:valid ds]
				# len = size name
				| name % (len - 4, len - 1) == "." +++ EXTENSION_USER_DYNAMIC = [fromFilename (name % (0, len - 5)):valid ds]
				= valid ds
			valid _ = []

	ylseRemoveFolder path st=:{root} famke
		# (ok, famke) = RemoveDirectory (makePath root path) famke
		= (ok, st, famke)

	ylseMount path id st famke = (False, st, famke)

	ylseUnmount path st famke = (False, st, famke)

makePath :: !String !Path` -> String
makePath root xs = foldl (\x y -> x +++ "\\" +++ toFilename y) root xs

toFilename :: !String -> String
toFilename s = toString (f (fromString s) [])
where
	f [x] ys | isMember x invalidFrontEnd  = escape x [] ys
	f [x:xs] [] | isMember x invalidFrontEnd = escape x xs []
	f [x:xs] ys 
		| isMember x invalidAnywhere = escape x xs ys
		= f xs [x:ys]	
	f _ ys = reverse ys
	
	escape x xs ys = f xs [hex.[i bitand 15], hex.[i >> 4], FILENAME_ESCAPE:ys]
	where
		i = toInt x
		hex = "0123456789ABCDEF"
	
	invalidFrontEnd = [FILENAME_ESCAPE:[' .']] ++ invalidAnywhere
	invalidAnywhere = [FILENAME_ESCAPE:['\\/:*?"<>|']] ++ [toChar i \\ i <- [0..31]] ++ [toChar i \\ i <- [128..255]]

fromFilename :: !String -> String
fromFilename s = toString (f (fromString s))
where
	f [FILENAME_ESCAPE, a, b:xs] = [toChar (value a << 4 + value b):f xs]
	where
		value c
			| c > '9' = toInt (toUpper c - 'A') + 10
			= toInt (c - '0')
	f [x:xs] = [x:f xs]
	f _ = []

StartFileServer :: !YlseId !String !*World -> *World
StartFileServer rpcid root famke = StartYlseServer rpcid {root = root} famke
