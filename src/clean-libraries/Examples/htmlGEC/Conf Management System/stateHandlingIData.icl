implementation module stateHandlingIData

import StdList, StdString
import StdHtml
import stateHandling
import loginAdminIData, confIData

// Entrance

guestAccountStore :: ((Bool,ConfAccount) -> (Bool,ConfAccount)) !*HSt -> (Form (Bool,ConfAccount),!*HSt)
guestAccountStore fun hst = mkStoreForm (Init,nFormId "shd_temp_guest" (False,guest)) fun hst
where
	guest = mkAccount (mkLogin "guest" (PasswordBox "temppassword")) (Guest createDefault)

loginHandlingPage  :: !ConfAccounts !*HSt -> (Maybe ConfAccount,[BodyTag],!*HSt)
loginHandlingPage accounts hst
# (mbaccount,login,hst) = loginPage accounts hst	// has account ?
| isJust mbaccount		= (mbaccount,[],hst)		// ok, goto member area
# (forgotf,hst)			= passwordForgotten accounts hst
# (yes,addauthorf,hst)	= addAuthorPage accounts hst
# (guest,hst)			= guestAccountStore (if yes (\(_,guest) -> (True,guest)) id) hst
# mbaccount				= if (fst guest.value) (Just (snd guest.value)) mbaccount
= 	( mbaccount
	, [	B [] "Members Area: ", Br, Br 
	  ,	BodyTag login
	  , split
	  , BodyTag forgotf
	  , split
	  , BodyTag addauthorf
	  , split
	  ] 
	, hst)
where
	split = BodyTag [Br, Br, Hr [], Br]

passwordForgotten ::  !ConfAccounts !*HSt -> ([BodyTag],!*HSt)
passwordForgotten accounts hst
# (emailadres,hst)	= mkEditForm (Init,nFormId "email_addr" "") hst
# (mailmebut,hst)	= simpleButton "sh_mailme" "MailMe" id hst
# (_,persons,hst) 	= getAllPersons accounts hst
# found 			= search emailadres.value persons accounts
=	(	[ B [] "Password / login forgotten ?", Br, Br	
		, Txt "Type in your e-mail address: "
		, BodyTag emailadres.form, Br, Br
		, BodyTag mailmebut.form, Br, Br
		, if (	mailmebut.changed && 
				emailadres.value <> "") 
					(if (isJust found) 
						(Txt "e-mail has been sent")  			// **** But I don't know yet how to do that
						(Txt "you are not administrated")) 
					EmptyBody
		]
	, hst)
where
	search emailaddress persons account 
		= case [acc.login \\ pers <- persons & acc <- account | pers.emailAddress == emailaddress] of
			[] -> Nothing
			[x:_] -> Just x 
			
addAuthorPage :: !ConfAccounts !*HSt -> (Bool,[BodyTag],!*HSt)
addAuthorPage accounts hst 
# (yessubmitf,hst)	= simpleButton "sh_Yes_submit" "Yes" id hst
=	(	yessubmitf.changed
	,	[ B [] "Paper Submission Area:", Br, Br	
		, Txt "Deadline is due on xx-yy-2006", Br, Br
		, Txt "Do you want to submit a paper?", Br, Br
		, BodyTag yessubmitf.form
		]
	, hst)

// Conference manager editors for changing account information, may conflict with other members

tempAccountsId accounts = sFormId "sh_root_accounts" accounts 	// temp editor for accounts

modifyStatesPage :: !ConfAccounts !*HSt -> ([BodyTag],!*HSt)
modifyStatesPage accounts hst
# (naccounts,hst)	= vertlistFormButs 15 True (Init,tempAccountsId accounts) hst	// make a list editor to modify all accounts
# (accounts,hst)	= AccountsDB Set naccounts.value hst 							// if correct store in global database
# (naccounts,hst)	= vertlistFormButs 15 True (Set,tempAccountsId accounts) hst	// make a list editor to modify all accounts
= (naccounts.form, hst)

assignPapersConflictsPage :: !ConfAccounts !*HSt -> ([BodyTag],!*HSt)
assignPapersConflictsPage accounts hst
# (accountsf,hst)	= vertlistFormButs 15 True (Init,tempAccountsId accounts) hst	// make a list editor to modify all accounts
# accounts			= accountsf.value												// current value in temp editor
# (assignf,hst) 	= ListFuncCheckBox (Init, nFormId "sh_assigments" (showAssignments accounts)) hst
# (conflictsf,hst) 	= ListFuncCheckBox (Init, nFormId "sh_conflicts"  (showConflicts   accounts)) hst
# accounts			= (fst assignf.value)    accounts
# accounts			= (fst conflictsf.value) accounts
# (accounts,hst)	= AccountsDB Set accounts hst 									// if correct store in global database
# (_,hst)			= vertlistFormButs 15 True (Set,tempAccountsId accounts) hst 	// store in temp editor
= (	[B [] "Assign papers to referees:", Br,Br] ++
	table (allRefereeNames accounts) assignf.form accounts ++ 
	[Br,B [] "Specify the conflicting papers:", Br,Br] ++
	table (allRefereeNames accounts) conflictsf.form accounts 
	,hst)
where
	allPaperNumbers acc	= map fst (getRefPapers acc)
	allRefereeNames acc	= [Txt person \\ (RefPerson (Ref2 person),_,_) <- getConflictsAssign acc]
	allPaperNames   acc	= [Txt (toString nr +++ " ") \\ nr <- allPaperNumbers acc]

	table referees assignm acc
		 = [	[B [] "paper nr: ":referees] <=|> 
				group (length (allPaperNumbers acc)) (allPaperNames acc ++ assignm)]

	group n list = [BodyTag (take n list): group n (drop n list)] 

	showAssignments  accounts 
		= [(check "sh_shw_assign" (isMember papernr assigment) papernr person
			, adjustAssignments papernr (RefPerson (Ref2 person))
			) 
			\\ (RefPerson (Ref2 person),_,assigment) <- getConflictsAssign accounts 
			,  papernr <- allPaperNumbers accounts
			]

	showConflicts accounts 
		= [(check "sh_shw_confl" (isMember papernr conflicts) papernr person
			, adjustConflicts papernr (RefPerson (Ref2 person))
			) 
			\\ (RefPerson (Ref2 person),conflicts,_) <- getConflictsAssign accounts
			,  papernr <- allPaperNumbers accounts
			]

	check prefix bool i name 
	| bool	= CBChecked (prefix +++ toString i +++ name)
	= CBNotChecked (prefix +++ toString i +++ name)

	adjustAssignments:: !Int !RefPerson !Bool ![Bool] !ConfAccounts -> ConfAccounts
	adjustAssignments nr person True  bs accounts 	= addAssignment 	nr person accounts
	adjustAssignments nr person False bs accounts 	= removeAssignment  nr person accounts

	adjustConflicts:: !Int !RefPerson !Bool ![Bool] !ConfAccounts -> ConfAccounts
	adjustConflicts nr person True  bs accounts 	= addConflict 	nr person accounts
	adjustConflicts nr person False bs accounts 	= removeConflict  nr person accounts

// general editors

changeInfo :: !ConfAccount !*HSt -> ([BodyTag],!*HSt)
changeInfo account hst
# (personf,hst) = mkEditForm (Init,nFormId "sh_changeInfo" (fromJust (getRefPerson account.state))) hst
= ([Br, Txt "Change your personal information:", Br, Br] ++ personf.form,hst)

submitPaperPage ::  !ConfAccount !*HSt -> ([BodyTag],!*HSt)
submitPaperPage account hst
# [(nr,refpaper):_]	= getRefPapers [account]
# (paperf,hst)	= mkEditForm (Init,sFormId "sh_sbm_paper" refpaper) hst
= (paperf.form,hst)

showPapersPage :: !ConfAccounts !*HSt -> ([BodyTag],!*HSt)
showPapersPage  accounts hst
# irefpaper 	= getRefPapers accounts // [(Int,RefPaper)]
# (papersf,hst) = vertlistFormButs 10 False (Init,sdFormId "sh_shw_papers" 
						(map (\(nr,p) -> (DisplayMode ("Paper Nr: " <+++ nr)<|>p)) irefpaper)) hst
= (papersf.form,hst)

submitReportPage :: !ConfAccount !ConfAccounts !*HSt -> ([BodyTag],!*HSt)
submitReportPage account accounts hst
# myirefreports		= getMyReports account // [(Int, RefReport)]
# mypapersnrs		= map fst myirefreports
| mypapersnrs == []	= ([ Txt "There are no papers for you to referee (yet)" ],hst)
# myrefreports		= [DisplayMode ("Paper Nr: " +++ toString i) <|> refreport \\ (i,refreport) <- myirefreports] 			
# (refreportsf,hst)	= vertlistFormButs 10 False (Init,sFormId "sh_subm_reports" myrefreports) hst
# (reports,hst)		= derefReports (map snd myirefreports) hst
= (show1 mypapersnrs ++ show2 mypapersnrs reports ++ show3 mypapersnrs reports ++ refreportsf.form,hst)
where
	show1 mypapers 			= [Txt ("The following papers have been assigned to you: "), B [] (print mypapers),Br]

	show2 mypapers reports	= [Txt ("You have done: ")		 , B [] (print [i \\ i <- mypapers & n <- reports | isJust n]), Br]
	show3 mypapers reports	= [Txt ("You still have to do: "), B [] (print [i \\ i <- mypapers & n <- reports | isNothing n]), Br]

	print [] = "Nothing"
	print ps = printToString ps

showReportsPage :: !ConfAccount !ConfAccounts !*HSt -> ([BodyTag],!*HSt)
showReportsPage account accounts hst
# allreports = [("paper " +++ toString nr,map (\(RefPerson (Ref2 name),report) -> (name,report)) reports) 
				\\ (nr,reports) <- getMyRefReports account accounts]
# (reportsf,hst) 	= vertlistFormButs 5 False (Set,sdFormId "sh_shw_reports" allreports) hst
= (reportsf.form,hst)

discussPapersPage :: !ConfAccount !ConfAccounts !*HSt -> ([BodyTag],!*HSt)
discussPapersPage account accounts hst
# (allreports,hst)	= getAllMyReports account accounts hst
# allpapernrs		= map fst allreports
# pdmenu			= (0, [("Show paper nr " +++ toString nr, \_ -> i) \\ i <- [0 .. ] & nr <- allpapernrs]) 
# (pdfun,hst)		= FuncMenu (Init, sFormId "sh_dpp_pdm" pdmenu) hst
# selected			= snd pdfun.value
# selectedpaper		= allpapernrs!!selected
# mbpaperrefinfo	= getPaperInfo selectedpaper accounts
# (RefDiscussion (Ref2 name)) = (fromJust mbpaperrefinfo).discussion
# (disclist,hst)	= universalDB (Init,storageOption,Discussion [],name) (\_ _ -> Ok) hst
# ((time,date),hst)	= getTimeAndDate hst
# (newsubmit,newdiscf,hst)	
					= mkSubStateForm (if pdfun.changed Set Init, nFormId "sh_dpp_adddisc" (TS 80 "")) disclist
						(\s -> addItemTextInput (account.login.loginName) time date (toS s)) hst
# (_,hst)			= if newsubmit (universalDB (Set,storageOption,newdiscf.value,name) (\_ _ -> Ok) hst) (undef,hst)
# (disclistf,hst) 	= mkEditForm (Set,sdFormId "sh_show_disc" newdiscf.value) hst
# (newsubmit,newdiscf,hst)	
					= if newsubmit (mkSubStateForm (Set,nFormId "sh_dpp_adddisc" (TS 80 "")) disclist
						(\s -> addItemTextInput (account.login.loginName) time date (toS s)) hst) (newsubmit,newdiscf,hst)
= (	pdfun.form ++ [Br,Hr []] <|.|>  
	hd (mkdisplay allreports selectedpaper) ++ [Br,Hr [], Br] <|.|>
	newdiscf.form <|.|> [Br,Hr []] 
	++ disclistf.form,hst)
where
	addItemTextInput name time date message (Discussion list) 
		=  Discussion [{messageFrom = name, date = date, time = time, message = message}:list]

	toS (TS _ s) = s

	mkdisplay allrep snr =	[ 	[mkTable 	[	[B [] "Paper nr:"	, B [] (toString nr)]
									 		,	[B [] "Status"		, toHtml (paperInfo nr).status] 
									 		]
								] ++
								[mkTable	[ 	[ B [] "Referee: ", Txt (ref.firstName +++ " " +++ ref.lastName)] ++ summarize report	
											\\ ref <- map fst refs_reports & report <- map snd refs_reports 
											]
								]
								\\ (nr,refs_reports) <- allrep | nr == snr
							]
	where
		paperInfo nr = fromJust (getPaperInfo nr accounts)

		summarize Nothing 		= [EmptyBody]
		summarize (Just report)	= [ toHtml report.recommendation , toHtml report.familiarity]	


showPapersStatusPage :: !ConfAccount !ConfAccounts !*HSt -> ([BodyTag],!*HSt)
showPapersStatusPage account accounts hst
# (pdmenu,hst)			= mkEditForm   (Init,sFormId "sh_sPSP_pdm" Submitted) hst // to select status of papers you want to see
# (allireports,hst)		= getAllMyReports account accounts hst	//[(Int,[(Person, Maybe Report)])]
# allpapernrs			= map fst allireports 
# selpaperinfo			= [(nr,paperinfo.status) 	\\ nr <- allpapernrs 
												, (Just paperinfo) <- [getPaperInfo nr accounts]
												| paperinfo.status == pdmenu.value] 	
# selpapernrs			= map fst selpaperinfo	// the number of the papers that have the selected status

| isEmpty selpapernrs	= ([Txt "Show status of all papers which are:",Br,Br] ++ pdmenu.form ++ [Br, Txt "There are no papers that obey these criteria.",Br],hst)
# selreports			= [(nr,map snd persreport) \\ (nr,persreport) <- allireports | isMember nr selpapernrs]
# selsummary			= [("Paper nr: " <+++ nr,	[ (report.recommendation,report.familiarity)
													\\ (Just report) <- reports
						  							]) 
						  \\ (nr,reports) <- selreports]
# (sumlist,hst)			= vertlistForm (Set,tdFormId "sh_sPSP_summ" selsummary) hst
= ([Txt "List all papers which are:",Br,Br] ++ pdmenu.form ++ [Br] ++ sumlist.form,hst)

// utility

show StrongAccept 	= colorbox "Strong Accept" Green
show Accept 		= colorbox "Accept" Lime
show WeakAccept 	= colorbox "Weak Accept" Olive
show Discuss 		= colorbox "Discuss" Black
show WeakReject 	= colorbox "Weak Reject" Maroon
show Reject 		= colorbox "Reject" Fuchsia
show StrongReject 	= colorbox "Strong Reject" Red
colorbox bla color = Table [] [Td [Td_Align Aln_Center,Td_VAlign Alo_Top, Td_Width (Pixels (defpixel)),Td_Bgcolor (`Colorname color)] [Txt bla]]
