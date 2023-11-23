implementation module dynamicAGEC

import StdEnv
import StdIO
import StdGEC, StdGECExt, StdAGEC
import modeGEC, layoutGEC, basicAGEC
import EstherInterFace
from EstherBackend import toStringDynamic
import StdDynamic, StdPSt, iostate

/* OLD VERSION was to restrictive in a (gGEC{|*|} a)
dynamicAGEC2 :: a -> AGEC a | TC a & gGEC {|*|} a	 					
dynamicAGEC2 v = mkAGEC { toGEC   = toExpr
					  , fromGEC = fromExpr
					  , updGEC  = updExpr
					  , value   = v
//					  } ("dynamicGEC2")
					  } ("dynamicGEC2" +++ ShowValueDynamic (dynamic v))
where
	toExpr v Undefined 		= display v (prettyVal  v)
	toExpr v (Defined b)	= b 				

	display v s 			= DynStr (dynamic v) s <-> hidAGEC (v,s)

	fromExpr (_ <-> hvs )	= fst (^^ hvs)
	fromExpr _ = undef
	
	updExpr (DynStr nd=:(d::a^) s <-> _)	= display d s
	updExpr (_ <-> hvs) 					= display (fst (^^ hvs)) (snd (^^ hvs))

	prettyVal  v  	= fst (toStringDynamic (dynamic v))
*/

dynamicAGEC :: d -> AGEC d | TC d
dynamicAGEC dv = mkAGEC { toGEC   = toExpr
						 , fromGEC = fromExpr dv
						 , updGEC  = \vv ps -> (True,updExpr dv vv,ps)
						 , value   = dv
						 , pred	   = \t -> (DontTest,t)
//						 } ("dynamicGEC2")
						 } ("dynamicGEC2" +++ ShowValueDynamic (dynamic dv))
where
	toExpr dv Undefined 	= display dv (prettyVal dv)
	toExpr dv (Defined vv)	= vv

//	display dv ds 			= (DynStr (dynamic dv) ds,hidAGEC (DynStr (dynamic dv) ds))
	display dv ds = let dx = DynStr (dynamic dv) ds in (dx,hidAGEC dx)

	fromExpr :: d (DynString, AGEC DynString) -> d | TC d
	fromExpr _ (_,oldd)		= case (^^oldd) of
								DynStr (dv::d^) _ -> dv
	
	updExpr :: d (DynString, AGEC DynString) -> (DynString, AGEC DynString) | TC d
	updExpr _ (newd=:(DynStr (dv::d^) s),_)
							= (newd, hidAGEC newd)
	updExpr _ (_, oldd)		= (^^oldd, oldd)

	prettyVal x				= foldr (+++) "" (fst (toStringDynamic (dynamic x)))

/*dynamicAGEC :: a -> AGEC a | TC a & gGEC {|*|} a	 					
dynamicAGEC v = mkAGEC { toGEC   = toExpr
					  , fromGEC = fromExpr
					  , updGEC  = updExpr
					  , value   = v
					  } ("dynamicGEC")
//					  } ("dynamicGEC" +++ (snd(prettyDynamic (dynamic v))))
where
	toExpr v Undefined 		= display v (prettyVal  v)
	toExpr v (Defined b)	= b 				

	display v s 		= prettyValD v s <-> prettyType v <-> DynStr (dynamic v) s <-> hidAGEC (v,s) 

	fromExpr (_ <-> _ <-> _ <-> hvs)	= fst (^^ hvs)
	
	updExpr ( _ <-> _ <-> DynStr nd=:(d::a^) s <-> hvs)	= display d s
	updExpr ( _ <-> _ <-> _ <-> hvs) 					= display (fst (^^ hvs)) (snd (^^ hvs))

	prettyVal  v  	= fst (toStringDynamic (dynamic v))
	prettyValD v s	= case (dynamic v) of
						(x::(a -> b)) = Display (strip(s +++ " "))
						else		  = Display (fst(toStringDynamic (dynamic v)) +++ " ")  // +++ " " caused by bug in Display
	prettyType v	= Display (":: " +++ (snd(toStringDynamic (dynamic v))) +++ " ")
*/
	
:: DynString = DynStr Dynamic String

gGEC{|DynString|} gecArgs=:{gec_value=mbexpr,update=biupdate} pSt
	= case mbexpr of 
		Just dynexprGEC=:(DynStr dyn str) 
					= convert dynexprGEC (gGEC{|*|} {gecArgs & gec_value=Just str,update=bupdate dynexprGEC} pSt)
//		Nothing		= abort "Cannot make up function value for Dynam"
		Nothing		= convert (DynStr (dynamic "") "") (gGEC{|*|} {gecArgs & gec_value=Just "",update=bupdate (DynStr (dynamic "") "")} pSt)
where
	convert dynexprGEC (ahandle,pst) 
					= ({ahandle & gecSetValue = AGECSetValue ahandle.gecSetValue ahandle.gecGetValue
	                            , gecGetValue = AGECGetValue dynexprGEC ahandle.gecGetValue
	                   },pst)

	AGECSetValue aSetValue aGetValue upd (DynStr dyn str) pst  
					= aSetValue upd str pst
	AGECGetValue (DynStr dyn str) aGetValue pst
		# (nstr,pst) = aGetValue pst
		  (ndyn,pst) = applyWorld (stringToDynamic nstr) pst
		= (DynStr ndyn nstr,pst)
	
	bupdate (DynStr dyn str) reason nstr pst 
	# (ndyn,pst)= applyWorld (stringToDynamic nstr) pst
	= biupdate reason (DynStr ndyn nstr) pst

applyWorld :: (*World -> (!a,!*World)) *(PSt .pst) -> (!a,!*(PSt .pst))
applyWorld funworld pst
# (w,pst) 	= accPIO ioStGetWorld pst
  (a,w)		= funworld w
  pst 		= appPIO (ioStSetWorld w) pst
= (a,pst)

// this instance was needed because I could not create an instance of gGEC for ::T a  without | gGEC {|a|} a

gGEC{|(->)|} gGECa gGECb args=:{gec_value = Just (id), update = modeupdate} pSt
= createDummyGEC OutputOnly (id) modeupdate pSt
gGEC{|(->)|} gGECa gGECb args=:{gec_value = Nothing, update = modeupdate} pSt
= createDummyGEC OutputOnly (undef) modeupdate pSt

ShowValueDynamic :: Dynamic -> String
ShowValueDynamic d = strip (foldr (+++) "" (fst (toStringDynamic d)) +++ " ")

ShowTypeDynamic :: Dynamic -> String
ShowTypeDynamic d = strip (snd (toStringDynamic d) +++ " ")

strip s = { ns \\ ns <-: s | ns >= '\020' && ns <= '\0200'}

	
ggen{|Dynamic|} trace stream = [dynamic 0 :: Int \\ i <- [0..] ]