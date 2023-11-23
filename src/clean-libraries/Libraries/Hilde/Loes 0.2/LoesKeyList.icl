implementation module LoesKeyList

import LoesAssoc
import StdMisc, LoesListColl

:: KeyListValue k a = {key :: !k, value :: a}
:: KeyList k a = {keylist :: !.[#.KeyListValue k a!]}

(|->) infix
(|->) k v :== {KeyListValue|key = k, value = v}

instance == (KeyListValue k a) | == k
where
	(==) (x |-> _) (y |-> _) = x == y

selectK k x=:(y |-> _) = (y == k, x)

KeyList xs :== {KeyList|keylist=xs}

instance Empty (KeyList k .a)
where
	Empty = KeyList [|]

instance Size (KeyList k a)
where
	IsEmpty (KeyList xs) = IsEmpty xs
	Size (KeyList xs) = Size xs

instance AssocX KeyList k a | == k
where
	InsertK k x (KeyList xs) = KeyList (Insert (k |-> x) xs)
	DeleteK k (KeyList xs) = KeyList (Delete (k |-> abort "LoesKeyList;AssocX KeyList;DeleteK") xs)
	IsMemberK k (KeyList xs) = IsMember (k |-> abort "LoesKeyList;AssocX KeyList;IsMemberK") xs
	CountMemberK k (KeyList xs) = CountMember (k |-> abort "LoesKeyList;AssocX KeyList;CountMemberK") xs

instance Assoc KeyList k a | == k
where
	LookupK k (KeyList xs) = lookup k xs
	where
		lookup k [|r=:(y |-> x):xs]
			| y == k = Just x
			= lookup k xs
		lookup _ _ = Nothing

instance Fold (KeyList k) a
where
	Fold f e (KeyList xs) = Fold (\(_ |-> y) x -> f y x)  e xs

instance uSize (KeyList k .a)
where
	uIsEmpty (KeyList xs)
		# (e, xs) = uIsEmpty xs
		= (e, KeyList xs)
	uSize (KeyList xs) 
		# (s, xs) = uSize xs
		= (s, KeyList xs)

instance uAssocX KeyList k a | == k
where
	uInsertK k x (KeyList xs) = KeyList (uInsert (k |-> x) xs)
	uDeleteK k (KeyList xs) = KeyList (uDelete (selectK k) xs)

instance uAssoc KeyList k a | == k
where
	uSearchK k (KeyList xs)
		# (maybe, xs) = usearch k xs
		= (maybe, KeyList xs)
	where
		usearch k [|r=:(y |-> x):xs]
			| y == k = (Just x, [|r:xs])
			# (maybe, xs) = usearch k xs
			= (maybe, [|r:xs])
		usearch _ [|] = (Nothing, [|])

	uExtractK k (KeyList xs)
		# (maybe, xs) = uextract k xs
		= (maybe, KeyList xs)
	where
		uextract k [|r=:(y |-> x):xs]
			| y == k = (Just x, xs)
			# (maybe, xs) = uextract k xs
			= (maybe, [|r:xs])
		uextract _ [|] = (Nothing, [|])

