/************************************************/
/* Module:	searchtree 							*/
/* 												*/
/* Auteurs:	Tim Nieuwenhuis, Coen Goedegebure 	*/
/*												*/
/* Datum:	14/07/00							*/
/*												*/
/************************************************/

implementation module searchtree

import StdEnv, StdIO	//, StdDebug

// Definition Type
:: Definition = { funName	:: String
			     ,funDef	:: String
			    }	

definitionsFileName	:==	"Defs.def"

// Tree Type
::	Tree
	=	Leaf !Definition
	|	Node Tree !Definition Tree

// Empty Tree
newTree :== Leaf { funName= "" 
				  ,funDef = ""
		  	     }

// insert the definition in the Tree
insertIntoTree :: !Definition !Tree -> Tree
insertIntoTree d b=:(Node l e r)
	| e.funName ==""		= Node l d r
	| d.funName < e.funName	= Node (insertIntoTree d l) e r
	| d.funName > e.funName	= Node l e (insertIntoTree d r)
	| otherwise	= b
insertIntoTree d b=:(Leaf e)
	| e.funName ==""		= Node (newTree) d (newTree)
	| d.funName < e.funName	= Node (Leaf d) e (newTree)
	| d.funName > e.funName	= Node (newTree) e (Leaf d)
	| otherwise	= b

// Returns True if The String occurs in the tree
inTree :: !String !Tree -> Bool
inTree x (Leaf e)		= e.funName==x
inTree x (Node l e r)	= e.funName==x || (x<e.funName && inTree x l) || (x>e.funName && inTree x r)

// Similar to inTree, more a test-function
inBoom :: !String !Tree -> String
inBoom x b=:(Leaf e)		
	| (inTree x b)		= x
	| otherwise			= "dacht het niet LEAF" 
inBoom x b=:(Node l e r)	
	| (inTree x b)		= x
	| otherwise			= "echt niet NODE"

// Returns True if the Leaf in the Tree is empty
isLeafEmpty :: !Tree -> Bool
isLeafEmpty (Leaf e) = e.funName=="" 
isLeafEmpty (Node _ e _) = e.funName=="" 

// Test function... Writes the Tree to stderr
showTree :: !Tree -> String
showTree b=:(Node l e r)					
	| e.funName == "" = "*"
	| otherwise		  =  "<<-"+++(showTree l)+++"->>" +++"<<"+++ e.funName +++ ">>" +++ "<<-"+++(showTree r)+++"->>"
showTree b=:(Leaf e)  = e.funName 

// Test function.. fills the tree with numbers 0 to n
fillTree :: !Int !Tree -> Tree
fillTree n b=:(Node _ _ _)
	| n==0		= b
	| otherwise	= fillTree (n-1) (insertIntoTree ({funName=toString n,funDef=toString n +++" def"}) b)
fillTree n b=:(Leaf _)
	| n==0		= b
	| otherwise	= fillTree (n-1) (insertIntoTree ({funName=toString n,funDef=toString n +++" def"}) b)

// Returns the size of the tree
sizeTree :: !Tree -> Int
sizeTree (Leaf _)		= 1
sizeTree (Node l _ r)	= sizeTree l+sizeTree r+1

// Returns the depth of the tree
depthTree :: !Tree -> Int
depthTree (Leaf _)		= 1
depthTree (Node l _ r)	= max (depthTree l+1) (depthTree r+1)

// Find a definition-name in the Tree and returns the definition, that should be showed in the tooltip
searchTree :: !String !Tree -> String
searchTree x (Leaf e)  
	| ((x==" ") || (x=="\t") || (x==""))	= "space or tab"
	| e.funName==x				= e.funDef
	| otherwise					= "not found"
searchTree x (Node l e r)	
	| ((x==" ") || (x=="\t") || (x==""))	= "space or tab"
	| e.funName==x				= e.funDef
	| x<e.funName				= searchTree x l
	| x>e.funName				= searchTree x r