definition module LoesCommon

import StdClass, StdMaybe

class Empty a :: .a

class Size a
where
	IsEmpty :: !a -> Bool
	Size :: !a -> Int

class uSize a 
where
	uIsEmpty :: !*a -> (!Bool, !*a)
	uSize :: !*a -> (!Int, !*a)

class Fold t a :: !(.a -> .(.b -> .b)) .b !.(t .a) -> .b

class Foldl t a :: !(.b -> .(.a -> .b)) .b !.(t .a) -> .b
class Foldr t a :: !(.a -> .(.b -> .b)) .b !.(t .a) -> .b

class Map t a b :: !(a -> b) !(t a) -> t b
class uMap t a b :: !(.a -> .b) !*(t .a) -> *t .b
