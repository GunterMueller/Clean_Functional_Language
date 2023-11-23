implementation module DynamicFileSystem

import StdDynamic
import StdMisc, StdBool, StdString, StdFile, StdArray, StdList/*, StdDynamicFileIO*/, Windows
from DynID import EXTENSION_USER_DYNAMIC

FILENAME_ESCAPE :== '%'
FILENAME_DIRECTORY_SEPARATOR :== '\\'
FILENAME_INVALID_FRONT_END =: [' .'] ++ FILENAME_INVALID
FILENAME_INVALID =: [FILENAME_ESCAPE:['\\/:*?"<>|']] ++ [toChar i \\ i <- [0..31]] ++ [toChar i \\ i <- [128..255]]
FILENAME_DYNAMIC_EXTENSION =: "." +++ EXTENSION_USER_DYNAMIC

instance DynamicFileSystem World
where
	dynamicExists path world
		# (ok, h, _, world) = FindFirstFile (toDirectory path +++ FILENAME_DYNAMIC_EXTENSION) world
		| not ok = (False, world)
		# (ok, world) = FindClose h world
		= (ok, world)

	dynamicRead path world
		# directory = toDirectory path
		  (ok, list, world) = listFolder directory world
		| ok = (True, dynamic list :: DynamicDirectory, world)
		# (ok, d, world) = (False, undef, world) // readDynamic (directory +++ FILENAME_DYNAMIC_EXTENSION) world
		| not ok = (False, dynamic abort "dynamicRead failed" :: A.a: a, world)
		= (True, d, world)
	where
		listFolder directory world
			# (ok, h, data, world) = FindFirstFile (directory +++ "\\*.*") world
			| not ok = (False, [], world)
			= list h [data] world
		where
			list h ds world
				# (ok, data, world) = FindNextFile h world
				| ok = list h [data:ds] world
				# (ok, world) = FindClose h world
				= (ok, valid ds, world)
			where
				valid [{cFileName=name, dwFileAttributes}:ds]
					| dwFileAttributes bitand FILE_ATTRIBUTE_DIRECTORY <> 0
						| name == "." || name == ".." = valid ds
						= [DynamicDirectory (fromFilename name):valid ds]
					# len = size name
					| name % (len - size FILENAME_DYNAMIC_EXTENSION, len - 1) == FILENAME_DYNAMIC_EXTENSION = [DynamicFile (fromFilename (name % (0, len - size FILENAME_DYNAMIC_EXTENSION - 1))):valid ds]
					= valid ds
				valid _ = []

	dynamicWrite path (_ :: DynamicDirectory) world = CreateDirectory (toDirectory path) world
	dynamicWrite path d world = (False, world) //writeDynamic (toDirectory path +++ FILENAME_DYNAMIC_EXTENSION) d world

	dynamicRemove path world
		# directory = toDirectory path
		  (ok, world) = RemoveDirectory directory world
		| ok = (True, world)
		= DeleteFile (directory +++ FILENAME_DYNAMIC_EXTENSION) world

	dynamicSetRoot root world
		# (ok, world) = (False, world) //SetCurrentDirectory root world
		| not ok = abort "dynamicSetRoot failed"
		= world

toDirectory :: !DynamicPath -> String
toDirectory xs = foldl (\x y -> x +++ {FILENAME_DIRECTORY_SEPARATOR} +++ toFilename y) "." xs

toFilename :: !String -> String
toFilename s = toString (f (fromString s) [])
where
	f [x] ys | isMember x FILENAME_INVALID_FRONT_END  = escape x [] ys
	f [x:xs] [] | isMember x FILENAME_INVALID_FRONT_END = escape x xs []
	f [x:xs] ys 
		| isMember x FILENAME_INVALID = escape x xs ys
		= f xs [x:ys]	
	f _ ys = reverse ys
	
	escape x xs ys = f xs [hex.[i bitand 15], hex.[i >> 4], FILENAME_ESCAPE:ys]
	where
		i = toInt x
		hex = "0123456789ABCDEF"
	
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
