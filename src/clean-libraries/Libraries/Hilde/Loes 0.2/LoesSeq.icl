implementation module LoesSeq

import LoesCommon

ToSeq :: !.(s a) -> t a | Foldr s a & Seq t a
ToSeq xs = Foldr (\x y -> Cons x y) Empty xs

uToSeq :: !.(s .a) -> *t .a | Foldr s a & uSeq t a
uToSeq xs = Foldr (\x y -> uCons x y) Empty xs
