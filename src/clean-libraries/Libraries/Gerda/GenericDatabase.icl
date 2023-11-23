module GenericDatabase

import Gerda, StdEnv, GenEq//, MyDebug

:: R = {naam :: [Char], leeftijd :: Real, rec :: Maybe R}
:: A = C R
:: B = D A String | E (Char, Int) | F
:: N = C1 | C2 | C3
:: Tree a b = Bin !(Tree a b) !a !(Tree a b) | Tip !b
:: Rose a = Rose a [Rose a]
:: GRose m a = GRose a (m (GRose m a))
:: Test` = Constr` Int

:: Test = E. a: {value :: a, write :: a *Gerda -> *Gerda, read :: *Gerda -> *(a, *Gerda), equal :: a a -> Bool}

test :: a -> Test | gerda{|*|}, gEq{|*|} a
test x = {value = x, write = \x g -> writeGerda "test" x g, read = \g -> case readGerda "test" g of (Just x, g) -> (x, g), equal = (===)}

tests = flatten (repeatn 10 [
//	test {gerdaKey = 1, gerdaValue = 2},
	test 42, 
	test C1, 
	test (Constr` 42),
	test [1, 3, 5, 7], 
	test (1, 3.1415927, 'a', [C3, C1, C2, C1, C3, C2]),
	test [[[[[[[1]]]]]]],
	test "test",
	test ("a" +++ {'b' \\ _ <- [1..1000]}),
	test [['aap'], ['noot']],
	test (Bin (Tip 'a') 42 (Tip 'b')),
	test (Rose 1 [Rose 2 [], Rose 3 []]),
	test p1,
	test p2,
	test r2,
	test (strictArray {2, 3, 5, 7, 11, 13, 17, 19}), 
	test (array {r1, r2, r2, r1}),
	test (GRose (1, 'a', 0.5, "bud") [GRose (2, 'b', 0.75, "another bud") [], GRose (3, 'c', 0.875, "yet another bud") []]),
	test {gerdaUnique = 21}])
where
	r1 = {naam = ['noot'], leeftijd = 41.2, rec = Nothing} 
	r2 = {naam = ['aap'], leeftijd = 13.5, rec = Just r1}

	p1 :: Phantom Char
	p1 = Opera

	p2 :: Phantom [Int]
	p2 = Opera

	array :: !{a} -> {a}
	array x = x

	strictArray :: !{!a} -> {!a}
	strictArray x = x

runTests [{value, write, read, equal}:ts] g
	# g = write value g
	  (v, g) = read g
	| not (equal v value) = abort "TEST FAILED" //<<- (value, v)
	= runTests ts g
runTests _ g = g

Start world 
	# (g, world) = openGerda "Clean Data Structures" world
	  g = runTests tests g
	  x = gerdaObject (42, 'a', 3.14, [1..10])
	  g = writeGerda "test2" x g
	  (y, g) = readGerda "test2" g
	  w = case y of Just {gerdaWrite} -> gerdaWrite; _ -> const id
	  r = case y of Just {gerdaRead} -> gerdaRead; _ -> (\g -> (abort "NO readGerda", g))
	  g = w (123, 'b', 2.41, []) g
	  (u, g) = r g
	  g = w (789, 'c', 1.61, []) g
	  (z, g) = r g
	  (v, g) = readGerda "test2" g
	= (mapMaybe (\{gerdaObject} -> gerdaObject) y `typeOf` x.gerdaObject, u, z, mapMaybe (\{gerdaObject} -> gerdaObject) v `typeOf` x.gerdaObject, closeGerda g world)
//	= closeGerda g world
where
	(`typeOf`) :: !(Maybe a) a -> Maybe a
	(`typeOf`) x _ = x

derive gerda (,), (,,), (,,,), Tree, Rose, R, N, GRose, Test`, Phantom
derive gEq GerdaPrimary, GerdaUnique, Binary252, Maybe, Tree, Rose, R, N, Test`, Phantom

gEq{|GRose|} eq_m eq_a (GRose x xs) (GRose y ys) = eq_a x y && eq_m (gEq{|(*->*)->*->*|} eq_m eq_a) xs ys

:: Phantom a = Opera

/*
:: T3 a b c = C3 a b c | D3 | E3

:: T a = C (T a) | D (T a) | E (T (a, a)) | F (Rose a)
:: Rose a = Node [Rose a] | Leaf a

:: W a = W1 (R a)
:: R a = R1 (W a) | R2 a

:: T4 a = T4 [[[[[[[[[[a]]]]]]]]]]

:: T5 a = T5 [[[[(Real, [[a]]) -> ([[[a]]], Int)]]]]

:: T6 a b = T6a (T7 b a)

:: T7 a b = T7a (T6 a b) | T7b a

:: T8 a b c d e f g h = T8a (T8 b c d e f g h a) | T8b a

:: T9 a b c d = T9a [T9 Int [(Real, ((String, a), Char))] [[((Int, b), Int)]] [[[c]]]] | T9b (Real, d)

:: T1 a = T1 a
:: T2 a = T2 (T1 a)

:: S1 a = S1 a
:: S2 a = S2 (S1 a)
:: S3 a = S3R (S1 a) | S3 (S2 a)

:: X1 a b c = X1a (X2 a c b)
:: X2 a b c = X2a (X3 b a c)
:: X3 a b c = X3a (X4 b c a)
:: X4 a b c = X4a (X5 c a b)
:: X5 a b c = X5a (X6 c b a)
:: X6 a b c = X6a a | X6b (X1 b b c) | X6c (X1 b c c)

:: Rec a b = {f1 :: Rose a, f2 :: Rec [b] [a]}

:: ADT a b = Rec a b
*/