definition module treeparse

import StdFile, searchtree
import StdString

readFileInTree :: !*env -> (!Tree,!*env) | FileEnv env
spitDclDoor :: !String !*env -> *env | FileEnv env
