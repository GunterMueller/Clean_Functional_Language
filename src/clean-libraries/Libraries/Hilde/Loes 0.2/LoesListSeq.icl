implementation module LoesListSeq

import LoesSeq, StdStrictLists
from StdOverloadedList import abort, LengthM, IsEmptyM, MapM, HdM, TlM, LastM, InitM, ++$, ReverseM
import StdInt

instance Empty [.a] where Empty = EmptyM
instance Empty [!.a] where Empty = EmptyM
instance Empty [.a!] where Empty = EmptyM
instance Empty [!.a!] where Empty = EmptyM

instance Size [a]
where
	IsEmpty xs = IsEmptyM xs
	Size xs = LengthM xs

instance Size [!a]
where
	IsEmpty xs = IsEmptyM xs
	Size xs = LengthM xs

instance Size [a!]
where
	IsEmpty xs = IsEmptyM xs
	Size xs = LengthM xs

instance Size [!a!]
where
	IsEmpty xs = IsEmptyM xs
	Size xs = LengthM xs

instance Fold [] a where Fold f e xs = FoldrM f e xs
instance Fold [! ] a where Fold f e xs = FoldrM f e xs
instance Fold [ !] a where Fold f e xs = FoldrM f e xs
instance Fold [!!] a where Fold f e xs = FoldrM f e xs

instance Foldl [] a where Foldl f e xs = FoldlM f e xs
instance Foldl [! ] a where Foldl f e xs = FoldlM f e xs
instance Foldl [ !] a where Foldl f e xs = FoldlM f e xs
instance Foldl [!!] a where Foldl f e xs = FoldlM f e xs

instance Foldr [] a where Foldr f e xs = FoldrM f e xs
instance Foldr [! ] a where Foldr f e xs = FoldrM f e xs
instance Foldr [ !] a where Foldr f e xs = FoldrM f e xs
instance Foldr [!!] a where Foldr f e xs = FoldrM f e xs

instance Seq [] a
where
	Cons x xs = ConsM x xs
	Head xs = HdM xs
	Tail xs = TlM xs
	Reverse xs = ReverseM xs

instance Seq [! ] a
where
	Cons x xs = ConsM x xs
	Head xs = HdM xs
	Tail xs = TlM xs
	Reverse xs = ReverseM xs

instance Seq [ !] a
where
	Cons x xs = ConsM x xs
	Head xs = HdM xs
	Tail xs = TlM xs
	Reverse xs = ReverseM xs

instance Seq [!!] a
where
	Cons x xs = ConsM x xs
	Head xs = HdM xs
	Tail xs = TlM xs
	Reverse xs = ReverseM xs

instance DeSeq [] a
where
	Snoc xs x = SnocM xs x
	Last xs = LastM xs
	Init xs = InitM xs

instance DeSeq [! ] a
where
	Snoc xs x = SnocM xs x
	Last xs = LastM xs
	Init xs = InitM xs

instance DeSeq [ !] a
where
	Snoc xs x = SnocM xs x
	Last xs = LastM xs
	Init xs = InitM xs

instance DeSeq [!!] a
where
	Snoc xs x = SnocM xs x
	Last xs = LastM xs
	Init xs = InitM xs

instance Map [] a b where Map f xs = MapM f xs
instance Map [! ] a b where Map f xs = MapM f xs
instance Map [ !] a b where Map f xs = MapM f xs
instance Map [!!] a b where Map f xs = MapM f xs

instance uSize [.a] 
where 
	uIsEmpty xs = uIsEmptyM xs
	uSize xs = uLengthM xs

instance uSize [!.a]
where 
	uIsEmpty xs = uIsEmptyM xs
	uSize xs = uLengthM xs

instance uSize [.a!]
where 
	uIsEmpty xs = uIsEmptyM xs
	uSize xs = uLengthM xs

instance uSize [!.a!]
where 
	uIsEmpty xs = uIsEmptyM xs
	uSize xs = uLengthM xs

instance uSeq [] a
where
	uCons x xs = ConsM x xs
	uDeCons xs = uDeConsM xs
	uReverse xs = ReverseM xs

instance uSeq [! ] a
where
	uCons x xs = ConsM x xs
	uDeCons xs = uDeConsM xs
	uReverse xs = ReverseM xs

instance uSeq [ !] a
where
	uCons x xs = ConsM x xs
	uDeCons xs = uDeConsM xs
	uReverse xs = ReverseM xs

instance uSeq [!!] a
where
	uCons x xs = ConsM x xs
	uDeCons xs = uDeConsM xs
	uReverse xs = ReverseM xs

instance uDeSeq [] a
where
	uSnoc xs x = SnocM xs x
	uDeSnoc xs = uDeSnocM xs

instance uDeSeq [! ] a
where
	uSnoc xs x = SnocM xs x
	uDeSnoc xs = uDeSnocM xs

instance uDeSeq [ !] a
where
	uSnoc xs x = SnocM xs x
	uDeSnoc xs = uDeSnocM xs

instance uDeSeq [!!] a
where
	uSnoc xs x = SnocM xs x
	uDeSnoc xs = uDeSnocM xs

instance uMap [] a b where uMap f xs = MapM f xs
instance uMap [! ] a b where uMap f xs = MapM f xs
instance uMap [ !] a b where uMap f xs = MapM f xs
instance uMap [!!] a b where uMap f xs = MapM f xs

instance Empty [#.a] | UList a where Empty = EmptyM
instance Empty [#.a!] | UTSList a where Empty = EmptyM

instance Size [#a] | UList a
where
	IsEmpty xs = IsEmptyM xs
	Size xs = LengthM xs

instance Size [#a!] | UTSList a
where
	IsEmpty xs = IsEmptyM xs
	Size xs = LengthM xs

instance Fold [#] a | UList a where Fold f e xs = FoldrM f e xs
instance Fold [#!] a | UTSList a where Fold f e xs = FoldrM f e xs

instance Foldl [#] a | UList a where Foldl f e xs = FoldlM f e xs
instance Foldl [#!] a | UTSList a where Foldl f e xs = FoldlM f e xs

instance Foldr [#] a | UList a where Foldr f e xs = FoldrM f e xs
instance Foldr [#!] a | UTSList a where Foldr f e xs = FoldrM f e xs

instance Seq [#] a | UList a
where
	Cons x xs = ConsM x xs
	Head xs = HdM xs
	Tail xs = TlM xs
	Reverse xs = ReverseM xs

instance Seq [#!] a | UTSList a
where
	Cons x xs = ConsM x xs
	Head xs = HdM xs
	Tail xs = TlM xs
	Reverse xs = ReverseM xs

instance DeSeq [#] a | UList a
where
	Snoc xs x = SnocM xs x
	Last xs = LastM xs
	Init xs = InitM xs

instance DeSeq [#!] a | UTSList a
where
	Snoc xs x = SnocM xs x
	Last xs = LastM xs
	Init xs = InitM xs

instance Map [#] a b | UList a & UList b where Map f xs = MapM f xs
instance Map [#!] a b | UTSList a & UTSList b where Map f xs = MapM f xs

instance uSize [#.a] | UList a
where 
	uIsEmpty xs = uIsEmptyM xs
	uSize xs = uLengthM xs

instance uSize [#.a!] | UTSList a
where 
	uIsEmpty xs = uIsEmptyM xs
	uSize xs = uLengthM xs

instance uSeq [#] a | UList a
where
	uCons x xs = ConsM x xs
	uDeCons xs = uDeConsM xs
	uReverse xs = ReverseM xs

instance uSeq [#!] a | UTSList a
where
	uCons x xs = ConsM x xs
	uDeCons xs = uDeConsM xs
	uReverse xs = ReverseM xs

instance uDeSeq [#] a | UList a
where
	uSnoc xs x = SnocM xs x
	uDeSnoc xs = uDeSnocM xs

instance uDeSeq [#!] a | UTSList a
where
	uSnoc xs x = SnocM xs x
	uDeSnoc xs = uDeSnocM xs

instance uMap [#] a b | UList a & UList b where uMap f xs = MapM f xs
instance uMap [#!] a b | UTSList a & UTSList b where uMap f xs = MapM f xs

EmptyM :== [|]

uIsEmptyM xs :== uisempty xs
where
	uisempty nil=:[|] = (True, nil)
	uisempty xs = (False, xs)

uLengthM xs :== ulength 0 xs
where
	ulength n nil=:[|] = (n, nil)
	ulength n [|x:xs] 
		# (n, xs) = ulength (n + 1) xs
		= (n, [|x:xs])
	
FoldlM op r l :== foldl r l
where
	foldl r [|]		= r
	foldl r [|a:x]	= foldl (op r a) x

FoldrM op r l :== foldr l
where
	foldr [|] = r
	foldr [|a:x] = op a (foldr x)

ConsM x xs :== [|x:xs]

uDeConsM xs :== udecons xs
where
	udecons [|x:xs] = (Just x, xs)
	udecons nil = (Nothing, nil)

SnocM xs x :== xs ++$ [|x]

uDeSnocM xs :== udesnoc xs
where
	udesnoc [|x:xs]
		# (xs, maybe) = udesnoc xs
		= ([|x:xs], maybe)
	udesnoc nil = (nil, Nothing)
