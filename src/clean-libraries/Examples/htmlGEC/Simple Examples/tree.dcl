definition module tree

import StdHtml

:: Tree a = Node (Tree a) a (Tree a) | Leaf    

derive gForm  	Tree
derive gPrint 	Tree
derive gParse 	Tree
derive gUpd 	Tree
derive gerda 	Tree

import StdClass

balanceTree 		:: ((Tree a) -> (Tree a)) | Ord a
fromTreeToList 		:: (Tree a) -> [a]
fromListToBalTree 	:: [a] -> Tree a | Ord a

        