implementation module YlseServer

import StdMaybe
import FamkeRpc, StdEnv

:: YlseIn
	= ExistFile !Path`
	| ReadFile !Path`
	| WriteFile !Path` Dynamic
	| RemoveFile !Path`
	| MakeFolder !Path`
	| ListFolder !Path`
	| RemoveFolder !Path`
	| Mount !Path` !YlseId
	| Unmount !Path`

:: YlseOut
	= FileExists
	| FileRead Dynamic
	| FileWritten
	| FileRemoved
	| FolderMade
	| FolderListed ![String]
	| FolderRemoved
	| Mounted
	| Unmounted
	| PathNotFound
	| FolderNotEmpty
	| OperationNotSupported


existFileAt :: !YlseId !Path` !*World -> (!Bool, !*World)
existFileAt server path famke
	# (reply, famke) = rpc server (ExistFile path) famke
	= case reply of
		FileExists -> (True, famke)
		_ -> (False, famke)

readFileAt :: !YlseId !Path` !*World -> (!Maybe Dynamic, !*World)
readFileAt server path famke
	# (reply, famke) = rpc server (ReadFile path) famke
	= case reply of
		FileRead d -> (Just d, famke)
		_ -> (Nothing, famke)

writeFileAt :: !YlseId !Path` Dynamic !*World -> (!Bool, !*World)
writeFileAt server path d famke
	# (reply, famke) = rpc server (WriteFile path d) famke
	= case reply of
		FileWritten -> (True, famke)
		_ -> (False, famke)

removeFileAt :: !YlseId !Path` !*World -> (!Bool, !*World)
removeFileAt server path famke
	# (reply, famke) = rpc server (RemoveFile path) famke
	= case reply of
		FileRemoved -> (True, famke)
		_ -> (False, famke)

makePathAt :: !YlseId !Path` !*World -> (!Bool, !*World)
makePathAt server path famke
	# (reply, famke) = rpc server (MakeFolder path) famke
	= case reply of
		FolderMade -> (True, famke)
		PathNotFound 
			# (ok, famke) = makePathAt server (init path) famke
			| not ok -> (False, famke)
			-> makePathAt server path famke
		_ -> (False, famke)

listFolderAt :: !YlseId !Path` !*World -> (!Maybe [String], !*World)
listFolderAt server path famke
	# (reply, famke) = rpc server (ListFolder path) famke
	= case reply of
		FolderListed xs -> (Just (sort xs), famke)
		_ -> (Nothing, famke)

removePathAt :: !YlseId !Path` !*World -> (!Bool, !*World)
removePathAt server path famke
	# (reply, famke) = rpc server (RemoveFolder path) famke
	= case reply of
		FolderRemoved -> (True, famke)
		FolderNotEmpty 
			# (maybe, famke) = listFolderAt server path famke
			-> case maybe of
				Just xs
					# (ok, famke) = foldr remove (True, famke) xs
					| not ok -> (False, famke)
					-> removePathAt server path famke
				_ -> (False, famke)
		_ -> (False, famke)
where
	remove _ st=:(False, _) = st
	remove name (True, famke)
		# (ok, famke) = removeFileAt server (path ++ [name]) famke
		| ok = (True, famke)
		= removePathAt server (path ++ [name]) famke

StartYlseServer :: !YlseId !*env !*World -> *World | YlseServer env
StartYlseServer rpcid env famke
	# (_, server, famke) = rpcOpen rpcid famke
	  (env, server, famke) = ylseServer env server famke
	  famke = rpcClose server famke
	= famke
where
	ylseServer env server famke
		# (request, reply, server, famke) = rpcWait server famke
		  (answer, env, famke) = case request of
			ExistFile path
				# (yes, env, famke) = ylseExistFile path env famke
				| yes -> (FileExists, env, famke)
				-> (PathNotFound, env, famke)
			ReadFile path
				# (maybe, env, famke) = ylseReadFile path env famke
				-> case maybe of
					Just d -> (FileRead d, env, famke)
					-> (PathNotFound, env, famke)
			WriteFile path d
				# (yes, env, famke) = ylseWriteFile path d env famke
				| yes -> (FileWritten, env, famke)
				-> (PathNotFound, env, famke)
			RemoveFile path
				# (yes, env, famke) = ylseRemoveFile path env famke
				| yes -> (FileRemoved, env, famke)
				-> (PathNotFound, env, famke)
			MakeFolder path
				# (yes, env, famke) = ylseMakeFolder path env famke
				| yes -> (FolderMade, env, famke)
				-> (PathNotFound, env, famke)
			ListFolder path
				# (maybe, env, famke) = ylseListFolder path env famke
				-> case maybe of
					Just fs -> (FolderListed fs, env, famke)
					-> (PathNotFound, env, famke)
			RemoveFolder path
				# (yes, env, famke) = ylseRemoveFolder path env famke
				| yes -> (FolderRemoved, env, famke)
				-> (PathNotFound, env, famke)
			Mount path id
				# (yes, env, famke) = ylseMount path id env famke
				| yes -> (Mounted, env, famke)
				-> (PathNotFound, env, famke)
			Unmount path
				# (yes, env, famke) = ylseUnmount path env famke
				| yes -> (Unmounted, env, famke)
				-> (PathNotFound, env, famke)
		  famke = reply answer famke
		= ylseServer env server famke
