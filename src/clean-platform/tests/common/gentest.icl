module gentest

import StdEnv

import System.CommandLine

import Control.GenBimap
import Control.GenMap
import Control.GenMapSt
import Control.GenMonad
import Control.GenFMap
import Control.GenReduce
import Data.GenFDomain
import Data.GenLexOrd
import Data.GenZip
import Text.GenParse
import Text.GenPrint
import qualified Data.Maybe
import Data.Maybe.GenPrint
import Data.Maybe.GenParse

:: Tree a b = Tip a | Bin b (Tree a b) (Tree a b)
:: Rose a = Rose a .[Rose a]
:: Fork a = Fork a a
:: Sequ a = SequEmpty | SequZero .(Sequ .(Fork a)) | SequOne a .(Sequ .(Fork a))
:: InfCons 
	= :+: infixl 2 InfCons InfCons
	| :-: infixl 2 InfCons InfCons
	| :*: infixl 3 InfCons InfCons
	| :->: infixr 4 InfCons InfCons
	| U
	| I Int 
:: Rec a b c = { rec_fst :: a, rec_snd :: b, rec_thd :: c }	
:: Color = Red | Green | Blue
:: NewType =: NT Int

derive bimap Tree, Rose, Fork, Sequ

derive gEq 				Tree, Rose, Fork, Sequ, Color, InfCons, Rec, NewType, ?#
derive gLexOrd 			Tree, Rose, Fork, Sequ
derive gMap 			Tree, Rose, Fork, Sequ
derive gMapLSt 			Tree, Rose, Fork, Sequ
derive gMapRSt 			Tree, Rose, Fork, Sequ
derive gMapLM 			Tree, Rose, Fork, Sequ
derive gMapRM 			Tree, Rose, Fork, Sequ
derive gReduceLSt 		Tree, Rose, Fork, Sequ
derive gReduceRSt 		Tree, Rose, Fork, Sequ
derive gReduce 			Tree, Rose, Fork, Sequ
derive gZip				Tree, Rose, Fork, Sequ
derive gMaybeZip 		Tree, Rose, Fork, Sequ
derive gPrint			Tree, Rose, Fork, Sequ, Color, InfCons, Rec, NewType
derive gParse			Tree, Rose, Fork, Sequ, Color, InfCons, Rec, NewType
derive gLookupFMap		Tree, Rose, Fork, Sequ, Color
derive gInsertFMap		Tree, Rose, Fork, Sequ, Color

tree = Bin 1 (Bin 2 (Tip 1.1) (Tip 2.2)) (Bin 3 (Tip 3.3) (Tip 4.4)) 
rose = Rose 1 [Rose 2 [], Rose 3 [Rose 5 [], Rose 6 []], Rose 4[]]
sequ = SequZero (SequOne (Fork 1 2) (SequOne (Fork (Fork 3 4) (Fork 5 6)) SequEmpty))

testEq :: [Bool]
testEq =	
	[ [1,2,3] === [1,2,3]
	, [1,2,3] =!= [1,2,3,4]
	, [1,2,3] =!= [1,2,4] 
	, tree === tree
	, rose === rose
	, sequ === sequ
	, NT 4 =!= NT 5
	, NT 42 === NT 42
	]

testLexOrd = 
	[ ([1,2,3] =?= [1,2,3]) === EQ 
	, ([1,2,3] =?= [1,2,3,4]) === LT
	, ([1,2,4] =?= [1,2,3,4]) === GT
	, (Rose 1 [Rose 2 [], Rose 3 []] =?= Rose 1 [Rose 2 [], Rose 3 []]) === EQ 
	, (Rose 1 [Rose 2 [], Rose 3 []] =?= Rose 1 [Rose 2 [], Rose 3 [], Rose 4 []]) === LT
	, (Rose 1 [Rose 2 [], Rose 4 []] =?= Rose 1 [Rose 2 [], Rose 3 [], Rose 4 []]) === GT
	]
	
testMap =
	[ gMap{|*->*|} inc [1,2,3] === [2,3,4]
	, gMap{|*->*->*|} inc dec (Bin 1 (Tip 2.0) (Tip 3.0)) === Bin 0 (Tip 3.0) (Tip 4.0)
	, gMap{|*->*|} inc (Rose 1 [Rose 2 [], Rose 3 []]) === Rose 2 [Rose 3 [], Rose 4 []] 
	, gMap{|*->*|} inc (SequZero (SequOne (Fork 1 2) (SequOne (Fork (Fork 3 4) (Fork 5 6)) SequEmpty)))
		=== SequZero (SequOne (Fork 2 3) (SequOne (Fork (Fork 4 5) (Fork 6 7)) SequEmpty))
	]

testMapRSt =
	[ gMapRSt{|*->*|} (\x st-> (dec x, [x:st])) [1,2,3] [] === ([0,1,2], [1,2,3]) 
	]		

testMapLSt =
	[ gMapLSt{|*->*|} (\x st-> (dec x, [x:st])) [1,2,3] [] === ([0,1,2], [3,2,1]) 
	]		

testReduceRSt =
	[ gReduceRSt{|*->*|} (\x st -> [x:st]) [1,2,3] [] === [1,2,3]
	]

testReduceLSt =
	[ gReduceLSt{|*->*|} (\x st -> [x:st]) [1,2,3] [] === [3,2,1]
	]

testMapRM =
	[ gMapRM{|*->*|} (?Just o inc) [1,2,3] === (?Just [2,3,4])
	, (gMapRM{|*->*|} (\x -> {st_monad=(\xs -> (inc x, [x:xs]))}) [1,2,3]).st_monad [] === ([2,3,4], [1,2,3])  
	]

testMapLM =
	[ gMapLM{|*->*|} (?Just o inc) [1,2,3] === (?Just [2,3,4])
	, (gMapLM{|*->*|} (\x -> {st_monad=(\xs -> (inc x, [x:xs]))}) [1,2,3]).st_monad [] === ([2,3,4], [3,2,1])  
	]		

testParsePrint =
	[ test 1 
	, test 123
	, test -123

	, test 1.09
	, test 0.123
	, test -123.456
	, test 1.23E-12
	, test 1.23E+12
	, test 1.23E5

	, test True
	, test False

	, test 'a'
	, test '\n'
	, test '"'
	, test '\''
	, test "Hello"
	, test "Hello\n"
	, test "Hello \"string\""

	, test nil
	, test [1]
	, test [1,2,3]

	, test (arr nil)
	, test (arr [1])
	, test (arr [1,2,3])

	, test Red
	, test Green
	, test Blue

	, test {rec_fst=1, rec_snd='a', rec_thd=1.2}

	, test (Bin 'a' (Tip 1) (Bin 'b' (Tip 2) (Bin 'c' (Tip 3) (Tip 4))))
	, test (Rose 1 [Rose 2 [], Rose 3 [], Rose 4 [Rose 5 []]])

	, test (U :+: U)
	, test (U :+: U :+: U)
	, test (U :->: U :->: U)
	, test (U :+: U :*: U)
	, test (U :*: U :->: U)
	, test (I 1 :+: I 2 :+: I 3)
	, test (I 1 :*: I 2 :+: I 3)
	, test (I 1 :+: I 2 :*: I 3)
	, test (I 1 :+: I 2 :*: I 3 :+: I 4)
	, test (I 1 :+: (I 2 :+: I 3) :+: I 4)

	, test [I 1 :+: I 2 :+: I 3, I 4 :->: I 5 :->: I 6]
	, test (arr [I 1 :+: I 2 :+: I 3, I 4 :->: I 5 :->: I 6])

	, test (NT 5)
	, test (NT 42)
	, test
		{	rec_fst = I 1 :+: I 2 :+: I 3
		, 	rec_snd = I 4 :->: I 5 :->: I 6
		,	rec_thd = I 7 :*: I 8 :+: I 9
		}

	, test none
	, test (?Just 42)

	, test lnone
	, test (?^Just 42)

	, test bnone
	, test (?#Just 42)

	, test ()
	]
where
	test x = case parseString (printToString x) of
		?None -> False
		?Just y -> x === y

	nil :: [Int]
	nil = []

	arr :: [a] -> {a}
	arr xs = {x\\x<-xs}

	none :: ?Int
	none = ?None

	lnone :: ?^Int
	lnone = ?^None

	bnone :: ?#Int
	bnone = ?#None

testFMap =
	[ lookupFMap 1 fmap_int === ?Just 10
	, lookupFMap 3 fmap_int === ?Just 30
	, lookupFMap "two" fmap_str === ?Just 2
	, lookupFMap "three" fmap_str === ?Just 3
	, lookupFMap (Rose 1 [Rose 2 [], Rose 30 []]) fmap_rose === ?Just 3
	, lookupFMap (Rose 1 [Rose 20 [], Rose 1 []]) fmap_rose === ?Just 100
	]
where	
	fmap_int = emptyFMap 
		<<= (1, 10) 
		<<= (2, 20) 
		<<= (3,30) 
		<<= (4,40) 
		<<= (5, 50)
	fmap_str = emptyFMap 
		<<= ("one", 1) 
		<<= ("two", 2) 
		<<= ("three", 3) 
		<<= ("four",4) 
		<<= ("five", 5)
	fmap_rose = emptyFMap 
		<<= (Rose 1 [Rose 2 [], Rose 10 []], 1)
		<<= (Rose 1 [Rose 2 [], Rose 20 []], 2)
		<<= (Rose 1 [Rose 2 [], Rose 30 []], 3)
		<<= (Rose 1 [Rose 2 [], Rose 40 []], 4)
		<<= (Rose 1 [Rose 2 [], Rose 50 []], 5)
		<<= (Rose 1 [Rose 20 [], Rose 1 []], 100)

Start w = (tests, setReturnCode (if (foldr (&&) True (flatten tests)) 0 1) w)
where
	tests =
		[ testEq
		, testLexOrd
		, testMap
		, testMapRSt
		, testMapLSt
		, testMapRM
		, testMapLM
		, testReduceRSt
		, testReduceLSt
		, testParsePrint
		, testFMap
		]
