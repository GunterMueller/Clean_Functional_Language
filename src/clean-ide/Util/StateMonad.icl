implementation module StateMonad

// a general-purpose state monad (implemented by macros)

:: StateM state a
	:== state -> *(a, state)

/*

result :: a -> StateM .state a
result x
  = result`
  where
	result` state = (x, state)

(>>>=) infixl :: (StateM .state a) (a -> StateM .state b) -> StateM .state b
(>>>=) ma f
  = bindWithResult
  where
	bindWithResult state
	  # (a, state`) = ma state
	  = f a state`

(>>>) infixl :: (StateM .state a) (StateM .state b) -> StateM .state b
(>>>) ma mb
  = bindWithoutResult
  where
	bindWithoutResult state
	  # (_, state`) = ma state
	  = mb state`

*/

mapl :: (a -> StateM state b) ![a] -> StateM state [b]
mapl f []
  = result []
mapl f [a:as]
  = f a				>>>= \b ->
	mapl f as		>>>= \bs ->
	result [b:bs]

skip :== result nothing

IF guard _ thenBranch _ elseBranch :== if guard thenBranch elseBranch
THEN :== 0
ELSE :== 0

nothing :: nothing
nothing = nothing

mfoldr :: (a b -> StateM state b) b ![a] -> StateM state b
mfoldr op e [] 
  = result e
mfoldr op e [a:as]
  = mfoldr op e as >>>= \b ->
	op a b

runState		:: state !(StateM state a)				-> (a,state)
runState state f
  = f state

onlyIf :: !Bool (StateM .env nothing) -> StateM .env nothing
onlyIf True  monad	= monad
onlyIf False _		= skip

sequence :: ![StateM s a] -> StateM s [a]
sequence [] = result []
sequence [x:xs] = x >>>= \y -> sequence xs >>>= \ys -> result [y:ys]

mmap :: (a -> b) (StateM s a) -> StateM s b
mmap f ma = ma >>>= \a -> result (f a)

mWhile :: (StateM s Bool) (StateM s a) -> StateM s [a]
mWhile cond action
  = cond >>>= \bool ->
    if bool
    (
      action             >>>= \a ->
      mWhile cond action >>>= \as ->
      result [a:as]
    )
    (
      result []
    )

/* MACRO VERIONS OF RESULT AND BIND  */

result x :== \state -> (x, state)

(>>>=) infixl 
(>>>=) ma f  :== \state -> let (a, state`) = ma state in f a state`

(>>>) infixl
(>>>) ma mb :== \state -> let (_, state`) = ma state in mb state`

