definition module EstherScript

import EstherPostParser, EstherTransform

ENV_PATH :== ["path"]
ENV_CWD :== ["cwd"]

:: EstherBuiltin env = {builtin :: ![(String, Dynamic)], env :: !env}

:: EstherError = EstherError !String

compose :: !String !*env -> (!MaybeException Dynamic, !*env) | resolveFilename, ExceptionEnv, bimap{|*|} env

instance resolveFilename World

instance resolveFilename (EstherBuiltin *env) | resolveFilename env
instance ExceptionEnv (EstherBuiltin *env) | ExceptionEnv env
