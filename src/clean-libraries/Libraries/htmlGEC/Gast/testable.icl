implementation module testable

/*
	GAST: A Generic Automatic Software Test-system
	
	testable: the test algorithm for logical properties

	Pieter Koopman, 2002-2004
	Radboud Universty, Nijmegen
	The Netherlands
	pieter@cs.ru.nl
*/

import StdEnv, MersenneTwister, genLibTest /*, StdTime*/ , gen

derive gLess Result
instance == Result where (==) x y = x===y

newAdmin :: Admin
newAdmin = {res=Undef, labels=[], args=[], name=[]}

class TestArg a | genShow{|*|}, ggen{|*|} a

class Testable a where evaluate :: a RandomStream Admin -> [Admin]

instance Testable Bool where evaluate b rs result = [{result & res = if b OK CE, args = reverse result.args}]

instance Testable Property
where evaluate (Prop p) rs result = p rs result

instance Testable (a->b) | Testable b & TestArg a  
where evaluate f rs admin
		# (rs,rs2) = split rs
		= forAll f (generateAll rs) rs2 admin

instance Testable [a] | Testable a  
where evaluate list rs admin = diagonal [ evaluate x (genRandInt seed) admin \\ x<-list & seed<-rs ]

:: Property = Prop (RandomStream Admin -> [Admin])

prop :: a -> Property | Testable a
prop p = Prop (evaluate p)

forAll :: !(a->b) ![a] RandomStream Admin -> [Admin] | Testable b & TestArg a
forAll f list rs r = diagonal [apply f a (genRandInt seed) r \\ a<-list & seed<-rs ]

apply :: !(a->b) a RandomStream Admin -> [Admin] | Testable b & TestArg a
apply f a rs r = evaluate (f a) rs {r & args = [show1 a:r.args]}

diagonal :: [[a]] -> [a]
diagonal list = f 1 2 list []
where
	f n m [] [] = []
	f 0 m xs ys = f m (m+1) (rev ys xs) []
	f n m [] ys = f m (m+1) (rev ys []) []
	f n m [[x:r]:xs] ys = [x: f (n-1) m xs [r:ys]]
	f n m [[]:xs] ys = f (n-1) m xs ys
	
	rev []    accu = accu
	rev [x:r] accu = rev r [x:accu]

generateAll :: RandomStream -> [a] | ggen{|*|} a
generateAll rnd = ggen{|*|} 2 rnd

derive gEq Result
derive bimap [], (,), (,,), (,,,), (,,,,), (,,,,,)

//--- Random ---//

split :: RandomStream -> (RandomStream,RandomStream)
split [r,s:rnd]
	# seed = r*s
	| seed==0
		= split rnd
		= (rnd, genRandInt seed)

(>>=) infix 0 :: (a -> (b,a)) (b a -> d) -> a -> d
(>>=) f g = \st = let (r,st1) = f st in g r st1

result :: b -> a -> (b,a)
result b = \a = (b,a)

//--- testing ---//

verbose  :: RandomStream p -> [String] | Testable p
verbose rs p = testConfig rs verboseConfig p

verbosen :: !Int RandomStream p -> [String] | Testable p
verbosen n rs p = testConfig rs { verboseConfig & maxTests = n, maxArgs = 100*n } p

concise :: RandomStream p -> [String] | Testable p
concise rs p = testConfig rs countConfig p

concisen   :: !Int RandomStream p -> [String] | Testable p
concisen n rs p = testConfig rs { countConfig & maxTests = n, maxArgs = 100*n } p

quiet :: RandomStream p -> [String] | Testable p
quiet rs p = testConfig rs quietConfig p

quietn   :: !Int RandomStream p -> [String] | Testable p
quietn n rs p = testConfig rs { quietConfig & maxTests = n, maxArgs = 100*n } p

:: Config
 =	{ maxTests	:: Int
	, maxArgs	:: Int
	, every		:: Int Admin [String] -> [String]
	, errors	:: Int
	}

verboseConfig
 =	{ maxTests	= 100
	, maxArgs	= 1000
	, every		= \n r c = [blank,toString n,":":showArgs r.args c]
	, errors	= 1
	}

traceConfig
 =	{ maxTests	= 100
	, maxArgs	= 1000
	, every		= \n r c = ["\n",toString n,":":showArgs r.args c]
	, errors	= 1
	}

blank :: String
blank =: { createArray len ' ' & [0] = '\r', [len-1] = '\r' } where len = 81

countConfig
 =	{ maxTests	= 100
	, maxArgs	= 10000
	, every		= \n r c = [toString n,"\r": c]
	, errors	= 1
	}

quietConfig
 =	{ maxTests	= 100
	, maxArgs	= 10000
	, every		= \n r c = c
	, errors	= 1
	}

test :: p -> [String] | Testable p
test p = testn NrOfTest p

testn :: !Int p -> [String] | Testable p
testn n p = verbosen n aStream p

testnm :: !Int !Int p -> [String] | Testable p
testnm n m p = testConfig aStream { verboseConfig & maxTests = n, maxArgs = 100*n, errors = m } p

ttestn :: !Int p -> [String] | Testable p
ttestn n p = testConfig aStream { traceConfig & maxTests = n, maxArgs = 100*n } p

ttestnm :: !Int !Int p -> [String] | Testable p
ttestnm n m p = testConfig aStream { traceConfig & maxTests = n, maxArgs = 100*n, errors = m } p

aStream :: RandomStream
aStream = genRandInt 1957

gather :: [Admin] -> [[String]]
gather list = [r.args \\ r<- list]

testConfig :: RandomStream Config p -> [String] | Testable p
testConfig rs {maxTests,maxArgs,every,errors} p = analyse (evaluate p rs newAdmin) maxTests maxArgs 0 0 0 []
where
	analyse [] ntests nargs 0    0    0  labels = [blank,"Proof: success for all arguments": conclude ntests nargs 0 0 labels]
	analyse [] ntests nargs nrej 0    0  labels = [blank,"Proof: Success for all not rejected arguments,": conclude ntests nargs nrej 0 labels]
	analyse [] ntests nargs nrej nund 0  labels
				| ntests==maxTests			 = [blank,"Undefined: no success nor counter example found, all tests rejected or undefined ": conclude ntests nargs nrej nund labels]
											 = [blank,"Success for arguments, ": conclude ntests nargs nrej nund labels]
	analyse [] ntests nargs nrej nund ne labels = [blank,toString ne," errors found,": conclude ntests nargs nrej nund labels]
	analyse _  0      nargs nrej nund 0  labels = [blank,"Passed": conclude 0 nargs nrej nund labels]
	analyse _  0      nargs nrej nund ne labels = [blank,toString ne," errors found,": conclude 0 nargs nrej nund labels]
	analyse _  ntests 0     nrej nund 0  labels
		| ntests==maxTests				= [blank,"No tests performed, maximum number of arguments (",toString maxArgs,") generated": conclude ntests 0 nrej nund labels]
										= [blank,"Passed: maximum number of arguments (",toString maxArgs,") generated": conclude ntests 0 nrej nund labels]
	analyse _  ntests 0     nrej nund ne labels = [blank,toString ne," errors found,": conclude 0 0 nrej nund labels]
	analyse [res:rest] ntests nargs nrej nund ne labels
		= every (maxTests-ntests+1) res
		  (	case res.res of
			 OK 	= analyse rest (ntests-1) (nargs-1) nrej nund ne (admin res.labels labels)
			 Pass	= analyse rest (ntests-1) (nargs-1) nrej nund ne (admin res.labels labels) // NOT YET CORRECT ?
			 CE		= ["\n":showName res.name ["Counterexample found after ",toString (maxTests-ntests+1)," tests:":showArgs res.args ["\n":more]]]
			 		  where
			 		  	more | ne+1<errors
			 		  		= analyse rest (ntests-1) (nargs-1) nrej nund (ne+1) labels
			 		  		= [toString (ne+1)," errors found,": conclude ntests nargs nrej nund labels]
			 Rej	= analyse rest ntests (nargs-1) (nrej+1) nund     ne labels
			 Undef	= analyse rest ntests (nargs-1) nrej     (nund+1) ne labels
			 		= abort "analyse: missing case for result\n"
		  )

	conclude ntests nargs nrej nund labels
		# n    = maxTests-ntests
		  rest = showLabels n (sort labels)
		  rest = case nrej of
		  			0 = rest
		  			1 = [" one case rejected":rest]
		  			  = [" ",toString nrej," cases rejected":rest]
		  rest = case nund of
		  			0 = rest
		  			1 = [" one case undefined":rest]
		  			  = [" ",toString nund," cases undefined":rest]
		| n==0
			= rest
			= [" after ",toString n," tests":rest]

	admin :: [String] [(String,Int)] -> [(String,Int)]
	admin [] accu = accu
	admin [label:rest] accu = admin rest (insert label accu)

	insert :: String [(String,Int)] -> [(String,Int)]
	insert label [] = [(label,1)]
	insert label [this=:(old,n):rest]
	 | label==old
		= [(old,n+1):rest]
		= [this:insert label rest]

	showLabels :: Int [(String,Int)] -> [String]
	showLabels ntests [] = ["\n"]
	showLabels 0      [(lab,n):rest] = ["\n",lab,": ",toString n:showLabels 0 rest]
	showLabels ntests [(lab,n):rest] = ["\n",lab,": ",toString n," (",toString (toReal (n*100)/toReal ntests),"%)":showLabels ntests rest]

	showName l c = s (reverse l) c
	where
		s [] c = c
		s [l] c = [l," ":c]
		s [a:x] c = [a,".":s x c]

cr :== "\r"

showArgs :: [String] [String] -> [String]
showArgs []       c = c // ["\n":c] // c
showArgs [a:rest] c = [" ",a: showArgs rest c]
