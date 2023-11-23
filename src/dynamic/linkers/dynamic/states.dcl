definition module states

import
	State;
	
:: *States :== [(!Int,*State)]

AddState :: !Int !*State !*States -> *States
RemoveState :: !Int !*States -> (!Bool,!*State,!*States)
DefaultStates :: *States;