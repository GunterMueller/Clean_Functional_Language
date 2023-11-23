implementation module confIData

import StdHtml, StdFunc, StdList, StdString

import stateHandling
import loginAdmin, loginAdminIData
import StdListExtensions

// global account database editor

AccountsDB :: !Init  !ConfAccounts *HSt -> (ConfAccounts,!*HSt) 				// conf management database
AccountsDB init accounts hst 
# accounts = setInvariantAccounts accounts										// ensure that all links are correct
= universalDB (init,storageOption,accounts,uniqueDBname) (\s a -> invariantLogAccounts s a + invariantConfAccounts s a) hst 

PaperNrStore :: !(Int -> Int) *HSt -> (Int,!*HSt) // paper counter
PaperNrStore fun hst 
# (intf,hst) = mkStoreForm (Init,{storeFormId "LastPaperNr" 1 & mode = NoForm}) fun hst
= (intf.value,hst)

// utility access functions for dereferencing

derefPersons :: [RefPerson] !*HSt -> ([Person],!*HSt)
derefPersons refpersons hst
# (personsf,hst)	= maplSt editorRefPerson [(Init,xtFormId ("shid_deref_pers" <+++ i) pers) \\ i <- [0..] & pers <- refpersons] hst
= (map (\v -> v.value) personsf,hst)

derefReports :: [RefReport] !*HSt -> ([Maybe Report],!*HSt)
derefReports refreport hst
# (reportsf,hst)	= maplSt editorRefReport [(Init,xtFormId ("shid_deref_reports" <+++ i) rep) \\ i <- [0..] & rep <- refreport] hst
= (map (\v -> v.value) reportsf,hst)

getAllPersons :: !ConfAccounts !*HSt -> ([RefPerson],[Person],!*HSt)
getAllPersons accounts hst
# refpersons 			= [refperson \\ acc <- accounts, (Just refperson) <- [getRefPerson acc.state]]	
# (persons,hst)			= derefPersons refpersons hst
= (refpersons,persons,hst)

getAllMyReports :: !ConfAccount !ConfAccounts !*HSt -> ([(Int,[(Person, Maybe Report)])],!*HSt)
getAllMyReports account accounts hst
# (refpersons,persons,hst) 
						= getAllPersons accounts hst
# allirefreports 		= getMyRefReports account accounts // [(Int,[(RefPerson, RefReport)])]
# refreports			= [map snd refperson_refreports \\	(_,refperson_refreports) <- allirefreports]
# (reports,hst)			= maplSt derefReports refreports hst

# allireports 			= [(nr,	[(findperson refperson refpersons persons,report1)	\\ (refperson,_) <- refperson_refreports
																						&	report1 <- report
								])
						  \\ (nr,refperson_refreports) <- allirefreports
						  & report <- reports
						  ]

= (allireports,hst)
where
	findperson refperson refpersons persons = hd [p \\ ref <- refpersons & p <- persons | ref == refperson]

// ref editor definitions

editorRefPerson :: !(InIDataId RefPerson) !*HSt -> (Form Person,!*HSt)
editorRefPerson (init,formid) hst
# (RefPerson refperson)					= formid.ival
# (Ref2 name)							= refperson
= universalRefEditor storageOption (init,reuseFormId formid refperson <@ Submit) (invariantPerson name) hst

editorRefPaper :: !(InIDataId RefPaper) !*HSt -> (Form Paper,!*HSt)
editorRefPaper (init,formid) hst
# (RefPaper refpaper)					= formid.ival
# (Ref2 name)							= refpaper
= universalRefEditor storageOption (init,reuseFormId formid refpaper <@ Submit) (invariantPaper name) hst

editorRefReport :: !(InIDataId RefReport) !*HSt -> (Form (Maybe Report),!*HSt)
editorRefReport (init,formid) hst
# (RefReport refreport)					= formid.ival
# (Ref2 name)							= refreport
= universalRefEditor storageOption (init,reuseFormId formid refreport <@ Submit) (invariant name) hst
where
	invariant name Nothing 				= Ok
	invariant name (Just report)		= invariantReport name report
	
editorRefDiscussion :: !(InIDataId RefDiscussion) !*HSt -> (Form Discussion,!*HSt)
editorRefDiscussion (init,formid) hst
# (RefDiscussion refdiscus)				= formid.ival
# (Ref2 name)							= refdiscus
= universalRefEditor storageOption (init,reuseFormId formid refdiscus) (const Ok) hst

// specialized idata forms

gForm {|RefPerson|}     iniformid hst	= specialize (invokeRefEditor editorRefPerson) 		iniformid hst
gForm {|RefPaper|}      iniformid hst	= specialize (invokeRefEditor editorRefPaper)  		iniformid hst
gForm {|RefReport|}     iniformid hst	= specialize (invokeRefEditor editorRefReport)		iniformid hst
gForm {|RefDiscussion|} iniformid hst 	= specialize (invokeRefEditor editorRefDiscussion)	iniformid hst


gForm {|Reports|} informid hst			= specialize myeditor informid hst
where
	myeditor (init,formid) hst
	# (Reports reports) 				= formid.ival
	# (reportsf,hst)					= vertlistFormButs 10 True (init,subsFormId formid "report" reports) hst
	= ({reportsf & value = Reports reportsf.value},hst)

gForm {|Conflicts|} informid hst		= specialize myeditor informid hst
where
	myeditor (init,formid) hst
	# (Conflicts papernrs) 				= formid.ival
	# (papersf,hst)						= vertlistFormButs 10 True (init,subsFormId formid "conflict" papernrs) hst
	= ({papersf & value = Conflicts papersf.value},hst)

gForm {|Co_authors|} informid hst		= specialize myeditor informid hst
where
	myeditor (init,formid) hst
	# (Co_authors authors) 				= formid.ival
	# (authorsf,hst)					= vertlistFormButs 10 True (init,subsFormId formid "authors" authors) hst
	= ({authorsf & value = Co_authors authorsf.value},hst)

gForm {|Discussion|} informid hst		= specialize myeditor informid hst
where
	myeditor (init,formid) hst
	# (Discussion messages)				= formid.ival
	= ({changed = False, form = showDiscussion messages, value = formid.ival},hst)
	where
		showDiscussion [] 	= []
		showDiscussion [{messageFrom,date,time,message}:more] 
							= 	[ mkTable [	[ Txt "date: ", toHtml date, Txt "time: ", toHtml time]
										  ,	[ Txt "from: ", B [] messageFrom ]
								]] ++ 
								[ Txt "message:", Txt message] ++
								[Hr []] ++ showDiscussion more

gForm {|[]|} gHa (init,formid) hst 
= case formid.ival of
	[x:xs]
	# (x,hst) 	= gHa (init,subFormId formid (toString (length xs)) x) hst
	# (xs,hst) 	= gForm {|*->*|} gHa (init,reuseFormId formid xs) hst
	= ({changed = x.changed||xs.changed,form = x.form ++ xs.form,value = [x.value:xs.value]},hst)
	[] 
	= ({changed = False,form = [],value = []},hst)

// derived forms ....

derive gForm /*[], */Maybe, Ref2
derive gUpd [], Maybe, Ref2
derive gPrint Maybe, Ref2
derive gParse Maybe, Ref2

derive gForm 	
				Login, Account, Member, ManagerInfo, RefereeInfo, /*Conflicts, */
				/*RefPerson, */Person,
				/*Reports, *//*RefReport, */ Report, Recommendation, Familiarity, 
				/*RefPaper, */Paper, PaperInfo,/* RefDiscussion,*/ 
				PaperStatus/*, Discussion */ , DiscussionStatus, Message 
derive gUpd 	
				Login, Account, Member, ManagerInfo, RefereeInfo, Conflicts, 
				RefPerson, Person,
				Reports, RefReport, Report, Recommendation, Familiarity, 
				RefPaper, Paper, PaperInfo, Co_authors, RefDiscussion,
				PaperStatus, Discussion, DiscussionStatus, Message
derive gPrint 	
				Login, Account, Member, ManagerInfo, RefereeInfo, Conflicts,
				RefPerson, Person,
				Reports, RefReport, Report, Recommendation, Familiarity, 
				RefPaper, Paper, PaperInfo, Co_authors, RefDiscussion,
				PaperStatus, Discussion, DiscussionStatus, Message
derive gParse 	
				Login, Account, Member, ManagerInfo, RefereeInfo, Conflicts, 
				RefPerson, Person,
				Reports, RefReport, Report, Recommendation, Familiarity, 
				RefPaper, Paper, PaperInfo, Co_authors, RefDiscussion,
				PaperStatus, Discussion, DiscussionStatus, Message
derive gerda 	
				Login, Account, Member, ManagerInfo, RefereeInfo, Conflicts,
				RefPerson, Person,
				Reports, RefReport, Report, Recommendation, Familiarity, 
				RefPaper, Paper, PaperInfo, Co_authors, RefDiscussion,
				PaperStatus, Discussion, DiscussionStatus, Message,
				Ref2
