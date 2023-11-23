definition module LoesBatchedSeq

import LoesSeq

:: BatchedSeq a = {front :: !.[a], rear :: !.[a]}

instance Empty (BatchedSeq .a)
instance uSize (BatchedSeq .a)
instance Fold BatchedSeq a | Foldl BatchedSeq a
instance Foldr BatchedSeq a | Foldr [ /*!*/] a
instance Foldl BatchedSeq a | Foldl [ /*!*/] a
instance uSeq BatchedSeq a | uSeq [ /*!*/] a
instance uDeSeq BatchedSeq a | uDeSeq [ /*!*/] a
instance uMap BatchedSeq a b | uMap [ /*!*/] a b
