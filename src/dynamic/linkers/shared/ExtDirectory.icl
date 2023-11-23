implementation module ExtDirectory

from StdReal import entier; // RWS marker

import StdEnv

import Directory

make_dir_error_readable :: !DirError !String -> String
make_dir_error_readable NoDirError file_name
	= "";
make_dir_error_readable AlreadyExists file_name
	= "file '" +++ file_name +++ "' already exists"
make_dir_error_readable _ file_name
	= abort "make_dir_error_readable; not completely implemented"
	
/*	
::	DirError = NoDirError | DoesntExist | BadName | NotEnoughSpace | AlreadyExists | NoPermission
				| MoveIntoOffspring | MoveAcrossDisks | NotYetRemovable | OtherDirError
*/
