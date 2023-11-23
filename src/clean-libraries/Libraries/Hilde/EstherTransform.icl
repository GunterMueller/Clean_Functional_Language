implementation module EstherTransform

import EstherBackend
import CleanTricks, StdList, StdString, StdBool, StdMisc, StdFunc
import EstherPostParser, DynamicFileSystem, EstherScript

(@) infixl 9
(@) e1 e2 :== CoreApply e1 e2

LAMBDA ps e :== Term (Plain (Lambda (Scope (NTlambda Tlambda (+- ps) Tarrow e))))
LET ds e :== Term (Plain (Let (Scope (NTlet Tlet (+- ds) Tin e))))
(LETDEF) infix 0
(LETDEF) d e :== NTletDef d Tis e
NAME n p :== Term (Plain (NameOrValue (NTname n p)))
VAR v p :== VariablePattern (NTvariable v p)

generic transform e :: !e -> Core

transform{|EITHER|} gl gr (LEFT l) = gl l
transform{|EITHER|} gl gr (RIGHT r) = gr r

transform{|CONS|} gx (CONS x) = gx x

transform{|FIELD|} gx (FIELD x) = gx x

transform{|OBJECT|} gx (OBJECT x) = gx x

transform{|Core|} srce = srce

transform{|NTstatements|} (Compound s1 _ s2) = bind @ transform{|*|} s1 @ transform{|*|} s2
where
	bind = CoreCode (dynamic >> :: A.a b env: (*env -> *(a, *env)) (*env -> *b) *env -> *b)
	where
		>> f g env 
			# (_, env) = f env
			= g env
transform{|NTstatements|} (Pipe s1 _ s2) = bind @ transform{|*|} s1 @ transform{|*|} s2
where
	bind = CoreCode (dynamic >>= :: A.a b env: (*env -> *(a, *env)) (a *env -> *b) *env -> *b)
	where
		>>= f g env 
			# (x, env) = f env
			= g x env
transform{|NTstatements|} (Statement s) = transform{|*|} s

transform{|NTstatement|} (Expression e) = transform{|*|} e
transform{|NTstatement|} (Write e _ (NTnameDef n p)) = CoreCode (dynamic write :: Dynamic *World -> *(Bool, *World)) @ transform{|*|} (NTdynamic Tdynamic e)
where
	write d env 
		# (ok, dyn, env) = dynamicRead ENV_CWD env
		  cwd = if ok (case dyn of (p :: DynamicPath) -> p; _ -> []) []
		= dynamicWrite (cwd ++ [f p]) d env

//	writeFile n p d env
//		# (maybe, world) = resolveFilename n env

	f (GenConsPrio GenConsAssocRight i) = "(" +++ n +++ ") infixr " +++ toString i
	f (GenConsPrio GenConsAssocLeft i) = "(" +++ n +++ ") infixl " +++ toString i
	f (GenConsPrio GenConsAssocNone i) = "(" +++ n +++ ") infix " +++ toString i
	f _ = n
transform{|NTstatement|} (Function f) = transform{|*|} f

transform {|NTfunction|} (NTfunction n=:(NTnameDef v p) vs _ e) = transform{|*|} (Write f Twrite n)
where
	f = LET [VAR v p LETDEF (case vs of [] -> e; vs -> LAMBDA vs e)] (NAME v p)

transform{|NTexpression|} (Term e) = transform{|*|} e
transform{|NTexpression|} (Apply f x) = transform{|*|} f @ transform{|*|} x
transform{|NTterm|} (Plain e) = transform{|*|} e
transform{|NTterm|} (Sugar e) = transform{|*|} (desugar e)

transform{|NTdynamic|} (NTdynamic _ e) = coreDynamic @ transform{|*|} e

transform{|NTnameOrValue|} (NTvalue d _) = CoreCode d
transform{|NTnameOrValue|} (NTname y _) = CoreVariable y

transform{|NTlambda|} (NTlambda _ (+- ps) _ e) = transformMatch ps (transform{|*|} e) codeMismatch

transform{|NTlet|} (NTlet _ (+- ds) _ e) = transformLet Nothing (p, d`, e)
where
	(p, d) = combine ds
	d` = codeY @ transform{|*|} (LAMBDA [p] d)

	combine [NTletDef p _ d] = (p, d)
	combine [d:ds] = (TuplePattern Topen p1` Tcomma (+- [p2]) Tclose, Term (Sugar (Tuple Topen d1` Tcomma (+- [d2]) Tclose)))
	where
		(p1`, d1`) = combine [d]
		(p2, d2) = combine ds

	transformLet Nothing (p, srcd, srce) = transform{|*|} (LAMBDA [p] srce) @ transform{|*|} srcd

transform{|NTcase|} (NTcase _ e` _ (+- as`)) = transformAlts as` @ m
where
	m = transform{|*|} e`

	transformAlts [Scope (NTcaseAlt (+- ps) _ e):as] = transformMatch [NestedPattern Topen (+- ps) Tclose] (transform{|*|} e) (transformAlts as @ m)
	transformAlts [] = codeMismatch

transform{|(|-|)|} _ ge _ (|-| e) = ge e

transform{|c|} _ = raise "default transform{|*|}: internal error"

derive transform NTplain, Scope

transformMatch :: ![NTpattern] !e !e -> Core | transform{|*|} e
transformMatch [] th _ = transform{|*|} th
transformMatch ps th el = transformMatch (init ps) (patternMatch 1 (last ps) (transform{|*|} th) el`) (abstract_ el`)
where
	el` = transform{|*|} el
	
	patternMatch _ (TuplePattern _ t _ (+- ts) _) then else	= codeApply (dynamicTuple (length [t:ts])) @ transformMatch [t:ts] then else
	patternMatch n (ConsPattern t1 hd Nothing t2) then else = patternMatch n (ConsPattern t1 hd (Just (Tcolon, NilPattern TopenBracket TcloseBracket)) t2) then else
	patternMatch _ (ConsPattern _ hd (Just (_, tl)) _) then else = patternMatch 3 (NameOrValuePattern (NTvalue dynamicCons GenConsNoPrio)) (transformMatch [hd, tl] then else) else
	patternMatch _ (NilPattern _ _) then else = patternMatch 1 (NameOrValuePattern (NTvalue dynamicNil GenConsNoPrio)) then else
	patternMatch _ (NestedPattern _ (+- [t:ts]) _) then else = patternMatch (length ts + 1) t (transformMatch ts then else) else
	patternMatch n (NameOrValuePattern (NTvalue constr _)) then else = match constr n @ (codeApply constr @ then) @ else
	patternMatch _ (VariablePattern (NTvariable x _)) then _ = abstract x then
	patternMatch _ (AnyPattern _) then _ = abstract_ then

	match :: !Dynamic !Int -> Core
	match (x :: Real) 1 = ifEqual x
	match (x :: Int) 1 = ifEqual x
	match (x :: Char) 1 = ifEqual x
	match (x :: String) 1 = ifEqual x
	match (x :: Bool) 1 = ifEqual x
	match constr n = case constructorNode constr of
		(arity, x :: a) -> if (n <> arity) (ifMatch x) (raise CaseBadConstructorArity)
	where
		ifMatch :: !a -> Core | TC a
		ifMatch x = CoreCode (dynamic IfConstr :: A.b: (a^ -> b) b a^ -> b)
		where
			IfConstr th el y = if (matchConstructor x y) (th y) el
	
		constructorNode :: !Dynamic -> (!Int, !Dynamic)
		constructorNode (f :: a -> b) = (n + 1, d)
		where
			(n, d) = constructorNode (dynamic f (unsafeTypeCast []) :: b)
		constructorNode d = (0, d)
		
	ifEqual :: !a -> Core | TC a & == a
	ifEqual x = CoreCode (dynamic IfEq :: A.b: (a^ -> b) b a^ -> b)
	where
		IfEq th el y = if (x == y) (th y) el
	
	codeApply :: !Dynamic -> Core
	codeApply (_ :: a b c d e f g h i -> j) = raise (NotSupported "constructors with arity above eight")
	codeApply (_ :: a b c d e f g h -> i) = CoreCode (dynamic \f n -> f (unsafeSelect1of8 n) (unsafeSelect2of8 n) (unsafeSelect3of8 n) (unsafeSelect4of8 n) (unsafeSelect5of8 n) (unsafeSelect6of8 n) (unsafeSelect7of8 n) (unsafeSelect8of8 n) :: A.j: (a b c d e f g h -> j) i -> j)
	codeApply (_ :: a b c d e f g -> h) = CoreCode (dynamic \f n -> f (unsafeSelect1of7 n) (unsafeSelect2of7 n) (unsafeSelect3of7 n) (unsafeSelect4of7 n) (unsafeSelect5of7 n) (unsafeSelect6of7 n) (unsafeSelect7of7 n) :: A.i: (a b c d e f g -> i) h -> i)
	codeApply (_ :: a b c d e f -> g) = CoreCode (dynamic \f n -> f (unsafeSelect1of6 n) (unsafeSelect2of6 n) (unsafeSelect3of6 n) (unsafeSelect4of6 n) (unsafeSelect5of6 n) (unsafeSelect6of6 n) :: A.h: (a b c d e f -> h) g -> h)
	codeApply (_ :: a b c d e -> f) = CoreCode (dynamic \f n -> f (unsafeSelect1of5 n) (unsafeSelect2of5 n) (unsafeSelect3of5 n) (unsafeSelect4of5 n) (unsafeSelect5of5 n) :: A.g: (a b c d e -> g) f -> g)
	codeApply (_ :: a b c d -> e) = CoreCode (dynamic \f n -> f (unsafeSelect1of4 n) (unsafeSelect2of4 n) (unsafeSelect3of4 n) (unsafeSelect4of4 n) :: A.f: (a b c d -> f) e -> f)
	codeApply (_ :: a b c -> d) = CoreCode (dynamic \f n -> f (unsafeSelect1of3 n) (unsafeSelect2of3 n) (unsafeSelect3of3 n) :: A.e: (a b c -> e) d -> e)
	codeApply (_ :: a b -> c) = CoreCode (dynamic \f n -> f (unsafeSelect1of2 n) (unsafeSelect2of2 n) :: A.d: (a b -> d) c -> d)
	codeApply (_ :: a -> b) = CoreCode (dynamic \f n -> f (unsafeSelect1of1 n) :: A.c: (a -> c) b -> c)
	codeApply (_ :: a) = CoreCode (dynamic \f n -> f :: A.b: b a -> b)
	
dynamicTuple :: !Int -> Dynamic
dynamicTuple 2 = dynamicTuple2
dynamicTuple 3 = dynamicTuple3
dynamicTuple 4 = dynamicTuple4
dynamicTuple 5 = dynamicTuple5
dynamicTuple 6 = dynamicTuple6
dynamicTuple 7 = dynamicTuple7
dynamicTuple 8 = dynamicTuple8
dynamicTuple 9 = dynamicTuple9
dynamicTuple 10 = dynamicTuple10
dynamicTuple 11 = dynamicTuple11
dynamicTuple 12 = dynamicTuple12
dynamicTuple n = raise (NotSupported "tuples with arity less than one of more than twelve")

dynamicTuple2 = dynamic \a b -> (a, b) :: A.a b: a b -> (a, b)
dynamicTuple3 = dynamic \a b c -> (a, b, c) :: A.a b c: a b c -> (a, b, c)
dynamicTuple4 = dynamic \a b c d -> (a, b, c, d) :: A.a b c d: a b c d -> (a, b, c, d)
dynamicTuple5 = dynamic \a b c d e -> (a, b, c, d, e) :: A.a b c d e: a b c d e -> (a, b, c, d, e)
dynamicTuple6 = dynamic \a b c d e f -> (a, b, c, d, e, f) :: A.a b c d e f: a b c d e f -> (a, b, c, d, e, f)
dynamicTuple7 = dynamic \a b c d e f g -> (a, b, c, d, e, f, g) :: A.a b c d e f g: a b c d e f g -> (a, b, c, d, e, f, g)
dynamicTuple8 = dynamic \a b c d e f g h -> (a, b, c, d, e, f, g, h) :: A.a b c d e f g h: a b c d e f g h -> (a, b, c, d, e, f, g, h)
dynamicTuple9 = dynamic \a b c d e f g h i -> (a, b, c, d, e, f, g, h, i) :: A.a b c d e f g h i: a b c d e f g h i -> (a, b, c, d, e, f, g, h, i)
dynamicTuple10 = dynamic \a b c d e f g h i j -> (a, b, c, d, e, f, g, h, i, j) :: A.a b c d e f g h i j: a b c d e f g h i j -> (a, b, c, d, e, f, g, h, i, j)
dynamicTuple11 = dynamic \a b c d e f g h i j k -> (a, b, c, d, e, f, g, h, i, j, k) :: A.a b c d e f g h i j k: a b c d e f g h i j k -> (a, b, c, d, e, f, g, h, i, j, k)
dynamicTuple12 = dynamic \a b c d e f g h i j k l -> (a, b, c, d, e, f, g, h, i, j, k, l) :: A.a b c d e f g h i j k l: a b c d e f g h i j k l -> (a, b, c, d, e, f, g, h, i, j, k, l)

dynamicCons :: Dynamic
dynamicCons = dynamic \x xs -> [x:xs] :: A.a: a [a] -> [a]

dynamicNil :: Dynamic
dynamicNil = dynamic [] :: A.a: [a]

codeMismatch :: Core
codeMismatch = CoreCode (dynamic mismatch :: A.a: a) 
where 
	mismatch = raise PatternMismatch

codeY :: Core
codeY = CoreCode (dynamic Y :: A.a: (a -> a) -> a) 
where 
	Y f = let x = f x in x 

coreDynamic :: Core
coreDynamic = CoreCode (overloaded "TC" (dynamic (undef, id) :: A.a: (a, (a -> Dynamic) -> (a -> Dynamic))))

