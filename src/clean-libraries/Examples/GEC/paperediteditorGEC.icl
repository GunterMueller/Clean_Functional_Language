module paperediteditorGEC

// editor that can be used to design and test another editor --MJP

import StdEnv
import StdIO
import StdGEC

:: Bug = C1 | C2

derive gGEC Bug


Start :: *World -> *World
Start world = goGui testDynamic world  
//Start world = goGui testDynamic world  
/*
Start world = goGui mytest world
where
	mytest pst = pst1 
	where	
	    (hndl,pst1) = createNGEC  "test" Interactive (vertlistAGEC [(3,C1)]) (set hndl) pst
	   
	    set handl _ list pst = handl.gecSetValue NoUpdate (vertlistAGEC (test1 (^^ list))) pst
	
		test1 [x:xs] = [x,x:xs]
		test1 else = else
*/	

derive gGEC Maybe 

gecEdit :== edit
(@|) infixr 8
(@|) f g :== arr f >>> g
(|@) infixr 8
(|@) g f :== g >>> arr f
%| :== feedback
(|>>>|) infixr 1
(|>>>|) :== (>>>)
CGEC :== startCircuit
:: CGEC a b :== GecCircuit a b

derive ggen DynString, Command, Editor, TypeVal, Maybe, ApplicationElem
ggen {|(->)|} ga gb i is = undef

testDynamic = CGEC  (%| (dotest @| gecEdit "test" ))  initval  
where	
	initval  = horlistAGEC [testinit] <|> showAGEC ":: String"
	testinit = DynStr (dynamic "") "Type expression:"
	 
	dotest (list <|> _) = horlistAGEC (checkdyn (^^ list)) <|>  showAGEC (showdyn (^^ list))
	where
		checkdyn [x:xs] 	= [x:check (strip x) xs]
		where
			check (f::a -> b) [d2=:DynStr (x::a) s:xs] 	= [d2: check (dynamic undef :: b) xs]
			check dyn=:(f::a -> b) else 				= [testinit]
			check dyn _ 								= []

		showdyn [x:xs] 	= show (strip x) xs
		where
			show (f::a -> b) [d2=:DynStr (x::a) s:xs] 	= show (dynamic (f x)) xs
			show dyn=:(f::a -> b) else 					= ShowTypeDynamic  dyn
			show dyn _ 									= ShowValueDynamic dyn

		strip (DynStr d str) = d

goGui :: (*(PSt u:Void) -> *(PSt u:Void)) *World -> .World
goGui gui world = startIO MDI Void gui [ProcessClose closeProcess] world


// The Editors and Circuits:

derive gGEC TypeVal, Editor, Command, ApplicationElem

editoreditor = CGEC (designeditor |@ convert |>>>| applicationeditor) initvalue
where
	designeditor :: CGEC DesignEditor DesignEditor
	designeditor 		= %| (toDesignEditor @| gecEdit "design" |@ updateDesign o fromDesignEditor)

	applicationeditor :: CGEC ApplicationEditor ApplicationEditor
	applicationeditor 	= %| (toApplicEditor o updateApplication @| gecEdit "application" |@ fromApplicEditor)

	toDesignEditor   (table,clipboard) = (listAGEC True (map vertlistAGEC table),hidAGEC clipboard)
	fromDesignEditor (table,clipboard) = (map (^^) (^^ table),^^ clipboard)

	toApplicEditor		= table_vh_AGEC	
	fromApplicEditor	= ^^
	
// Initial value of design editor

initvalue	= ([[initelem,initelem,initelem],[initelem,initelem]],zeroValue)
initelem	= (Choose,zeroValue)
zeroValue 	= (Identity,Int_ 0)

// the design editor types:

:: DesignEditor :== (DesignTable,Clipboard)				// the table is displayed as col x rows
:: DesignTable	:== [[(Command,Element)]]
:: Clipboard	:== Element
:: Element 		:== (Editor,TypeVal)
:: TableIndex	:== (Int,Int)			

:: TypeVal 	= F_I_I   (Maybe (PAIR (AGEC (Int -> Int))      TableIndex))		 // define function :: Int -> Int 
			| F_R_R   (Maybe (PAIR (AGEC (Real -> Real))    TableIndex)) 		 // define function :: Real -> Real
			| F_LI_I  (Maybe (PAIR (AGEC ([Int] -> Int))   (AGEC [TableIndex]))) // define function :: [Int] -> Int
			| F_LR_R  (Maybe (PAIR (AGEC ([Real] -> Real)) (AGEC [TableIndex]))) // define function :: [Real] -> Real
			| Dyn_    (Maybe (PAIR DynString (AGEC [TableIndex]))) 				 // any dynamic 								
			| String_ String										// define initial string 								
			| Real_   Real											// define initial real value 
			| Int_ 	  Int											// define initial int value (default)
			
:: Editor 	= Counter												// ad counter
			| Displayval											// display non editable value
			| Calculator											// ad Calculator
			| Expression											// allow expressions /function definitions
			| Identity 												// identity editor (default)

:: Command	= Insert												// insert element from clipboard
			| Append												// append element from clipboard
			| Delete												// delete element
			| UpWards												// move   element upwards
			| DownWards												// move   element downwards
			| Copy													// copy   element to clipboard
			| Paste													// paste  element from clipboard
			| Choose												// noop (default)

:: Maybe2 a b :== Maybe (<|> a b)
// create default functions


// Update of design editor

updateDesign :: DesignEditor -> DesignEditor
updateDesign (table,s) =  (keepone (update newclipboard (initfuns table)),newclipboard)
where
	keepone [] = [[initelem]]		// to ensure that there is at least one element...
	keepone xs = xs

	newclipboard = case [elem \\ col <- table, (Copy,elem) <- col] of // copy to clipboard
					[elem] -> elem
					else   -> s

	update :: Clipboard DesignTable -> DesignTable // all other commands ...
	update cb table = map (update_col cb) table 
	where
		update_col cb [(Paste,elem):xs] 		= [(Choose,cb):xs]
		update_col cb [(Insert,elem):xs] 		= [(Choose,cb),(Choose,elem):xs]
		update_col cb [(Append,elem):xs] 		= [(Choose,elem),(Choose,cb):xs]
		update_col cb [(Delete,_   ):xs] 		= xs
		update_col cb [(DownWards,elem),y:xs]	= [y,(Choose,elem):xs]
		update_col cb [x,(UpWards,elem):xs] 	= [(Choose,elem),x:xs]
		update_col cb [(_,elem):xs]   	  		= [(Choose,elem):update_col cb xs] 
		update_col cb []      		  	  		= []

	initfuns :: DesignTable -> DesignTable
	initfuns table = map (map initfun) table // fill in proper default functions
	where
		initfun :: (Command,Element) -> (Command,Element)
		initfun (c,(e,typeval)) = (c,(e,init typeval))

		init (F_I_I  Nothing) = (F_I_I  (Just (PAIR (dynamicAGEC (const 0  )) (0,0))))
		init (F_R_R  Nothing) = (F_R_R  (Just (PAIR (dynamicAGEC (const 0.0)) (0,0))))
		init (F_LI_I Nothing) = (F_LI_I (Just (PAIR (dynamicAGEC (const 0))   (dynamicAGEC []))))
		init (F_LR_R Nothing) = (F_LR_R (Just (PAIR (dynamicAGEC (const 0.0)) (dynamicAGEC []))))
		init (Dyn_   Nothing) = (Dyn_   (Just (PAIR (DynStr (dynamic 0) "0") (dynamicAGEC [])))) 
		init elem = elem

// the application editor types:

:: ApplicationEditor :== [[ApplicationElem]]

:: ApplicationElem											
			= AF_I_I 	(AGEC String) (AGEC (Int->Int,	   TableIndex ))
			| AF_R_R 	(AGEC String) (AGEC (Real->Real,   TableIndex ))
			| AF_LI_I 	(AGEC String) (AGEC ([Int]->Int,  [TableIndex]))
			| AF_LR_R 	(AGEC String) (AGEC ([Real]->Real,[TableIndex]))
			| AF_Dyn 	(AGEC String) (AGEC (DynString,   [TableIndex]))
			| AInt_		(AGEC Int)
			| AReal_	(AGEC Real)
			| AString_ 	(AGEC String)

// turn design editor info in working user application editor

convert :: DesignEditor -> ApplicationEditor
convert (table,clipboard) = map (map (toAppl o snd)) table
where
	toAppl (Calculator, Int_ i)				= AInt_		(intcalcAGEC i)
	toAppl (agec,       Int_ i)				= AInt_ 	(chooseAGEC agec i)
	toAppl (Calculator, Real_ r) 			= AReal_  	(realcalcAGEC r)
	toAppl (agec,	    Real_ r) 			= AReal_	(chooseAGEC agec r)
	toAppl (Displayval, String_ s)			= AString_ 	(showAGEC s)
	toAppl (_, 			String_ s) 			= AString_ 	(idAGEC s)
	toAppl (_, F_I_I  (Just (PAIR f ix)))	= AF_I_I  	(showAGEC "") (hidAGEC (^^ f, ix))
	toAppl (_, F_R_R  (Just (PAIR f ix)))	= AF_R_R  	(showAGEC "") (hidAGEC (^^ f, ix))
	toAppl (_, F_LI_I (Just (PAIR f ix)))	= AF_LI_I  	(showAGEC "") (hidAGEC (^^ f, ^^ ix))
	toAppl (_, F_LR_R (Just (PAIR f ix)))	= AF_LR_R  	(showAGEC "") (hidAGEC (^^ f, ^^ ix))
	toAppl (_, Dyn_   (Just (PAIR d ix)))	= AF_Dyn  	(showAGEC "") (hidAGEC (   d, ^^ ix))
	toAppl _					 			= AString_ 	(showAGEC "not implemented")

	chooseAGEC Counter 		= counterAGEC
	chooseAGEC Displayval 	= showAGEC
	chooseAGEC Expression 	= dynamicAGEC
	chooseAGEC _ 			= idAGEC

// the handling of the application editor boils down to applying all defined functions like in a spreadsheet ...

updateApplication :: ApplicationEditor -> ApplicationEditor
updateApplication table = map (map updatefun) table
where
	updatefun (AF_I_I  _ fix) = AF_I_I  (showIFUN (applyfii  fix)) fix
	updatefun (AF_R_R  _ fix) = AF_R_R  (showRFUN (applyfrr  fix)) fix
	updatefun (AF_LI_I _ fix) = AF_LI_I (showIFUN (applyflii fix)) fix
	updatefun (AF_LR_R _ fix) = AF_LR_R (showRFUN (applyflrr fix)) fix
	updatefun (AF_Dyn  _ fix) = AF_Dyn  (showDyn  (applydyn  fix)) fix
	updatefun x 			 = x

	showIFUN :: (Bool,Bool,Int) -> AGEC String
	showIFUN (bix,bty,ival)
		| bix	= showAGEC "Index error "
		| bty	= showAGEC "Int arg expected "
		= showAGEC (ToString ival)
	
	showRFUN :: (Bool,Bool,Real) -> AGEC String
	showRFUN (bix,bty,rval)
		| bix	= showAGEC "Index error "
		| bty	= showAGEC "Real arg expected "
		= showAGEC (ToString rval)

	showDyn :: (Bool,Bool,Dynamic) -> AGEC String
	showDyn (bix,bty,rval)
		| bix	= showAGEC "Index error "
		| bty	= showAGEC "Dynamic Type Error "
		= case rval of
			dyn=:(f::a -> b) -> (showAGEC (ShowTypeDynamic   dyn))
			dyn				 -> (showAGEC (ShowValueDynamic  dyn))

	applyfii  fix = calcfli (f o hd) [ix] 	where (f,ix) = ^^ fix
	applyflii fix = calcfli f ix			where (f,ix) = ^^ fix
	applyfrr  fix = calcflr (f o hd) [ix] 	where (f,ix) = ^^ fix
	applyflrr fix = calcflr f ix 			where (f,ix) = ^^ fix
	applydyn  fix = calcdyn f ix 			where (f,ix) = ^^ fix

	calcfli :: ([Int] -> Int) [TableIndex] -> (Bool,Bool,Int)
	calcfli f indexlist
	# res				= map tryGetIntArg indexlist
	= (or (map fst3 res),or (map snd3 res),f (map thd3 res)) 
	
	calcflr :: ([Real] -> Real) [TableIndex] -> (Bool,Bool,Real)
	calcflr f indexlist
	# res				= map tryGetRealArg indexlist
	= (or (map fst3 res),or (map snd3 res),f (map thd3 res)) 

	calcdyn :: DynString [TableIndex] -> (Bool,Bool,Dynamic)
	calcdyn (DynStr d=:(f::[a]->b) s) indexlist
	# res				= map (tryDynArgs d) indexlist
	= (or (map fst3 res),or (map snd3 res),apply d (dynamic [] :: A.c: [c]) (map thd3 res))
	where
		apply :: Dynamic Dynamic [Dynamic] -> Dynamic
		apply d=:(f::[a] -> b) (acc::[a]) [(x::a):xs] = apply d (dynamic [x:acc]) xs
		apply d=:(f::[a] -> b) (acc::[a]) [(x::c):xs] = dynamic "list type error"
		apply d=:(f::[a] -> b) (acc::[a]) [] = dynamic (f (reverse acc))

	calcdyn (DynStr dyn s) indexlist
	= (False,False,dyn) 

	tryGetIntArg :: TableIndex -> (Bool,Bool,Int)
	tryGetIntArg (r,c) 
	| checkBounds (r,c) = (True,False,0)
	= fetchIntVal (table!!c!!r)
	where
			fetchIntVal (AInt_ i) 		= (False,False,^^ i)
			fetchIntVal (AF_I_I  _ fi) 	= applyfii fi
			fetchIntVal (AF_LI_I _ fi) 	= applyflii fi
			fetchIntVal _ 				= (False,True,0)
				 
	tryGetRealArg :: TableIndex -> (Bool,Bool,Real)
	tryGetRealArg (r,c)
	| checkBounds (r,c) = (True,False,0.0)
	= fetchRealVal (table!!c!!r)
	where
			fetchRealVal (AReal_ r) 	= (False,False,^^ r)
			fetchRealVal (AF_R_R  _ fi) = applyfrr fi
			fetchRealVal (AF_LR_R _ fi) = applyflrr fi
			fetchRealVal _ 				= (False,True,0.0)

	tryDynArgs :: Dynamic TableIndex -> (Bool,Bool,Dynamic)
	tryDynArgs (f::[a]->b) (r,c)
	| checkBounds (r,c) = (True,False,dynamic "error")
	= fetchDynVal (table!!c!!r) (dynamic undef :: a)
	where
			fetchDynVal (AInt_ i)      (nn::Int)  = (False,False,dynamic (^^ i))
			fetchDynVal (AF_I_I  _ fi) (nn::Int)  = mkdyn (applyfii  fi)
			fetchDynVal (AF_LI_I _ fi) (nn::Int)  = mkdyn (applyflii fi)
			fetchDynVal (AReal_ r) 	   (nn::Real) = (False,False,dynamic (^^ r))
			fetchDynVal (AF_R_R  _ fi) (nn::Real) = mkdyn (applyfrr  fi)
			fetchDynVal (AF_LR_R _ fi) (nn::Real) = mkdyn (applyflrr fi)
			fetchDynVal (AString_ s)   (nn::Int)  = (False,False,dynamic (^^ s))
			fetchDynVal (AF_Dyn  _ fi) _ 		  = (applydyn fi)
			fetchDynVal _   _ 					  = (False,True,dynamic (23))
			
			mkdyn (b1,b2,v) = (b1,b2,dynamic v)

	checkBounds (i,j) = j < 0 || j >= length table || i < 0 || i >= length (table!!j)

// small auxilery functions

showAGEC i = (modeAGEC (Display ( i)))

ToString v = toString v +++ " "


