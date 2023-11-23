definition module DynamicRefTools

from StdFile import class FileSystem

::Tree= Node String [Tree] [String] //Node dynname refstootherdynamics typandcoderefs
	//this type represets a reference-tree built up from a dynamic

createRealDynamicFilenames :: [String] *f -> ([String],*f) | FileSystem f

readRefsFromDyn :: String [String] *f -> ([String],[String],[String],*f) | FileSystem f

refTreeBuilder :: [String] *f -> ([Tree],[String],[String],*f) | FileSystem f
/*  
  refTreeBuilder builts up the reference trees of the dynamics named in the
  first argument (these must be given in the String format of path). 
  It produces a Tuple4: (listOfReferenceTrees,touched dynamics,log messages,world).

*/

collectReferenced :: [Tree] -> [String]
/*
  Gives back all the filenames referenced by the tree. All referenced 
  filenames appear only once in this list.
*/

readRefsFromBats :: [String] *f -> ([String],[String],*f) | FileSystem f
/*
  Gives back all the filenames referenced by the '.bat' files
  given in the first argument.
*/

//findPattern :: String String -> (Bool,Int)
