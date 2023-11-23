definition module stateHandling

import loginAdmin, htmlFormlib

// The Information to maintain:

:: ConfAccounts	:== [ConfAccount]
:: ConfAccount	:== Account Member

// Shared Information:

:: RefPerson	=	RefPerson   	(Ref2 Person)
:: RefPaper		=	RefPaper 		(Ref2 Paper)	
:: RefReport	=	RefReport		(Ref2 MaybeReport)
:: RefDiscussion=	RefDiscussion	(Ref2 Discussion)

// Information maintained by the Conference Manager

:: Member 		= 	ConfManager		ManagerInfo			
				|	Authors			PaperInfo							
				| 	Referee 		RefereeInfo
				|	Guest			Person
				
:: ManagerInfo	=	{ person		:: RefPerson
					}
:: PaperInfo	=	{ person		:: RefPerson
					, nr			:: PaperNr
					, paper			:: RefPaper
					, status		:: PaperStatus
					, discussion	:: RefDiscussion
					}
:: PaperNr 		:==	Int
:: PaperStatus	=	Accepted
				|	CondAccepted
				|	Rejected
				|	UnderDiscussion	DiscussionStatus
				|	Submitted
:: DiscussionStatus
				=	ProposeAccept
				|	ProposeCondAccept
				|	ProposeReject
				|	DoDiscuss	

:: RefereeInfo	=	{ person		:: RefPerson  
					, conflicts		:: Conflicts 
					, reports		:: Reports
					} 
:: Reports		=	Reports			[(PaperNr, RefReport)]

:: Conflicts	=	Conflicts 		[PaperNr]
 
// Information maintained by a referee

:: MaybeReport	:==	Maybe Report

:: Report		=	{ recommendation:: Recommendation
					, familiarity 	:: Familiarity 
					, commCommittee	:: CommCommittee
					, commAuthors	:: CommAuthors
					}
:: Recommendation 
				= 	StrongAccept
				| 	Accept
				| 	WeakAccept
				|	Discuss
				| 	WeakReject
				| 	Reject
				| 	StrongReject
:: Familiarity	= 	Expert
				| 	Knowledgeable
				| 	Low
:: CommCommittee:== TextArea 
:: CommAuthors	:==	TextArea 

// Information maintained by the Conference Manager *or* a Referee *or* an Author

:: Person 		=	{ firstName 	:: String
					, lastName		:: String
					, affiliation	:: String
					, emailAddress	:: String
					} 

// Information maintained by the Conference Manager *or* a Referee *or* an Author

:: Discussion	=	Discussion [Message]
:: Message		= 	{ messageFrom	:: String
					, date			:: HtmlDate
					, time			:: HtmlTime
					, message 		:: String
					}

// Information submitted by an author

:: Paper		=	{ title			:: String
					, first_author	:: Person
					, co_authors	:: Co_authors
					, abstract		:: TextArea
					, pdf			:: String
					}
:: Co_authors 	=	Co_authors [Person]					

// Access functions on these data structures:

initManagerLogin 	:: Login
initManagerAccount 	:: Login 		-> ConfAccount

isConfManager 		:: ConfAccount	-> Bool
isReferee			:: ConfAccount -> Bool
isAuthor			:: ConfAccount -> Bool
isGuest				:: ConfAccount -> Bool

getRefPerson 		:: Member 		-> (Maybe RefPerson)

getPaperNumbers 	:: ConfAccounts -> [PaperNr]
getRefPapers 		:: ConfAccounts -> [(PaperNr,RefPaper)]
getPaperInfo 		:: PaperNr ConfAccounts -> Maybe PaperInfo
getAssignments 		:: ConfAccounts -> [(RefPerson,[PaperNr])]
getConflicts 		:: ConfAccounts -> [(RefPerson,[PaperNr])]
getConflictsAssign	:: ConfAccounts -> [(RefPerson,[PaperNr],[PaperNr])]
getRefReports 		:: ConfAccounts -> [(PaperNr,[(RefPerson, RefReport)])]
getMyRefReports 	:: ConfAccount ConfAccounts -> [(PaperNr,[(RefPerson, RefReport)])]

getMyReports 		:: ConfAccount -> [(PaperNr, RefReport)]
addMyReport 		:: (PaperNr, RefReport) ConfAccount ConfAccounts -> ConfAccounts

hasAssignment 		:: PaperNr RefPerson ConfAccounts -> Bool
hasConflict 		:: PaperNr RefPerson ConfAccounts -> Bool

addAssignment 		:: PaperNr RefPerson ConfAccounts -> ConfAccounts
removeAssignment 	:: PaperNr RefPerson ConfAccounts -> ConfAccounts
addConflict 		:: PaperNr RefPerson ConfAccounts -> ConfAccounts
removeConflict 		:: PaperNr RefPerson ConfAccounts -> ConfAccounts


instance == RefPerson, RefPaper, RefReport, PaperStatus

// invariants testing and setting

invariantConfAccounts 	:: String ConfAccounts 	-> Judgement
invariantPerson 		:: String Person 		-> Judgement
invariantPersons 		:: String [Person] 		-> Judgement
invariantPaper 			:: String Paper 		-> Judgement
invariantReport 		:: String Report 		-> Judgement

setInvariantAccounts 	:: ConfAccounts -> ConfAccounts
