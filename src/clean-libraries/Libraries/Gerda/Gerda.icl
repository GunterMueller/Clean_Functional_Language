implementation module Gerda

import StdMisc, StdMaybe, StdGeneric
import StdEnv, odbc, odbccp, StdDebug//, MyDebug

(TRACE_SQL) infix 0 
(TRACE_SQL) value statement :== statement
//(TRACE_SQL) value statement :== trace_n value statement

:: Gerda = {
		index :: !Int,
		buffer :: !.{#Int},
		layout :: !Tables,
		connection :: !SQLHDBC,
		environment :: !SQLHENV,
		state :: !.SqlState}
	
:: GerdaType :== Path History Int -> (GenType, Bool, Int)
:: GerdaLayout :== [SqlAttr] String String Tables Int -> ([Column], Tables, Int)
:: GerdaWrite a :== .(Maybe a) *Gerda -> *Gerda
:: GerdaRead a :== *Gerda -> *(.Maybe a, *Gerda)
:: GerdaNext a :== (a, a -> .(Bool, a))

:: GerdaFunctions a = {
		gerdaT :: !GerdaType,
		gerdaL :: !GerdaLayout,
		gerdaW :: !(GerdaWrite a),
		gerdaR :: !(GerdaRead a),
		gerdaN :: !.(GerdaNext a)}

:: History = History !Int !String !String !History | NoHistory
:: Path = P !Path !Path | T !Int !String !String

:: Tables = NoTables | E. k v: Table !(Table k v) !Tables

:: Table k v = {
	name :: !String,
	columns :: [Column],
	primary :: [Column],
	key :: !(GerdaFunctions k),
	value :: !(GerdaFunctions v),
//	split :: !(a -> (k, v)),
//	join :: !(k v -> a),
	bufferSize :: !Int,
	bufferPointer :: !Int,
	insertStmt :: !SQLHSTMT,
	updateStmt :: !SQLHSTMT,
	selectStmt :: !SQLHSTMT}

:: Column = {
	name :: !String,
	sqlType :: !SqlType,
	sqlAttr :: ![SqlAttr]}

:: SqlAttr 
	= SqlReference !String
	| SqlUnique
	| SqlPrimary
	| SqlNull

:: SqlType
	= SqlInteger
	| SqlBit
	| SqlChar1
	| SqlVarChar252
	| SqlDouble

:: SomeTable v = E. k: {some :: !.(Table k v)}

openGerda :: !String !*World -> (!*Gerda, !*World)
openGerda dbname world
	# (state, world) = openSqlState world
	  (r, env, state) = SQLAllocHandle SQL_HANDLE_ENV SQL_NULL_HANDLE state
	| r <> SQL_SUCCESS = abort "SQLAllocHandle SQL_HANDLE_ENV failed"
	# (r, state) = SQLSetEnvAttr env SQL_ATTR_ODBC_VERSION SQL_OV_ODBC2 0 state
	| r <> SQL_SUCCESS = abort "SQLSetEnvAttr failed"
	# (r, dbc, state) = SQLAllocHandle SQL_HANDLE_DBC env state
	| r <> SQL_SUCCESS = abort "SQLAllocHandle SQL_HANDLE_DBC failed"
	# path = "."
	  what = "DSN=MS Access Database;DBQ=" +++ path +++ "\\" +++ dbname +++ ".mdb;DefaultDir=" +++ path +++ ";FIL=MS Access;"
	  (r, _, _, state) = SQLDriverConnect dbc 0 what (size what) 0 SQL_DRIVER_NOPROMPT state
	  state = case r of
	  	SQL_SUCCESS -> state
	  	_
			# (r, state) = SQLConfigDataSource 0 ODBC_ADD_DSN "Microsoft Access Driver (*.mdb)\0" ("CREATE_DB=\"" +++ path +++ "\\" +++ dbname +++ ".mdb\" General\0\0") state
		 	| r <> 1 -> abort "SQLConfigDataSource failed"
	  		# (r, _, _, state) = SQLDriverConnect dbc 0 what (size what) 0 SQL_DRIVER_NOPROMPT state
		 	| r <> SQL_SUCCESS -> abort "SQLDriverConnect failed"
	  		-> state
	= ({index = 0, buffer = {}, layout = NoTables, 
		connection = dbc, environment = env, state = state}, world)

closeGerda :: !*Gerda !*World -> *World
closeGerda g=:{layout} world 
	# g=:{connection, environment, state} = closeTables layout g
	  (r, state) = SQLDisconnect connection state;
	| r <> SQL_SUCCESS = abort "SQLDisconnect failed"
	# (r, state) = SQLFreeHandle SQL_HANDLE_DBC connection state
	| r <> SQL_SUCCESS = abort "SQLFreeHandle SQL_HANDLE_DBC failed"
	# (r, state) = SQLFreeHandle SQL_HANDLE_ENV environment state
	| r <> SQL_SUCCESS = abort "SQLFreeHandle SQL_HANDLE_DBC failed"
	= closeSqlState state world
where
	closeTables (Table t ts) g
		# g = closeTable t g
		= closeTables ts g
	closeTables _ g = g

writeGerda :: !String !a !*Gerda -> *Gerda | gerda{|*|} a
writeGerda name x g=:{layout}
//	| trace_tn (typeA (T 0 "" "") NoHistory 0) //= abort "THIS IS ONLY THE TYPE"
	# g = removeTable tableName g
	  (layout, g) = g!layout
	  ({some}, tables) = layoutTable tableName Nothing gerdaA layout
	  (k, g) = writeToTable tableName some tables x g
	= g //<<- ("writeGerda", name, k, x)
where
	gerdaA = gerda{|*|}
	tableName = "*" +++ name

	stripForeign [c=:{sqlAttr}:cs] = [{c & sqlAttr = filter p sqlAttr}:stripForeign cs]
	where
		p (SqlReference _) = False
		p _ = True
	stripForeign _ = []

readGerda :: !String !*Gerda -> (!Maybe a, !*Gerda) | gerda{|*|} a
readGerda name g=:{layout} 
	# ({some=some=:{key={gerdaN=(defKey, _)}}}, tables) = layoutTable tableName Nothing gerdaA layout
	  (m, g) = readFromTable tableName some tables (cast 0) g
	= (m, g) //<<- ("readGerda", name, 0, m)
where
	(gerdaA=:{gerdaL=layoutA, gerdaR=readA}) = gerda{|*|}
	tableName = "*" +++ name

deleteGerda :: !String !*Gerda -> *Gerda
deleteGerda name g = removeTable tableName g
where
	tableName = "*" +++ name

unsafeRead :: !String !(Table k v) !k !(v -> w) !*Gerda -> (Maybe w, !*Gerda)
unsafeRead tableName table=:{value} ref f g=:{layout, connection, environment}
	#!(state, _) = openSqlState (cast 0x9E5DA)
	#!g` = {index = 0, buffer = {}, layout = layout, 
	  		connection = connection, environment = environment, state = state}
	# (m, _) = readFromTable tableName table NoTables ref g`
	= (mapMaybe f m, g)

generic gerda a :: GerdaFunctions a

gerda{|OBJECT of {gtd_name, gtd_arity, gtd_num_conses}|} gerdaA
	= {gerdaT = typeO, gerdaL = layoutO, gerdaW = writeO, gerdaR = readO, gerdaN = (OBJECT defA, nextO)}
where
	(gerdaA`=:{gerdaT=typeA, gerdaL=layoutA, gerdaW=writeA, gerdaR=readA, gerdaN=(defA, nextA)}) = gerdaA

	typeO path=:(T arity con typ) history i
		| gtd_arity == 0 = (GenTypeCons gtd_name, False, i)
		| lookup history > arity = (t, False, j)
		= (realtype, False, k)
	where
		realtype = unify (repeatn gtd_num_conses t) ts t
	
		ts = splitEithers gtd_num_conses ta
		where
			splitEithers 1 t = [t]
			splitEithers n (GenTypeApp (GenTypeApp (GenTypeCons "EITHER") a) b) 
				= splitEithers (n >> 1) a ++ splitEithers ((n + 1) >> 1) b
	
		(ta, hasKey, k) = typeA path history j
	
		(t, j) = makeType gtd_arity (GenTypeCons gtd_name) i
		where
			makeType 0 t i = (t, i)
			makeType n t i = makeType (n - 1) (GenTypeApp t (GenTypeVar (/*toString*/ i))) (i + 1)
	
		lookup (History n c t hs)
			| c == con && t == typ = n
			| otherwise = lookup hs
		lookup _ = 0
	
	tableName = type2tableName type
	where
		(type, _, _) = typeO (T 0 "" "") NoHistory 0

	layoutO attr constr field tables i = (columns, tables``, j)
	where
		(columns, tables``, j) = layoutR [SqlReference tableName:attr] constr field tables` i
		({some={key={gerdaL=layoutR}}}, tables`) = layoutTable tableName Nothing gerdaA` tables
	
	writeO m g
		# ({some=some=:{key={gerdaW=writeR}}}, g) = findTable tableName g
		= case m of
			Just (OBJECT x)
				# (key, g) = writeToTable tableName some NoTables x g
				-> writeR (Just key) g
			_ -> writeR Nothing g

	readO g
		# ({some=some=:{key={gerdaR=readR}}}, g) = findTable tableName g
		= case readR g of
					(Just ref, g) -> unsafeRead tableName some ref OBJECT g
					(_, g) -> (Nothing, g)

	nextO (OBJECT x) = (overflow, OBJECT y)
	where
		(overflow, y) = nextA x

gerda{|OBJECT|} gerdaA = gerdaBimap (GenTypeApp (GenTypeCons "OBJECT")) (\(OBJECT x) -> x) OBJECT gerdaA

gerda{|EITHER|} gerdaA gerdaB = {gerdaT = typeE, gerdaL = layoutP, gerdaW = writeE, gerdaR = readE, gerdaN = (defE, nextE)}
where
	{gerdaT=typeP, gerdaL=layoutP, gerdaW=writeP, gerdaR=readP, gerdaN=(defP, nextP)} = gerda{|*->*->*|} (gerda{|*->*|} gerdaA) (gerda{|*->*|} gerdaB)

	typeE path history i = (GenTypeApp (GenTypeApp (GenTypeCons "EITHER") ta) tb, hasKey, j)
	where
		(GenTypeApp (GenTypeApp (GenTypeCons _) (GenTypeApp _ ta)) (GenTypeApp _ tb), hasKey, j) = typeP (P path path) history i
			
	writeE = mapWrite writeP either2pair
	where
		either2pair (LEFT x) = PAIR (Just x) Nothing
		either2pair (RIGHT y) = PAIR Nothing (Just y)
	
	readE g = case readP g of (m, g) -> (pair2either m, g)
	where
		pair2either (Just (PAIR (Just x) _)) = Just (LEFT x)
		pair2either (Just (PAIR _ (Just y))) = Just (RIGHT y)
		pair2either _ = trace_n "<<<WARNING: Cannot make EITHER from PAIR Nothing Nothing, possible type error in your program>>>" Nothing

	defE = case defP of PAIR (Just x) _ -> LEFT x; PAIR _ (Just y) -> RIGHT y

	nextE (LEFT x) = case nextP (PAIR (Just x) Nothing) of (overflow, PAIR (Just x) _) -> (overflow, LEFT x)
	nextE (RIGHT y) = case nextP (PAIR Nothing (Just y)) of (overflow, PAIR _ (Just y)) -> (overflow, RIGHT y)

gerda{|CONS of {gcd_name, gcd_arity, gcd_type, gcd_type_def}|} gerdaA
	= {gerdaT = typeC, gerdaL = layoutC, gerdaW = writeC, gerdaR = readC, gerdaN = (CONS defA, nextC)}
where
	{gerdaT=typeA, gerdaL=layoutA, gerdaW=writeA, gerdaR=readA, gerdaN=(defA, nextA)} = gerdaA
	
	{gtd_name, gtd_arity} = gcd_type_def

	typeC path history i 
		| gcd_arity == 0 = (t, False, j)
		= (unify formals actuals result, hasKey, k)
	where
		actuals = splitPairs gcd_arity type
		where
			splitPairs 1 t = [t]
			splitPairs n (GenTypeApp (GenTypeApp (GenTypeCons "PAIR") a) b) 
				= splitPairs (n >> 1) a ++ splitPairs ((n + 1) >> 1) b
	
		(type, hasKey, k) = typeA cons history` j
	
		(cons, _) = makePairs gcd_arity formals
		where
			makePairs 1 [f:fs] 
				| varApp = (T gtd_arity gcd_name gtd_name, fs)
				= (T gtd_arity gcd_name typecons, fs)
			where
				(varApp, typecons) = typeCons f False
			makePairs n fs 
				# (a, fs) = makePairs (n >> 1) fs
				  (b, fs) = makePairs ((n + 1) >> 1) fs
				= (P a b, fs) 
	
			typeCons (GenTypeApp x y) _ = typeCons x True
			typeCons (GenTypeCons x) _ = (False, x)
			typeCons (GenTypeVar x) varApp = (varApp, "")
	
		history` = foldl increment history (typeConses gcd_type [])
		where
			typeConses (GenTypeApp x y) acc = typeConses y (typeConses x acc)
			typeConses (GenTypeArrow x y) acc = typeConses y (typeConses x acc)
			typeConses (GenTypeCons x) acc | not (isMember y acc) = [y:acc]
				where y = (gcd_name, x)
			typeConses _ acc = acc
	
			increment (History n c t hs) (con, typ)
				| c == con && t == typ = History (n + 1) c t hs
				| otherwise = History n c t (increment hs (con, typ))
			increment _ (con, typ) = History 1 con typ NoHistory
			
		(formals, result) = splitType gcd_arity t
		where
			splitType 0 t = ([], t)
			splitType n (GenTypeArrow x y) = ([x:xs], r)
				where (xs, r) = splitType (n - 1) y
				
		(t, j) = freshCopy gcd_type i

	layoutC attr _ field tables i = layoutA attr gcd_name field tables i
	
	writeC = mapWrite writeA \(CONS x) -> x

	readC = mapRead readA CONS
	
	nextC (CONS x) = (overflow, CONS y)
	where
		(overflow, y) = nextA x

gerda{|CONS|} gerdaA = gerdaBimap (GenTypeApp (GenTypeCons "CONS")) (\(CONS x) -> x) CONS gerdaA

gerda{|FIELD of {gfd_name}|} gerdaA = {gerdaT = typeA, gerdaL = layoutF, gerdaW = writeF, gerdaR = readF, gerdaN = (FIELD defA, nextF)}
where
	{gerdaT=typeA, gerdaL=layoutA, gerdaW=writeA, gerdaR=readA, gerdaN=(defA, nextA)} = gerdaA
	
	layoutF attr _ _ tables i = layoutA attr "" gfd_name tables i
	
	writeF = mapWrite writeA \(FIELD x) -> x

	readF = mapRead readA FIELD
	
	nextF (FIELD x) = (overflow, FIELD y)
	where
		(overflow, y) = nextA x

gerda{|FIELD|} gerdaA = gerdaBimap (GenTypeApp (GenTypeCons "FIELD")) (\(FIELD x) -> x) FIELD gerdaA

gerda{|PAIR|} gerdaA gerdaB = {gerdaT = typeP, gerdaL = layoutP, gerdaW = writeP, gerdaR = readP, gerdaN = (PAIR defA defB, nextP)}
where
	{gerdaT=typeA, gerdaL=layoutA, gerdaW=writeA, gerdaR=readA, gerdaN=(defA, nextA)} = gerdaA
	{gerdaT=typeB, gerdaL=layoutB, gerdaW=writeB, gerdaR=readB, gerdaN=(defB, nextB)} = gerdaB
	
	typeP path history i = (GenTypeApp (GenTypeApp (GenTypeCons "PAIR") a) b, hasKeyA || hasKeyB, k)
	where
		(a, hasKeyA, j) = typeA pa history i
		(b, hasKeyB, k) = typeB pb history j
		(pa, pb) = case path of 
						P l r -> (l, r)
						_ -> (path, path)

	layoutP attr constr field tables i = (columns ++ columns`, tables``, k)
	where
		(columns`, tables``, k) = layoutB attr constr "" tables` j
		(columns, tables`, j) = layoutA attr constr field tables i

	writeP (Just (PAIR x y)) g
		# g = writeA (Just x) g
		= writeB (Just y) g
	writeP _ g
		# g = writeA Nothing g
		= writeB Nothing g

	readP g
		# (ma, g) = readA g
		  (mb, g) = readB g
		= (case (ma, mb) of (Just x, Just y) -> Just (PAIR x y); _ -> Nothing, g)

	nextP (PAIR x y) = (overflowx && overflowy, PAIR x1 y1) 
	where
		(overflowx, x1) = nextA x
		(overflowy, y1) = nextB y

gerda{|UNIT|} =: {gerdaT = typeU, gerdaL = layoutU, gerdaW = writeU, gerdaR = readU, gerdaN = (UNIT, \x -> (True, x))}
where
	{gerdaL=layoutB, gerdaW=writeB, gerdaR=readB} = gerda{|*|}
	
	typeU _ _ i = (GenTypeCons "UNIT", False, i)
	
	layoutU attr constr field tables i = layoutB (removeMember SqlNull attr) constr field tables i

	writeU m g = writeB (Just (isJust m)) g

	readU g 
		# (Just b, g) = readB g 
		= if b (Just UNIT, g) (Nothing, g)
		
gerda{|Int|} =: gerdaInt

gerda{|Bool|} =: gerdaInline (GenTypeCons "Bool") SqlBit 2 store load False next
where
	store x index buffer = {buffer & [index] = 1, [index + 1] = if x -1 0}
	load 1 index buffer 
		# (x, buffer) = buffer![index + 1]
		= (x bitand 1 <> 0, buffer)
		
	next x = (x, not x)
	
gerda{|Char|} =: gerdaInline (GenTypeCons "Char") SqlChar1 2 store load '\0' next
where
	store x index buffer = {buffer & [index] = 1, [index + 1] = toInt x}
	load 1 index buffer 
		# (x, buffer) = buffer![index + 1]
		= (toChar x, buffer)
	
	next c = (c == '\255', c + '\1')

gerda{|Real|} =: gerdaInline (GenTypeCons "Real") SqlDouble 3 store load 0.0 next
where
	store x index buffer 
		# (i1, i2) = real2ints x
		= {buffer & [index] = 8, [index + 1] = i1, [index + 2] = i2}
	where
		real2ints :: !Real -> (!Int, !Int)
		real2ints _ = code {
				pop_a	0
			}

	load 8 index buffer 
		# (i1, buffer) = buffer![index + 1]
		  (i2, buffer) = buffer![index + 2]
		= (ints2real i1 i2, buffer)
	where	
		ints2real :: !Int !Int -> Real
		ints2real _ _ = code {
				pop_a 0
			}
	
	next x = (y == 0.0, y)
	where
		y = x + 1.0

gerda{|Binary252|} =: gerdaInline (GenTypeCons "Binary252") SqlVarChar252 64 store load {binary252 = ""} next
where
	store {binary252} index buffer = storeString 0 binary252 (index + 1) {buffer & [index] = size binary252}
	where
		storeString :: !Int !String !Int !*{#Int} -> *{#Int}
		storeString i s j d = case size s - i of
			1 -> {d & [j] = toInt s.[i]}
			2 -> {d & [j] = toInt s.[i] + toInt s.[i + 1] << 8}
			3 -> {d & [j] = toInt s.[i] + toInt s.[i + 1] << 8 + toInt s.[i + 2] << 16}
			x | x <= 0 -> d
			_ -> storeString (i + 4) s (j + 1) {d & [j] = toInt s.[i] + toInt s.[i + 1] << 8 + toInt s.[i + 2] << 16 + toInt s.[i + 3] << 24}
	
	load avail index buffer | 0 <= avail && avail <= 252
		# (s, buffer) = loadString 0 (createArray avail '\0') (index + 1) buffer
		= ({binary252 = s}, buffer)
	where
		loadString :: !Int !*String !Int !u:{#Int} -> (!*String, !u:{#Int})
		loadString i d j s 
			# (e, s) = s![j]
			= case size d - i of
				1 -> ({d & [i] = toChar e}, s)
				2 -> ({d & [i] = toChar e, [i + 1] = toChar (e >> 8)}, s)
				3 -> ({d & [i] = toChar e, [i + 1] = toChar (e >> 8), [i + 2] = toChar (e >> 16)}, s)
				x | x <= 0 -> (d, s)
				_ ->  loadString (i + 4) {d & [i] = toChar e, [i + 1] = toChar (e >> 8), [i + 2] = toChar (e >> 16), [i + 3] = toChar (e >> 24)} (j + 1) s

	next {binary252} = (size binary252 > 252, {binary252 = incr binary252 (size binary252 - 1)})
	where
		incr s i
			| i < 0 = "\0" +++ s
			| s.[i] == '\255' = incr s (i - 1)
			= {s +++. "" & [i] = s.[i] + '\1'}

gerda{|Maybe|} gerdaA = {gerdaT = typeM, gerdaL = layoutM, gerdaW = writeM, gerdaR = readM, gerdaN = (Just defA, nextM)}
where
	{gerdaT=typeA, gerdaL=layoutA, gerdaW=writeA, gerdaR=readA, gerdaN=(defA, nextA)} = gerdaA
	
	typeM path history i = (GenTypeApp (GenTypeCons "Maybe") a, hasKey, j)
	where
		(a, hasKey, j) = typeA path history i

	layoutM attr constr field tables i = layoutA (if (isMember SqlNull attr) attr [SqlNull:attr]) constr field tables i

	writeM (Just x=:(Just _)) g = writeA x g
	writeM _ g = writeA Nothing g
	
	readM g 
		# (m, g) = readA g
		= (Just m, g)

	nextM (Just x) = (overflow, Just y)
	where
		(overflow, y) = nextA x
	nextM _ = (True, Nothing)

gerda{|String|} =: gerdaBimap typeS fromS toS (gerda{|*->*|} gerda{|*|})
where
	typeS _ = GenTypeCons "_String"
	
	fromS s = CompactList {binary252 = s % (0, 251)} (f (s % (252, size s - 1)))
	where
		f s
			| size s <= 0 = Nothing
			= Just (CompactList {binary252 = s % (0, 251)} (f (s % (252, size s - 1))))

	toS (CompactList {binary252} tail) = binary252 +++ f tail
	where
		f (Just (CompactList {binary252} tail)) = binary252 +++ f tail
		f _ = ""

gerda{|[]|} gerdaA = gerdaBimap typeL toMCL fromMCL (gerda{|*->*|} (gerda{|*->*|} gerdaA))
where
	typeL (GenTypeApp _ (GenTypeApp _ a)) = GenTypeApp (GenTypeCons "_List") a

	toMCL [x:xs] = Just (CompactList x (toMCL xs))
	toMCL _ = Nothing
	
	fromMCL (Just (CompactList x xs)) = [x:fromMCL xs]
	fromMCL _ = []

gerda{|{}|} gerdaA = gerdaArray (GenTypeCons "{}") gerdaA

gerda{|{!}|} gerdaA = gerdaArray (GenTypeCons "{!}") gerdaA

gerda{|GerdaObject|} gerdaA = {gerdaT = typeG, gerdaL = layoutG, gerdaW = writeG, gerdaR = readG, gerdaN = (gerdaObject defA, nextG)}
where
	(gerdaA`=:{gerdaT=typeA, gerdaL=layoutA, gerdaW=writeA, gerdaR=readA, gerdaN=(defA, nextA)}) = gerdaA

	typeG path history i = (GenTypeApp (GenTypeCons "GerdaObject") a, hasKey, j)
	where
		(a, hasKey, j) = typeA path history i
	
	tableName = type2tableName type
	where
		(type, _, _) = typeG (T 0 "" "") NoHistory 0

	layoutG attr constr field tables i = (columnsR, tables``, j)
	where
		(columnsR, tables``, j) = layoutR [SqlReference tableName:attr] constr field tables` i
		({some={key={gerdaL=layoutR}}}, tables`) = layoutTable tableName Nothing gerdaA` tables

	writeG m g
		# ({some=some=:{key={gerdaW=writeR}}}, g) = findTable tableName g
		= case m of
			Just {gerdaObject}
				# (key, g) = writeToTable tableName some NoTables gerdaObject g
				-> writeR (Just key) g
			_ -> writeR Nothing g

	readG g=:{layout}
		# ({some=some=:{key={gerdaR=readR}}}, g) = findTable tableName g
		= case readR g of
				(Just ref, g) -> case readFromTable tableName some NoTables ref g of
									(Just x, g) -> (Just {gerdaObject = x, 
														gerdaWrite = updateInTable tableName some NoTables ref, 
														gerdaRead = \g -> case readFromTable tableName some NoTables ref g of (Just x, g) -> (x, g)}, g)
									(_, g) -> (Nothing, g)
				(_, g) -> (Nothing, g)

	nextG g=:{gerdaObject} = (overflow, {g & gerdaObject = v})
	where
		(overflow, v) = nextA gerdaObject

gerda{|GerdaPrimary|} gerdaK gerdaV = {gerdaT = typeP, gerdaL = layoutP, gerdaW = writeP, gerdaR = readP, gerdaN = ({gerdaKey = defK, gerdaValue = defV}, nextP)}
where
	(gerdaK`=:{gerdaT=typeK, gerdaL=layoutK, gerdaW=writeK, gerdaR=readK, gerdaN=(defK, nextK)}) = gerdaK
	(gerdaV`=:{gerdaT=typeV, gerdaL=layoutV, gerdaW=writeV, gerdaR=readV, gerdaN=(defV, nextV)}) = gerdaV

	typeP path history i = (GenTypeApp (GenTypeApp (GenTypeCons "GerdaKey") k) v, True, j`)
	where
		(k, _, j) = typeK path history i
		(v, _, j`) = typeV path history j

	tableName = type2tableName type
	where
		(type, _, _) = typeP (T 0 "" "") NoHistory 0

	layoutP attr constr field tables i = (columns, tables``, j)
	where
		(columns, tables``, j) = layoutK [SqlReference tableName:attr] constr field tables` i
		(_, tables`) = layoutTable tableName (Just gerdaK`) gerdaV` tables

	writeP m g
		= case m of
			Just {gerdaKey, gerdaValue}
				# ({some}, g) = findTable tableName g
				  (ref, g) = writeToTable tableName {some & key = {gerdaK` & gerdaN = (gerdaKey, nextK)}} NoTables gerdaValue g
				-> writeK (Just ref) g
			_ -> writeK Nothing g

	readP g
		# ({some}, g) = findTable tableName g
		= case readK g of
					(Just ref, g) -> unsafeRead tableName {some & key = {gerdaK` & gerdaN = (ref, nextK)}} ref (\v -> {gerdaKey = ref, gerdaValue = v}) g
					(_, g) -> (Nothing, g)

	nextP p=:{gerdaKey} = (overflow, {p & gerdaKey = x})
	where
		(overflow, x) = nextK gerdaKey

gerda{|GerdaUnique|} gerdaK = {gerdaT = typeP, gerdaL = layoutP, gerdaW = writeP, gerdaR = readP, gerdaN = ({gerdaUnique = defK}, nextP)}
where
	{gerdaT=typeK, gerdaL=layoutK, gerdaW=writeK, gerdaR=readK, gerdaN=(defK, nextK)} = gerdaK

	typeP path history i = (GenTypeApp (GenTypeCons "GerdaUnique") a, hasKey, j)
	where
		(a, hasKey, j) = typeK path history i

	layoutP attr constr field tables i = layoutK [SqlUnique:attr] constr field tables i

	writeP = mapWrite writeK \{gerdaUnique} -> gerdaUnique

	readP = mapRead readK \k -> {gerdaUnique = k}
	
	nextP {gerdaUnique} = (overflow, {gerdaUnique = x})
	where
		(overflow, x) = nextK gerdaUnique

gerdaInt :: GerdaFunctions Int
gerdaInt =: gerdaInline (GenTypeCons "Int") SqlInteger 2 store load 0 (\x -> (x == -1, x + 1))
where
	store x index buffer = {buffer & [index] = 4, [index + 1] = x}
	load 4 index buffer = buffer![index + 1]

gerdaBimap :: !(GenType -> GenType) !(b -> a) !(a -> b) !(GerdaFunctions a) -> GerdaFunctions b
gerdaBimap typeF toA toB gerda = {gerdaT = typeB, gerdaL = layoutB, gerdaW = writeB, gerdaR = readB, gerdaN = (toB defA, nextB)}
where
	{gerdaT=typeA, gerdaL=layoutA, gerdaW=writeA, gerdaR=readA, gerdaN=(defA, nextA)} = gerda
	
	typeB path history i = (typeF type, hasKey, j)
	where
		(type, hasKey, j) = typeA path history i

	layoutB attr constr field tables i = layoutA attr constr field tables i

	writeB = mapWrite writeA toA

	readB = mapRead readA toB
	
	nextB b = (overflow, toB a)
	where
		(overflow, a) = nextA (toA b)

gerdaInline genType sqlType dataSize store load def next :== gerdaI
where
	gerdaI = {gerdaT = typeI, gerdaL = layoutI, gerdaW = writeI, gerdaR = readI, gerdaN = (def, next)}

	typeI _ _ i = (genType, False, i)

	layoutI attr constr field tables i = ([{name = n, sqlType = sqlType, sqlAttr = attr}], tables, i + 1)
	where
		n = if (field == "") (toString i +++ case (constr, genType) of ("", GenTypeCons c) -> c; _ ->  constr) field

	writeI m g=:{index, buffer} = case m of
		Just x -> {g & index = index + dataSize, buffer = store x index buffer}
		_ -> {g & index = index + dataSize, buffer = {buffer & [index] = SQL_NULL_DATA}}

	readI g=:{index, buffer}
		# (avail, buffer) = buffer![index]
		| avail == SQL_NULL_DATA = (Nothing, {g & index = index + dataSize, buffer = buffer})
		# (x, buffer) = load avail index buffer 
		#!x = x
		= (Just x, {g & index = index + dataSize, buffer = buffer})
	
gerdaArray type gerdaA :== {gerdaT = typeY, gerdaL = layoutY, gerdaW = writeY, gerdaR = readY, gerdaN = ({}, nextY)}
where
	(gerdaA`=:{gerdaT=typeA, gerdaL=layoutA, gerdaW=writeA, gerdaR=readA}) = gerdaA
/*
	{gerdaL=layoutR, gerdaW=writeR, gerdaR=readR} = gerdaInt
*/
	{gerdaL=layoutS, gerdaW=writeS, gerdaR=readS} = gerdaInt

	typeY path history i = (GenTypeApp type a, False, j)
	where
		(a, _, j) = typeA path history i
	
	tableName = type2tableName type
	where
		(type, _, _) = typeY (T 0 "" "") NoHistory 0

	layoutY attr constr field tables i = (columnsR ++ columnsS, tables```, k)
	where
		(columnsS, tables```, k) = layoutS attr constr "" tables`` j
		(columnsR, tables``, j) = layoutR [SqlReference tableName:attr] constr field tables` i
		({some={key={gerdaL=layoutR}}}, tables`) = layoutTable tableName Nothing gerdaA` tables

	writeY m g
		# ({some=some=:{key={gerdaW=writeR, gerdaN=(start, next)}}}, g) = findTable tableName g
		= case m of
			Just array
				# len = size array
				  g = writeArray 0 len array some g
				  g = writeR (Just start) g
				-> writeS (Just len) g
			_ 
				# g = writeR Nothing g
				-> writeS Nothing g
		where
			writeArray i len array some=:{key=key=:{gerdaN=(k, n)}} g
				| i >= len = g
				# (_, g) = writeToTable tableName some NoTables array.[i] g
				  (overflow, k`) = n k
				| overflow = abort "Primary key overflow in array"
				= writeArray (i + 1) len array {some & key = {key & gerdaN = (k`, n)}} g

	readY g
		# ({some=some=:{key={gerdaR=readR, gerdaN=(_, next)}}}, g) = findTable tableName g
		= case readR g of
			(Just ref, g) -> case readS g of
								(Just len, g) -> readArray ref 0 (createArray len (cast [])) next some g
								(_, g) -> (Nothing, g)
			(_, g) -> (Nothing, g)
	where
		readArray ref i array next some g
			| i >= size array = (Just array, g)
			= case readFromTable tableName some NoTables ref g of
				(Just x, g) -> case next ref of
								(False, ref) -> readArray ref (i + 1) {array & [i] = x} next some g
								_ -> abort "Primary key overflow in array index"
				(_, g) -> (Nothing, g)

	nextY array = abort "nextY" /*incr array (size array - 1)
	where
		incr array i
			| i < 0 = {defA} +++ s
			| s.[i] == defA = incr s (i - 1)
			= {s +++. "" & [i] = s.[i] + '\1'}*/
		
mapWrite write f m g :== write (mapMaybe f m) g

mapRead read f g :== case read g of (m, g) -> (mapMaybe f m, g)

layoutTable :: !String !(Maybe (GerdaFunctions k)) (GerdaFunctions v) Tables -> (SomeTable v, Tables)
layoutTable tableName Nothing gerdaA layout = layoutTable tableName (Just gerdaInt) gerdaA layout
layoutTable tableName (Just key=:{gerdaL=layoutK}) gerdaA=:{gerdaT=typeA, gerdaL=layoutA} layout
	= case extractTable tableName layout of
		(Just some, _) -> (some, layout)
		_ -> ({some = table}, tables)
where
    table = {name = tableName, columns = columns, primary = primary, key = key, value = gerdaA,
    		bufferSize = 0, bufferPointer = 0, insertStmt = 0, updateStmt = 0, selectStmt = 0}

	(columns, tables, _) = layoutA [] "" "" (Table table layout) i

	(primary, _, i) = layoutK [SqlPrimary] "" "" tables 0
	
writeToTable :: !String !(Table k v) !Tables !v !*Gerda -> (!k, !*Gerda)
writeToTable tableName table=:{key=key=:{gerdaN=(currentKey, nextKey)}} tables x g
	# (overflow, newKey) = nextKey currentKey
	| overflow = abort ("Overflow in primary key in table " +++ tableName)
	# ({key={gerdaW=writeKey, gerdaN=(testKey, _)}, value, columns, bufferSize, bufferPointer, insertStmt}, g=:{index=previousIndex, buffer=previousBuffer}) = newTables {table & key = {key & gerdaN = (newKey, nextKey)}} tables g
	  g = writeKey (Just currentKey) {g & index = 0, buffer = createArray bufferSize 0}
	  g=:{layout, buffer, connection, state} = value.gerdaW (Just x) g
	  (_, state) = bufferToPointer 0 bufferPointer buffer state
	  (r, state) = SQLExecute (" INSERT " +++ tableName TRACE_SQL insertStmt) state
//	  state = closeStmt insertStmt state
	| r <> SQL_SUCCESS = abort ("SQLExecute failed on INSERT " +++ tableName)
	= (currentKey, {g & index = previousIndex, buffer = previousBuffer, state = state})

readFromTable :: !String !(Table k v) !Tables !k !*Gerda -> (!Maybe v, !*Gerda)
readFromTable tableName table tables k g
	# ({key={gerdaW=writeKey, gerdaR=readKey}, value, bufferSize, bufferPointer, selectStmt}, g=:{layout, index=previousIndex, buffer=previousBuffer}) = newTables table tables g
	  g=:{buffer, connection, state} = writeKey (Just k) {g & index = 0, buffer = createArray bufferSize 0}
	  (buffer, state) = bufferToPointer 0 bufferPointer buffer state
	  (r, state) = SQLExecute (" SELECT " +++ tableName TRACE_SQL selectStmt) state
	  (r, state) = if (r == SQL_SUCCESS) (SQLFetch selectStmt state) (r, state)
	  (buffer, state) = pointerToBuffer 0 bufferPointer buffer state
	  state = closeStmt selectStmt state
	| r <> SQL_SUCCESS = (Nothing, {g & index = previousIndex, buffer = previousBuffer, state = state})
	# (_, g) = readKey {g & index = 0, buffer = buffer, state = state}
	  (m, g) = value.gerdaR g
	= (m, {g & index = previousIndex, buffer = previousBuffer})

updateInTable :: !String !(Table k v) !Tables !k !v !*Gerda -> *Gerda
updateInTable tableName table tables k v g
	# ({key={gerdaW=writeKey}, value, bufferSize, bufferPointer, insertStmt, updateStmt}, g=:{index=previousIndex, buffer=previousBuffer}) = newTables table tables g
	  g = value.gerdaW (Just v) {g & index = 0, buffer = createArray bufferSize 0}
	  g=:{buffer, connection, state} = writeKey (Just k) g
	  (_, state) = bufferToPointer 0 bufferPointer buffer state
	  (r, state) = SQLExecute (" UPDATE " +++ tableName TRACE_SQL updateStmt) state
	| r <> SQL_SUCCESS = abort ("SQLExecute failed on UPDATE " +++ tableName)
	# state = closeStmt updateStmt state
	= {g & index = previousIndex, buffer = previousBuffer, state = state}

removeTable :: !String !*Gerda -> *Gerda
removeTable tableName g=:{layout}
	# (m, layout) = extractTable tableName layout
	  g = {g & layout = layout}
	  g=:{connection, state} = case m of
		Just {some} 
			# g = closeTable some g
			-> alterTables False (Table some NoTables) g
		_ -> g
	# (r, h, state) = SQLAllocHandle SQL_HANDLE_STMT connection state
	| r <> SQL_SUCCESS = abort "SQLAllocHandle SQL_HANDLE_STMT failed"
	# drop = "DROP TABLE " +++ sqlEscape tableName
	  (r, state) = SQLExecDirect h (drop TRACE_SQL drop) (size drop) state
	  state = freeStmt h state
//	| r <> SQL_SUCCESS = abort ("SQLExecDirect failed " +++ drop)
	= {g & state = state}

findTable :: !String !*Gerda -> (!SomeTable v, !*Gerda)
findTable tableName g=:{layout}
	# (maybe, _) = extractTable tableName layout
	= case maybe of
		Just some -> (some, g)
		_ -> abort ("Cannot find table " +++ tableName +++ " (internal error)")

extractTable :: !String !Tables -> (!Maybe (SomeTable v), !Tables)
extractTable tableName (Table t=:{Table|name} ts)
	| name == tableName = (Just {some = cast t}, ts)
	# (maybe, ts) = extractTable tableName ts
	= (maybe, Table t ts)
extractTable _ _ = (Nothing, NoTables)

closeTable :: !(Table k v) !*Gerda -> *Gerda
closeTable t=:{name, bufferPointer, insertStmt, updateStmt, selectStmt} g=:{state}
	# state = freeStmt insertStmt state
	  state = freeStmt selectStmt state
	  state = freeStmt updateStmt state
	  (r, state) = LocalFree bufferPointer state
	| r <> 0 = abort "LocalFree failed"
	= {g & state = state}

newTables :: !(Table k v) !Tables !*Gerda -> (!Table k v, !*Gerda)
newTables table tables g
	# (alter, table, g) = createTable table g
	  (alters, tables, g) = createTables tables (if alter (Table table NoTables) NoTables) NoTables g
	  g = alterTables True alters g
	  (table, g) = openTable table g
	  g = openTables tables g
	= (table, g)

openTables :: !Tables !*Gerda -> *Gerda
openTables (Table t ts) g
	# (_, g) = openTable t g
	= openTables ts g
openTables _ g=:{layout} = g

openTable :: !(Table k v) !*Gerda -> (!Table k v, !*Gerda)
openTable t=:{name, columns, primary, key, value, bufferSize, bufferPointer} g=:{layout, connection, state}
	= case extractTable name layout  of
		(Just {some}, ts) = let t = {some & key = key, value = value} in (t, {g & layout = Table t ts})
		_
			# (bufferPointer, state) = LocalAlloc 0 (bufferSize << 2) state
			| bufferPointer == 0 = abort "LocalAlloc failed"

			# (r, insertStmt, state) = SQLAllocHandle SQL_HANDLE_STMT connection state
			| r <> SQL_SUCCESS = abort "SQLAllocHandle SQL_HANDLE_STMT failed"
			# insert = "INSERT INTO " +++ sqlName +++ " VALUES (" +++ separatorList "," ["?" \\ _ <- header] +++ ")"
			  (r, state) = SQLPrepare insertStmt (insert TRACE_SQL insert) (size insert) state
			| r <> SQL_SUCCESS = abort ("SQLPrepare failed " +++ insert)
			# (_, state) = bindParameters header 1 bufferPointer insertStmt state
		
			  (r, selectStmt, state) = SQLAllocHandle SQL_HANDLE_STMT connection state
			| r <> SQL_SUCCESS = abort "SQLAllocHandle SQL_HANDLE_STMT failed"
			# select = "SELECT " +++ separatorList "," [sqlEscape name \\ {name, sqlType} <- columns] +++ " FROM " +++ sqlName +++ wherePrimary
			  (r, state) = SQLPrepare selectStmt (select TRACE_SQL select) (size select) state
			| r <> SQL_SUCCESS = abort ("SQLPrepare failed " +++ select)
			# (p, state) = bindParameters primary 1 bufferPointer selectStmt state
			  state = bindCols columns 1 p selectStmt state
		
			  (r, updateStmt, state) = SQLAllocHandle SQL_HANDLE_STMT connection state
			| r <> SQL_SUCCESS = abort "SQLAllocHandle SQL_HANDLE_STMT failed"
			# update = "UPDATE " +++ sqlName +++ " SET " +++ separatorList "," [sqlEscape name +++ "=?" \\ {name, sqlType} <- columns] +++ wherePrimary
			  (r, state) = SQLPrepare updateStmt (update TRACE_SQL update) (size update) state
			| r <> SQL_SUCCESS = abort ("SQLPrepare failed " +++ update)
			# (_, state) = bindParameters (columns ++ primary) 1 bufferPointer updateStmt state
		
			  t = {t & bufferPointer = bufferPointer, insertStmt = insertStmt, selectStmt = selectStmt, updateStmt = updateStmt}
			= (t, {g & layout = Table t layout, state = state})
where
	header = primary ++ columns
	
	sqlName = sqlEscape name
	
	wherePrimary = " WHERE " +++ separatorList " AND " [sqlEscape name +++ "=?" \\ {name, sqlType} <- primary]

	bindParameters [{sqlType}:cs] i p h state
		# (r, state) = SQLBindParameter h i SQL_PARAM_INPUT c_type sql_type (bytes - 4) 0 (p + 4) 0 p state
		| r <> SQL_SUCCESS = abort "SQLBindParameter failed"
		= bindParameters cs (i + 1) (p + bytes) h state
	where
		bytes = len << 2
		(len, c_type, sql_type, _) = sqlTypeInfo sqlType
	bindParameters _ _ p _ state = (p, state)
	
createTables :: !Tables !Tables !Tables !*Gerda -> (!Tables, !Tables, !*Gerda)
createTables (Table t ts) as rs g
	# (alter, t, g) = createTable t g
	= createTables ts (if alter (Table t as) as) (Table t rs) g
createTables _ as rs g = (as, rs, g)

createTable :: !(Table k v) !*Gerda -> (!Bool, !Table k v, !*Gerda)
createTable t=:{name, columns, primary, key=key=:{gerdaR=readKey,gerdaN=(defKey, nextKey)}, value} g=:{layout}
	= case extractTable name layout of
		(Just {some}, ts) = let t = {some & key = key, value = value} in (False, t, {g & layout = Table t ts})
		_
			# (k, bufferSize, alter, g=:{connection, state}) = createTableIfNotExists g
		
			  t = {t & key = {key & gerdaN = (k, nextKey)}, value = value, bufferSize = bufferSize}
			= (alter, t, {g & state = state})
where
	sqlName = sqlEscape name
	
	createTableIfNotExists g=:{index=previousIndex, buffer=previousBuffer, connection, state}
		# (r, h, state) = SQLAllocHandle SQL_HANDLE_STMT connection state
		| r <> SQL_SUCCESS = abort "SQLAllocHandle SQL_HANDLE_STMT failed"
		# select = "SELECT " +++ separatorList "," ["MAX(" +++ sqlEscape name +++ ")" \\ {name, sqlType} <- primary] +++ " FROM " +++ sqlName
		  (r, state) = SQLExecDirect h (select TRACE_SQL select) (size select) state
		| r == SQL_SUCCESS
			# (p, state) = LocalAlloc 0 (bufferSize << 2) state
			| p == 0 = abort "LocalAlloc failed"
			# state = bindCols primary 1 p h state
			  (r, state) = SQLFetch h state
			  state = freeStmt h state
			| r <> SQL_SUCCESS = abort ("SQLFetch failed " +++ select)
			# (buffer, state) = pointerToBuffer 0 p (createArray bufferSize 0) state
			  (r, state) = LocalFree p state
			| r <> 0 = abort "LocalAlloc failed"
			# (m, g=:{state}) = readKey {g & index = 0, buffer = buffer, state = state}
			= (case m of
				Just key -> case nextKey key of
								(False, key) -> key
								_ -> abort ("Overflow in primary key in table " +++ sqlName)
				_ -> defKey, bufferSize, False, {g & index = previousIndex, buffer = previousBuffer, state = state})
		# create = "CREATE TABLE " +++ sqlName +++ " (" +++ separatorList "," cols +++ ")"
		  (r, state) = SQLExecDirect h (create TRACE_SQL create) (size create) state
		  state = freeStmt h state
		| r <> SQL_SUCCESS = abort ("SQLExecDirect failed: " +++ create)
		= (defKey, bufferSize, alter, {g & state = state})
	where
		(alter, cols, bufferSize) = attributes (primary ++ columns)
		where
			attributes [column=:{name, sqlType, sqlAttr}:columns]
				# (alter, cols, lens) = attributes columns
				  (alter`, attr) = sql2attr True sqlAttr
				  (len, _, _, sql_descr) = sqlTypeInfo sqlType
				= (alter || alter`, [foldl (\x y -> x +++ " " +++ y) (sqlEscape name +++ " " +++ sql_descr) attr:cols], lens + len)
			where
				sql2attr first [SqlUnique:as]
					# (alter, attr) = sql2attr first as
					= (alter, attr ++ ["UNIQUE"])
				sql2attr first [SqlPrimary:as]
					# (alter, attr) = sql2attr False as
					= (alter, attr ++ if first ["PRIMARY KEY"] ["UNIQUE"])
				sql2attr first [SqlReference t:as] 
					# (_, attr) = sql2attr first as
					= (True, attr)
				sql2attr first [SqlNull:as]
					# (alter, attr) = sql2attr first as
					= (alter, ["NULL":filter ((<>) "NOT NULL") attr])
				sql2attr _ _ = (False, ["NOT NULL"])
			attributes _ = (False, [], 0)

alterTables :: !Bool !Tables !*Gerda -> *Gerda
alterTables add (Table t=:{name, columns} ts) g
	# g = alterTables add ts g
	# g = addConstraints 0 (constraints columns) g
	= g
where
	addConstraints i [(n, t):cs] g=:{layout}
		# (m, layout) = extractTable t layout
		  g = case m of
			  	Just {some} -> "Closing table " +++ t TRACE_SQL closeTable some g
			  	_ -> g
		# g=:{connection, state} = {g & layout = layout}
		# (r, h, state) = SQLAllocHandle SQL_HANDLE_STMT connection state
		| r <> SQL_SUCCESS = abort "SQLAllocHandle SQL_HANDLE_STMT failed"
		# symbol = sqlEscape (name +++ toString i)
		# alter = if add
					("ALTER TABLE " +++ sqlEscape name +++ " ADD CONSTRAINT " +++ symbol +++ " FOREIGN KEY (" +++ sqlEscape n +++ ") REFERENCES " +++ sqlEscape t)
					("ALTER TABLE " +++ sqlEscape name +++ " DROP CONSTRAINT " +++ symbol)
		  (r, state) = SQLExecDirect h (alter TRACE_SQL alter) (size alter) state
		  state = freeStmt h state
		| r <> SQL_SUCCESS = abort ("SQLExecDirect failed: " +++ alter)
		# g = {g & state = state}
		  g = case m of
			  	Just {some} 
			  		# (_, g) = "Reopening table " +++ t TRACE_SQL openTable some g
			  		-> g
			  	_ -> g
		= addConstraints (i + 1) cs g
	addConstraints _ _ g = g

	constraints [column=:{name, sqlType, sqlAttr}:columns] = sql2cons sqlAttr ++ constraints columns
	where
		sql2cons [SqlUnique:as] = sql2cons as
		sql2cons [SqlPrimary:as] = sql2cons as
		sql2cons [SqlReference t:as] = [(name, t):sql2cons as]
		sql2cons [SqlNull:as] = sql2cons as
		sql2cons _ = []
	constraints _ = []
alterTables _ _ g = g

bindCols [{sqlType}:cs] i p h state
	# (r, state) = SQLBindCol h i c_type (p + 4) (bytes - 4) p state
	| r <> SQL_SUCCESS = abort "SQLBindCol failed"
	= bindCols cs (i + 1) (p + bytes) h state
where
	bytes = len << 2
	(len, c_type, _, _) = sqlTypeInfo sqlType
bindCols _ _ _ _ state = state

freshCopy :: !GenType !Int -> (!GenType, !Int)
freshCopy t fresh = (s t, fresh`)
where
	(s, fresh`) = makeSubst t fresh
	
	makeSubst (GenTypeVar x) fresh = (subst (toString x) (GenTypeVar (/*toString*/ fresh)), fresh + 1)
	makeSubst (GenTypeApp x y) fresh = (s2 o s1, fresh``)
	where 
		(s1, fresh`) = makeSubst x fresh
		(s2, fresh``) = makeSubst y fresh`
	makeSubst (GenTypeArrow x y) fresh = (s2 o s1, fresh``)
	where 
		(s1, fresh`) = makeSubst x fresh
		(s2, fresh``) = makeSubst y fresh`
	makeSubst _ fresh = (id, fresh)

unify :: ![GenType] ![GenType] -> GenType -> GenType
unify [GenTypeVar x:xs] [GenTypeVar y:ys] | x == y = unify xs ys
unify [GenTypeVar x:xs] [y:ys] 
/*	| not (occurs x y)*/ = unify (map s xs) (map s ys) o s where s = subst (toString x) y
unify [x:xs] [GenTypeVar y:ys] 
/*	| not (occurs y x)*/ = unify (map s xs) (map s ys) o s where s = subst (toString y) x
unify [GenTypeApp x1 x2:xs] [GenTypeApp y1 y2:ys] 
	= unify [x1, x2:xs] [y1, y2:ys]
unify [GenTypeArrow x1 x2:xs] [GenTypeArrow y1 y2:ys] 
	= unify [x1, x2:xs] [y1, y2:ys]
unify [GenTypeCons x:xs] [GenTypeCons y:ys] | x == y = unify xs ys
unify [] [] = id
unify xs ys = abort ("Cannot unify " +++ separatorList "," xs +++ " and " +++ separatorList "," ys)
/*
occurs :: !String !GenType -> Bool
occurs v (GenTypeVar x) = v == x
occurs v (GenTypeCons x) = v == x
occurs v (GenTypeApp x y) = occurs v x || occurs v y
occurs v (GenTypeArrow x y) = occurs v x || occurs v y
*/
subst :: !String !GenType !GenType -> GenType
subst x y (GenTypeApp a b) = GenTypeApp (subst x y a) (subst x y b)
subst x y (GenTypeArrow a b) = GenTypeArrow (subst x y a) (subst x y b)
subst x y (GenTypeVar t) | toString t == x = y
subst _ _ t = t

type2tableName t = f False t
where
	f _ (GenTypeVar x) = toString x
	f _ (GenTypeCons x) = case x of
		"_List" -> "l"
		"Char" -> "h"
		"Int" -> "i"
		"Real" -> "r"
		"Bool" -> "b"
		"OBJECT" -> "o"
		"EITHER" -> "e"
		"CONS" -> "c"
		"PAIR" -> "p"
		"UNIT" -> "u"
		"Maybe" -> "m"
		"Binary252" -> "y"
		"CompactList" -> "k"
		"{}" -> "a"
		"{!}" -> "s"
		"_String" -> "t"
		"GerdaObject" -> "g"
		s | s % (0, 5) == "_Tuple" -> s % (6, size s - 1)
		els -> els
//	f p (GenTypeApp (GenTypeCons "GerdaUnique") a) = f p a
//	f p (GenTypeApp (GenTypeCons "GerdaKey") a) = f p a
	f False (GenTypeApp x y) 
		| l.[size l - 1] == ')' || r.[0] == '(' = l +++ r
		= l +++ " " +++ r
	where
		l = f False x
		r = f True y
	f False (GenTypeArrow x y) = f True x +++ "_" +++ f False y
	f True x = "(" +++ f False x +++ ")"

sqlTypeInfo :: !SqlType -> (!Int, !Int, !Int, !String)
sqlTypeInfo SqlBit = (2, SQL_C_BIT, SQL_BIT, "BIT")
sqlTypeInfo SqlInteger = (2, SQL_C_SLONG, SQL_INTEGER, "INTEGER")
sqlTypeInfo SqlDouble = (3, SQL_C_DOUBLE, SQL_DOUBLE, "DOUBLE")
sqlTypeInfo SqlChar1 = (2, SQL_C_BINARY, SQL_BINARY, "CHAR(1)")
sqlTypeInfo SqlVarChar252 = (64, SQL_C_BINARY, SQL_VARCHAR, "VARCHAR(252)")

separatorList :: !String ![a] -> String | toString a
separatorList s xs = f xs
where
	f [x] = toString x
	f [x:xs] = toString x +++ s +++ f xs
	f _ = ""

instance toString GenType where
	toString x = f x False
	where
		f (GenTypeVar x) _ = toString x
		f (GenTypeCons x) _ = x
		f (GenTypeArrow x y) _ = f x True +++ " -> " +++ f y False
		f (GenTypeApp x y) False = f x False +++ " " +++ f y True
		f t True = "(" +++ f t False +++ ")"

instance == GenType where
	(==) (GenTypeCons x) (GenTypeCons y) = x == y
	(==) (GenTypeApp x1 x2) (GenTypeApp y1 y2) = x1 == y1 && x2 == y2
	(==) (GenTypeArrow x1 x2) (GenTypeArrow y1 y2) = x1 == y1 && x2 == y2
	(==) _ _ = False

instance == SqlAttr where
	(==) SqlNull SqlNull = True
	(==) SqlPrimary SqlPrimary = True
	(==) SqlUnique SqlUnique = True
	(==) (SqlReference t1) (SqlReference t2) = t1 == t2
	(==) _ _ = False

closeStmt :: !SQLHSTMT !*SqlState -> *SqlState
closeStmt stmt state
	# (r, state) = SQLFreeStmt stmt SQL_CLOSE state
	| r <> SQL_SUCCESS = abort "SQLFreeStmt SQL_CLOSE failed"
	= state

unbindStmt :: !SQLHSTMT !*SqlState -> *SqlState
unbindStmt stmt state
	# (r, state) = SQLFreeStmt stmt SQL_UNBIND state
	| r <> SQL_SUCCESS = abort "SQLFreeStmt SQL_UNBIND failed"
	= state

resetStmt :: !SQLHSTMT !*SqlState -> *SqlState
resetStmt stmt state
	# (r, state) = SQLFreeStmt stmt SQL_RESET_PARAMS state
	| r <> SQL_SUCCESS = abort "SQLFreeStmt SQL_RESET_PARAMS failed"
	= state

freeStmt :: !SQLHSTMT !*SqlState -> *SqlState
freeStmt stmt state
	# (r, state) = SQLFreeHandle SQL_HANDLE_STMT stmt state
	| r <> SQL_SUCCESS = abort ("SQLFreeHandle SQL_HANDLE_STMT failed " +++ toString stmt)
	= state

bufferToPointer :: !Int !Int !*{#Int} !*st -> (!*{#Int}, !*st)
bufferToPointer i ptr buffer state
	| i >= size buffer = (buffer, state)
	# (e, buffer) = buffer![i]
	  state = poke ptr e state
	= bufferToPointer (i + 1) (ptr + 4) buffer state

pointerToBuffer :: !Int !Int !*{#Int} !*st -> (!*{#Int}, !*st)
pointerToBuffer i ptr buffer state
	| i >= size buffer = (buffer, state)
	# (x, state) = peek ptr state
	= pointerToBuffer (i + 1) (ptr + 4) {buffer & [i] = x} state

LocalAlloc :: !Int !Int !*st -> (!Int, !*st)
LocalAlloc flags size st = code inline {
		ccall LocalAlloc@8 "PII:I:A"
	}

LocalFree ::  !Int !*st -> (!Int, !*st)
LocalFree p st = code inline {
		ccall LocalFree@4 "PI:I:A"
	}

sqlEscape :: !String -> String
sqlEscape s = toString (['`':escape (fromString s)])
where
	escape [c:cs] 
		| toInt c < 32 = abort ("Illegal SQL string, cannot escape symbol < 32: " +++ s)
		| toInt c > 127 = abort ("Illegal SQL string, cannot escape symbol > 127: " +++ s)
//		| c == '`' = abort ("Illegal SQL string, contains a `: " +++ s)
		| c == '.' = ['"':escape cs]
		| c == '`' = ['\'':escape cs]
		= [c:escape cs]
	escape _ = ['`']

poke :: !Int !Int !*st -> *st
poke p v st = code inline {
    pushI -4
    addI
    push_b_a 0
    pop_b 1
    fill1_r _ 0 1 0 01
.keep 0 1
    pop_a 1
}

peek :: !Int !*st -> (!Int, !*st)
peek p st = code inline {
    push_b_a 0
    pop_b 1
    pushD_a 0
    pop_a 1
}

cast :: !u:a -> v:b
cast _ = code inline {
		pop_a	0
	}

derive bimap GerdaFunctions, (,), (,,), (,,,), [], Maybe
derive gerda CompactList
/*
(++.)	infixr 5	:: !Columns Columns -> Columns
(++.) (Column c cs) ds = Column c (cs ++. ds)
(++.) _ ds = ds

mapColumns f (Column c cs) = [f c:mapColumns f cs]
mapColumns _ _ = []

filterColumns f (Column c cs)
	| f c = Column c (filterColumns f cs)
	= filterColumns f cs
filterColumns _ _ = NoColumns
*/
mapTables f (Table c cs) = [f c:mapTables f cs]
mapTables _ _ = []

instance toString (a, b, c) | toString a & toString b & toString c where
	toString (x, y, z) = "(" +++ toString x +++ "," +++ toString y +++ "," +++ toString z +++ ")"