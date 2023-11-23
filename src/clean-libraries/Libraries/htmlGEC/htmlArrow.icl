implementation module htmlArrow

import StdFunc, StdList, StdString
import htmlFormlib
import StdArrow

startCircuit :: !(GecCircuit a b) !a !*HSt -> (!Form b,!*HSt) 
startCircuit (HGC circuit) initval hst 
# ((val,body),ch,hst) = circuit ((initval,[]),False,hst)
= (	{changed= ch
	,value	= val
	,form	= reverse (removedup body [])
	},hst)
where
	removedup [] _ = []
	removedup [(id,body):rest] ids
	| isMember id ids = removedup rest ids
	| otherwise = [body: removedup rest [id:ids]]

:: GecCircuit a b 	
	= HGC !((GecCircuitState a)  -> GecCircuitState b)
:: *GecCircuitState a :== *((a, [(String,BodyTag)]), GecCircuitChanged, *HSt )
:: GecCircuitChanged :== Bool


instance Arrow GecCircuit where
	arr fun = HGC fun`
	where
		fun` ((a,body),ch,hst) = ((fun a,body),ch,hst)

	(>>>) (HGC gec_ab) (HGC gec_bc) = HGC (gec_bc o gec_ab)

	first (HGC gec_ab) = HGC first`
	where
		first` (((a,c),prevbody),ch,hst)
		# ((b,bodya),ch,hst) = gec_ab ((a,prevbody),ch,hst)
		= (((b,c),bodya),ch,hst)

edit :: (FormId a) -> GecCircuit a a |  iData a
edit formid = HGC mkApplyEdit`
where
	mkApplyEdit` ((initval,prevbody),ch,hst) 
	# (na,hst) = mkApplyEditForm (Init,setFormId formid initval) initval hst
	= ((na.value,[(formid.id,BodyTag na.form):prevbody]),ch||na.changed,hst) // propagate change

display :: (FormId a) -> GecCircuit a a |  iData a
display formid = HGC mkEditForm`
where
	mkEditForm` ((val,prevbody),ch,hst) 
	# (na,hst) = mkEditForm (Set,setFormId {formid & mode = Display} val) hst
	= ((na.value,[(formid.id,BodyTag na.form):prevbody]),ch||na.changed,hst)

store :: (FormId s) -> GecCircuit (s -> s) s |  iData s
store formid = HGC mkStoreForm`
where
	mkStoreForm` ((fun,prevbody),ch,hst) 
	# (store,hst) = mkStoreForm (Init,formid) fun hst
	= ((store.value,[(formid.id,BodyTag store.form):prevbody]),ch||store.changed,hst)

self :: (a -> a) !(GecCircuit a a) -> GecCircuit a a
self fun gecaa = feedback gecaa (arr fun)
	
feedback :: !(GecCircuit a b) !(GecCircuit b a) -> (GecCircuit a b)
feedback (HGC gec_ab) (HGC gec_ba) = HGC (gec_ab o gec_ba o gec_ab)

loops :: !(GecCircuit (a, b) (c, b)) -> GecCircuit a c |  iData b
loops (HGC gec_abcb) = HGC loopForm
where
	loopForm ((aval,prevbody),ch,hst) 
	# (bstore,hst) = mkStoreForm (Init,xsFormId "??" createDefault) id hst
	# (((cval,bval),bodyac),ch,hst) = gec_abcb (((aval,bstore.value),prevbody),ch,hst)
	# (bstore,hst) = mkStoreForm (Set,xsFormId "??" createDefault) (\_ -> bval) hst
	= ((cval,bodyac),ch,hst)	


(`bindC`) infix 0 :: !(GecCircuit a b) (b -> GecCircuit b c) -> (GecCircuit a c)
(`bindC`) (HGC gecab) bgecbc = HGC binds
where
	binds ((a,abody),ach,hst)
	# ((b,bbody),bch,hst)	= gecab ((a,abody),ach,hst)
	# (HGC gecbc) 			= bgecbc b
	= gecbc ((b,bbody ++ abody),ach||bch,hst) 

(`bindCI`) infix 0 :: !(GecCircuit a b) ((Form b) -> GecCircuit b c) -> (GecCircuit a c)
(`bindCI`) (HGC gecab) bgecbc = HGC binds
where
	binds ((a,abody),ach,hst)
	# ((b,bbody),bch,hst)	= gecab ((a,abody),ach,hst)
	# (HGC gecbc) 			= bgecbc {changed = bch, value = b, form = map snd bbody}
	= gecbc ((b,bbody ++ abody),ach||bch,hst) 

lift :: !(InIDataId a) ((InIDataId a) *HSt -> (Form b,*HSt)) -> GecCircuit a b
lift (Set,formid) fun = HGC fun`
where
	fun` ((a,body),ch,hst)
	# (nb,hst) =  fun (setID formid a) hst
	= ((nb.value,[(formid.id,BodyTag nb.form):body]),ch||nb.changed,hst) 
lift (Init,formid) fun = HGC fun`
where
	fun` ((a,body),ch,hst)
	# (nb,hst) =  fun (Init, setFormId formid a) hst
	= ((nb.value,[(formid.id,BodyTag nb.form):body]),ch||nb.changed,hst) 
