module newsGroups

//	In this example newsgroups are created and maintained
//	User 0 is the manager of the newsgroup who can create new newgroups
//	All other users can subscribe to such a newsgroup, commit a message or read news
// (c) mjp 2007 

import StdEnv, StdHtml

derive gForm 	[]
derive gUpd 	[]

npersons 		= 5							// number of participants
storageKind 	= Database					// storage format
nmessage		= 5							// maximum number of messages to read from group

:: NewsGroups	:== [GroupName]				// list of newsgroup names
:: GroupName	:== String					// Name of the newsgroup
:: NewsGroup	:== [News]					// News stored in a news group
:: News			:== (Subscriber,Message)	// a message and the id of its publisher
:: Subscriber	:== Int						// the id of the publisher
:: Message		:== String					// the message
:: Subscriptions:== [Subscription]			// newsgroup subscriptions of user
:: Subscription	:== (GroupName,Index)		// last message read in corresponding group
:: Index		:== Int						// 0 <= index < length newsgroup 

Start world = doHtmlServer (multiUserTask npersons True allTasks) world

allTasks = andTasks_mu "newsGroups" [(0,foreverTask newsManager):[(i,foreverTask newsReader) \\ i <- [1 .. npersons - 1]]]

newsManager
=	chooseTask 	[("newGroup",  addNewsGroup -||- editTask "Cancel" Void)
				,("showGroup", showGroup)
				]
where
	addNewsGroup
	=	[Txt "Define name of new news group:",Br,Br] ?>> 
		editTask "Define" "" =>> \newName  ->
		readNewsGroups       =>> \oldNames ->	
		writeNewsGroups (removeDup (sort [newName:oldNames])) #>>
		return_V Void
	showGroup
	=	(readNewsGroups =>> PDMenu) #>> return_V Void

PDMenu list
=	[] ?>> 
	editTask "OK" (PullDown (1,100) (0,list)) =>> \value ->	
	return_V (toInt value,toString value)

newsReader 
=	taskId *>> \me ->
	chooseTask 	[("subscribe", subscribeNewsGroup me -||- editTask "Cancel" Void)
				,("readNews", readNews me)]
where
	OK :: Task Void
	OK = editTask "OK" Void

	subscribeNewsGroup :: Subscriber -> Task Void
	subscribeNewsGroup me
	=	readNewsGroups =>> \groups    ->
		PDMenu groups  =>> \(_,group) ->
		addSubscription me (group,0) #>>
		[Txt "You have subscribed to news group ", B [] group,Br,Br] ?>> OK

	readNews :: Subscriber -> Task Void
	readNews me
	=	readSubscriptions me =>> \mygroups ->
		PDMenu ([group \\ (group,_) <- mygroups] ++ ["Cancel"]) =>> \(_,group) ->
		readNews` group
	where
		readNews` "Cancel"=	[Txt "You have not selected a newgroup you are subscribed on!",Br,Br] ?>> OK
		readNews` group	=	[Txt "You are looking at news group ", B [] group, Br, Br] 
							?>>	foreverTask 
								(	readIndex me  group =>> \index ->
									readNewsGroup group =>> \news  ->
									showNews index (news%(index,index+nmessage-1)) (length news) 
									?>>	chooseTask 	
										[("<<",			readNextNewsItems me (group,index) (~nmessage) (length news))
										,("update",		return_V Void)
										,(">>",			readNextNewsItems me (group,index) nmessage (length news))
										,("commitNews",	commitItem group me)
										]
								)
								-||-
								editTask "leaveGroup" Void

	readNextNewsItems :: Subscriber Subscription Int Int -> Task Void
	readNextNewsItems  me (group,index) offset length
	# nix = index + offset
	# nix = if (nix < 0) 0 (if (length <= nix) index nix)
	= addSubscription me (group,nix) #>> return_V Void				 

	commitItem :: GroupName Subscriber -> Task Void
	commitItem group me 
	=	[Txt "Type your message ..."] 
		?>>	editTask "Commit" (TextArea 4 80 "") <<@ Submit =>>	\(TextArea _ _ val) -> 	
		readNewsGroup  group =>> \news ->	
		writeNewsGroup group (news ++ [(me,val)]) #>>
		[Txt "Message commited to news group ",B [] group, Br,Br] ?>> OK


// displaying news groups

showNews ix news nrItems = [STable [] 	[[B [] "Issue:", B [] "By:", B [] "Contents:"]
								:[[Txt (showIndex nr),Txt (toString who),Txt (toString info)] 
									\\ nr <- [ix..] & (who,info) <- news]
								]]
where
	showIndex i	= ((i+1) +++> " of ") <+++ nrItems
	
// reading and writing of storages

readNewsGroups :: Task NewsGroups
readNewsGroups = readDB newsGroupsId

writeNewsGroups :: NewsGroups -> Task NewsGroups
writeNewsGroups newgroups = writeDB newsGroupsId newgroups

readSubscriptions :: Subscriber -> Task Subscriptions
readSubscriptions me = readDB (readerId me)

writeSubscriptions :: Subscriber Subscriptions -> Task Subscriptions
writeSubscriptions me subscriptions = writeDB (readerId me) subscriptions

addSubscription :: Subscriber Subscription -> Task Subscriptions
addSubscription me (groupname,index)
# index	= if (index < 0) 0 index
= readSubscriptions  me =>> \subscriptions ->
  writeSubscriptions me [(groupname,index):[(group,index) \\ (group,index) <- subscriptions | group <> groupname]]

readIndex :: Subscriber GroupName -> Task Index
readIndex me groupname
= readSubscriptions me =>> \subscriptions ->
  return_V (hds [index \\ (group,index) <- subscriptions | group == groupname])
where
	hds [x:xs] = x
	hds [] = 0

readNewsGroup :: GroupName -> Task NewsGroup
readNewsGroup groupname = readDB (groupNameId groupname)

writeNewsGroup :: GroupName NewsGroup -> Task NewsGroup
writeNewsGroup groupname news = writeDB (groupNameId groupname) news

// iData database storage access utility functions

newsGroupsId		:==	"newsGroups"
readerId i			= 	"reader" <+++ i
groupNameId name	=	"NewsGroup-" +++ name

readDB 	name 		= appHSt (DB name id)
writeDB name value 	= appHSt (DB name (const value)) 

DB :: String (a -> a) *HSt -> (a,*HSt) | iData a
DB name fun hst 
# (form,hst)	= mkStoreForm (Init,nFormId name createDefault <@ storageKind) fun hst
= (form.value,hst)
