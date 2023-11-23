implementation module DodoUtil
import StdEnv

sSplit :: !.Char !String -> (!String,!String)
/*
sSplit c s
	# (s1,s2) = span c s
	= (s1,drop1 s2)
*/
sSplit c s
	| sp == mx
		= (s,"")
	= (s%(b1,e1),s%(b2,e2))
where
	mx = size s
	sp = findPos c s 0 mx
	b1 = 0
	e1 = sp - 1
	b2 = sp + 1
	e2 = size s - 1

eSplit :: !.Char !String -> (!String,!String)
eSplit c s = (s%(b1,e1),s%(b2,e2))
where
	sp = findPos` c s (dec(size s))
	b1 = 0
	e1 = sp - 1
	b2 = sp + 1
	e2 = size s - 1

lSplit :: !.Char !String -> [String]
lSplit c s = lsplit c s (dec (size s)) []
where
	lsplit c s i l
		| i < 0		= l
		# i`	= findPos` c s i
		= lsplit c s (dec i`) [s%(i`+1,i):l]
		
	
findPos c s i m
	// moet evt out of range checking toevoegen...
	| i >= m = m
	| s.[i] == c = i
	= findPos c s (inc i) m

findPos` c s i
	| i < 0 = ~1
	| s.[i] == c = i
	= findPos` c s (dec i)

words :: !String -> [String]
/*
words s = wrds (dropWhile isSpace (fromString s))
where
   wrds [] = []
   wrds s  = [toString  s1 : (wrds (dropWhile isSpace s2)) ]
   where
     (s1,s2) = span (not o isSpace) s
*/
words s
	| size s == 0 = []
	= [s%(b,e-1) \\ (b,e) <- bes2]
where
	bes1 = [i \\ i <- [1..(size s - 1)] | (isSpace s.[i]) <> (isSpace s.[i-1])]

	bes2
		| isSpace s.[0]
			= zip` bes1
			= zip` [0:bes1]

	zip` [b] = [(b,size s)]
	zip` [b,e:r] = [(b,e):zip` r]
	zip` _ = []

unwords :: ![String] -> String
/*
unwords [h]   = h
unwords [h:t] = h +++. " " +++. unwords t
unwords []    = ""
*/
unwords l
	# s = sizelist l
	# a = createArray s ' '
	# (_,a) = copylist l a 0
	= a
where
	sizelist [] = ~1
	sizelist [h:t] = size h + 1 + sizelist t
	
	copylist [] a i = (i,a)
	copylist [h:t] a i
		# (i,a) = scopy (size h) i 0 a h
		= copylist t a (inc i)

scopy ::
	!Int		// end of copy source index
	!Int		// current target index
	!Int		// current source index
	!*{#Char}	// target string
	!{#Char}	// source string
	-> (!Int,!.{#Char})
scopy n i j s h
	| j >= n = (i,s)
	#! s = {s & [i] = h.[j]}
	= scopy n (i+1) (j+1) s h
