implementation module stateHandling

import StdEnv, StdHtml, confIData

import loginAdmin

initManagerLogin :: Login
initManagerLogin	
= (mkLogin "root" (PasswordBox "secret"))

initManagerAccount :: Login -> ConfAccount
initManagerAccount	login 
= mkAccount login (ConfManager {ManagerInfo | person = RefPerson (Ref2 "")})

instance == RefPerson
where
	(==) (RefPerson rp1) (RefPerson rp2) = rp1 == rp2
instance == RefPaper
where
	(==) (RefPaper rp1) (RefPaper rp2) = rp1 == rp2
instance < RefPaper
where
	(<) (RefPaper (Ref2 rp1)) (RefPaper (Ref2 rp2)) = rp1 < rp2
instance == RefReport
where
	(==) (RefReport rp1) (RefReport rp2) = rp1 == rp2
instance < RefReport
where
	(<) (RefReport (Ref2 rp1)) (RefReport (Ref2 rp2)) = rp1 < rp2
instance == PaperStatus
where
	(==) Accepted Accepted = True
	(==) CondAccepted CondAccepted = True
	(==) Rejected Rejected = True
	(==) (UnderDiscussion d1) (UnderDiscussion d2) = d1 == d2
	(==) Submitted Submitted = True
	(==) _ _ = False

instance == DiscussionStatus
where
	(==) ProposeAccept ProposeAccept = True
	(==) ProposeCondAccept ProposeCondAccept = True
	(==) ProposeReject ProposeReject = True
	(==) DoDiscuss DoDiscuss = True
	(==) _ _ = False

:: DiscussionStatus
				=	ProposeAccept
				|	ProposeCondAccept
				|	ProposeReject
				|	DoDiscuss	

isConfManager :: ConfAccount -> Bool
isConfManager account 
= case account.state of
	ConfManager _ -> True
	_ ->  False

isReferee:: ConfAccount -> Bool
isReferee account 
= case account.state of
	Referee _ -> True
	_ ->  False

isAuthor:: ConfAccount -> Bool
isAuthor account 
= case account.state of
	Authors _ -> True
	_ ->  False

isGuest:: ConfAccount -> Bool
isGuest account 
= case account.state of
	Guest _ -> True
	_ ->  False

getRefPerson :: Member -> (Maybe RefPerson)
getRefPerson (ConfManager managerInfo) 	= Just managerInfo.ManagerInfo.person
getRefPerson (Referee refereeInfo)		= Just refereeInfo.RefereeInfo.person							
getRefPerson (Authors paperInfo)		= Just paperInfo.PaperInfo.person
getRefPerson _ = Nothing

getRefPapers :: ConfAccounts -> [(PaperNr,RefPaper)]
getRefPapers accounts = sort [(nr,refpapers) 
							\\ {state = Authors {nr,paper = refpapers}} <- accounts]


getPaperInfo :: PaperNr ConfAccounts -> Maybe PaperInfo
getPaperInfo i accounts =  case [info \\ {state = Authors info=:{nr}} <- accounts | i == nr] of
							[] -> Nothing
							[x:_] -> Just x


getPaperNumbers :: ConfAccounts -> [PaperNr]
getPaperNumbers accounts = sort [nr \\ {state = Authors {nr}} <- accounts]

getAssignments :: ConfAccounts -> [(RefPerson,[PaperNr])]
getAssignments accounts = [(person,map fst reportslist) 
						 \\ {state = Referee {person,reports = Reports reportslist}} 	<- accounts]

getRefReports :: ConfAccounts -> [(PaperNr,[(RefPerson, RefReport)])]
getRefReports accounts = [(nr,	[ (person,refreports) 
								\\ {state = Referee {person,reports = Reports reportslist}} <- accounts
						 		, (rnr,refreports) 									<- reportslist
						 		| rnr == nr ])
							\\ nr <- getPaperNumbers accounts]


getMyRefReports :: ConfAccount ConfAccounts -> [(PaperNr,[(RefPerson, RefReport)])]
getMyRefReports account accounts
# me = getRefPerson account.state 
| isNothing me	= []
=  [(i,reports) 			\\ (i,reports) <- getRefReports accounts
							| not (hasConflict i (fromJust me) [account])]

getMyReports :: ConfAccount -> [(PaperNr, RefReport)]
getMyReports {state = Referee {reports = Reports allreports}} =  sort allreports
getMyReports _ = []

addMyReport :: (PaperNr,RefReport) ConfAccount ConfAccounts -> ConfAccounts
addMyReport myreport acc=:{state = Referee refinfo=:{reports = Reports oldreports}} accounts 
# account = {acc & state = Referee {refinfo & reports = Reports (addreport myreport oldreports)}}
=  changeAccount account accounts
where
	addreport (i,mbrep)[] = [] 
	addreport (i,mbrep)[(j,oldrep):reps] 
	| i == j = [(i,mbrep):reps]
	= [(j,oldrep):addreport (i,mbrep) reps]

getConflicts :: ConfAccounts -> [(RefPerson,[PaperNr])]
getConflicts accounts = [(person,nrs) 
						 \\ {state = Referee {person,conflicts = Conflicts nrs}} 		<- accounts]

getConflictsAssign :: ConfAccounts -> [(RefPerson,[PaperNr],[PaperNr])]
getConflictsAssign accounts = [(person,nrs,map fst reportslist) 
						 	\\ {state = Referee {person,conflicts = Conflicts nrs
							 ,  reports = Reports reportslist}} 						<- accounts]


hasAssignment :: PaperNr RefPerson ConfAccounts -> Bool
hasAssignment nr sperson [] = False
hasAssignment nr sperson [acc=:{state = Referee ref}:accs] 
# person 			= ref.RefereeInfo.person
# (Reports reports) = ref.RefereeInfo.reports
| sperson == person = isMember nr (map fst reports)
hasAssignment nr sperson [acc:accs] = hasAssignment nr sperson accs

hasConflict :: PaperNr RefPerson ConfAccounts -> Bool
hasConflict nr sperson [] = False
hasConflict nr sperson [acc=:{state = Referee ref}:accs] 
# person 				= ref.RefereeInfo.person
# (Conflicts conflicts) = ref.RefereeInfo.conflicts
| sperson == person = isMember nr conflicts
hasConflict nr sperson [acc:accs] = hasConflict nr sperson accs

addAssignment :: PaperNr RefPerson ConfAccounts -> ConfAccounts
addAssignment nr sperson [] = []
addAssignment nr sperson [acc=:{state = Referee ref}:accs] 
# person 			= ref.RefereeInfo.person
# (Reports reports) = ref.RefereeInfo.reports
| sperson == person = [{acc & state  = Referee {ref & reports = Reports [(nr,RefReport (Ref2 "")):reports]}}:accs]
= [acc:addAssignment nr sperson accs]
addAssignment nr sperson [acc:accs] = [acc:addAssignment nr sperson accs]

removeAssignment :: PaperNr RefPerson ConfAccounts -> ConfAccounts
removeAssignment nr sperson [] = []
removeAssignment nr sperson [acc=:{state = Referee ref}:accs] 
# person 			= ref.RefereeInfo.person
# (Reports reports) = ref.RefereeInfo.reports
| sperson == person = [{acc & state  = Referee {ref & reports = Reports (remove nr reports)}}:accs]
with
	remove nr [] = []
	remove nr [(pnr,report):reports]
	| nr == pnr = reports
	= [(pnr,report):remove nr reports]
= [acc:removeAssignment nr sperson accs]
removeAssignment nr sperson [acc:accs] = [acc:removeAssignment nr sperson accs]

addConflict :: PaperNr RefPerson ConfAccounts -> ConfAccounts
addConflict nr sperson [] = []
addConflict nr sperson [acc=:{state = Referee ref}:accs] 
# person 				= ref.RefereeInfo.person
# (Conflicts conflicts) = ref.RefereeInfo.conflicts
| sperson == person = [{acc & state  = Referee {ref & conflicts = Conflicts [nr:conflicts]}}:accs]
= [acc:addConflict nr sperson accs]
addConflict nr sperson [acc:accs] = [acc:addConflict nr sperson accs]

removeConflict :: PaperNr RefPerson ConfAccounts -> ConfAccounts
removeConflict nr sperson [] = []
removeConflict nr sperson [acc=:{state = Referee ref}:accs] 
# person 				= ref.RefereeInfo.person
# (Conflicts conflicts) = ref.RefereeInfo.conflicts
| sperson == person = [{acc & state  = Referee {ref & conflicts = Conflicts (remove nr conflicts)}}:accs]
with
	remove nr [] = []
	remove nr [cnr:conflicts]
	| nr == cnr = conflicts
	= [cnr:remove nr conflicts]
= [acc:removeConflict nr sperson accs]
removeConflict nr sperson [acc:accs] = [acc:removeConflict nr sperson accs]

invariantPerson :: String Person -> Judgement
invariantPerson id {firstName,lastName,affiliation,emailAddress}
| firstName		== ""	= Just (id,"first name is not specified!")
| lastName		== ""	= Just (id,"last name is not specified!")
| affiliation	== ""	= Just (id,"affiliation is not specified!")
| emailAddress	== ""	= Just (id,"email address is not specified!")
= Ok

invariantPersons :: String [Person] -> Judgement
invariantPersons id persons
= Ok

invariantPaper :: String Paper -> Judgement
invariantPaper id {title,first_author,co_authors = Co_authors authors,abstract,pdf}
| title			== ""	= Just (id,"title of paper not specified!")
| tabstract		== ""	= Just (id,"no abstract of paper specified!")
| pdf			== ""	= Just (id,"no pdf given!")
# judgementFirst_author	= invariantPerson (id +++ " first author") first_author
# judgementCo_authors	= foldl (+) Ok (map (invariantPerson (id +++ " co_authors")) authors)
= judgementFirst_author + judgementCo_authors
where
 (TextArea _ _ tabstract) = abstract	

invariantReport :: String Report -> Judgement
invariantReport id {commCommittee=(TextArea _ _ commcommittee),commAuthors=(TextArea _ _ commauthors)}
| commauthors	== ""	= Just (id,"You have to make some remarks to the authors")
| commcommittee	== ""	= Just (id,"You have to make some remarks to the committee")
= Ok

invariantConfAccounts :: String ConfAccounts -> Judgement
invariantConfAccounts id accounts 
# allpapernrs 		= [nr \\ (nr,refpapers) <- getRefPapers accounts]
| isMember 0 allpapernrs 					= Just (id,"paper number has to be a positive number")
| not (allUnique allpapernrs) 				= Just (id,"paper number already in use")
# uniqueconflicts 	= and [allUnique nrs \\ (_,nrs) <- getConflicts accounts] 
| not uniqueconflicts						= Just (id,"conflict already assigned to referee")
# uniqueassigment 	= and [allUnique nrs  \\ (_,nrs) <- getAssignments accounts] 
| not uniqueassigment						= Just (id,"paper already assigned to referee")
# uniqueassignconfl = or [isAnyMember conflnrs asnrs \\ (_,conflnrs,asnrs) <- getConflictsAssign accounts] 
| uniqueassignconfl							= Just (id,"paper assigned conflicts with conflict assigned")
# allreportnrs		= [nr \\ (_,nrs) <- getAssignments accounts, nr <- nrs]
| not (allMembers allreportnrs allpapernrs)	= Just (id,"assignment refers to non existing paper number")
# allconflicts		= [nr \\ (_,nrs) <- getConflicts accounts, nr <- nrs]
| not (allMembers allconflicts allpapernrs)	= Just (id,"conflict refers to non existing paper number")
= Ok

allUnique :: [a] -> Bool | Eq a
allUnique list = length list == length (removeDup list)

allMembers [] list = True
allMembers [x:xs] list = isMember x list && allMembers xs list


setInvariantAccounts :: ConfAccounts -> ConfAccounts
setInvariantAccounts confaccounts
	= map setInvariantAccount confaccounts
where
	setInvariantAccount :: ConfAccount -> ConfAccount
	setInvariantAccount account
	=	case account.state of
			(ConfManager managerInfo) -> 
				{account & state = ConfManager 	{managerInfo 
												& ManagerInfo.person 	= RefPerson (Ref2 uniquename)}}
			(Referee refereeInfo) ->
				{account & state = Referee 		{refereeInfo 
												& RefereeInfo.person 	= RefPerson (Ref2 uniquename)
												, RefereeInfo.reports 	= setInvariantReports refereeInfo.reports}}
			(Authors paperInfo) ->
				{account & state = Authors 		{paperInfo 
												& PaperInfo.person 		= RefPerson 	(Ref2 uniquename)
												, PaperInfo.discussion	= RefDiscussion (Ref2 (uniqueDiscussion paperInfo.nr uniquename))
												, PaperInfo.paper 		= RefPaper      (Ref2 (uniquePaper paperInfo.nr uniquename))}}
			_ -> account
	where
		uniquename								= uniquePerson account.login.loginName
		setInvariantReports (Reports reports)	= Reports (map setInvariantReport reports)
		
		setInvariantReport :: (PaperNr, RefReport) -> (PaperNr, RefReport)
		setInvariantReport (nr, (RefReport (Ref2 _)))
						 = (nr, (RefReport (Ref2 (uniqueReport nr uniquename))))
