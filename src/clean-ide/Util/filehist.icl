implementation module filehist

import StdMenu, StdMenuElementClass, StdMenuReceiver, StdReceiver
import ioutil


:: FileHistLocalState =
	{ paths :: [String]
	, menid :: [Id]
	}

:: FileHistMenu ls pst = FileHistMenu String Int Id (R2Id String [String]) Id [String] (String pst -> pst)

instance MenuElements FileHistMenu
where 
	getMenuElementType _ = "FileHistMenu"
	menuElementToHandles (FileHistMenu title fh_num mFileMenId mFhRecId mFHmenId inits action) ps
		=
		menuElementToHandles
			{ newLS = {fh_ini_loc & paths = inits}
			, newDef =
					SubMenu title
					(	ListLS [fh_item e \\ e <- inits]
					:+:	Receiver2 mFhRecId fh_menu_add []
					/*
					Problem is when to add and remove elements...
					*/
					) [MenuId mFHmenId]
			} ps
	where
		fh_item path = MenuItem path [MenuFunction (item_action path)]
		item_action path (ls,ps)
//			# (_,ps) = syncSend2 mFhRecId path ps
			# ps = action path ps
			= (ls,ps)
		fh_ini_loc = {paths = [], menid = []}
		fh_menu_add path (ls=:{paths},ps)
			| path == ""
				= (paths,(ls,ps))
			# (i,paths)	= removeIndex` path paths
			| i <> 0	// already existed in list
				# paths	= [path:paths]
				#! ps	= appPIO (closeSubMenuIndexElements mFHmenId [i]) ps
				# ls	= {ls & paths = paths}
				# (_,ps)	= openSubMenuElements mFHmenId 0 ls (fh_item path) ps
				= ([],(ls,ps))
			# paths		= [path:paths]
			# (paths,ps)= safeclose paths ps
			# ls		= {ls & paths = paths}
			# (_,ps)	= openSubMenuElements mFHmenId 0 ls (fh_item path) ps
			= ([],(ls,ps))
		safeclose paths ps
			| length paths <= fh_num = (paths,ps)
			# paths = take fh_num paths
			# ps = appPIO (closeSubMenuIndexElements mFHmenId [fh_num]) ps
			= (paths,ps)

removeIndex` :: a !u:[a] -> (Int,u:[a]) | Eq a
removeIndex` e xs = removei e xs 1
where
	removei :: a u:[a] !Int -> (Int,u:[a]) | == a;
	removei e [x:xs] i
		| x==e
			= (i,xs)
			= (j,[x:res])
			with
				(j,res) = removei e xs (inc i)
	removei e [] i = (0,[])

