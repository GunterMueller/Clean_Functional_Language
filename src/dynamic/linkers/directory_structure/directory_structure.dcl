definition module directory_structure;

from DynIDMacros import DS_LIBRARIES_DIR, DS_SYSTEM_DYNAMICS_DIR;
from StdOverloaded import class +++ (+++);
from StdString import instance +++ {#Char};
from StdMaybe import :: Maybe;

/* Directory structure:
**
** There's is a root-directory called 'Dynamics'. This directory
** contains the following file:
** - DynamicLinker.exe
**
** And the following subdirectories:
** - libraries
** - lazy dynamics
** - conversion
** - utilities
*/

from StdFile import class FileSystem, ::Files;

ds_create_directory :: !{#.Char} !{#.Char} !*a -> *(.(Maybe {#Char}),*a) | FileSystem a;

APPEND_LIBRARY_PATH ddir id :== ddir +++ "\\" +++ DS_LIBRARIES_DIR +++ "\\" +++ id;

APPEND_LAZY_DYNAMIC_PATH ddir id :== ddir +++ "\\" +++ DS_SYSTEM_DYNAMICS_DIR +++ "\\" +++ id +++ ".sysdyn";