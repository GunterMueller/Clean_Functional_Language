implementation module LoesAssoc

import LoesSeq

ToAssoc :: !.(s (k, a)) -> t k a | Fold s (k, a) & AssocX t k a
ToAssoc xs = Fold (\(k, y) x -> InsertK k y x) Empty xs

uToAssoc :: !.(s (k, .a)) -> *t k .a | Fold s (k, a) & uAssocX t k a
uToAssoc xs = Fold (\(k, y) x -> uInsertK k y x) Empty xs
