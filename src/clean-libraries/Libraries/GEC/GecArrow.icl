implementation module GecArrow

import StdArrow, StdGECExt
import store, GenDefault, StdDebug
import StdMisc, StdFunc

:: GecCircuit a b = GecCircuit !.(A. .ps: (GecSet b ps) *(PSt ps) -> *(GecSet a ps, *PSt ps))

:: GecSet a ps :== a *(PSt ps) -> *PSt ps

startGEC :: ((PSt Void) -> (PSt Void)) *World -> *World
startGEC editor world = startIO MDI Void editor [ProcessClose closeProcess] world


runCircuit (GecCircuit k) = k

startCircuit :: !(GecCircuit a b) a !*(PSt .ps) -> *PSt .ps
startCircuit g a env = thd3 (evalCircuit (const id) g a env)
	
evalCircuit :: (CircuitCB b .ps) !(GecCircuit a b) a !*(PSt .ps) -> (CircuitGet b .ps, CircuitSet a .ps, *PSt .ps)
evalCircuit cb g a env
	# (id_b, env) = openStore` Nothing env
	  (seta, env) = runCircuit g (evalCircuit_setb cb id_b) env
	= (readStore id_b, seta, seta a env)
where
	evalCircuit_setb cb id_b b env 
		# env = writeStore id_b b env
		= cb b env

edit :: String -> GecCircuit a a | gGEC{|*|} a 
edit title = gecEdit True title
	
display :: String -> GecCircuit a a | gGEC{|*|} a 
display title = gecEdit False title

gecEdit :: Bool String -> GecCircuit a a | gGEC{|*|} a 
gecEdit edit title = GecCircuit k
where
	k seta env 
		# (id_rec, env) = openStore` Nothing env
		= (gecEdit_seta seta id_rec, env)
		
	gecEdit_seta seta id_rec a env
		# (ok, env) = valueStored id_rec env
		  ({gecSetValue}, env) = case ok of
					  	True -> readStore id_rec env
					  	_
							# (rec, env) = createNGEC title (if edit Interactive OutputOnly) 
											True a (\_ -> seta) env
							  env = writeStore id_rec rec env
							-> (rec, env)
		= gecSetValue YesUpdate a env

gecMouse :: String -> GecCircuit a MouseState
gecMouse title = GecCircuit k
where
	k seta env
		# (_, env) = createMouseGEC title Interactive (\r -> seta) env
		= (\_ env -> env, env)

instance Arrow GecCircuit
where
	arr f = GecCircuit k
	where
		k setb env = (arr_seta setb f, env)

		arr_seta setb f a env = setb (f a) env
	
	(>>>) l r = GecCircuit k
	where 
		k setc env 
			# (setb, env) = runCircuit r setc env
			= runCircuit l setb env

	first g = GecCircuit k
	where
		k setbc env 
			# (id_c, env) = openStore` Nothing env
			  (seta, env) = runCircuit g (first_setb id_c setbc) env
			= (first_setac id_c seta, env)
		
		first_setac id_c seta ac env
			# env = writeStore id_c (snd ac) env
			= seta (fst ac) env

		first_setb id_c setbc b env 
			# (c, env) = readStore id_c env
			= setbc (b, c) env

instance ArrowChoice GecCircuit
where
	left g = GecCircuit k
	where
		k setbc env 
			# (seta, env) = runCircuit g (left_setb setbc) env
			= (left_setac seta setbc, env)

		left_setac seta setbc (LEft a) env = seta a env
		left_setac seta setbc (RIght c) env = setbc (RIght c) env

		left_setb setbc b env = setbc (LEft b) env

instance ArrowLoop GecCircuit
where
	loop g = GecCircuit k
	where
		k setc env 
			# (id_b, env) = openStore` Nothing env
			  (setab, env) = runCircuit g (loop_setcb setc id_b) env
			= (loop_seta setab id_b, env)

		loop_setcb setc id_b cb env
			# env = setc (fst cb) env
			= writeStore id_b (snd cb) env
		
		loop_seta setab id_b a env = env`
		where
			(b, env`) = readStore id_b (setab (a, b) env)

instance ArrowCircuit GecCircuit
where
	delay a = GecCircuit k
	where
		k seta env 
			# (id_a, env) = openStore` (Just a) env
			= (delay_seta seta id_a, env)

		delay_seta seta id_a a` env
			# (a, env) = readStore id_a env
			  env = seta a env
			= writeStore id_a a` env

probe :: String -> GecCircuit a a | toString a
probe s = GecCircuit k
where
	k seta env = (probe_seta seta, env)
	
	probe_seta seta a env
		| trace (s +++ ": ") False = undef
		| trace_n a False = undef
		= seta a env

self :: (GecCircuit a b) (GecCircuit b a) -> GecCircuit a b
self g f = GecCircuit k
where 
	k seta env 
		# (id_B, env) = openStore` (Just False) env
		  (seta`, env) = self_k` id_B seta env
		= (self_seta id_B seta`, env)

	self_k` id_B seta env = (gseta, env``)
	where
		(fseta, env`) = runCircuit f gseta env
		(gseta, env``) = runCircuit g (self_setrec id_B seta fseta) env`

	self_setrec id_B setout setrec a env 
		# (exit, env) = readStore id_B env
		  env = writeStore id_B (not exit) env
		= (if exit setout setrec) a env

	self_seta id_B seta a env 
		# env = writeStore id_B False env
		= seta a env

	/* = arr addLEFT >>> feedback (first g >>> arr selectX >>> f >>> arr addRIGHT) >>> arr fst
	where
		addLEFT x = (x, LEFT x)
		selectX (x, LEFT _) = x
		selectX (_, RIGHT x) = x
		addRIGHT x = (x, RIGHT x)*/

feedback :: (GecCircuit a a) -> GecCircuit a a
feedback g = self g (arr id)

sink :: GecCircuit a Void
sink = GecCircuit k
where
	k _ env = (\_ env -> env, env)

source :: (GecCircuit a b) -> GecCircuit Void b
source g = GecCircuit k
where
	k setb env 
		# (_, env) = runCircuit g setb env
		= (\_ env -> env, env)

flowControl :: (a -> Maybe b) -> GecCircuit a b
flowControl f = GecCircuit k
where
    k setb env = (seta, env)
    where
        seta a env = case f a of
            Just b -> setb b env
            _ -> env

gecIO :: (A. .ps: a *(PSt .ps) -> *(b, *PSt .ps)) -> GecCircuit a b
gecIO f = GecCircuit k
where
	k setb env = (seta, env)
	where
		seta a env 
			# (b, env) = f a env
			= setb b env
			
openStore` :: !(Maybe a) !(PSt .ps) -> (!StoreId a, !PSt .ps)
openStore` maybe env
	# (id, env) = openStoreId env
	  (_, env) = openStore id maybe env
	= (id, env)
