implementation module EstherPostParser

import EstherParser
import StdMisc, StdList, StdString, EstherTransform

(@) infixl 9
(@) e1 e2 :== Apply e1 e2
VALUE d p :== Plain (NameOrValue (NTvalue d p))
NAME n p :== Plain (NameOrValue (NTname n p))

generic resolveNames e :: !e ![(String, GenConsPrio)] !*env -> (!e, ![(String, GenConsPrio)], !*env) | resolveFilename env

resolveNames{|c|} e vs st = (e, vs, st)

resolveNames{|PAIR|} gl gr (PAIR l r) vs st = (PAIR l` r`, vs``, st``)
where
	  (l`, vs`, st`) = gl l vs st
	  (r`, vs``, st``) = gr r vs` st`

resolveNames{|EITHER|} gl gr (LEFT l) vs st = (LEFT l`, vs`, st`)
where
	(l`, vs`, st`) = gl l vs st
resolveNames{|EITHER|} gl gr (RIGHT r) vs st = (RIGHT r`, vs`, st`)
where
	(r`, vs`, st`) = gr r vs st

resolveNames{|CONS|} gx (CONS x) vs st = (CONS x`, vs`, st`)
where
	(x`, vs`, st`) = gx x vs st

resolveNames{|FIELD|} gx (FIELD x) vs st = (FIELD x`, vs`, st`)
where
	(x`, vs`, st`) = gx x vs st

resolveNames{|OBJECT|} gx (OBJECT x) vs st = (OBJECT x`, vs`, st`)
where
	(x`, vs`, st`) = gx x vs st
/*
resolveNames{|Src|} ge src=:{node} vs st = ({src & node = node`}, vs`, st`)
where
	(node`, vs`, st`) = ge node vs st
*/
resolveNames{|NTlet|} (NTlet t1 (+- p_ds) t2 e) vs st = (NTlet t1 p_ds` t2 e`, vs`, st```)
where
	ps = [p \\ NTletDef p _ _ <- p_ds]
	(_, vs`, st`) = resolveNames{|*|} ps vs st
	(p_ds`, _, st``) = resolveNames{|*|} (+- p_ds) vs` st`
	(e`, _, st```) = resolveNames{|*|} e vs` st``

resolveNames{|NTvariable|} e=:(NTvariable n p) vs st = (e, [(n, p):vs], st)

resolveNames{|NTnameDef|} e=:(NTnameDef n p) vs st = (e, [(n, p):vs], st)

resolveNames{|NTnameOrValue|} (NTvalue (x :: a) prio) vs st 
	#!x = x
	= (NTvalue (dynamic x :: a) prio, vs, st)
resolveNames{|NTnameOrValue|} (NTname n _) vs st 
	= case member n vs of
		Just p -> (NTname n p, vs, st)
		_ -> case resolveFilename n st of
			(Just (dyn, prio), st) -> (NTvalue dyn prio, vs, st)
			(_, st) -> (raise (NameNotFound n), vs, st)
where
	member n [] = Nothing
	member n [(x, p):xs]
		| x == n = Just p
		= member n xs

resolveNames{|Scope|} ge (Scope e) vs st = (Scope e`, vs, st`)
where
	(e`, _, st`) = ge e vs st

resolveNames{|NTterm|} (Sugar e) vs st = (Plain (Nested (|-| e`)), vs`, st`)
where
	(e`, vs`, st`) = resolveNames{|*|} (desugar e) vs st
resolveNames{|NTterm|} (Plain e) vs st = (Plain e`, vs`, st`)
where
	(e`, vs`, st`) = resolveNames{|*|} e vs st

derive resolveNames NTstatements, NTstatement, NTfunction, NTexpression, NTsugar, NTplain, NTlist, NTlambda, NTpattern, NTletDef, NTcase, NTcaseAlt, NTlistComprehension, NTdynamic
derive resolveNames +-, |-|, [], Maybe, (,)

desugar :: !NTsugar -> NTexpression
desugar (Tuple _ e _ (+- es) _) = foldl (\f x -> f @ Plain (Nested (|-| x))) (Term (VALUE (dynamicTuple (length es`)) GenConsNoPrio)) es`
where
	es` = [e:es]
desugar (List (|-| e)) = desugarList e
where
	desugarList (Cons hds Nothing) = desugarList (Cons hds (Just (Tcolon, Term (Sugar (List (|-| Nil))))))
	desugarList (Cons (+- [hd:hds]) (Just tl)) = Term (VALUE dynamicCons GenConsNoPrio) @ Plain (Nested (|-| hd)) @ Plain (Nested (|-| (Term (Sugar (List (|-| (Cons (+- hds) (Just tl))))))))
	desugarList (Cons (+- []) (Just (_, tl))) = tl
	desugarList Nil = Term (VALUE dynamicNil GenConsNoPrio)
	desugarList (ListComprehension c) = desugarListComprehension c
	
	desugarListComprehension (DotDot f t _ e) = desugarDotDot f t e
	desugarListComprehension (ZF e _ qs) = raise (NotSupported "ZF expressions")

	desugarDotDot f Nothing Nothing = Term (VALUE dynamicFrom GenConsNoPrio) @ Plain (Nested (|-| f))
	desugarDotDot f Nothing (Just e) = Term (VALUE dynamicFromTo GenConsNoPrio) @ Plain (Nested (|-| f)) @ Plain (Nested (|-| e))
	desugarDotDot f (Just (_, t)) Nothing = Term (VALUE dynamicFromThen GenConsNoPrio) @ Plain (Nested (|-| f)) @ Plain (Nested (|-| t))
	desugarDotDot f (Just (_, t)) (Just e) = Term (VALUE dynamicFromThenTo GenConsNoPrio) @ Plain (Nested (|-| f)) @ Plain (Nested (|-| t)) @ Plain (Nested (|-| e))

generic fixInfix e :: !e -> e

fixInfix{|c|} e = e

fixInfix{|PAIR|} gl gr (PAIR l r) = PAIR (gl l) (gr r)

fixInfix{|EITHER|} gl gr (LEFT l) = LEFT (gl l)
fixInfix{|EITHER|} gl gr (RIGHT r) = RIGHT (gr r)

fixInfix{|CONS|} gx (CONS x) = CONS (gx x)

fixInfix{|FIELD|} gx (FIELD x) = FIELD (gx x)

fixInfix{|OBJECT|} gx (OBJECT x) = OBJECT (gx x)

//fixInfix{|Src|} gx src=:{node} = {src & node = gx node}

fixInfix{|NTexpression|} e = fix e []
where
	fix (Term e) es = foldl (@) (Term (fixInfix{|*|} e)) es
	fix (_ @ VALUE _ (GenConsPrio _ _)) [] = raise InfixRightArgumentMissing
	fix (_ @ NAME _ (GenConsPrio _ _)) [] = raise InfixRightArgumentMissing
	fix (l @ r) es
		# r = fixInfix{|*|} r
		= case l of
			(ll @ lr=:(VALUE _ (GenConsPrio rightAssoc rightPrio)))
				# ll = fixInfix{|*|} ll
				  leftish = Term (fixInfix{|*|} lr) @ Plain (Nested (|-| ll)) @ Plain (Nested (|-| (foldl (@) (Term r) es)))
				-> case ll of
					llll=:(Term (VALUE _ (GenConsPrio leftAssoc leftPrio))) @ lllr @ llr
						# rightish = llll @ lllr @ (Plain (Nested (|-| (Term (fixInfix{|*|} lr) @ llr @ r))))
						| rightPrio < leftPrio -> leftish
						| leftPrio < rightPrio -> rightish
						-> case (rightAssoc, leftAssoc) of
							(GenConsAssocLeft, GenConsAssocLeft) -> leftish
							(GenConsAssocRight, GenConsAssocRight) -> rightish
							-> raise UnsolvableInfixOrder
					llll=:(Term (NAME _ (GenConsPrio leftAssoc leftPrio))) @ lllr @ llr
						# rightish = llll @ lllr @ (Plain (Nested (|-| (Term (fixInfix{|*|} lr) @ llr @ r))))
						| rightPrio < leftPrio -> leftish
						| leftPrio < rightPrio -> rightish
						-> case (rightAssoc, leftAssoc) of
							(GenConsAssocLeft, GenConsAssocLeft) -> leftish
							(GenConsAssocRight, GenConsAssocRight) -> rightish
							-> raise UnsolvableInfixOrder
					_ -> leftish
			(ll @ lr=:(NAME _ (GenConsPrio rightAssoc rightPrio)))
				# ll = fixInfix{|*|} ll
				  leftish = Term (fixInfix{|*|} lr) @ Plain (Nested (|-| ll)) @ Plain (Nested (|-| (foldl (@) (Term r) es)))
				-> case ll of
					llll=:(Term (VALUE _ (GenConsPrio leftAssoc leftPrio))) @ lllr @ llr
						# rightish = llll @ lllr @ (Plain (Nested (|-| (Term (fixInfix{|*|} lr) @ llr @ r))))
						| rightPrio < leftPrio -> leftish
						| leftPrio < rightPrio -> rightish
						-> case (rightAssoc, leftAssoc) of
							(GenConsAssocLeft, GenConsAssocLeft) -> leftish
							(GenConsAssocRight, GenConsAssocRight) -> rightish
							-> raise UnsolvableInfixOrder
					llll=:(Term (NAME _ (GenConsPrio leftAssoc leftPrio))) @ lllr @ llr
						# rightish = llll @ lllr @ (Plain (Nested (|-| (Term (fixInfix{|*|} lr) @ llr @ r))))
						| rightPrio < leftPrio -> leftish
						| leftPrio < rightPrio -> rightish
						-> case (rightAssoc, leftAssoc) of
							(GenConsAssocLeft, GenConsAssocLeft) -> leftish
							(GenConsAssocRight, GenConsAssocRight) -> rightish
							-> raise UnsolvableInfixOrder
					_ -> leftish
			(Term (VALUE _ (GenConsPrio _ _))) -> raise InfixLeftArgumentMissing
			(Term (NAME _ (GenConsPrio _ _))) -> raise InfixLeftArgumentMissing
			_ -> fix l [r:es]

derive fixInfix NTstatements, NTstatement, NTfunction, NTterm, NTsugar, NTlist, NTlistComprehension, NTlambda, NTpattern, NTlet, NTletDef, NTcase, NTcaseAlt, NTplain, NTdynamic
derive fixInfix +-, |-|, [], Maybe, (,), Scope

derive bimap (,), (,,)

dynamicFrom = overloaded2 "+" "one" (dynamic (undef, undef, From) :: A.a: (a, a, (a a -> a) a a -> [a]))
where
	From add one n = frm n
	where
		frm n = [n : frm (add n one)]

dynamicFromTo = overloaded3 "<" "+" "one" (dynamic (undef, undef, undef, FromTo) :: A.a: (a, a, a, (a a -> Bool) (a a -> a) a a a -> [a]))
where
	FromTo less add one n e = from_to n e
	where
		from_to n e
			| not (less e n) = [n : from_to (add n one) e]
			= []

dynamicFromThen = overloaded2 "-" "+" (dynamic (undef, undef, From_then) :: A.a: (a, a, (a a -> a) (a a -> a) a a -> [a]))
where
	From_then sub add n1 n2 = [n1 : from_by n2 (sub n2 n1)]
	where
		from_by n s	= [n : from_by (add n s) s]

dynamicFromThenTo = overloaded3 "<" "-" "+" (dynamic (undef, undef, undef, From_then_to) :: A.a: (a, a, a, (a a -> Bool) (a a -> a) (a a -> a) a a a -> [a]))
where
	From_then_to less sub add n1 n2 e
		| not (less n2 n1) = from_by_to n1 (sub n2 n1) e
		= from_by_down_to n1 (sub n2 n1) e
	where
		from_by_to n s e
			| not (less e n) = [n : from_by_to (add n s) s e]
			= []
		from_by_down_to n s e
			| not (less n e) = [n : from_by_down_to (add n s) s e]
			= []
