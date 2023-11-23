definition module pdExtFile;

import StdFile;
from StdInt import toChar, >>;
from StdString import String;

(FWB) infixl
(FWB) f i :== fwritec (toChar i) f;

(FWW) infixl
(FWW) f i :== fwritec (toChar i) (fwritec (toChar (i>>8)) f);

FileExists :: !String !*env -> (!Bool,!*env) | FileSystem env;

path_separator :== ':';