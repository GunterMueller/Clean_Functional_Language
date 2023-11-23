implementation module LoesColl

import LoesSeq

ToColl :: !.(s a) -> t a | Fold s a & CollX t a
ToColl xs = Fold Insert Empty xs

uToColl :: !.(s .a) -> *t .a | Fold s a & uCollX t a
uToColl xs = Fold uInsert Empty xs
