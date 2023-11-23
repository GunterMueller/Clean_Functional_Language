definition module loginAdmin

import StdMaybe, htmlRefFormlib, htmlButtons

:: Account s			= 	{ login			:: Login		// login info		
							, state			:: s			// state 
							}
:: Login 				= 	{ loginName 	:: String		// Should be unique
							, password		:: PasswordBox	// Should remain secret
							}
:: Accounts s			:== [Account s]

// Access functions

instance == (Account s)
instance <  (Account s)

mkLogin 			:: String PasswordBox 	-> Login
mkAccount			:: Login s 			-> Account s
changePassword 		:: PasswordBox  (Account s) -> (Account s) 

addAccount 			::	(Account s) (Accounts s) -> (Accounts s) 
removeAccount 		::	(Account s) (Accounts s) -> (Accounts s) 
changeAccount 		::	(Account s) (Accounts s) -> (Accounts s) 
hasAccount 			::	Login		(Accounts s) -> (Maybe (Account s))

//	Invariants

invariantLogins		:: 	String [Login] 	 	-> Judgement
invariantLogAccounts::	String (Accounts s) -> Judgement
