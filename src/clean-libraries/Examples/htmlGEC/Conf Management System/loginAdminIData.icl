implementation module loginAdminIData

import StdEnv, StdHtml, StdMaybe
import loginAdmin

derive gForm  	Login
derive gUpd 	Login
derive gPrint	Login
derive gParse	Login
derive gerda	Login

// this session login form will be used at every event to check whether the end user is indeed administrated

loginForm :: !(Init,Login) !*HSt -> (Form Login,!*HSt)
loginForm (init,login) hst = mkEditForm (init,sFormId "adminID_login" login <@ Submit) hst

// scratch form 

passwordForm :: !String !*HSt -> (Form PasswordBox,!*HSt)
passwordForm fid hst = mkEditForm (Init, nFormId fid (PasswordBox "")) hst

editForm :: !String !*HSt -> (Form String,!*HSt)
editForm fid hst = mkEditForm (Init, nFormId fid "") hst

// program controlled logins

adjustLogin 			:: !(Account s)  	!*HSt -> (Maybe (Account s),!*HSt)
adjustLogin account hst
# (_,hst)	= loginForm (Set,account.login) hst 
= (Just account,hst)

// pages

loginPage  :: !(Accounts s) !*HSt -> (Maybe (Account s),[BodyTag],!*HSt)
loginPage accounts hst
# (login,hst) = loginForm (Init,mkLogin "" (PasswordBox "")) hst
= 	( hasAccount login.value accounts
	, [	Txt "Please log in."
	  ,	Br
	  ,	Br
	  ,	BodyTag login.form
	  ] 
	, hst)

mkLoginPage  :: s !(Accounts s) !*HSt -> (Maybe (Account s),[BodyTag],!*HSt)
mkLoginPage state accounts hst
# (namef,hst)		= editForm "mk_name" hst
# (passwd1,hst)		= passwordForm "mk_passwd1" hst
# (passwd2,hst)		= passwordForm "mk_passwd2" hst
# ok				= passwd1.value == passwd2.value &&
		 			  passwd1.value <> (PasswordBox "") && 
					  namef.value <> ""
| not ok			= (Nothing, dolog namef.form passwd1.form passwd2.form ++ [Br,Txt "Please check supplied login information"],hst)
# newlogin 			= {loginName = namef.value, password = passwd1.value}
# (exception,hst)	= ExceptionStore ((+) (invariantLogins namef.value [newlogin:map (\acc -> acc.login) accounts])) hst 
| isJust exception	= (Nothing, dolog namef.form passwd1.form passwd2.form,hst)
# (_,hst)			= loginForm (Set,newlogin) hst	// password approved
# newaccount		= {login = newlogin, state = state}
= (Just newaccount, [Br,Txt "New login accepted",Br], hst)
where
	dolog name pass1 pass2 = 
			[	mkTable		[ [Txt "Enter desired login name: ",BodyTag name]
							, [Txt "Enter your password: ",		BodyTag pass1]
							, [Txt "Re-enter your password: ",	BodyTag pass2]
							]
			]

changePasswordPage :: !(Account s) !*HSt -> (Maybe (Account s),[BodyTag],!*HSt)
changePasswordPage account hst
# (oldpasswrd,hst)		= passwordForm "oldpasswrd" hst
# (newpasswrd1,hst)		= passwordForm "newpasswrd1" hst
# (newpasswrd2,hst)		= passwordForm "newpasswrd2" hst
# ok	= oldpasswrd.value == account.login.password &&
		 newpasswrd1.value == newpasswrd2.value  &&
		 newpasswrd1.value <> (PasswordBox "")
| not ok				= (Nothing, changePasswrdBody oldpasswrd newpasswrd1 newpasswrd2, hst)

# newaccount			= changePassword newpasswrd1.value account
# (exception,hst)		= ExceptionStore ((+) (invariantLogAccounts account.login.loginName [newaccount])) hst 
| isJust exception		= (Nothing, changePasswrdBody oldpasswrd newpasswrd1 newpasswrd2, hst)

# (_,hst)				= loginForm (Set,newaccount.login) hst	// password approved
= (Just newaccount, [Br,Txt "New Password accepted",Br], hst)
where
	changePasswrdBody oldpasswrd newpasswrd1 newpasswrd2 = 	
		if (oldpasswrd.value <> account.login.password)
			[	Txt "Retype old password .."
			,	Br, Br
			,	BodyTag oldpasswrd.form, Br
			]
			[	Txt "Type in new password.."
			,	Br, Br
			,	BodyTag newpasswrd1.form
			, 	Br, Br
			:	if (newpasswrd1.value <> newpasswrd2.value && newpasswrd1.value <> (PasswordBox ""))
					[	Txt "Re_type new password.."
					,	Br, Br
					,	BodyTag newpasswrd2.form, Br
					]
					[]
			] 
