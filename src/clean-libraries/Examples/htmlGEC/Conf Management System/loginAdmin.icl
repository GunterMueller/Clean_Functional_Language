implementation module loginAdmin

import StdArray, StdList, StdOrdList, StdString
import StdHtml, StdMaybe

instance == (Account s)
where
	(==) login1 login2 = login1.login.loginName == login2.login.loginName

instance == Login
where
	(==) login1 login2 = login1.loginName == login2.loginName

instance < (Account s)
where
	(<) login1 login2 = login1.login.loginName < login2.login.loginName

mkAccount :: Login s -> (Account s)
mkAccount login s
	= 	{ login			= login
		, state			= s
		}

mkLogin :: String PasswordBox -> Login
mkLogin name password = {loginName = name, password = password}

addAccount :: (Account s) (Accounts s) -> (Accounts s) 
addAccount account accounts 
| isNothing (invariantLogAccounts account.login.loginName [account:accounts])	= sort [account:accounts]	
| otherwise 																	= accounts

changePassword 	:: PasswordBox (Account s) -> (Account s) 
changePassword nwpasswrd oldlogin 
= mkAccount (mkLogin oldlogin.login.loginName nwpasswrd) oldlogin.state

changeAccount :: (Account s) (Accounts s) -> (Accounts s) 
changeAccount account accounts
# (before,after) = span ((<>) account) accounts
= updateAt (length before) account accounts

removeAccount :: (Account s) (Accounts s) -> (Accounts s) 
removeAccount login accounts 
# (before,after) = span ((<>) login) accounts
= removeAt (length before) accounts

hasAccount :: Login (Accounts s) -> (Maybe (Account s))
hasAccount login [] = Nothing
hasAccount login [acc:accs]
| login.loginName == acc.login.loginName && login.password == acc.login.password = Just acc
= hasAccount login accs

// Invariants

invariantLogAccounts:: String (Accounts s) -> Judgement
invariantLogAccounts id accounts = invariantLogins id [login \\ {login} <- accounts]

invariantLogins :: String [Login] -> Judgement
invariantLogins id [] 			= Ok
invariantLogins id [login=:{loginName,password=PasswordBox mypassword}:logins]
| loginName  == "" 				= Just (id,"login name is not specified!")
//| mypassword == ""				= Just (id,"password required!")
| isMember login logins			= Just (id,"login name " +++ loginName +++ " is already being used!")
| size mypassword < 6			= Just (id,"at least 6 characters required for a password!")
= invariantLogins id logins
