/************************************************/
/* Module:	searchtree 							*/
/* 												*/
/* Auteurs:	Tim Nieuwenhuis, Coen Goedegebure 	*/
/*												*/
/* Datum:	04/07/00							*/
/*												*/
/************************************************/

definition module searchtree

import StdEnv
//import StdIO, StdDebug

:: Definition = { funName	:: String
			       ,funDef	:: String
			      }	

::	Tree
	=	Leaf !Definition
	|	Node Tree !Definition Tree

newTree :== Leaf { funName= "" 
				  ,funDef = ""
		  	     }
	
insertIntoTree :: !Definition !Tree -> Tree
inTree :: !String !Tree -> Bool
isLeafEmpty :: !Tree -> Bool
showTree :: !Tree -> String
fillTree :: !Int !Tree -> Tree
inBoom :: !String !Tree -> String
sizeTree :: !Tree -> Int
depthTree :: !Tree -> Int
searchTree :: !String !Tree -> String
