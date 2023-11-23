definition module type_io_write

import type_io_read

// compiler

from utilities import foldSt, mapSt
from general import ::Optional(..) //aYes, No

from ExtString import CharIndex, CharIndexBackwards
from pdExtFile import path_separator

//F a b :== b
import DebugUtilities

create_type_archive :: [String] [String] !String !*Files -> (!Bool,!*Files);
