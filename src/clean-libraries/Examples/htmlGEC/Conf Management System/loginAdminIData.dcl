definition module loginAdminIData

import loginAdmin, htmlHandler

// login page: 			returns account if user is adminstrated
// mkLoginPage:			returns a new account if new login not yet taken
// changePasswordPage: 	returns new account if changed password has been approved
// adjustLogin:			adjust login using given (new) login account

loginPage  			:: !(Accounts s)	!*HSt -> (Maybe (Account s),[BodyTag],!*HSt)
mkLoginPage  		:: s !(Accounts s) 	!*HSt -> (Maybe (Account s),[BodyTag],!*HSt)
changePasswordPage 	:: !(Account s) 	!*HSt -> (Maybe (Account s),[BodyTag],!*HSt)

adjustLogin 		:: !(Account s)  	!*HSt -> (Maybe (Account s),!*HSt)
