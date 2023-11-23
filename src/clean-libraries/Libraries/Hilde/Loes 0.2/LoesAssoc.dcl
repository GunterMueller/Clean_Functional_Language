definition module LoesAssoc

import LoesSeq

class AssocX t k a | Empty, Size (t k a)
where
	InsertK :: !k a !(t k a) -> t k a
	DeleteK :: !k !(t k a) -> t k a
	IsMemberK :: !k !(t k a) -> Bool
	CountMemberK :: !k !(t k a) -> Int

class Assoc t k a | AssocX t k a & Fold (t k) a
where
	LookupK :: !k !(t k a) -> Maybe a

class uAssocX t k a | Empty, uSize (t k a)
where
	uInsertK :: !k .a !*(t k .a) -> *t k .a
	uDeleteK :: !k !*(t k .a) -> *t k .a

class uAssoc t k a | uAssocX t k a & Fold (t k) a
where
	uSearchK :: !k !*(t k a) -> (!*Maybe a, !*t k a)
	uExtractK :: !k !*(t k .a) -> (!*Maybe .a, !*t k .a)

ToAssoc :: !.(s (k, a)) -> t k a | Fold s (k, a) & AssocX t k a
uToAssoc :: !.(s (k, .a)) -> *t k .a | Fold s (k, a) & uAssocX t k a
