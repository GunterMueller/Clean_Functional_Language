module estherGEC

import StdEnv
import StdGEC
import StdDynamic
import EstherInterFace

// TO TEST JUST REPLACE THE EXAMPLE NAME IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF FORM pst -> pst

goGui :: (*(PSt u:Void) -> *(PSt u:Void)) *World -> .World
goGui gui world = startIO MDI Void gui [ProcessClose closeProcess] world

Start :: *World -> *World
Start world 
= 	goGui 
 	test9
 	world  

//testX = CGEC (gecEdit "test")  (dynamicGEC 23)

derive gGEC MyRecord, MyRecord2, T
				
:: MyRecord a =  { arg:: AGEC a
				 , fun:: AGEC (a -> a)
				 , fun_arg:: AGEC a 
				 }

/*test1 = CGEC (selfGEC "self" calcsum) 	{ arg	  = dynamicGEC 0
							  			, fun	  = dynamicGEC id
							  			, fun_arg = modeGEC (Display 0)}
where
	calcsum  rec = {rec & MyRecord.fun_arg = rec.MyRecord.fun_arg ^= (^^ rec.fun) (^^ rec.arg)}
*/
:: MyRecord2 a =  { field1:: AGEC a
				  , field2:: AGEC a
				  , sum:: AGEC a 
				  }

/*test2 = CGEC (selfGEC "self" calcsum) 	{ field1	= counterGEC 0
							  			, field2	= dynamicGEC 0
							  			, sum 		= modeGEC (Display 0)}
where
	calcsum rec = {rec & MyRecord2.sum = rec.MyRecord2.sum ^= (^^ rec.field1 + ^^ rec.field2)}
*/
:: T a b = C a | B Int Real b a
/* PA: uit arren moede in commentaar gezet omdat de compiler anders crasht...
:: Tdyn :== T DynString DynString

fromDynString :: a DynString -> a | TC a
fromDynString _ (DynStr (v::a^) _) = v
fromDynString v _ = v

toDynString :: a  -> DynString | TC a & toString a
toDynString v = DynStr (dynamic v) (toString v)

mapFDS dynstr i r = gMap {|* -> * -> *|} (fromDynString i) (fromDynString r) dynstr
mapTDS tab = gMap {|* -> * -> *|} toDynString toDynString tab

mapFDS2 dynstr  = gMap {|* -> * |}  (^^)  dynstr
mapTDS2 tab = gMap {|* -> * |} counterGEC  tab

//	mapFDS dynstr i r = gMap {|* -> * -> *|} (^^) (fromDynString r)  dynstr
//	mapTDS tab = gMap {|* -> * -> *|} counterGEC toDynString  tab

//	mapFDS dynstr i r = gMap {|* -> * -> *|} (^^) (^^)  dynstr
//	mapTDS tab = gMap {|* -> * -> *|} counterGEC dynamicGEC  tab
*/
import GenMap
derive gMap T
/*
test3 = CGEC (selfGEC "self" calc) (mapTDS init,init)	
where
	init = B 3 4.5 22 5
	
//	calc :: (T (AGEC Int) DynString, T Int Bool) -> (T (AGEC Int) DynString, T Int Bool)
	calc (dyn,val) =   (ndyn, nval) 
	where
		ndyn = mapTDS nval
		nval = mapFDS dyn 5 22
*/

:: MyRecord3 a b c =  	{ val1::  a
				  		, val2::  b
				  		, res ::  c 
				  		}
				  		
derive gMap MyRecord3
derive gGEC MyRecord3

test4 = startCircuit (feedback (edit "self" >>> arr convert)) (mapTo init)	
where
	init = 	{ val1	= 0.0
			, val2	= 0.0
			, res 	= 0.0}
	
	calcsum rec = {rec & MyRecord3.res = rec.val1 + rec.val2}
		
	convert = mapTo o calcsum o mapFrom

	mapFrom agec  	= gMap {|* -> * -> * -> *|} (^^) (^^) (^^) agec
	mapTo val 		= gMap {|* -> * -> * -> *|} counterAGEC dynamicAGEC (modeAGEC o Display) val





:: X a = X a
derive gGEC X

//test7 = CGEC (selfGEC "self" convert2) (mapto2 init) //(mapTo init)	
test7 = startCircuit (edit "self" >>> arr mapto2) init //(mapTo init)	
where
	init = 	X (3,(idAGEC [1..3]))

	mapto2 (X (n,list`)) = if (isEven (length list)) (X (n,(idAGEC  (mytest list)))) 
												 (X (n,(horlistAGEC (mytest list))))
	where
		list = ^^ list`											

	convert2 list = list
	
	mytest [x:xs] = [x+1,x:xs]
	mytest [] = [1]
		
	convert = mapTo o mytest o mapFrom

	mapFrom agec  	= gMap {|* -> * |} (^^) agec
	mapTo val 		= gMap {|* -> * |} horlistAGEC val

/*	PA: voorbeelden uit APLAS 2004 artikel:
*/
/*	Section 4.1. Example 1
	Problem with this definition is that it does not recover previous input when guiApply fails.

:: MyRecord8 = { function :: DynString
               , argument :: DynString
               , result   :: DynString }
derive gGEC MyRecord8

test8
   = startCircuit (feedback (guiApply @>> edit "test"))
                  (initval ((+) 1) 3)
where
   initval f v = { function = mkDynStr f
                 , argument = mkDynStr v
                 , result   = mkDynStr (f v) }
   guiApply all=:{ function = DynStr (f::a -> b) _
                 , argument = DynStr (v::a) _}
                 = {all & result = mkDynStr (f v)}
   guiApply else = else
*/
mkDynStr x = let dx = dynamic x in DynStr dx (ShowValueDynamic dx)

derive ggen Mode, DynString, MyRecord3, T, X, MyRecord10
ggen {|(->)|} ga gb i is = undef


/*	Section 4.1. Example 2
*/
test9
   = startCircuit (feedback (arr (guiApply o (^^)) >>> edit "test" ))
                  (vertlistAGEC [show "expression " 0])
where
   guiApply [f:args]
      = vertlistAGEC [f : check (fromDynStr f) args]
   where
      check (f::a -> b) [(_,DynStr (x::a) _):xs]
         = [show "argument " x : check (dynamic f x) xs]
      check (f::a -> b) _ = [show "argument " "??"]
      check (x::a)      _ = [show "result "   x]

   show s v = (Display s,mkDynStr v)
   fromDynStr (_,(DynStr d _)) = d

/*	Section 4.2. Example 1
*/
:: MyRecord10 a b = { function :: AGEC (a -> b)
                    , argument :: AGEC a
                    , result   :: AGEC b }
derive gGEC MyRecord10

test10
   = startCircuit (feedback (arr guiApply >>> edit "test"))
                  (initval ((+) 1.0) 3.0)
where
   initval f v = { function = dynamicAGEC f
                 , argument = dynamicAGEC v
                 , result   = displayAGEC (f v) }
   guiApply all=:{ function = af
                 , argument = av }
      = {all & result = displayAGEC ((^^af)(^^av))}

displayAGEC x = modeAGEC (Display x)


/*	Section 4.2. Example 2
*/
test11
   = startCircuit (feedback (arr guiApply >>> edit "test"))
                  (initval ((+) 1.0) 3.0)
where
   initval f v = { function = dynamicAGEC f
                 , argument = counterAGEC v
                 , result   = displayAGEC (f v) }
   guiApply all=:{ function = af
                 , argument = av }
      = {all & result = displayAGEC ((^^af)(^^av))}
