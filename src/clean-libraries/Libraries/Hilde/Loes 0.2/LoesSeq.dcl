definition module LoesSeq

import LoesCommon

class Seq t a | Empty, Size (t a) & Fold, Foldl t a
where
	Cons :: a !(t a) -> t a
	Head :: !(t a) -> a
	Tail :: !(t a) -> t a
	Reverse :: !(t a) -> t a

class DeSeq t a | Seq, Foldr t a
where
	Snoc :: !(t a) a -> t a
	Last :: !(t a) -> a
	Init :: !(t a) -> t a
	
class uSeq t a | Empty, uSize (t .a) & Fold, Foldl t a
where
	uCons :: .a !*(t .a) -> *t .a
	uDeCons :: !*(t .a) -> (!*Maybe .a, !*t .a)
	uReverse :: !*(t .a) -> *t .a

class uDeSeq t a | uSeq, Foldr t a
where
	uSnoc :: !*(t .a) .a -> *t .a
	uDeSnoc :: !*(t .a) -> (!*t .a, !*Maybe .a)

ToSeq :: !.(s a) -> t a | Foldr s a & Seq t a
uToSeq :: !.(s .a) -> *t .a | Foldr s a & uSeq t a
