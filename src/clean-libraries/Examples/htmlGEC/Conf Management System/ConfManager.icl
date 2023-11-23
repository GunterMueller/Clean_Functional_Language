module ConfManager

import StdEnv, StdHtml

import loginAdminIData, confIData, stateHandlingIData 

// Here it starts ....

import StdDebug

//Start world = doHtmlServer test world
Start world = doHtmlServer mainEntrance world

mainEntrance :: *HSt -> *(Html,*HSt)
mainEntrance hst
# (body,hst) 	= loginhandling hst				// a login will be checked on correctness each time a page is requested !
= mkHtml "Conference Manager" body hst


//Start world = doHtmlServer test world

test hst
= mkHtml "test" [BodyTag (download "back35.jpg")] hst
where
	download url = [A [Lnk_Href url, Lnk_Target Trg__Blank] [Txt "click here"]]

// login page handling

loginhandling :: *HSt -> ([BodyTag],*HSt)
loginhandling  hst											
# (accounts,hst) 			= AccountsDB Init [initManagerAccount initManagerLogin] hst	// read out all accounts read only
# (mblogin,loginBody,hst)	= loginHandlingPage accounts hst	// set up a login page
= case mblogin of												// check result of login procedure
	Nothing		= (loginBody,hst)								// show login page when (still) not logged in
	Just login	= doConfPortal login accounts hst				// show member page otherwise

// The different pages that exists:

:: CurrPage 	= 	RootHomePage			// root pages
				| 	AssignPapers
				| 	ModifyStates

				| 	AuthorsHomePage			// authors
				| 	SubmitPaper

				| 	ChangePassword			// common			
				| 	ChangeInfo

				| 	ListPapers				// referees + root
				| 	ListReports
				| 	DiscussPapers
				|	ShowPapersStatus
				|	RefereeForm				
				| 	RefereeHomePage			// referees

				| 	GuestHomePage			// guests

derive gForm 	CurrPage
derive gUpd 	CurrPage
derive gPrint 	CurrPage
derive gParse 	CurrPage
derive gerda 	CurrPage

homePage :: Member -> CurrPage
homePage (ConfManager info) = RootHomePage
homePage (Referee info) 	= RefereeHomePage
homePage (Authors info) 	= AuthorsHomePage
homePage (Guest info)		= GuestHomePage

navigationButtons :: Member *HSt -> (Form (CurrPage -> CurrPage),*HSt)
navigationButtons state hst = ListFuncBut (Init, sFormId "navigation" (navButtons state)) hst
where
	navButtons (ConfManager info) = 
		[ (LButton defpixel "RootHome", 		const RootHomePage)
		, (LButton defpixel "ModStates", 		const ModifyStates)
		, (LButton defpixel "ListPapers", 		const ListPapers)
		, (LButton defpixel "AssignPapers", 	const AssignPapers)
		, (LButton defpixel "ListReports", 		const ListReports)
		, (LButton defpixel "DiscussPapers", 	const DiscussPapers)
		, (LButton defpixel "ShowPaperStatus", 	const ShowPapersStatus)
		, (LButton defpixel "ChangeInfo", 		const ChangeInfo)
		, (LButton defpixel "ChangePsswrd", 	const ChangePassword)
		]

	navButtons (Referee info) = 
		[ (LButton defpixel "Home", 			const RefereeHomePage)
		, (LButton defpixel "ListPapers", 		const ListPapers)
		, (LButton defpixel "RefereeForm", 		const RefereeForm)
		, (LButton defpixel "ListReports", 		const ListReports)
		, (LButton defpixel "DiscussPapers", 	const DiscussPapers)
		, (LButton defpixel "ShowPaperStatus", 	const ShowPapersStatus)
		, (LButton defpixel "ChangeInfo", 		const ChangeInfo)
		, (LButton defpixel "ChangePsswrd", 	const ChangePassword)
		]
	navButtons (Authors info) = 
		[ (LButton defpixel "Home", 			const AuthorsHomePage)
		, (LButton defpixel "SubmitPaper", 		const SubmitPaper)
		, (LButton defpixel "ChangeInfo", 		const ChangeInfo)
		, (LButton defpixel "ChangePsswrd", 	const ChangePassword)
		]
	navButtons (Guest info) = 
		[ 
		]

// you are in, determine what to do

doConfPortal :: ConfAccount ConfAccounts *HSt -> ([BodyTag],*HSt)
doConfPortal account accounts hst
# (navButtons,hst) 	= navigationButtons account.state hst							// setup proper set of navigation buttons
# (currPage,hst)	= currPageStore (homePage account.state) navButtons.value hst	// determine which current page to display
# (navBody,hst)		= handleCurrPage currPage.value account accounts  hst			// and handle the corresponding page
# (exception,hst)	= ExceptionStore id hst											// see if an error has occured somewhere
= ( [ mkSTable2 [ [EmptyBody,B [] "Conference" <.||.> B [] "Manager ",oops exception currPage.value]
				, [mkColForm navButtons.form, EmptyBody, BodyTag navBody]
				]
	] // for debugging ++ [Txt (printToString accounts)]
	, hst)
where

	mkSTable2 :: [[BodyTag]] -> BodyTag
	mkSTable2 table
	= Table []	(mktable table)
	where
		mktable table 	= [Tr [] (mkrow rows) \\ rows <- table]	
		mkrow rows 		= [Td [Td_VAlign Alo_Top] [row] \\ row <- rows] 
	
	oops (Just (id,message)) currpage
	= Font [Fnt_Color (`Colorname Yellow)] [B [] (print currpage), Br, B [] (id +++ " : " +++ message)]
	oops Nothing currpage
	= Font [Fnt_Color (`Colorname Silver)] [B [] (print currpage)] 

	print currpage = printToString (currpage) +++ " of " +++ account.login.loginName

	currPageStore :: !CurrPage  !(CurrPage -> CurrPage) *HSt -> (!Form CurrPage,!*HSt)	// current page to display
	currPageStore currpage cbf hst = mkStoreForm (Init, sFormId "cf_currPage" currpage) cbf hst 
	
	handleCurrPage :: CurrPage ConfAccount ConfAccounts *HSt -> ([BodyTag],*HSt)
	handleCurrPage currPage account accounts hst 
	= case currPage of
			RootHomePage 	-> rootHomePage                          hst
			RefereeHomePage -> refereeHomePage                       hst
			AuthorsHomePage -> authorsHomePage                       hst
			GuestHomePage	-> guestHomePage        account accounts hst
			ModifyStates 	-> modifyStatesPage	            accounts hst
			AssignPapers 	-> assignPapersConflictsPage    accounts hst
			SubmitPaper		-> submitPaperPage      account          hst
			ListPapers 		-> showPapersPage               accounts hst
			RefereeForm 	-> submitReportPage     account accounts hst
			ListReports		-> showReportsPage      account accounts hst
			DiscussPapers	-> discussPapersPage    account accounts hst
			ShowPapersStatus-> showPapersStatusPage account accounts hst
			ChangeInfo		-> changeInfo           account          hst
			ChangePassword 	-> changePasswrdPage    account accounts hst
			_				-> ([],hst)
	where
		changePasswrdPage account accounts hst 
		# (mbaccount,body,hst) = changePasswordPage account hst
		= case mbaccount of
			Nothing 		-> (body, hst)
			Just naccount 	
							# accounts			= changeAccount naccount accounts	// replace changed account in accounts
							# (accounts,hst)	= AccountsDB Set accounts hst		// store accounts in database administration
							-> handleCurrPage (homePage account.state) naccount accounts  hst

// the different pages the super user can choose from

rootHomePage hst =
	(	[ Txt "Welcome Conference Manager ... "
		]
	, 	hst )


refereeHomePage hst =
	(	[ Txt "Welcome Referee ... "
		]
	, 	hst )

authorsHomePage hst =
	(	[ Txt "Welcome Author ... "
		]
	, 	hst )

:: GuestPages 	= GuestSubmitPaper
				| GuestPerson
				| GuestMakeLogin

derive gForm	GuestPages
derive gUpd		GuestPages
derive gParse	GuestPages
derive gPrint	GuestPages
derive gerda	GuestPages

guestHomePage account accounts hst
# (subpagef,hst)	= guestSubPages Init id hst
=	case subpagef.value of
		GuestMakeLogin 		-> guestMakeLogin hst
		GuestPerson		 	-> guestPerson hst
		GuestSubmitPaper 	-> guestSubmitPaper hst
where
	guestSubPages :: Init (GuestPages -> GuestPages) !*HSt -> (Form GuestPages,!*HSt)
	guestSubPages init fgst hst = mkStoreForm (init,nFormId "cmg_guest_page" createDefault) fgst hst
	
	guestMakeLogin hst		// 1. make a new login 
	# (mbaccount,loginb,hst)= mkLoginPage (Guest createDefault) accounts hst
	| isNothing mbaccount	= ([Txt "1. First we make an account for you.",Br,Txt "Please fill in the form.",Br,Br] ++ loginb,hst)
	# (_,hst)				= guestSubPages Set (\_ -> GuestPerson) hst
	# (Just newaccount)		= mbaccount
	# (_,hst)				= guestAccountStore (\(_,guest) -> (True,newaccount)) hst		// update guest account
	= guestHomePage newaccount accounts hst
	
	guestPerson hst 		// 2. administrate personel administration
	# (personf,hst)			= mkEditForm (Init,nFormId "cms_guest_person" createDefault <@ Submit) hst
	# (exception,hst)		= ExceptionStore ((+) (invariantPerson account.login.loginName personf.value)) hst	
	| isJust exception		= ([Txt "2. Please fill in your personal data so that we can inform you.",Br,Br ] ++ personf.form,hst)
	# (_,hst)				= guestSubPages Set (\_ -> GuestSubmitPaper) hst
	# account				= {account & state = Guest personf.value}
	# (_,hst)				= guestAccountStore (\(_,guest) -> (True,{guest & state = Guest personf.value})) hst		// update guest account
	= guestHomePage account accounts hst

	guestSubmitPaper hst	// 3. handle paper submission
	# (paperf,hst)			= mkEditForm (Init,nFormId "cms_guest_paper" createDefault <@ Submit) hst
	# (exception,hst)		= ExceptionStore ((+) (invariantPaper account.login.loginName paperf.value)) hst	
	| isJust exception		= ([Txt "3. Now submit your paper.", Br, Br] ++ paperf.form,hst)
	# (paperNr,hst)			= PaperNrStore inc hst	// now all iformation is there, make it all persistent
	# (guestf,hst)			= guestAccountStore id hst									// retrieve guest account
	# (Guest person)		= (snd guestf.value).state
	# uniquename			= uniquePerson (snd guestf.value).login.loginName
	# uniquepaper			= uniquePaper paperNr uniquename
	# uniquediscussion		= uniqueDiscussion paperNr uniquename
	# account				= {login  = (snd guestf.value).login
							  , state = Authors 	{ person =  RefPerson (Ref2 uniquename)
													, nr = paperNr
													, paper	= RefPaper (Ref2 uniquepaper)
													, status = Submitted
													, discussion = RefDiscussion (Ref2 uniquediscussion) 
													}}
	# (_,hst)				= adjustLogin account hst
	# accounts				= addAccount account accounts
	# (_,hst)				= AccountsDB Set accounts hst								// store accounts
	# (exception,hst)		= ExceptionStore id hst	
	| isJust exception		
		= ([Txt "Sorry, an exception occurred, something went wrong, you have to try again"],hst)

	# (_,hst)				= mkEditForm (Set,storeFormId uniquename (0,person)) hst		// store person info
	# (_,hst)				= mkEditForm (Set,storeFormId uniquepaper (0,paperf.value)) hst	// store paper info
	# (_,hst)				= guestAccountStore (\(_,guest) -> (False,account)) hst		// kick out guest
	= ([B [] "Paper submitted.",Br, Txt "Use your account to update provided information",Br,
			Txt "and stay in touch with us",Br],hst)
