definition module YlseServer

import StdMaybe
from FamkeRpc import :: RpcId(..), :: FamkePort(..), :: FamkeId(..)

:: Path` :== [String]

:: YlseId :== RpcId YlseIn YlseOut

:: YlseIn

:: YlseOut

existFileAt :: !YlseId !Path` !*World -> (!Bool, !*World)
readFileAt :: !YlseId !Path` !*World -> (!Maybe Dynamic, !*World)
writeFileAt :: !YlseId !Path` Dynamic !*World -> (!Bool, !*World)
removeFileAt :: !YlseId !Path` !*World -> (!Bool, !*World)
makePathAt :: !YlseId !Path` !*World -> (!Bool, !*World)
listFolderAt :: !YlseId !Path` !*World -> (!Maybe [String], !*World)
removePathAt :: !YlseId !Path` !*World -> (!Bool, !*World)

class YlseServer env
where
	ylseExistFile :: !Path` !*env !*World -> (!Bool, !*env, !*World)
	ylseReadFile :: !Path` !*env !*World -> (!Maybe Dynamic, !*env, !*World)
	ylseWriteFile :: !Path` Dynamic !*env !*World -> *(!Bool, !*env, !*World)
	ylseRemoveFile :: !Path` !*env !*World -> (!Bool, !*env, !*World)
	ylseMakeFolder :: !Path` !*env !*World -> (!Bool, !*env, !*World)
	ylseListFolder :: !Path` !*env !*World -> (!Maybe [String], !*env, !*World)
	ylseRemoveFolder :: !Path` !*env !*World -> (!Bool, !*env, !*World)
	ylseMount :: !Path` !YlseId !*env !*World -> (!Bool, !*env, !*World)
	ylseUnmount :: !Path` !*env !*World -> (!Bool, !*env, !*World)

StartYlseServer :: !YlseId !*env !*World -> *World | YlseServer env
