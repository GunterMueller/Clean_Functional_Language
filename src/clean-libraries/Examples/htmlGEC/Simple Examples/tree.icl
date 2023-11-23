implementation module tree

import StdEnv, StdHtml

// balance tree

derive gForm  	Tree
derive gPrint 	Tree
derive gParse 	Tree
derive gUpd 	Tree
derive gerda 	Tree
                                              
balanceTree :: ((Tree a) -> (Tree a)) | Ord a
balanceTree = fromListToBalTree o fromTreeToList

fromTreeToList :: (Tree a) -> [a]
fromTreeToList (Node l x r) = fromTreeToList l ++ [x] ++ fromTreeToList r
fromTreeToList Leaf         = []

fromListToBalTree :: [a] -> Tree a | Ord a
fromListToBalTree list = Balance (sort list)
where
	Balance [] = Leaf
	Balance [x] = Node Leaf x Leaf
	Balance xs
		= case splitAt (length xs/2) xs of
			(a,[b:bs]) = Node (Balance bs) b (Balance a)
			(as,[]) = Node Leaf (hd (reverse as)) (Balance (reverse (tl (reverse as))))
