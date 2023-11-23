definition module ExtDirectory

from Directory import :: DirError

make_dir_error_readable :: !DirError !String -> String
