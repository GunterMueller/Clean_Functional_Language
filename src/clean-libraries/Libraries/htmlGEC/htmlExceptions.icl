implementation module htmlExceptions

import StdMaybe
import htmlFormlib

derive gForm 	Maybe
derive gUpd 	Maybe
derive gPrint 	Maybe
derive gParse 	Maybe
derive bimap    Maybe, (,)

// Exception handling 

Ok						:: Judgement
Ok						= Nothing

noException				:: !Judgement -> Bool
noException judgement	= isNothing judgement

yesException			:: !Judgement -> Bool
yesException judgement	= not (noException judgement)

instance + Judgement where
//	(+) (Just (r1,j1)) (Just (r2,j2)) 	= (Just ((r1 +++ " " +++ r2),(j1 +++ " " +++ j2))) //for debugging
	(+) (Just j1) _ 	= Just j1
	(+) _  (Just j2) 	= Just j2
	(+) _ _ 			= Nothing

ExceptionStore :: !(Judgement -> Judgement) !*HSt -> (Judgement,!*HSt)
ExceptionStore judge hst 
# (judgef,hst)			= mkStoreForm (Init,nFormId "handle_exception" Ok <@ NoForm <@ Temp) judge hst
= (judgef.value,hst)
