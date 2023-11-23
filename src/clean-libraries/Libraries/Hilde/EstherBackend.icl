implementation module EstherBackend

import EstherParser, StdMaybe
import Debug, StdInt, StdString, StdList, StdBool, StdEnum, StdArray, StdTuple

(@) infixl 9
(@) e1 e2 :== CoreApply e1 e2

:: Overloaded d t o = (|||) infixr 0 !(d -> t) !o
:: Contexts a b = (&&&) infixr 0 !a !b
:: Context v = Class !String

overloaded :: !String !Dynamic -> Dynamic
overloaded c ((_, e) :: (v, d -> t)) = dynamic e ||| Class c :: Overloaded d t (Context v)

overloaded2 :: !String !String !Dynamic -> Dynamic
overloaded2 c1 c2 ((_, _, e) :: (v1, v2, d1 d2 -> t)) = dynamic (\(dict1 &&& dict2) -> e dict1 dict2) ||| Class c1 &&& Class c2 :: Overloaded (Contexts d1 d2) t (Contexts (Context v1) (Context v2))

overloaded3 :: !String !String !String !Dynamic -> Dynamic
overloaded3 c1 c2 c3 ((_, _, _, e) :: (v1, v2, v3, d1 d2 d3 -> t)) = dynamic (\(dict1 &&& dict2 &&& dict3) -> e dict1 dict2 dict3) ||| Class c1 &&& Class c2 &&& Class c3 :: Overloaded (Contexts d1 (Contexts d2 d3)) t (Contexts (Context v1) (Contexts (Context v2) (Context v3)))

abstract :: !String !Core -> Core
abstract v e | noVarOf v e = coreK @ e
abstract v (CoreVariable x) = coreI
//abstract v (srcf @ CoreVariable x) | noVarOf v srcf = srcf //dangerous!
/*abstract v (srcf @ CoreVariable x) | noVarOf v srcf = CoreEta srcf 
abstract v (CoreEta srcf) = CoreEta (abstract v srcf)*/
abstract v (srcf @ srcx @ srcy)
	| noVarOf v srcf
		| noVarOf v srcx = coreB` @ srcf @ srcx @ abstract v srcy
		| noVarOf v srcy = coreC` @ srcf @ abstract v srcx @ srcy
		= coreS` @ srcf @ abstract v srcx @ abstract v srcy
abstract v (srcf @ srcx)
	| noVarOf v srcf = coreB @ srcf @ abstract v srcx
	| noVarOf v srcx = coreC @ abstract v srcf @ srcx
	= coreS @ abstract v srcf @ abstract v srcx

abstract_ :: !Core -> Core
abstract_ e = coreK @ e

noVarOf :: !String !Core -> Bool
noVarOf v (f @ x) = noVarOf v f && noVarOf v x
noVarOf v (CoreVariable x) = v <> x
//noVarOf v (CoreEta f) = noVarOf v f
noVarOf _ _ = True

generateCode :: !Core !*env -> (!Dynamic, !*env) | resolveFilename env
generateCode (CoreCode d) env = (d, env)
generateCode (CoreVariable v) env = (raise (UnboundVariable v), env)
/*generateCode (CoreEta e) env
	# (codef, env) = generateCode e env
	= case codef of
		(f :: a b -> c) -> (dynamic f :: a b -> c, env)
		_ -> raise (ApplyTypeError (dynamic Omega :: A.d e f: d e -> f) codef)*/
generateCode (e1 @ e2) env 
	# (codef, env) = generateCode e1 env
	  (codex, env) = generateCode e2 env
	# d = case codex of
				(x :: A.a: a) -> case codef of
					(f :: A.b: b) -> dynamic f x :: A.c: c
					(f ||| c_f :: Overloaded d_f (d -> e) o_f) -> dynamic C f x ||| c_f :: Overloaded d_f e o_f
					(f :: f -> g) -> dynamic f x :: g
					_ -> raise (ApplyTypeError codef codex)
				(x ||| c_x :: Overloaded d_x h o_x) -> case codef of
					(f :: A.i: i) -> dynamic B f x ||| c_x :: A.j: Overloaded d_x j o_x
					(f ||| c_f :: Overloaded d_f (h -> k) o_f) -> dynamic P f x ||| c_f &&& c_x :: Overloaded (Contexts d_f d_x) k (Contexts o_f o_x)
					(f :: h -> l) -> dynamic B f x ||| c_x :: Overloaded d_x l o_x
					_ -> raise (ApplyTypeError codef codex)
				(x :: m) -> case codef of
					(f :: A.n: n) -> dynamic f x :: A.o: o
					(f ||| c_f :: Overloaded d_f (m -> p) o_f) -> dynamic C f x ||| c_f :: Overloaded d_f p o_f
					(f :: m -> q) -> dynamic f x :: q
					_ -> raise (ApplyTypeError codef codex)
	= solveOverloading d env

dynamicToDynamic :: a -> Dynamic | TC a
dynamicToDynamic _ = dynamic toDynamic :: a^ -> Dynamic
where
	toDynamic :: b -> Dynamic | TC b
	toDynamic x = dynamic x :: b^

solveOverloading :: !Dynamic !*env -> (!Dynamic, !*env) | resolveFilename env
solveOverloading d=:(_ :: A.a: a) env = (d, env)
solveOverloading d=:(_ :: Overloaded a b c) env
	# (maybe, env) = solve d env
	= case maybe of
		Just d` -> (check d`, env)
		_ -> (check d, env)
where
	solve d=:(e ||| Class c :: Overloaded d t (Context a)) env = case dynamic Omega :: a of
		(_ :: A.b: b) -> (Nothing, env)
		type
			# (maybe, env) = resolveInstance` c type env
			  (dyndict, env) = case maybe of
					Just dyndict -> (dyndict, env)
					_ 
						# (maybe, env) = resolveInstance` c (dynamic Omega :: A.c: c) env
						-> case maybe of
							Just dyndict -> (dyndict, env)
							_ -> (raise (InstanceNotFound c type), env)
			-> case dyndict of 
				(dict :: d) -> (Just (dynamic e dict :: t), env)
				(dict_e ||| dict_r :: Overloaded dict_d d dict_o) 
					# (d`, env) = solveOverloading (dynamic B e dict_e ||| dict_r :: Overloaded dict_d t dict_o) env
					-> (Just d`, env)
				_ -> (raise (InvalidInstance c type dyndict), env)
	where
		resolveInstance` "TC" (type :: a) env = (Just (dynamicToDynamic type), env)
		resolveInstance` n t env = case resolveFilename ("instance " +++ n +++ " " +++ snd (toStringDynamic t)) env of
			(Just (inst, _), env) -> (Just inst, env)
			(_, env) -> case resolveFilename ("instance " +++ n +++ " " +++ (outermostType t)) env of
				(Just (inst, _), env) -> (Just inst, env)
				(_, env) -> (Nothing, env)
		where
/*			outermostType :: !Dynamic -> String
			outermostType d = toString (snd (f (typeCodeOfDynamic d)))
			where
				f (TypeScheme _ type) = f type
				f (TypeUnique type) = f type
				f type=:(TypeCons cons) = (0, type)
				f (TypeApp t1 t2)
					# (n, t1) = f t1
					= (n + 1, TypeApp t1 (TypeVar n))
				f type = (0, type)*/
				
			outermostType :: !Dynamic -> String
			outermostType d = snd (toStringDynamic (f d))
			where
				f d=:(_ :: A.tc: tc) = d
				f d=:(_ :: A.tc: tc a) = d
				f d=:(_ :: A.tc: tc a b) = d
				f d=:(_ :: A.tc: tc a b c) = d
				f d=:(_ :: A.tc: tc a b c d) = d
				f d=:(_ :: A.tc: tc a b c d e) = d
				f d=:(_ :: A.tc: tc a b c d e f) = d
				f d=:(_ :: A.tc: tc a b c d e f g) = d
				f d=:(_ :: A.tc: tc a b c d e f g h) = d
				f (_ :: tc a b c d e f g h i) = raise (NotSupported` "instances for type constructors with more than eight type arguments")
				f (_ :: tc a b c d e f g h) = dynamic Omega :: A.a1 b1 c1 d1 e1 f1 g1 h1: tc a1 b1 c1 d1 e1 f1 g1 h1
				f (_ :: tc a b c d e f g) = dynamic Omega :: A.a1 b1 c1 d1 e1 f1 g1: tc a1 b1 c1 d1 e1 f1 g1
				f (_ :: tc a b c d e f) = dynamic Omega :: A.a1 b1 c1 d1 e1 f1: tc a1 b1 c1 d1 e1 f1
				f (_ :: tc a b c d e) = dynamic Omega :: A.a1 b1 c1 d1 e1: tc a1 b1 c1 d1 e1
				f (_ :: tc a b c d) = dynamic Omega :: A.a1 b1 c1 d1: tc a1 b1 c1 d1
				f (_ :: tc a b c) = dynamic Omega :: A.a1 b1 c1: tc a1 b1 c1
				f (_ :: tc a b) = dynamic Omega :: A.a1 b1: tc a1 b1
				f (_ :: tc a) = dynamic Omega :: A.a1: tc a1
				f d=:(_ :: tc) = d

/*		countTypeVar :: !Dynamic -> Int
		countTypeVar d = f (typeCodeOfDynamic d)
		where
			f :: !TypeCode -> Int
			f (TypeScheme n (TypeApp (TypeApp _ (TypeVar v)) t)) = g t
			where
				g :: !TypeCode -> Int
				g (TypeApp t1 t2) = g t1 + g t2
				g (TypeUnique t) = g t
				g (TypeVar i) 
					| i == v = 1
					= 0
				g _ = 0
			f _ = 0*/

	solve d=:(e ||| r1 &&& r2 :: Overloaded (Contexts d1 d2) t (Contexts c1 c2)) env 
		# (maybe1, env) = solve (dynamic I ||| r1 :: Overloaded d1 d1 c1) env
		  (maybe2, env) = solve (dynamic I ||| r2 :: Overloaded d2 d2 c2) env
		= case (maybe1, maybe2) of
			(Just (dict1 :: d1), Just (dict2 :: d2)) -> (Just (dynamic e (dict1 &&& dict2) :: t), env)
			(Just (dict1 :: d1), _) -> (Just (dynamic L e dict1 ||| r2 :: Overloaded d2 t c2), env)
			(_, Just (dict2 :: d2)) -> (Just (dynamic R e dict2 ||| r1 :: Overloaded d1 t c1), env)
			_ -> (Nothing, env)

	check d=:(_ :: A.a: a) = d
	check d=:(_ :: Overloaded d t o)
		# typeVars = countTypeVars (dynamic Omega :: o -> t) 
		  overloadedVars = countTypeVars (dynamic Omega :: o)
		| occur overloadedVars typeVars = d
		= raise UnsolvableOverloading
	where
		occur [x:xs] [y:ys] = y > x && occur xs ys
		occur [] _ = True
	
		countTypeVars :: !Dynamic -> [Int]
		countTypeVars d = [x \\ x <-: f (typeCodeOfDynamic d)]
		where
			f :: !TypeCode -> *{#Int}
			f (TypeScheme n type) = g type (createArray n 0)
			where
				g :: !TypeCode !*{#Int} -> *{#Int}
				g (TypeApp t1 t2) a = g t1 (g t2 a)
				g (TypeUnique t) a = g t a
				g (TypeVar i) a=:{[i]=n} = {a & [i] = n + 1}
				g _ a = a
			f _ = {}
	check d = d
solveOverloading d env = (d, env)

Omega = raise "Omega internal error"

coreI = CoreCode (dynamic I :: A.a: a -> a)
coreK = CoreCode (dynamic K :: A.a b: a b -> a)
coreS = CoreCode (dynamic S :: A.a b c: (a b -> c) (a -> b) a -> c)
coreB = CoreCode (dynamic B :: A.a b c: (a -> b) (c -> a) c -> b)
coreC = CoreCode (dynamic C :: A.a b c: (a b -> c) b a -> c)
coreS` = CoreCode (dynamic S` :: A.a b c d: (a b -> c) (d -> a) (d -> b) d -> c)
coreB` = CoreCode (dynamic B` :: A.a b c d: (a b -> c) a (d -> b) d -> c)
coreC` = CoreCode (dynamic C` :: A.a b c d: (a b -> c) (d -> a) b d -> c)

I x = x
K x y = x
S f g x = f x (g x)
B f g x = f (g x)
C f g x = f x g
S` f g h x = f (g x) (h x)
B` f g h x = f g (h x)
C` f g h x = f (g x) h

P f g (x &&& y) = f x (g y)
L f x y = f (x &&& y)
R f y x = f (x &&& y)

toStringDynamic :: !Dynamic -> ([String], String)
toStringDynamic d=:(_ :: A.a: a) = prettyDynamic d
toStringDynamic (e ||| c :: Overloaded d t o) = (value, type +++ " | " +++ contexts)
where
	(value, _) = prettyDynamic (dynamic e :: d -> t)
	(_, type) = prettyDynamic (dynamic Omega :: t)
	contexts = prettyContexts [(n, v) \\ n <- listNames d & v <- listVariables (typeCodeOfDynamic d)]
	where
		d = dynamic c :: o
		
		prettyContexts [(n, v)] = n +++ " " +++ v
		prettyContexts [c:cs] = prettyContexts [c] +++ " & " +++ prettyContexts cs
	
		listNames (Class name :: Context a) = [name]
		listNames (x &&& y :: Contexts a b) = listNames (dynamic x :: a) ++ listNames (dynamic y :: b)
		
		listVariables (TypeApp _ (TypeVar i)) = [if (i < 26) {'a' + toChar i} ("tv" +++ toString i)]
		listVariables (TypeApp _ (TypeCons c)) = [toString c]
		listVariables (TypeScheme _ t) = listVariables t
		listVariables (TypeApp t1 t2) = listVariables t1 ++ listVariables t2
		listVariables (TypeUnique t) = listVariables t
		listVariables _ = []
toStringDynamic d = prettyDynamic d

prettyDynamic :: !Dynamic -> ([String], String)
prettyDynamic d = (v, t)
where
//	v = case d of (x :: a) -> debugShowWithOptions [DebugTerminator "", DebugMaxChars (80 * 22)] x
	v = case d of (x :: a) -> debugShowWithOptions [DebugTerminator "", DebugMaxChars 79] x

	t = removeForAll (typeCodeOfDynamic d)
	where
		removeForAll (TypeScheme _ t) = toString t
		removeForAll t = toString t

instance toString Core where
	toString (CoreApply f x) = toString f +++ " (" +++ toString x +++ ")"
	toString (CoreVariable x) = x
	toString (CoreCode x) = foldr (+++) "" xs
	where
		(xs, t) = toStringDynamic x
