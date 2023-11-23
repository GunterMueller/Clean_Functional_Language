definition module LoesColl

import LoesSeq

class CollX t a | Empty, Size (t a) & == a
where
	Insert :: a !(t a) -> t a
	Delete :: a !(t a) -> t a
	IsMember :: a !(t a) -> Bool
	CountMember :: a !(t a) -> Int

class uCollX t a | Empty, uSize (t a)
where
	uInsert :: .a !*(t .a) -> *t .a
	uDelete :: (.a -> (Bool, .a)) !*(t .a) -> *t .a

class Coll t a | CollX, Fold t a
where
	Lookup :: a !(t a) -> Maybe a
	
class uColl t a | uCollX, Fold t a
where
	uSearch :: a !*(t a) -> (!Maybe a, !*t a)
	uExtract :: (.a -> .(Bool, .a)) !*(t .a) -> (!*Maybe .a, !*t .a)

ToColl :: !.(s a) -> t a | Fold s a & CollX t a
uToColl :: !.(s .a) -> *t .a | Fold s a & uCollX t a
