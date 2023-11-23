definition module ExtendedArithBasics

from StdBool import not

class EqInt a where
	(==%) infix  4 :: !a !Int -> Bool
	(<>%) infix  4 :: !a !Int -> Bool | EqInt a
	(<>%) a int :== not (a==%int)

class LessInt a where
	(<%)  infix  4 :: !a !Int -> Bool
	(>=%) infix  4 :: !a !Int -> Bool | LessInt a
	(>=%) a int :== not (a<%int)

class GreaterInt a where
	(>%)  infix  4 :: !a !Int -> Bool
	(<=%) infix  4 :: !a !Int -> Bool | GreaterInt a
	(<=%) a int :== not (a>%int)

class (+%)  infixl 6 a :: !a !Int -> a
class (-%)  infixl 6 a :: !a !Int -> a
class (%-)  infix  6 a :: !Int !a -> a
class (*%)  infixl 7 a :: !a !Int -> a

class (^%)  infix  8 a :: ! a !Int ->  a

