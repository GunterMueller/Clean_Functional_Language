module gecarrow

import StdMisc, StdFunc, StdTuple, StdInt, StdBool

:: GecCircuit a b :== (GecSet b) -> PSt -> *(GecSet a, PSt)

:: GecSet a :== IncludeUpdate -> a -> PSt -> PSt

gec :: (GecCircuit a b) (a -> b) (GecSet b) PSt -> (GecSet a, PSt)
gec f f` set env = (set` set f`, env)
where
	set` :: (GecSet b) (a -> b) IncludeUpdate a PSt -> PSt
	set` set f` u x env = set u (f` x) env

//GecCircuit :: (GecCircuit a b) -> GecCircuit a b
//GecCircuit x = x

RunCircuit :: (GecCircuit a b)(GecSet b) PSt -> (GecSet a, PSt)
RunCircuit g set env = g set env

//GecSet :: (GecSet a) IncludeUpdate a PSt -> PSt
//GecSet set u x env = set u x env

RunSet :: (GecSet a) IncludeUpdate a PSt -> PSt
RunSet set u x env = set u x env

arr :: (a -> b) (GecSet b) PSt -> (GecSet a, PSt)
arr f setb env = (arr_seta f setb, env)

arr_seta :: (a -> b) (GecSet b) IncludeUpdate a PSt -> PSt
arr_seta f setb u a env = setb u (f a) env
		
>>> :: (GecCircuit a b) (GecCircuit b c) (GecSet c) PSt -> (GecSet a, PSt)
>>> l r setc env = bind1 l (RunCircuit r setc env)

bind1 :: (GecCircuit a b) (GecSet b, PSt) -> (GecSet a, PSt)
bind1 l (setb, env) = RunCircuit l setb env

first :: (GecCircuit a b) (GecSet (b, c)) PSt -> (GecSet (a,c), PSt)
first g setbc env = first1 g setbc (openStoreId env)

first1 :: (GecCircuit a b) (GecSet (b, c)) (StoreId c, PSt) -> (GecSet (a,c), PSt)
first1 g setbc (id_c, env) = first2 g setbc id_c (openStore id_c Nothing env)

first2 :: (GecCircuit a b) (GecSet (b, c)) (StoreId c) (Bool, PSt) -> (GecSet (a,c), PSt)
first2 g setbc id_c (_, env) = first3 id_c (g (first_setb id_c setbc) env)

first3 :: (StoreId c) (GecSet a, PSt) -> (GecSet (a, c), PSt)
first3 id_c (seta, env) = (first_setac id_c seta, env)

first_setac :: (StoreId c) (GecSet a) IncludeUpdate (a, c) PSt -> PSt
first_setac id_c seta u ac env = seta u (fst ac) (writeStore id_c (snd ac) env)

first_setb :: (StoreId c) (GecSet (b, c)) IncludeUpdate b PSt -> PSt
first_setb id_c setbc u b env = first_setb2 id_c setbc u b (readStore id_c env)

first_setb2 :: (StoreId c) (GecSet (b, c)) IncludeUpdate b (c, PSt) -> PSt
first_setb2 id_c setbc u b (c, env) = setbc u (b, c) env

loop :: (GecCircuit (a, b) (c, b)) (GecSet c) PSt -> (GecSet a, PSt)
loop g setc env = loop1 g setc (openStoreId env)

loop1 :: (GecCircuit (a, b) (c, b)) (GecSet c) (StoreId b, PSt) -> (GecSet a, PSt)
loop1 g setc (id_b, env) = loop2 g setc id_b (openStore id_b Nothing env)

loop2 :: (GecCircuit (a, b) (c, b)) (GecSet c) (StoreId b) (Bool, PSt) -> (GecSet a, PSt)
loop2 g setc id_b (_, env) = loop3 id_b (g (loop_setcb setc id_b) env)

loop3 :: (StoreId b) (GecSet (a, b), PSt) -> (GecSet a, PSt)
loop3 id_b (setab, env) = (loop_seta0 setab id_b, env)

loop_setcb :: (GecSet c) (StoreId b) IncludeUpdate (c, b) PSt -> PSt
loop_setcb setc id_b u cb env = writeStore id_b (snd cb) (setc u (fst cb) env)

loop_seta0 :: (GecSet (a, b)) (StoreId b) IncludeUpdate a PSt -> PSt
loop_seta0 setab id_b u a env = env`
where
	(b, env`) = readStore id_b (setab u (a, b) env)

loop_seta1 :: (GecSet (a, b)) (StoreId b) IncludeUpdate a PSt -> PSt
loop_seta1 setab id_b u a env = snd (loop_seta2 setab id_b u a env)

loop_seta2 :: (GecSet (a, b)) (StoreId b) IncludeUpdate a PSt -> (b, PSt)
loop_seta2 setab id_b u a env = loop_seta3 setab id_b u a (loop_seta2 setab id_b u a env)

loop_seta3 :: (GecSet (a, b)) (StoreId b) IncludeUpdate a (b, PSt) -> (b, PSt)
loop_seta3 setab id_b u a (b, env) = readStore id_b (setab u (a, b) env) 

self :: (GecCircuit a a) (GecCircuit a a) (GecSet a) PSt -> (GecSet a, PSt)
self g f seta env = self1 g f seta (openStoreId env)

self1 :: (GecCircuit a a) (GecCircuit a a) (GecSet a) (StoreId Bool, PSt) -> (GecSet a, PSt)
self1 g f seta (id_B, env) = self2 g f seta id_B (openStore id_B (Just False) env)

self2 :: (GecCircuit a a) (GecCircuit a a) (GecSet a) (StoreId Bool) (Bool, PSt) -> (GecSet a, PSt)
self2 g f seta id_B (_, env) = self3 id_B (selfx g f id_B seta env)

self3 :: (StoreId Bool) (GecSet a, PSt) -> (GecSet a, PSt)
self3 id_B (gseta, env) = (self_seta id_B gseta, env)

selfx :: (GecCircuit a a) (GecCircuit a a) (StoreId Bool) (GecSet a) PSt -> (GecSet a, PSt)
selfx g f id_B seta env = (gseta, env``)
where
	(fseta, env`) = RunCircuit f gseta env
	(gseta, env``) = RunCircuit g (self_setrec id_B seta fseta) env`

self_setrec :: (StoreId Bool) (GecSet a) (GecSet a) IncludeUpdate a PSt -> PSt
self_setrec id_B setout setrec u a env = self_setrec1 id_B setout u a (readStore id_B env)

self_setrec1 :: (StoreId Bool) (GecSet a) IncludeUpdate a (Bool, PSt) -> PSt
self_setrec1 id_B setout u a (exit, env) = setout u a (writeStore id_B (not exit) env)

self_seta :: (StoreId Bool) (GecSet a) IncludeUpdate a PSt -> PSt
self_seta id_B seta u a env = seta u a (writeStore id_B False env)

`self :: (GecCircuit a a) (GecCircuit a a) (GecSet a) PSt -> (GecSet a, PSt)
`self g f seta env = `self1 g f seta (openStoreId env)

`self1 :: (GecCircuit a a) (GecCircuit a a) (GecSet a) (StoreId Bool, PSt) -> (GecSet a, PSt)
`self1 g f seta (id_B, env) = `self2 g f seta id_B (openStore id_B (Just False) env)

`self2 :: (GecCircuit a a) (GecCircuit a a) (GecSet a) (StoreId Bool) (Bool, PSt) -> (GecSet a, PSt)
`self2 g f seta id_B (_, env) = `self3 id_B (`selfx g f id_B seta env)

`self3 :: (StoreId Bool) (GecSet a, PSt) -> (GecSet a, PSt)
`self3 id_B (gseta, env) = (self_seta id_B gseta, env)

`selfx :: (GecCircuit a a) (GecCircuit a a) (StoreId Bool) (GecSet a) PSt -> (GecSet a, PSt)
`selfx g f id_B seta env 
	# (id_f, env) = openStoreId env
	  (gseta, env) = RunCircuit g (self_setrec id_B seta (`self_fseta id_f)) env
	  (fseta, env) = RunCircuit f gseta env
	  (_, env) = openStore id_f (Just fseta) env
	=(gseta, env)

`self_fseta id_f u x env
	# (fseta, env) = readStore id_f env
	= fseta u x env

feedback :: (GecCircuit a a) (GecSet a) PSt -> (GecSet a, PSt)
feedback g seta env = feedback1 g seta (openStoreId env)

feedback1 :: (GecCircuit a a) (GecSet a) (StoreId Bool, PSt) -> (GecSet a, PSt)
feedback1 g seta (id_B, env) = feedback2 g seta id_B (openStore id_B (Just False) env)

feedback2 :: (GecCircuit a a) (GecSet a) (StoreId Bool) (Bool, PSt) -> (GecSet a, PSt)
feedback2 g seta id_B (_, env) = feedback3 id_B (feedbackx g id_B seta env)

feedback3 :: (StoreId Bool) (GecSet a, PSt) -> (GecSet a, PSt)
feedback3 id_B (gseta, env) = (self_seta id_B gseta, env)

feedbackx :: (GecCircuit a a) (StoreId Bool) (GecSet a) PSt -> (GecSet a, PSt)
feedbackx g id_B seta env = (gseta, env`)
where
	(gseta, env`) = RunCircuit g (self_setrec id_B seta gseta) env

feedback` :: ((GecCircuit a a) (GecCircuit a a) -> GecCircuit a a) (GecCircuit a a) (GecSet a) PSt -> (GecSet a, PSt)
feedback` sf g set env = sf g (arr id) set env

self` :: ((GecCircuit (a, EITHER a a) (a, EITHER a a)) -> GecCircuit (a, EITHER a a) (a, EITHER a a)) (GecCircuit a a) (GecCircuit a a) (GecSet a) PSt -> (GecSet a, PSt)
self` fb g f set env = >>> (arr addLEFT) (>>> (fb (>>> (first g) (>>> (arr selectX) (>>> f (arr addRIGHT))))) (arr fst)) set env

:: EITHER a b = LEFT a | RIGHT b

addLEFT :: a -> (a, EITHER a b)
addLEFT x = (x, LEFT x)

selectX :: (a, EITHER b a) -> a
selectX (x, LEFT _) = x
selectX (_, RIGHT x) = x

addRIGHT :: a -> (a, EITHER b a)
addRIGHT x = (x, RIGHT x)

second :: (GecCircuit a b) (GecSet (c, b)) PSt -> (GecSet (c, a), PSt)
second g setcb env = >>> (arr swap) (>>> (first g) (arr swap)) setcb env

swap :: (a, b) -> (b, a)
swap t = (snd t, fst t)

returnA :: GecCircuit a a
returnA = arr id

<<<< :: (GecCircuit b c) (GecCircuit a b) -> GecCircuit a c 
<<<< l r = >>> r l

*** :: (GecCircuit a b) (GecCircuit c d) -> GecCircuit (a, c) (b, d)
*** l r = >>> (first l) (second r)

&&& :: (GecCircuit a b) (GecCircuit a c) -> GecCircuit a (b, c)
&&& l r = >>> (arr copy) (*** l r)

copy :: a -> (a, a)
copy x = (x, x)

fix :: (GecCircuit (a, b) b) -> GecCircuit a b
fix g = loop (>>> g (arr copy))

cross :: (a -> b) (c -> d) (a, c) -> (b, d)
cross f g t = (f (fst t), g (snd t))

assoc :: ((a, b), c) -> (a, (b, c))
assoc t = (fst (fst t), (snd (fst t), snd t))

unassoc :: (a, (b, c)) -> ((a, b), c)
unassoc t = ((fst t, fst (snd t)), snd (snd t))

simple_loop :: ((a, b) -> (c, b)) a -> c
simple_loop f a = fst (simple_loop0 f a)

simple_loop1 :: ((a, b) -> (c, b)) a -> (c, b)
simple_loop1 f a = f (a, snd (simple_loop1 f a))

simple_loop0 :: ((a, b) -> (c, b)) a -> (c, b)
simple_loop0 f a = let b = snd (f (a, b)) in f (a, b)

startCircuit :: (GecCircuit a b) a PSt -> PSt
startCircuit g a env = startCircuit1 a (g startCircuit_setb env)

startCircuit1 :: a (GecSet a, PSt) -> PSt
startCircuit1 a (seta, env) = seta YesUpdate a env

startCircuit_setb :: IncludeUpdate b PSt -> PSt
startCircuit_setb _ _ env = env

:: Maybe a = Nothing | Just a

:: Void = Void

:: IncludeUpdate = YesUpdate | NoUpdate

:: *PSt = PSt [Int] [Store] Event

:: Event = Normal | E. a: Special (EditId a) a

:: EditId a = EditId Int

:: Store = E. a: Store (StoreId a) a

:: StoreId a = StoreId Int

writeStore :: (StoreId a) a PSt -> PSt
writeStore i v (PSt fs xs ev) = PSt fs [Store i v:close_store i xs] ev

readStore :: (StoreId a) PSt -> (a, PSt)
readStore i st=:(PSt fs xs ev) = (read_store i xs, st)

read_store :: (StoreId a) [Store] -> a
read_store i [Store j v:xs] = unpack_if_equal i j v (read_store i xs)
read_store _ _ = undef

unpack_if_equal :: (StoreId a) (StoreId b) b a -> a
unpack_if_equal (StoreId i) (StoreId j) v d = if (i == j) (cast v) d
where
	cast :: !a -> b
	cast _ = code {
			pop_a	0
		}

openStoreId :: PSt -> (StoreId a, PSt)
openStoreId (PSt [f:fs] xs ev) = (StoreId f, PSt fs xs ev)

openStore :: (StoreId a) (Maybe a) PSt -> (Bool, PSt)
openStore i maybe pst = case maybe of
	Just v -> (True, writeStore i v pst)
	Nothing -> (True, pst)

closeStore :: (StoreId a) PSt -> PSt
closeStore si=:(StoreId i) (PSt fs xs ev) = PSt [i:fs] (close_store si xs) ev

close_store :: (StoreId a) [Store] -> [Store]
close_store si=:(StoreId i) [x=:(Store (StoreId j) v):xs] 
	| i == j = xs
	= [x:close_store si xs]
close_store i [] = []

Start :: Int
Start = 1
