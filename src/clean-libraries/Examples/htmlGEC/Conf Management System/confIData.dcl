definition module confIData

// In this module basic editors are either derived or specialized for all types used

import htmlFormData, loginAdmin, stateHandling

derive gForm 	Maybe, [], Ref2
derive gUpd  	Maybe, [], Ref2
derive gPrint 	Maybe, Ref2
derive gParse 	Maybe, Ref2

derive gForm 	
				Login, Account, Member, ManagerInfo, RefereeInfo, Conflicts,
				RefPerson, Person,
				Reports, RefReport, Report, Recommendation, Familiarity, 
				RefPaper, Paper, PaperInfo, Co_authors, RefDiscussion,
				PaperStatus, Discussion, DiscussionStatus, Message
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
				PaperStatus, Discussion, DiscussionStatus, Message

// Naming convention of shared persistent information

uniqueDBname				:== "conferenceDBS"							// accounts database
uniquePerson  	 name 		:== name									// personnel information
uniqueReport  	 int name 	:== name +++ ".report." +++ toString int	// report of paper submiited by referee
uniquePaper   	 int name 	:== name +++ ".paper."  +++ toString int	// submitted paper
uniqueDiscussion int name	:== "discuss."  +++ (uniquePaper int name)	// discussion about submitted paper

// TxtFile conf account database

AccountsDB			:: !Init !ConfAccounts   *HSt -> (ConfAccounts,!*HSt)	// confaccounts db
PaperNrStore 		:: !(Int -> Int) *HSt -> (Int,!*HSt) 					// paper counter

// editors for referenced types

editorRefPerson 	:: !(InIDataId RefPerson) 		!*HSt -> (Form Person,!*HSt)
editorRefPaper 		:: !(InIDataId RefPaper) 		!*HSt -> (Form Paper,!*HSt)
editorRefReport 	:: !(InIDataId RefReport) 		!*HSt -> (Form (Maybe Report),!*HSt)
editorRefDiscussion :: !(InIDataId RefDiscussion)	!*HSt -> (Form Discussion,!*HSt)

// access functions on referenced types

derefPersons 	:: [RefPerson] !*HSt -> ([Person],!*HSt)
derefReports 	:: [RefReport] !*HSt -> ([Maybe Report],!*HSt)
getAllPersons 	:: !ConfAccounts !*HSt -> ([RefPerson],[Person],!*HSt)
getAllMyReports :: !ConfAccount !ConfAccounts !*HSt -> ([(Int,[(Person, Maybe Report)])],!*HSt)

// global setting to store either in files or in a database 

storageOption 	:== TxtFile			// Choose this one to store in files
//storageOption 	:== Database		// Choose this one to store in a database

storeFormId 	:== if (storageOption == TxtFile) pFormId dbFormId 
