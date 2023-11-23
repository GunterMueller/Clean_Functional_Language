definition module tree

:: Tree a = Node (Tree a) a (Tree a) | Leaf    

import StdClass

balanceTree 		:: ((Tree a) -> (Tree a)) | Ord a
fromTreeToList 		:: (Tree a) -> [a]
fromListToBalTree 	:: [a] -> Tree a | Ord a
        