definition module StateMonad

// a general-purpose state monad (implemented by macros)

:: StateM state a
	:== state -> *(a, state)

// basic monad operations as macro definitions

//result :: a -> StateM .state a
result x :== \state -> (x, state)

//(>>>=) infixl :: (StateM .state a) (a -> StateM .state b) -> StateM .state b
(>>>=) infixl 
(>>>=) ma f  :== \state -> let (a, state`) = ma state in f a state`

//(>>>) infixl :: (StateM .state a) (StateM .state b) -> StateM .state b
(>>>) infixl
(>>>) ma mb :== \state -> let (_, state`) = ma state in mb state`

// more monad operations

mapl			:: (a -> StateM state b) ![a]				->	StateM state [b]
mfoldr			:: (a -> b -> StateM state b) b ![a]		->	StateM state b
runState		:: state !(StateM state a)					-> (a,state)
sequence		:: ![StateM s a]							-> StateM s [a]
mmap			:: (a -> b) (StateM s a)					-> StateM s b
mWhile			:: (StateM s Bool) (StateM s a)				-> StateM s [a]


skip :== result nothing

// an IF-THEN-ELSE construct, which is more readable if the branches are large

IF guard _ thenBranch _ elseBranch :== if guard thenBranch elseBranch
THEN :== 0
ELSE :== 0

// 'nothing' is used when a monadic operation has no real result
// and thus is a 'side-effect'.

nothing :: nothing

// The onlyIf function only executes its monad argument if the
// boolean is true. Otherwise, nothing is done (result nothing)

onlyIf :: !Bool (StateM .env nothing) -> StateM .env nothing

