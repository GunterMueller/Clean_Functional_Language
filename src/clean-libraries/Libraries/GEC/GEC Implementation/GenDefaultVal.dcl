definition module GenDefaultVal

import testable, StdMaybe, StdTime
from   iostate import :: PSt{..}, :: IOSt

gDefaultVal :: !*env -> (!t,!*env) | ggen {|*|} t & TimeEnv env

GenDefaultValIfNoValue :: !(Maybe t) !*env -> (!t,!*env) | ggen {|*|} t & TimeEnv env
