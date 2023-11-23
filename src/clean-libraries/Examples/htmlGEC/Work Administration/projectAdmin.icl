module projectAdmin

import StdEnv, StdHtml


:: Tree =  Leaf | Branch Tree Tree

L = Leaf
Bra = Branch

derive gForm  	Worker, Project, DailyWork, ProjectPlan, Status, WorkerPlan
derive gUpd 	Worker, Project, DailyWork, ProjectPlan, Status, WorkerPlan, []
derive gPrint	Worker, Project, DailyWork, ProjectPlan, Status, WorkerPlan
derive gParse	Worker, Project, DailyWork, ProjectPlan, Status, WorkerPlan
derive gerda	Worker, Project, DailyWork, ProjectPlan, Status, WorkerPlan


Start world  = doHtmlServer ProjectAdminPage world
//Start world  = doHtml ProjectAdminPage world

:: Project		= 	{ 	plan		:: ProjectPlan
					, 	status		:: Status
					,	members		:: [Worker]
					}	
:: ProjectPlan	= 	{ 	name		:: String
					, 	hours		:: Int
					}
:: Status		=	{ 	total		:: Int
					, 	left		:: Int
					}
:: Worker		=	{ 	name		:: String
					, 	status		:: Status
					, 	work		:: [Work]
					}
:: Work			:== (HtmlDate,Int)
:: WorkerPlan	= 	{ 	project		:: ProjectList
					,	name		:: String
					, 	hours		:: Int
					}
:: DailyWork	=	{ 	projectId 	:: ProjectList
					, 	myName		:: WorkersList
					, 	date		:: HtmlDate
					, 	hoursWorked	:: Int
					}
:: ProjectList	:== PullDownMenu
:: WorkersList	:== PullDownMenu

//	Form creation/update functions:
adminForm :: ([Project] -> [Project]) *HSt -> (Form [Project], *HSt)
adminForm update hst = mkStoreForm (Init, pdFormId "admin" initProjects) update hst

projectForm :: *HSt -> (Form ProjectPlan, *HSt)
projectForm hst = mkEditForm (Init, nFormId "project" (initProjectPlan "" 0)) hst

workerForm :: (WorkerPlan -> WorkerPlan) *HSt -> (Form WorkerPlan, *HSt)
workerForm update hst = mkStoreForm  (Init, nFormId "worker" (initWorkerPlan "" 0 0 initProjects)) update hst

hoursForm :: (DailyWork -> DailyWork) *HSt -> (Form DailyWork, *HSt)
hoursForm update hst = mkStoreForm  (Init, nFormId "hours" (initDailyWork 0 0 initProjects)) update hst

buttonsForm :: DailyWork WorkerPlan ProjectPlan *HSt -> (Form ([Project] -> [Project]), *HSt)
buttonsForm daylog workplan project hst = ListFuncBut (Init, nFormId "buttons" myButtons) hst
where
	myButtons = [ (LButton defpixel "addProject", addNewProject  project )
				, (LButton defpixel "addWorker",  addNewWorkplan workplan)
				, (LButton defpixel "addHours",   addDailyWork   daylog  )
				]
	
	addNewProject :: ProjectPlan -> [Project] -> [Project]
	addNewProject {ProjectPlan|name,hours} = flip (:^) (initProject name hours)
	
	addNewWorkplan :: WorkerPlan -> [Project] -> [Project]
	addNewWorkplan worker=:{project,name,hours}
		= updateElt (\{plan={ProjectPlan|name,hours}} -> name == toString project)
		            (\p -> {p & members = [initWorker name hours:p.members]})
	
	addDailyWork :: DailyWork [Project] -> [Project]
	addDailyWork daylog projects
		| daylog.hoursWorked == 0 || toString daylog.myName == "" || isEmpty projects
						= projects
		| otherwise 	= updateAt (toInt daylog.projectId) updatedProject projects
	where
		{status,plan=plan=:{ProjectPlan|hours},members}
					 	= projects!!(toInt daylog.projectId)
		totalHoursSpent = status.total + daylog.hoursWorked
		remainingHours	= hours - totalHoursSpent
		updatedProject 	= { status  = initStatus remainingHours totalHoursSpent
						  , members = addDay daylog members
						  , plan    = plan
						  }
		nworklog		= { name    = daylog.myName
						  , work    = [(daylog.date,daylog.hoursWorked)]
						  , status  = initStatus 0 0
						  }
	
		addDay :: DailyWork -> [Worker] -> [Worker]
		addDay nwork=:{myName,date,hoursWorked}
			= updateElt (\owork=:{Worker|name} -> name == toString myName)
			            (\owork=:{Worker|status,work}
			                  -> {owork & work   = work ++ [(date,hoursWorked)]
			                            , status = {status & total=status.total+hoursWorked
			                                               , left =status.left -hoursWorked
			                     }                 })

ProjectAdminPage :: *HSt -> (Html,*HSt)
ProjectAdminPage hst
	= updatePage (updateForms hst)
where
	updateForms :: *HSt -> ((Form [Project],Form ProjectPlan,Form WorkerPlan,Form DailyWork,Form ([Project] -> [Project])),*HSt)
	updateForms hst
//		# (adminF,  hst) = adminForm   id hst
		# (projectF,hst) = projectForm    hst
		# (workerF, hst) = workerForm  id hst
		# (hoursF,  hst) = hoursForm   id hst
		# (buttonsF,hst) = buttonsForm hoursF.value workerF.value projectF.value hst
		# (adminF,  hst) = adminForm   buttonsF.value hst
		# (hoursF,  hst) = hoursForm  (adjDailyWork adminF.value) hst
		# (workerF, hst) = workerForm (adjWorkers   adminF.value) hst
		= ((adminF,projectF,workerF,hoursF,buttonsF),hst)
	where
		adjDailyWork :: [Project] DailyWork -> DailyWork
		adjDailyWork projects daylog=:{projectId}
			= {	daylog & projectId = addProjectList projects projectId
			           , myName    = initWorkersList (toInt daylog.myName) (toInt projectId) projects
			  }
		
		adjWorkers :: [Project] WorkerPlan -> WorkerPlan
		adjWorkers projects worker = {worker & project = addProjectList projects worker.project}
		
		addProjectList :: [Project] PullDownMenu -> PullDownMenu
		addProjectList projects (PullDown dim (i,_)) = PullDown dim (i,[name \\ {plan={ProjectPlan|name}} <- projects])
	
	updatePage :: ((Form [Project],Form ProjectPlan,Form WorkerPlan,Form DailyWork,Form ([Project] -> [Project])),*HSt) -> (Html,*HSt)
	updatePage ((adminF,projectF,workerF,hoursF,buttonsF),hst)
		= mkHtml "table test"
			[ H1 [] "Project Administration"
			, STable []
				[ [ STable [] 
						[ [lTxt "Add New Project:"],          projectF.form,[projectButton]
						, [lTxt "Add New Worker:"],           workerF.form, [workerButton]
						: if no_projects [] 
						[ [lTxt "Administrate Worked Hours:"],hoursF.form,  [hoursButton]]
						]
				  : if no_projects []
				  [ STable []
						[ [ lTxt "Current Status of Project:" ]
						, [ toHtml (adminF.value!!(toInt hoursF.value.projectId)) ]
						]
				  ]]
				]
			] hst
	where
		no_projects	= isEmpty adminF.value
		lTxt s		= B [] s
		[projectButton,workerButton,hoursButton:_] = buttonsF.form

// specializations

//	List elements need to be displayed below each other, left aligned:
gForm {|[]|} gHa (init,formid) hst
= case formid.ival of
	[]	
	= ({changed = False, value = [], form =[EmptyBody]},hst)
	[x:xs]
	# (formx, hst) = gHa (init,reuseFormId formid x) hst
	# (formxs,hst) = gForm {|*->*|} gHa (init,setFormId formid xs) hst
	= ({changed = False, value = [x:xs], form = [formx.form <||> formxs.form]},hst)


//	Initial values of the work administration's data structures:
initProjects :: [Project]
initProjects = []

initProject :: String Int -> Project
initProject name hours
	= 	{ plan			= initProjectPlan name hours
		, status		= initStatus hours 0
		, members		= [] }
	
initProjectPlan :: String Int -> ProjectPlan
initProjectPlan name hours
	= 	{ProjectPlan
		| name			= name
		, hours			= hours }

initStatus :: Int Int -> Status
initStatus todo done
	=	{ total			= done
		, left			= todo }

initWorkerPlan :: String Int Int [Project] -> WorkerPlan
initWorkerPlan name hours i projects
	= 	{ project		= initProjectList i projects
		, name			= name
		, hours			= hours }

initWorker :: String Int -> Worker
initWorker name hours
	=	{ name			= name
		, status		= initStatus hours 0
		, work			= [] }

initDailyWork :: Int Int [Project] -> DailyWork
initDailyWork i j projects
	=	{ myName 		= initWorkersList i j projects
		, projectId 	= initProjectList i projects
		, date			= initDate
		, hoursWorked	= 0 }

initDate :: HtmlDate	
initDate = Date 1 1 2005

initWorkersList :: Int Int [Project] -> PullDownMenu
initWorkersList i j []			= PullDown (1,defpixel) (0,[])
initWorkersList i j projects	= PullDown (1,defpixel) (i,[name \\ {Worker|name} <- (projects!!j).members])

initProjectList :: Int [Project] -> PullDownMenu
initProjectList i projects		= PullDown (1,defpixel) (i,[name \\ {plan={ProjectPlan|name}} <- projects])

//	Useful list operations:
updateElt :: (a -> Bool) (a -> a) [a] -> [a]
updateElt c f [] = []
updateElt c f [a:as]
	| c a		= [f a:as]
	| otherwise	= [a:updateElt c f as]

updateElts :: (a -> Bool) (a -> a) [a] -> [a]
updateElts c f [] = []
updateElts c f [a:as]
	| c a		= [f a:updateElts c f as]
	| otherwise	= [  a:updateElts c f as]

(^:) infixr 5 :: a [a] -> [a]
(^:) a as = [a:as]

(:^) infixl 5 :: [a] a -> [a]
(:^) as a = as ++ [a]

//	Monadic digression:
::	StM st a :== st -> .(!a,!st)

(>>=) infixr 5 :: !u:(StM .st .a) !v:(.a -> .(StM .st .b)) -> w:(StM .st .b), [w<=u,w<=v]
(>>=) fA to_mB = mbind` fA to_mB
where
	mbind` fA to_mB st
		# (a,st)	= fA st
		= to_mB a st

(>>-) infixr 5 :: !u:(StM .st .a) !v:(StM .st .b) -> w:(StM .st .b), [w <= u,w <= v]
(>>-) fA fB = mbind_` fA fB
where
	mbind_` fA fB st
		# (_,st)	= fA st
		= fB st

mreturn :: !u:a -> v:(StM .st u:a), [v<=u]
mreturn x = mreturn` x
where
	mreturn` x st = (x,st)
