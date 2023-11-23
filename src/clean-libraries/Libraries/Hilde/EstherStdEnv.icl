implementation module EstherStdEnv

import EstherBackend
import StdInt, StdList, StdMisc, StdFunc, StdTuple, StdBool, StdString, StdReal

stdEnv :: [(String, Dynamic)]
stdEnv = 
	[	("if", dynamic IF :: A.a: Bool a a -> a)
	,	("raise", overloaded "TC" (dynamic (undef, \tc x -> raiseDynamic (tc x)) :: A.a b: (a, (a -> Dynamic) a -> b)))
//	,	("(>>>>) infix 0", overloaded "TC" (dynamic (undef, >>>>) :: A.a: (a, (a -> Dynamic) a String -> *World -> *(Bool, *World))))
	]	
	++ stdOverloaded ++ stdClass ++ stdInt ++ stdReal ++ stdList 
	++ stdFunc ++ stdMisc ++ stdBool ++ stdString ++ stdTuple
where
	IF x y z = if x y z
//	>>>> tc x n = dynamicWrite [n] (tc x)

	stdOverloaded = 
		[	("(+) infixl 6", overloaded "+" (dynamic (undef, id) :: A.a: (a, (a a -> a) a a -> a)))
		,	("(-) infixl 6", overloaded "-" (dynamic (undef, id) :: A.a: (a, (a a -> a) a a -> a)))
		,	("zero", overloaded "zero" (dynamic (undef, id) :: A.a: (a, a -> a)))
		,	("(*) infixl 7", overloaded "*" (dynamic (undef, id) :: A.a: (a, (a a -> a) a a -> a)))
		,	("(/) infixl 7", overloaded "/" (dynamic (undef, id) :: A.a: (a, (a a -> a) a a -> a)))
		,	("one", overloaded "one" (dynamic (undef, id) :: A.a: (a, a -> a)))
		,	("(==) infix 4", overloaded "==" (dynamic (undef, id) :: A.a: (a, (a a -> Bool) a a -> Bool)))
		,	("(<) infix 4", overloaded "<" (dynamic (undef, id) :: A.a: (a, (a a -> Bool) a a -> Bool)))
		,	("isEven", overloaded "isEven" (dynamic (undef, id) :: A.a: (a, (a -> Bool) a -> Bool)))
		,	("isOdd", overloaded "isOdd" (dynamic (undef, id) :: A.a: (a, (a -> Bool) a -> Bool)))
		,	("length", overloaded "length" (dynamic (undef, id) :: A.a: (a, (a -> Int) a -> Int)))
		,	("(%) infixl 9", overloaded "%" (dynamic (undef, id) :: A.a: (a, (a (Int, Int) -> a) a (Int, Int) -> a)))
		,	("(+++) infixr 5", overloaded "+++" (dynamic (undef, id) :: A.a: (a, (a a -> a) a a -> a)))
		,	("(^) infixr 8", overloaded "^" (dynamic (undef, id) :: A.a: (a, (a a -> a) a a -> a)))
		,	("abs", overloaded "abs" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("sign", overloaded "sign" (dynamic (undef, id) :: A.a: (a, (a -> Int) a -> Int)))
		,	("~", overloaded "~" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("(rem) infix 7", overloaded "rem" (dynamic (undef, id) :: A.a: (a, (a a -> a) a a -> a)))
		,	("gcd", overloaded "gcd" (dynamic (undef, id) :: A.a: (a, (a a -> a) a a -> a)))
		,	("lcm", overloaded "lcm" (dynamic (undef, id) :: A.a: (a, (a a -> a) a a -> a)))
		,	("toInt", overloaded "toInt" (dynamic (undef, id) :: A.a: (a, (a -> Int) a -> Int)))
		,	("toChar", overloaded "toChar" (dynamic (undef, id) :: A.a: (a, (a -> Char) a -> Char)))
		,	("toBool", overloaded "toBool" (dynamic (undef, id) :: A.a: (a, (a -> Bool) a -> Bool)))
		,	("toReal", overloaded "toReal" (dynamic (undef, id) :: A.a: (a, (a -> Real) a -> Real)))
		,	("toString", overloaded "toString" (dynamic (undef, id) :: A.a: (a, (a -> String) a -> String)))
		,	("ln", overloaded "ln" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("log10", overloaded "log10" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("exp", overloaded "exp" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("sqrt", overloaded "sqrt" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("sin", overloaded "sin" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("cos", overloaded "cos" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("tan", overloaded "tan" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("asin", overloaded "asin" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("acos", overloaded "acos" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("atan", overloaded "atan" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("sinh", overloaded "sinh" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("cosh", overloaded "cosh" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("tanh", overloaded "tanh" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("asinh", overloaded "asinh" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("acosh", overloaded "acosh" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		,	("atanh", overloaded "atanh" (dynamic (undef, id) :: A.a: (a, (a -> a) a -> a)))
		]
	
	stdClass =
		[	("inc", overloaded2 "+" "one" (dynamic (undef, undef, \p o x -> p o x) :: A.a: (a, a, (a a -> a) a a -> a)))
		,	("dec", overloaded2 "-" "one" (dynamic (undef, undef, \m o x -> m o x) :: A.a: (a, a, (a a -> a) a a -> a)))
		,	("(<>) infix 4", overloaded "==" (dynamic (undef, \eq x y -> not (eq x y)) :: A.a: (a, (a a -> Bool) a a -> Bool)))
		,	("(>) infix 4", overloaded "<" (dynamic (undef, \less x y -> less y x) :: A.a: (a, (a a -> Bool) a a -> Bool)))
		,	("(<=) infix 4", overloaded "<" (dynamic (undef, \less x y -> not (less y x)) :: A.a: (a, (a a -> Bool) a a -> Bool)))
		,	("(>=) infix 4", overloaded "<" (dynamic (undef, \less x y -> not (less x y)) :: A.a: (a, (a a -> Bool) a a -> Bool)))
		,	("min", overloaded "<" (dynamic (undef, \less x y -> if (less x y) x y) :: A.a: (a, (a a -> Bool) a a -> a)))
		,	("max", overloaded "<" (dynamic (undef, \less x y -> if (less x y) y x) :: A.a: (a, (a a -> Bool) a a -> a)))
		]
	
	stdInt =
		[	("instance + Int", dynamic (+) :: Int Int -> Int)
		,	("instance - Int", dynamic (-) :: Int Int -> Int)
		,	("instance zero Int", dynamic zero :: Int)
		,	("instance * Int", dynamic (*) :: Int Int -> Int)
		,	("instance / Int", dynamic (/) :: Int Int -> Int)
		,	("instance one Int", dynamic one :: Int)
		,	("instance ^ Int", dynamic (^) :: Int Int -> Int)
		,	("instance abs Int", dynamic abs :: Int -> Int)
		,	("instance sign Int", dynamic sign :: Int -> Int)
		,	("instance ~ Int", dynamic ~ :: Int -> Int)
		,	("instance == Int", dynamic (==) :: Int Int -> Bool)
		,	("instance < Int", dynamic (<) :: Int Int -> Bool)
		,	("instance isEven Int", dynamic isEven :: Int -> Bool)
		,	("instance isOdd Int", dynamic isOdd :: Int -> Bool)
		,	("instance toInt Char", dynamic toInt :: Char -> Int)
		,	("instance toInt Int", dynamic toInt :: Int -> Int)
		,	("instance toInt Real", dynamic toInt :: Real -> Int)
		,	("instance toInt {#Char}", dynamic toInt :: {#Char} -> Int)
		,	("instance rem Int", dynamic (rem) :: Int Int -> Int)
		,	("instance gcd Int", dynamic gcd :: Int Int -> Int)
		,	("instance lcm Int", dynamic lcm :: Int Int -> Int)
		,	("(bitor) infixl 6", dynamic (bitor) :: Int Int -> Int)
		,	("(bitand) infixl 6", dynamic (bitand) :: Int Int -> Int)
		,	("(bitxor) infixl 6", dynamic (bitxor) :: Int Int -> Int)
		,	("(<<) infix 7", dynamic (<<) :: Int Int -> Int)
		,	("(>>) infix 7", dynamic (>>) :: Int Int -> Int)
		,	("bitnot", dynamic bitnot :: Int -> Int)
		]
	
	stdReal =
		[	("instance + Real", dynamic (+) :: Real Real -> Real)
		,	("instance - Real", dynamic (-) :: Real Real -> Real)
		,	("instance zero Real", dynamic zero :: Real)
		,	("instance * Real", dynamic (*) :: Real Real -> Real)
		,	("instance / Real", dynamic (/) :: Real Real -> Real)
		,	("instance one Real", dynamic one :: Real)
		,	("instance ^ Real", dynamic (^) :: Real Real -> Real)
		,	("instance abs Real", dynamic abs :: Real -> Real)
		,	("instance sign Real", dynamic sign :: Real -> Int)
		,	("instance ~ Real", dynamic ~ :: Real -> Real)
		,	("instance == Real", dynamic (==) :: Real Real -> Bool)
		,	("instance < Real", dynamic (<) :: Real Real -> Bool)
		,	("instance toReal Int", dynamic toReal :: Int -> Real)
		,	("instance toReal Real", dynamic toReal :: Real -> Real)
		,	("instance toReal {#Char}", dynamic toReal :: {#Char} -> Real)
		,	("instance ln Real", dynamic ln :: Real -> Real)
		,	("instance log10 Real", dynamic log10 :: Real -> Real)
		,	("instance exp Real", dynamic exp :: Real -> Real)
		,	("instance sqrt Real", dynamic sqrt :: Real -> Real)
		,	("instance sin Real", dynamic sin :: Real -> Real)
		,	("instance cos Real", dynamic cos :: Real -> Real)
		,	("instance tan Real", dynamic tan :: Real -> Real)
		,	("instance asin Real", dynamic asin :: Real -> Real)
		,	("instance acos Real", dynamic acos :: Real -> Real)
		,	("instance atan Real", dynamic atan :: Real -> Real)
		,	("instance sinh Real", dynamic sinh :: Real -> Real)
		,	("instance cosh Real", dynamic cosh :: Real -> Real)
		,	("instance tanh Real", dynamic tanh :: Real -> Real)
		,	("instance asinh Real", dynamic asinh :: Real -> Real)
		,	("instance acosh Real", dynamic acosh :: Real -> Real)
		,	("instance atanh Real", dynamic atanh :: Real -> Real)
		,	("entier", dynamic entier :: Real -> Int)
		]
			
	stdList =
		[	("instance == [a]", overloaded "==" (dynamic (undef, eqList) :: A.a: (a, (a a -> Bool) [a] [a] -> Bool)))
		,	("instance length [a]", dynamic length :: A.a: [a] -> Int)
		,	("instance % [a]", dynamic (%) :: A.a: [a] (Int, Int) -> [a])
		,	("(!!) infixl 9", dynamic (!!) :: A.a: [a] Int -> a)
		,	("(++) infixr 5", dynamic (++) :: A.a: [a] [a] -> [a])
		,	("flatten", dynamic flatten :: A.a: [[a]] -> [a])
		,	("isEmpty", dynamic isEmpty :: A.a: [a] -> Bool)
		,	("hd", dynamic hd :: A.a: [a] -> a)
		,	("tl", dynamic tl :: A.a: [a] -> [a])
		,	("last", dynamic last :: A.a: [a] -> a)
		,	("init", dynamic init :: A.a: [a] -> [a])
		,	("take", dynamic take :: A.a: Int [a] -> [a])
		,	("takeWhile", dynamic takeWhile :: A.a: (a -> Bool) [a] -> [a])
		,	("drop", dynamic drop :: A.a: Int [a] -> [a])
		,	("dropWhile", dynamic dropWhile :: A.a: (a -> Bool) [a] -> [a])
		,	("span", dynamic span :: A.a: (a -> Bool) [a] -> ([a], [a]))
		,	("filter", dynamic filter :: A.a: (a -> Bool) [a] -> [a])
		,	("reverse", dynamic reverse :: A.a: [a] -> [a])
		,	("insert", dynamic insert :: A.a: (a a -> Bool) a [a] -> [a])
		,	("insertAt", dynamic insertAt :: A.a: Int a [a] -> [a])
		,	("removeAt", dynamic removeAt :: A.a: Int [a] -> [a])
		,	("updateAt", dynamic updateAt :: A.a: Int a [a] -> [a])
		,	("splitAt", dynamic splitAt :: A.a: Int [a] -> ([a], [a]))
		,	("map", dynamic map :: A.a b: (a -> b) [a] -> [b])
		,	("iterate", dynamic iterate :: A.a: (a -> a) a -> [a])
		,	("indexList", dynamic indexList :: A.a: [a] -> [Int])
		,	("repeatn", dynamic repeatn :: A.a: Int a -> [a])
		,	("repeat", dynamic repeat :: A.a: a -> [a])
		,	("unzip", dynamic unzip :: A.a b: [(a, b)] -> ([a], [b]))
		,	("zip2", dynamic zip2 :: A.a b: [a] [b] -> [(a, b)])
		,	("zip", dynamic zip :: A.a b: ([a], [b]) -> [(a, b)])
		,	("diag2", dynamic diag2 :: A.a b: [a] [b] -> [(a, b)])
		,	("diag3", dynamic diag3 :: A.a b c: [a] [b] [c] -> [(a, b, c)])
		,	("foldl", dynamic foldl :: A.a b: (a b -> a) a [b] -> a)
		,	("foldr", dynamic foldr :: A.a b: (a b -> b) b [a] -> b)
		,	("scan", dynamic scan :: A.a b: (a b -> a) a [b] -> [a])
		,	("and", dynamic and :: [Bool] -> Bool)
		,	("or", dynamic or :: [Bool] -> Bool)
		,	("any", dynamic any :: A.a: (a -> Bool) [a] -> Bool)
		,	("all", dynamic all :: A.a: (a -> Bool) [a] -> Bool)
		]
	where
		eqList eq [x:xs] [y:ys] = eq x y && eqList eq xs ys
		eqList _ [] [] = True
		eqList _ _ _ = False
	
	stdFunc =
		[	("id", dynamic id :: A.a: a -> a)
		,	("const", dynamic const :: A.a b: a b -> a)
		,	("flip", dynamic flip :: A.a b c: (a b -> c) b a -> c)
		,	("(o) infixr 9", dynamic (o) :: A.a b c: (b -> c) (a -> b) a -> c)
		,	("twice", dynamic twice :: A.a: (a -> a) a -> a)
		,	("while", dynamic while :: A.a: (a -> Bool) (a -> a) a -> a)
		,	("until", dynamic until :: A.a: (a -> Bool) (a -> a) a -> a)
		,	("iter", dynamic iter :: A.a: Int (a -> a) a -> a)
		,	("seq", dynamic seq :: A.s: [(s -> s)] s -> s)
		,	("seqList", dynamic seqList :: A.a s: [*s -> *(a, *s)] *s -> *([a], *s))
		,	("`bind` infix 0", dynamic (`bind`) :: A.a b s: (*s ->  *(a, *s)) (a *s -> *(b, *s)) *s -> *(b, *s))
		,	("return", dynamic return :: A.a s: a *s -> *(a, *s))
		]
	
	stdMisc =
		[	("undef", dynamic undef :: A.a: a)
		,	("abort", dynamic abort :: A.a: String -> a)
		]
	where
		undef = raise UndefEvaluated
		abort msg = raise (AbortEvaluated msg)

	stdBool =
		[	("instance == Bool", dynamic (==) :: Bool Bool -> Bool)
		,	("instance toBool Bool", dynamic toBool :: Bool -> Bool)
		,	("not", dynamic not)
		,	("(||) infixr 2", dynamic (||))
		,	("(&&) infixr 3", dynamic (&&))
		]

	stdString =
		[	("instance == {#Char}", dynamic (==) :: String String -> Bool)
		,	("instance < {#Char}", dynamic (<) :: String String -> Bool)
		,	("instance toString Int", dynamic toString :: Int -> String)
		,	("instance toString Char", dynamic toString :: Char -> String)
		,	("instance toString Real", dynamic toString :: Real -> String)
		,	("instance toString Bool", dynamic toString :: Bool -> String)
		,	("instance toString {#Char}", dynamic toString :: {#Char} -> String)
		,	("instance % {#Char}", dynamic (%) :: String (Int, Int) -> String)
		,	("instance +++ {#Char}", dynamic (+++) :: String String -> String)
		,	("(+++.) infixr 5", dynamic (+++.) :: String String -> *String)
		,	("(:=) infixl 9", dynamic (:=) :: String (Int, Char) -> String)
		]

	stdTuple =
		[	("fst", dynamic fst :: A.a b: (a, b) -> a)
		,	("snd", dynamic snd :: A.a b: (a, b) -> b)
		,	("fst3", dynamic fst3 :: A.a b c: (a, b, c) -> a)
		,	("snd3", dynamic snd3 :: A.a b c: (a, b, c) -> b)
		,	("thd3", dynamic thd3 :: A.a b c: (a, b, c) -> c)
		,	("curry", dynamic curry :: A.a b c: ((a, b) -> c) a b -> c)
		,	("uncurry", dynamic uncurry :: A.a b c: (a b -> c) (a, b) -> c)
		]
		