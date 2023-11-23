implementation module DrupDefault

import StdGeneric, StdMaybe
import StdInt, StdClass, StdList, StdBool, StdTuple, StdString, StdArray

:: DefaultHistory = History !Int !String !String !DefaultHistory | NoHistory
:: DefaultPath = Pair !DefaultPath !DefaultPath | Edge !String !String

SIZE_CHAR :== 1
SIZE_INT :== IF_INT_64_OR_32 8 4
SIZE_REAL :== 8

maybeDefault :: Maybe .a | default{|*|} a
maybeDefault = fst (default{|*|} (Edge "" "") NoHistory)

generic default a :: !DefaultPath !DefaultHistory -> (!Maybe .a, !Int)

default{|OBJECT of {gtd_arity}|} default_a path=:(Edge con typ) history
	# (a, sa) = default_a path history
	| recursion = (Nothing, SIZE_INT)
	= (mapMaybe OBJECT a, if pointer SIZE_INT sa)
where
	n = lookup history
	recursion = n > gtd_arity
	pointer = n > 0

	lookup (History n c t hs)
		| c == con && t == typ = n
		| otherwise = lookup hs
	lookup _ = 0

default{|OBJECT|} default_a path history 
	# (a, s) = default_a path history
	= (mapMaybe OBJECT a, s)

default{|EITHER|} default_a default_b path history
	# (a, sa) = default_a path history
	  (b, sb) = default_b path history
	= (either sa sb a b, max sa sb)
where
	either sa sb a b
		| sa <= sb = case a of Just x -> Just (LEFT x); _ -> mapMaybe RIGHT b
		= case b of Just y -> Just (RIGHT y); _ -> mapMaybe LEFT a

default{|CONS of {gcd_name, gcd_arity, gcd_type, gcd_index, gcd_type_def={gtd_name, gtd_arity, gtd_num_conses}}|} default_a path history
	# (a, sa) = default_a path` history`
	= (mapMaybe CONS a, if single sa (sa + if many SIZE_INT SIZE_CHAR))
where
	single = gtd_num_conses < 2
	many = gtd_num_conses > 255

	(path`, _) = makePairs gcd_arity gcd_type
	where
		makePairs :: !Int !GenType -> (!DefaultPath, !GenType)
		makePairs 0 t = (Edge gcd_name gtd_name, t)
		makePairs 1 (GenTypeArrow x y) = (Edge gcd_name (if isvar gtd_name typecons), y)
		where
			(isvar, typecons) = typeCons x False

		makePairs n fs 
			# (a, fs) = makePairs (n >> 1) fs
			  (b, fs) = makePairs ((n + 1) >> 1) fs
			= (Pair a b, fs)
	
	history` = foldl increment history (typeConses gcd_type [])
	where
		typeConses :: !GenType ![(String, String)] -> [(String, String)]
		typeConses (GenTypeArrow arg res) acc = typeConses res (if isvar acc [(gcd_name, tc):acc])
		where
			(isvar, tc) = typeCons arg True
		typeConses _ acc = acc

		increment (History n c t hs) (con, typ)
			| c == con && t == typ = History (n + 1) c t hs
			| otherwise = History n c t (increment hs (con, typ))
		increment _ (con, typ) = History 1 con typ NoHistory

	typeCons :: !GenType !Bool -> (!Bool, !String)
	typeCons (GenTypeApp x y) _ = typeCons x True
	typeCons (GenTypeCons x) _ = (False, x)
	typeCons (GenTypeVar x) isvar = (isvar, "")
	typeCons (GenTypeArrow x y) _ = (False, "(" +++ snd (typeCons x True) +++ " -> " +++ snd (typeCons y True) +++ ")")

default{|CONS|} default_a path history 
	# (a, s) = default_a path history
	= (mapMaybe CONS a, s)

default{|PAIR|} default_a default_b path history
	# (a, sa) = default_a pa history
	  (b, sb) = default_b pb history
	= (pair a b, sa + sb)
where
	(pa, pb) = case path of 
					Pair l r -> (l, r)
					_ -> (path, path)

	pair a b = case (a, b) of
				(Just x, Just y) -> Just (PAIR x y)
				_ -> Nothing
			
default{|FIELD|} default_a path history 
	# (a, s) = default_a path history
	= (mapMaybe FIELD a, s)

default{|UNIT|} path history = (Just UNIT, 0)

default{|Int|} path history = (Just 0, SIZE_INT)

default{|Char|} path history = (Just '\0', SIZE_CHAR)

default{|Bool|} path history = (Just False, SIZE_CHAR)

default{|Real|} path history = (Just 0.0, SIZE_REAL)

defaultArray :== (Just {}, SIZE_INT)

default{|{}|} _ _ _ = defaultArray
default{|{!}|} _ _  _ = defaultArray
default{|String|} _ _ = defaultArray

default{|(->)|} default_a default_b path history
	# (b, sb) = default_b path history
	= case b of
		Just _ -> (Just f, sb)
		_ -> (Nothing, sb)
where
	f _ = case default_b path history of
			(Just y, _) -> y
