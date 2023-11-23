implementation module htmlFormlib

// Handy collection of Form's
// (c) MJP 2005

import StdEnum, StdFunc, StdList, StdString, StdTuple
import htmlButtons, htmlFormData, htmlTrivial, htmlStylelib
import StdLib

derive gForm []; derive gUpd []


// easy creation of an html page

mkHtml		:: String [BodyTag] *HSt -> (Html,*HSt)
mkHtml s tags hst 			= (simpleHtml s [] tags,hst)

simpleHtml	:: String [BodyAttr] [BodyTag] -> Html
simpleHtml s ba tags	 	= Html (header s) (body tags)
where
	header s				= Head [`Hd_Std [Std_Title s]] [] 
	body tags				= Body ba tags

mkHtmlB		:: String [BodyAttr] [BodyTag] *HSt -> (Html,*HSt)
mkHtmlB s attr tags hst		= (simpleHtml s attr tags,hst)

// operators for lay-out of html bodys ...

// Place two bodies next to each other

(<=>) infixl 5   :: [BodyTag] [BodyTag] -> BodyTag
(<=>) [] []				= EmptyBody
(<=>) [] b2				= BodyTag b2
(<=>) b1 []				= BodyTag b1
(<=>) b1 b2				= (BodyTag b1) <.=.> (BodyTag b2)

(<.=.>) infixl 5 :: BodyTag BodyTag -> BodyTag
(<.=.>) b1 b2				=  STable [Tbl_CellPadding (Pixels 0), Tbl_CellSpacing (Pixels 0)] [[b1,b2]]

// Place second body below first

(<||>) infixl 4	 :: [BodyTag] [BodyTag] -> BodyTag		// Place a above b
(<||>) b1 b2				= (BodyTag b1) <.||.> (BodyTag b2)

(<|.|>) infixl 4 :: [BodyTag] [BodyTag] -> [BodyTag]	// Place a above b
(<|.|>) [] []				= []
(<|.|>) [] b2				= b2
(<|.|>) b1 []				= b1
(<|.|>) b1 b2				= [(BodyTag b1) <.||.> (BodyTag b2)]


(<.||.>) infixl 4:: BodyTag BodyTag -> BodyTag			// Place a above b
(<.||.>) b1 b2				= STable [Tbl_CellPadding (Pixels 0), Tbl_CellSpacing (Pixels 0)] [[b1],[b2]]

(<=|>) infixl 4	 :: [BodyTag] [BodyTag] -> BodyTag		// Place a above b
(<=|>) b1 b2				= STable [Tbl_CellPadding (Pixels 0), Tbl_CellSpacing (Pixels 0)] [[be1,be2] \\ be1 <- b1 & be2 <- b2]

// row and column making

mkColForm :: ![BodyTag] -> BodyTag
mkColForm xs 				= foldr (<.||.>) EmptyBody xs

mkRowForm :: ![BodyTag] -> BodyTag
mkRowForm xs	 			= foldr (<.=.>) EmptyBody xs


mkSTable :: [[BodyTag]] -> BodyTag
mkSTable table				= Table [] (mktable table)
where
	mktable table			= [Tr [] (mkrow rows) \\ rows <- table]	
	mkrow   rows 			= [Td [Td_VAlign Alo_Top, Td_Width (Pixels defpixel)] [row] \\ row <- rows] 

mkTable :: [[BodyTag]] -> BodyTag
mkTable table				= Table []	(mktable table)
where
	mktable table			= [Tr [] (mkrow rows) \\ rows <- table]	
	mkrow   rows	 		= [Td [Td_VAlign Alo_Top] [row] \\ row <- rows] 



// frequently used variants of mkViewForm

mkEditForm :: !(InIDataId d) !*HSt -> (Form d,!*HSt) | iData d
mkEditForm inIDataId hst
= mkViewForm inIDataId
	{ toForm = toViewId, updForm = const2, fromForm = const2, resetForm = Nothing } hst

mkSelfForm  :: !(InIDataId d) !(d -> d) !*HSt -> (Form d,!*HSt) | iData d
mkSelfForm inIDataId cbf hst
= mkViewForm inIDataId 
	{ toForm = toViewId, updForm = update, fromForm = const2, resetForm = Nothing } hst
where
	update b val
	| b.isChanged 			= cbf val
	| otherwise 			= val

mkStoreForm :: !(InIDataId d) !(d -> d) !*HSt -> (Form d,!*HSt) | iData d
mkStoreForm inIDataId cbf hst
= mkViewForm inIDataId
	{ toForm = toViewId, updForm = \_ v = cbf v, fromForm = const2, resetForm = Nothing } hst

mkApplyEditForm	:: !(InIDataId d) !d !*HSt -> (Form d,!*HSt) | iData d
mkApplyEditForm inIDataId inputval hst
= mkViewForm inIDataId
	{ toForm = toViewId, updForm = update, fromForm = const2, resetForm = Nothing } hst
where
	update b val
	| b.isChanged 			= val
	| otherwise 			= inputval

mkBimapEditor :: !(InIDataId d) !(Bimap d v) !*HSt -> (Form d,!*HSt) | iData v
mkBimapEditor inIDataId {map_to,map_from} hst
= mkViewForm inIDataId 
	{ toForm = toViewMap map_to, updForm = const2, fromForm = \_ v -> map_from v, resetForm = Nothing } hst 

mkSubStateForm :: !(InIDataId subState) !state !(subState state -> state) !*HSt -> (Bool,Form state,!*HSt) | iData subState
mkSubStateForm (init,formid) state upd hst
# (nsubState,hst)			= mkEditForm (init,subFormId formid "subst" subState) hst
# (commitBut,hst)			= FuncBut (Init,subnFormId formid "CommitBut" (LButton defpixel "commit",id)) hst
# (cancelBut,hst)			= FuncBut (Init,subnFormId formid "CancelBut" (LButton defpixel "cancel",id)) hst
# (nsubState,hst)			= if cancelBut.changed 
							     (mkEditForm (Set,setFormId formid subState) hst)
							     (nsubState,                                 hst)
= ( commitBut.changed
  ,	{ changed				= nsubState.changed || commitBut.changed || cancelBut.changed
	, value					= if commitBut.changed (upd nsubState.value state) state
	, form					= [ BodyTag nsubState.form
							  , Br
							  , if commitBut.changed (BodyTag [Txt "Thanks for (re-)committing",Br,Br]) EmptyBody
							  , BodyTag commitBut.form
							  , BodyTag cancelBut.form
							  ]
	}
  , hst )
where
	subState				= formid.ival

mkShowHideForm :: !(InIDataId a) !*HSt -> (Form a,!*HSt) | iData a
mkShowHideForm (init,formid) hst 
| formid.mode == NoForm || formid.lifespan == Temp
	= mkEditForm (init,formid) hst
# (hiding,hst)				= mkStoreForm (Init,subFormId formid "ShowHideSore" True) id hst			// True == Hide
# (switch,hst)				= myfuncbut hiding.value hst	
# hide 						= switch.value hiding.value
# (hiding,hst)				= mkStoreForm (Set,subFormId formid "ShowHideSore" True) (const hide) hst	// True == Hide
# (switch,hst)				= myfuncbut hiding.value hst
| hide
	# (info,hst)			= mkEditForm (init,formid <@ NoForm) hst
	= ({info & form			= switch.form},hst)
| otherwise
	# (info,hst)			= mkEditForm (init,formid) hst
	= ({info & form			= switch.form ++ info.form},hst)
where
	mybut     hide			= LButton defpixel (if hide "Show" "Hide") 	
	myfuncbut hide			= FuncBut (Init,subFormId formid "ShowHideBut" (mybut hide,not) <@ Edit)

// Form collection:

horlistForm :: !(InIDataId [a]) !*HSt -> (Form [a],!*HSt) | iData a
horlistForm inIDataId hSt	= layoutListForm (\f1 f2 -> [f1 <=> f2]) mkEditForm inIDataId hSt
			
vertlistForm :: !(InIDataId [a]) !*HSt -> (Form [a],!*HSt) | iData a
vertlistForm inIDataId hSt	= layoutListForm (\f1 f2 -> [f1 <||> f2]) mkEditForm inIDataId hSt

vertlistFormButs :: !Int !Bool !(InIDataId [a]) !*HSt -> (Form [a],!*HSt) | iData a
vertlistFormButs nbuts showbuts (init,formid=:{mode}) hst
# formid					= formid <@ Edit
# indexId					= subFormId formid "idx" 0 <@ Display
# (index,hst)				= mkEditForm (init,indexId) hst
# (olist,hst)				= listForm   (init,formid)  hst
# lengthlist				= length olist.value

# pdmenu					= PullDown (1,defpixel) (0, [toString lengthlist <+++ " More... " : ["Show " <+++ i \\ i <- [1 .. max 1 lengthlist]]]) 
# pdmenuId					= subFormId formid "pdm" pdmenu <@ Edit
# (pdbuts,hst)				= mkEditForm (Init, pdmenuId) hst
# step						= toInt pdbuts.value
| step == 0					= ({form=pdbuts.form,value=olist.value,changed=olist.changed || pdbuts.changed},hst)		

# bbutsId					= subFormId formid "bb" index.value <@ Edit
# (obbuts,hst)				= browseButtons (Init,bbutsId) step lengthlist nbuts hst

# addId						= subnFormId formid "add" addbutton
# (add,   hst) 				= ListFuncBut (Init,addId) hst	

# dellId					= subnFormId formid "dell" (delbutton obbuts.value step)
# (del,   hst) 				= ListFuncBut (Init,dellId) hst	
# insrtId					= subnFormId formid "ins"  (insertBtn createDefault obbuts.value step)
# (ins,   hst) 				= ListFuncBut (Init,insrtId) hst	
# appId						= subnFormId formid "app"  (appendBtn createDefault obbuts.value step)
# (app,   hst) 				= ListFuncBut (Init,appId) hst	

# elemId					= subFormId formid "copyelem" createDefault
# copyId					= subnFormId formid "copy"  (copyBtn obbuts.value step)
# (copy,  hst) 				= ListFuncBut (Init,copyId) hst	
# (elemstore,hst)			= mkStoreForm (Init,elemId) (if copy.changed (const (olist.value!!copy.value 0)) id) hst	

# pasteId					= subnFormId formid "paste" (pasteBtn obbuts.value step)
# (paste,hst) 				= ListFuncBut (Init,pasteId) hst	

# newlist					= olist.value
# newlist					= if paste.changed (updateAt (paste.value 0) elemstore.value newlist) newlist
# newlist					= ins.value newlist 
# newlist					= add.value newlist
# newlist					= app.value newlist 
# newlist					= del.value newlist 

# (list, hst)				= listForm (Set,setFormId formid newlist <@ mode) hst
# lengthlist				= length newlist
# (index,hst)				= mkEditForm (setID indexId obbuts.value) hst
# (bbuts,hst)				= browseButtons (Init, bbutsId) step lengthlist nbuts hst

# betweenindex				= (bbuts.value,bbuts.value + step - 1)

# pdmenu					= PullDown (1,defpixel) (step, [toString lengthlist <+++ " More... " : ["Show " <+++ i \\ i <- [1 .. max 1 lengthlist]]]) 
# (pdbuts,hst)				= mkEditForm (setID pdmenuId pdmenu) hst
 
= (	{ form 					= pdbuts.form ++ bbuts.form ++ 
								[[ toHtml ("nr " <+++ (i+1) <+++ " / " <+++ length list.value)
										<.||.> 
								   (onMode formid.mode (if showbuts (del <.=.> ins <.=.> app  <.=.> copy  <.=.> paste) EmptyBody) 
								   	(if showbuts (del <.=.> ins <.=.> app  <.=.> copy  <.=.> paste) EmptyBody)
								   	EmptyBody 
								   	EmptyBody)
								 \\ del <- del.form & ins <- ins.form & app <- app.form & copy <- copy.form & paste <- paste.form & i <- [bbuts.value..]]
										<=|> 
								list.form % betweenindex
								] ++ (if (lengthlist <= 0) add.form [])
	, value 				= list.value
	, changed 				= olist.changed || list.changed || obbuts.changed || del.changed  || pdbuts.changed || ins.changed ||
							  add.changed   || copy.changed || paste.changed  || list.changed || index.changed  || app.changed
	}
  ,	hst )
where
	but i s					= LButton (defpixel/i) s
	addbutton				= [ (but 1 "Append", const [createDefault]) ]
	delbutton   index step	= [ (but 5 "D", removeAt i)       \\ i <- [index .. index + step]]
	insertBtn e index step	= [ (but 5 "I", insertAt i e)     \\ i <- [index .. index + step]]
	appendBtn e index step	= [ (but 5 "A", insertAt (i+1) e) \\ i <- [index .. index + step]]
	copyBtn     index step	= [ (but 5 "C", const i)          \\ i <- [index .. index + step]]
	pasteBtn    index step	= [ (but 5 "P", const i)          \\ i <- [index .. index + step]]


table_hv_Form :: !(InIDataId [[a]]) !*HSt -> (Form [[a]],!*HSt)							| iData a
table_hv_Form inIDataId hSt = layoutListForm (\f1 f2 -> [f1 <||> f2]) horlistForm inIDataId hSt

t2EditForm  :: !(InIDataId (a,b)) !*HSt -> ((Form a,Form b),!*HSt)						| iData a & iData b
t2EditForm (init,formid) hst
# (forma,hst)				= mkEditForm (init,subFormId formid "t21" a) hst 
# (formb,hst)				= mkEditForm (init,subFormId formid "t21" b) hst
= ((forma,formb),hst) 
where
	(a,b)					= formid.ival

t3EditForm  :: !(InIDataId (a,b,c)) !*HSt -> ((Form a,Form b,Form c),!*HSt)				| iData a & iData b & iData c
t3EditForm (init,formid) hst
# (forma,hst)				= mkEditForm (init,subFormId formid "t31" a) hst 
# (formb,hst)				= mkEditForm (init,subFormId formid "t32" b) hst
# (formc,hst)				= mkEditForm (init,subFormId formid "t33" c) hst
= ((forma,formb,formc),hst) 
where
	(a,b,c)					= formid.ival

t4EditForm  :: !(InIDataId (a,b,c,d)) !*HSt -> ((Form a,Form b,Form c,Form d),!*HSt)	| iData a & iData b & iData c & iData d
t4EditForm (init,formid) hst
# (forma,hst)				= mkEditForm (init,subFormId formid "t41" a) hst 
# (formb,hst)				= mkEditForm (init,subFormId formid "t42" b) hst
# (formc,hst)				= mkEditForm (init,subFormId formid "t43" c) hst
# (formd,hst) 				= mkEditForm (init,subFormId formid "t44" d) hst
= ((forma,formb,formc,formd),hst) 
where
	(a,b,c,d)				= formid.ival

simpleButton :: !String !String !(a -> a) !*HSt -> (Form (a -> a),!*HSt)
simpleButton id label fun hst
//	= FuncBut (Init, nFormId (id +++ label) (LButton defpixel label,fun)) hst
	= FuncBut (Init, nFormId id (LButton defpixel label,fun)) hst

counterForm :: !(InIDataId a) !*HSt -> (Form a,!*HSt) | +, -, one, iData a
counterForm inIDataId hst	= mkViewForm inIDataId bimap hst
where
	bimap					= { toForm		= toViewMap (\n -> (n,down,up))
							  , updForm		= updCounter`
							  , fromForm	= \_ (n,_,_) -> n
							  , resetForm	= Nothing
							  }
	updCounter` b val
	| b.isChanged 			= updCounter val
	| otherwise 			= val

	updCounter (n,Pressed,_)= (n - one,down,up)
	updCounter (n,_,Pressed)= (n + one,down,up)
	updCounter else 		= else

	(up,down)				= (LButton (defpixel / 6) "+",LButton (defpixel / 6) "-")

listForm :: !(InIDataId [a]) !*HSt -> (Form [a],!*HSt) | iData a
listForm inIDataId hSt		= layoutListForm (\f1 f2 -> [BodyTag f1:f2]) mkEditForm inIDataId hSt

layoutListForm :: !([BodyTag] [BodyTag] -> [BodyTag]) 
                  !((InIDataId  a)   *HSt -> (Form  a,  *HSt))
                  ! (InIDataId [a]) !*HSt -> (Form [a],!*HSt) | iData a
layoutListForm layoutF formF (init,formid=:{mode}) hst 
# (store, hst)				= mkStoreForm (init,formid) id  hst			// enables to store list with different # elements
# (layout,hst)				= layoutListForm` 0 store.value hst
# (store, hst)				= mkStoreForm (init,formid) (const layout.value) hst
= (layout,hst)
where
	layoutListForm` n [] hst
		= ({ changed		= False
		   , value			= []
		   , form			= []
		   },hst)
	layoutListForm` n [x:xs] hst
		# (nxs,hst)			= layoutListForm` (n+1) xs hst
		# (nx, hst)			= formF (init,subFormId formid (toString (n+1)) x) hst
		= ({ changed		= nx.changed || nxs.changed
		   , value			= [nx.value:nxs.value]
		   , form			= layoutF nx.form nxs.form
		   },hst)

FuncBut :: !(InIDataId (Button, a -> a)) !*HSt -> (Form (a -> a),!*HSt)
FuncBut (init,formid) hst	= FuncButNr 0 (init,formid) hst 

FuncButNr :: !Int !(InIDataId (Button, a -> a)) !*HSt -> (Form (a -> a),!*HSt)
FuncButNr i (init,formid) hst
= case formid.ival of
	(Pressed,cbf)			= FuncButNr i (init,setFormId formid (LButton 10 "??",cbf)) hst
	(button, cbf)			= mkViewForm (init,reuseFormId nformid id) hbimap hst
	where
		hbimap				= { toForm		= \init _ v -> toViewId init button v
							  , updForm		= const2
							  , fromForm	= \_ but -> case but of 
															Pressed  -> cbf
															_		 -> id
							  , resetForm	= Just (const button)
							  }
		nformid				= case button of
								LButton _ name -> formid <@ formid.id <+++ iDataIdSeparator <+++ name <+++ iDataIdSeparator <+++ i
								PButton _ ref  -> formid <@ formid.id <+++ iDataIdSeparator <+++ i <+++ iDataIdSeparator <+++ ref

TableFuncBut :: !(InIDataId [[(Button, a -> a)]]) !*HSt -> (Form (a -> a) ,!*HSt)
TableFuncBut inIDataId hSt
	= layoutIndexForm (\f1 f2 -> [f1 <||> f2]) 
		(layoutIndexForm (\f1 f2 -> [BodyTag f1:f2]) FuncButNr id (o)) 
			id (o) 0 inIDataId hSt

ListFuncBut2 :: !(InIDataId [(Mode,Button, a -> a)]) !*HSt -> (Form (a -> a),!*HSt)
ListFuncBut2 (init,formid) hst
	= ListFuncBut` 0 formid.ival hst 
where
	ListFuncBut` _ [] hst
	= ({ changed			= False
	   , value				= id
	   , form				= []
	   },hst)
	ListFuncBut` n [(bmode,but,func):xs] hst 
	# (rowfun,hst)			= ListFuncBut` (n+1) xs hst
	# (fun   ,hst)			= FuncButNr n (init,{formid & ival = (but,func)} <@ bmode) hst
	= ({ changed			= rowfun.changed || fun.changed
	   , value				= fun.value o rowfun.value
	   , form				= [BodyTag fun.form:rowfun.form]
	   },hst)

TableFuncBut2 :: !(InIDataId [[(Mode,Button, a -> a)]]) !*HSt -> (Form (a -> a) ,!*HSt)
TableFuncBut2 (init,formid) hSt
	= TableFuncBut2` 0 formid.ival hSt
where
	TableFuncBut2` n [] hSt 	
		= ({ changed		= False
		   , value			= id
		   , form			= []
		   },hSt)
	TableFuncBut2` n [x:xs] hSt 
	# (nx, hSt)				= ListFuncBut2 (init,subFormId formid (toString n) x) hSt
	# (nxs,hSt)				= TableFuncBut2` (n+1) xs hSt
	= ({ changed			= nx.changed || nxs.changed
	   , value				= nx.value o nxs.value
	   , form				= [ nx.form <||> nxs.form ]
	   },hSt)


//	Generalized form of ListFuncBut:
layoutIndexForm :: !([BodyTag] [BodyTag] -> [BodyTag]) 
                   	!(Int (InIDataId x) *HSt -> (Form y,*HSt))
                   	 y (y y -> y) !Int !(InIDataId [x]) !*HSt -> (Form y,!*HSt)
layoutIndexForm layoutF formF r combineF n (init,formid) hSt
= case formid.ival of
	[]						= ({changed=False, value=r, form=[]},hSt)
	[x:xs]
	# (xsF,hSt)				= layoutIndexForm layoutF formF r combineF (n+1) (init,setFormId formid xs) hSt
	# (xF, hSt)				= formF n (init,reuseFormId formid x) hSt
	= ({ changed			= xsF.changed || xF.changed
	   , value				= combineF xsF.value xF.value
	   , form				= layoutF xF.form xsF.form
	   },hSt)

ListFuncBut :: !(InIDataId [(Button, a -> a)]) !*HSt -> (Form (a -> a),!*HSt)
ListFuncBut (init,formid) hSt
	= layoutIndexForm (\f1 f2 -> [BodyTag f1:f2]) FuncButNr id (o) 0 (init,formid) hSt

ListFuncCheckBox :: !(InIDataId [(CheckBox, Bool [Bool] a -> a)]) !*HSt -> (Form (a -> a,[Bool]),!*HSt)
ListFuncCheckBox (init,formid) hst 
# (check,hst)				= ListFuncCheckBox` formid.ival hst
# (f,bools)					= check.value
= ({ changed				= False
   , value					= (f bools,bools)
   , form					= check.form
   },hst)
where
	ListFuncCheckBox` :: ![(CheckBox, Bool [Bool] a -> a)] !*HSt -> (Form ([Bool] a -> a,[Bool]),!*HSt)
	ListFuncCheckBox` [] hst
	= ({ changed			= False
	   , value				= (const2,[])
	   , form				= []
	   },hst)
	ListFuncCheckBox` [x:xs] hst 
	# (rowfun,hst)			= ListFuncCheckBox`   xs hst
	# (fun   ,hst)			= FuncCheckBox formid x  hst
	# (rowfunv,boolsv)		= rowfun.value
	# (funv,nboolv)			= fun.value
	= ({ changed			= rowfun.changed || fun.changed
	   , value				= (funcomp funv rowfunv,[nboolv:boolsv])
	   , form				= [BodyTag fun.form:rowfun.form]
	   },hst)
	where
		funcomp f g			= \bools a = f bools (g bools a)
	
		FuncCheckBox formid (checkbox,cbf) hst
							= mkViewForm (init,nformid) bimap hst
		where
			bimap =	{ toForm 	= \init _ v -> toViewId init checkbox v
					, updForm	= \b v -> v
					, fromForm	= \b v -> if b.isChanged (cbf (toBool v),toBool v) (const2,toBool v)
					, resetForm	= Nothing
					}
		
			toggle (CBChecked    name) 	= CBNotChecked name
			toggle (CBNotChecked name) 	= CBChecked    name
		
			nformid = {formid & ival = (const2,False)} <@ formid.id +++ case checkbox of 
																			(CBChecked    name) = name
																			(CBNotChecked name) = name


// the radio buttons implementation is currently more complicated than strictly necessary
// browsers demand the same name to be used for every member in the radio group
// the current implementation requires different names
// we therefore ourselves have to determine and remember which radio button in the family is set


ListFuncRadio :: !(InIDataId (Int,[Int a -> a])) !*HSt -> (Form (a -> a,Int),!*HSt)
ListFuncRadio (init,formid) hst 
# (ni,   hst)				= mkStoreForm (init,nformidold) (setradio i) hst		// determine which radio to select
# (radio,hst)			 	= ListFuncRadio` ni.value 0 defs hst					// determine if radio changed by user
# (f,nni)					= radio.value
# (f,i)				 		= if (nni>=0) (f nni, nni) (id,ni.value)				// if so, select function, otherwise set to old radio
# (i,hst)					= mkStoreForm (init,nformidnew) (setradio i) hst		// store current selected radio for next round
= ({ changed				= ni.changed || radio.changed
   , value					= (f,i.value)
   , form					= radio.form
   },hst)
where
	(i,defs)				= formid.ival

	nformidold				= reuseFormId formid (setradio (abs i) 0)
	nformidnew				= reuseFormId formid (setradio i i)

	radio i j 
	| i==j	 				= RBChecked    formid.id
	| otherwise				= RBNotChecked formid.id

	setradio i j 
	| i>=0 && i<length defs	= i														// set to new radio buttun 
	| otherwise				= j														// set to old radio button

	ListFuncRadio` :: !Int !Int ![Int a -> a] !*HSt -> (Form (Int a -> a,Int),!*HSt)
	ListFuncRadio` i j [] hst
	= ({ changed			= False
	   , value				= (const2,-1)
	   , form				= []
	   },hst)
	ListFuncRadio` i j [f:fs] hst 
	# (listradio,hst) 		= ListFuncRadio` i (j+1) fs hst
	# (funcradio,hst)		= FuncRadio i j formid f hst
	# (rowfun,rri) 			= listradio.value
	# (fun,ri) 				= funcradio.value
	= ({ changed			= listradio.changed || funcradio.changed
	   , value				= (funcomp fun rowfun,max ri rri)
	   , form				= [BodyTag funcradio.form:listradio.form]
	   },hst)
	where
		funcomp f g			= \i a = f i (g i a)
	
		FuncRadio i j formid cbf hst
							= mkViewForm (init,nformid) bimap hst
		where
			bimap =	{ toForm 	= \_ _ v -> radio i j
					, updForm	= \b v -> if b.isChanged (RBChecked formid.id) (otherradio b v)
					, fromForm	= \b v -> if b.isChanged (cbf,j)               (const2,-1)
					, resetForm	= Nothing
					}
			otherradio b v
			| stripname (hd b.changedId) == formid.id		// REPAIR TO NEW 
							= RBNotChecked formid.id
			| otherwise		= v
			
			nformid			= {formid & ival = (const2,-1)} <@ formid.id <+++ iDataIdSeparator <+++ j

			stripname name	= mkString (takeWhile ((<>) radioButtonSeparator) (mkList name))

FuncMenu :: !(InIDataId (Int,[(String, a -> a)])) !*HSt -> (Form (a -> a,Int),!*HSt)
FuncMenu (init,formid) hst	= mkViewForm (init,nformid) bimap hst
where
	nformid					= reuseFormId formid (id,calc index)
	(index,defs)			= formid.ival
	menulist				= PullDown (1,defpixel) (calc index,map fst defs) 

	bimap =	{ toForm	 	= toViewMap (const menulist)
			, updForm		= const2
			, fromForm		= \b v -> if b.isChanged (snd (defs!!(toInt v)),toInt v) (id,toInt v)
			, resetForm		= Nothing
			}

	calc index
	| abs index >= 0 && abs index < length defs
							= abs index
	| otherwise				= 0

browseButtons :: !(InIDataId Int) !Int !Int !Int !*HSt -> (Form Int,!*HSt)
browseButtons (init,formid) step length nbuttuns hst
# (nindex,  hst)			= mkStoreForm (init,formid) id hst
# (calcnext,hst)			= browserForm nindex.value hst
# (nindex,  hst)			= mkStoreForm (init,formid) calcnext.value hst
# (shownext,hst)			= browserForm nindex.value hst
= ({ changed				= calcnext.changed
   , value					= nindex.value
   , form					= shownext.form
   },hst)
where
	curindex				= formid.ival

	browserForm :: !Int *HSt -> (Form (Int -> Int),!*HSt) 
	browserForm index hst
		= ListFuncBut2 (init,reuseFormId formid (browserButtons index step length)) hst
	where
		browserButtons :: !Int !Int !Int -> [(Mode,Button,Int -> Int)]
		browserButtons init step length
		=	if (init - range >= 0) [(formid.mode,sbut "--", const (init - range))] [] 
							++
			take nbuttuns [(setmode i index,sbut (toString i),const i) \\ i <- [startval,startval+step .. length-1]] 
							++ 
			if (startval + range < length) [(formid.mode,sbut "++", const (startval + range))] []
		where
			range 			= nbuttuns * step
			start i j		= if (i < range) j (start (i-range) (j+range))
			startval 		= start init 0
			sbut s			= LButton (defpixel/3) s
			setmode i index
			| index <= i && i < index + step
							= Display
			| otherwise		= formid.mode

// scripts

openWindowScript ::  !String !Int !Int !Bool !Bool !Bool !Bool !Bool !Bool !Html -> Script
openWindowScript scriptname height width toolbar menubar scrollbars resizable location status html
= FScript( \file -> file <+
			"\rfunction " <+ scriptname <+ "\r" <+
			"{\rOpenWindow=window.open(\"\", \"newwin\", \"" <+
					"height="      <+ height        <+
					",width="      <+ width         <+
					",toolbar="    <+ yn toolbar    <+
					",menubar="    <+ yn menubar    <+
					",scrollbars=" <+ yn scrollbars <+
					",resizable="  <+ yn resizable  <+
					",location="   <+ yn location   <+
					",status="     <+ yn status     <+ "\");\r" <+
				"OpenWindow.document.write(\"" <+ html <+ "</HTML>\");\r" <+
				"OpenWindow.document.close();\r" <+
			"}\r")
where
	yn bool					= if bool "yes" "no" 

openNoticeScript ::  !String !Int !Int !Html -> Script
openNoticeScript scriptname height width html 
	= openWindowScript scriptname height width False False False False False False html

OnLoadException :: !(!Bool,String) -> [BodyAttr]
OnLoadException (True,message) 	= [`Batt_Events [OnLoad (SScript ("\"alert('" +++ message +++ "')\""))]]
OnLoadException _				= []

// refresh time in "minutes:seconds" Minutes should range from 0 to inifinity. Seconds should range from 0 to 59

autoRefresh :: !Int !Int -> Script
autoRefresh minutes seconds 
= FScript( \file -> file <+
				"\rvar limit=\"" <+ minutes <+ ":" <+ seconds <+ "\"" <+ ";\r" <+

				"if (document.images)" <+
				"{ var parselimit=limit.split(\":\");\r" <+
				"  parselimit=parselimit[0]*60+parselimit[1]*1" <+
				"};\r" <+
				"function beginrefresh()\r" <+
				"{ if (!document.images)\r" <+
				"  return;\r" <+
				"  if (parselimit==1)\r" <+
				"  window.location.reload();\r" <+
				"  else\r" <+
				"  { parselimit-=1\r" <+
				"    curmin=Math.floor(parselimit/60)\r" <+
				"    cursec=parselimit%60\r" <+
				"    if (curmin!=0)\r" <+
				"      curtime=curmin+\" minutes and \"+cursec+\" seconds left until page refresh!\"\r" <+
				"    else\r" <+
				"    curtime=cursec+\" seconds left until page refresh!\"\r" <+
				"    window.status=curtime\r" <+
				"    setTimeout(\"beginrefresh()\",1000)\r" <+
				"  }\r" <+
				"}\r" //<+
				
//				"window.onload=beginrefresh"
		)
/*
<script>
<!--

/*
Auto Refresh Page with Time script
By JavaScript Kit (javascriptkit.com)
Over 200+ free scripts here!
*/

//enter refresh time in "minutes:seconds" Minutes should range from 0 to inifinity. Seconds should range from 0 to 59
var limit="0:30"

if (document.images){
var parselimit=limit.split(":")
parselimit=parselimit[0]*60+parselimit[1]*1
}
function beginrefresh(){
if (!document.images)
return
if (parselimit==1)
window.location.reload()
else{ 
parselimit-=1
curmin=Math.floor(parselimit/60)
cursec=parselimit%60
if (curmin!=0)
curtime=curmin+" minutes and "+cursec+" seconds left until page refresh!"
else
curtime=cursec+" seconds left until page refresh!"
window.status=curtime
setTimeout("beginrefresh()",1000)
}
}

window.onload=beginrefresh
//-->
</script>
*/

// special objects ...

mediaPlayer :: !(Int,Int) Bool String -> BodyTag
mediaPlayer (height,width) autostart filename
	= Body_Object 
		[ Oba_ClassId "CLSID:05589FA1-C356-11CE-BF01-00AA0055595A"
		, Oba_Height height
		, Oba_Width width
		] 
		[ Param [ Pam_Name "FileName",  Pam_Value (SV filename) ]
		, Param [ Pam_Name "autostart", Pam_Value (SV (toString autostart)) ]
		]

// special forms

MailForm :: String Int Int -> BodyTag
MailForm  mailaddress row col
	= Form	[Frm_Action ("mailto:" +++ mailaddress), Frm_Method Post, Frm_Enctype "text/plain"] 
			[mkSTable 	[ [B [] "Name:", 	Input [Inp_Type Inp_Text, Inp_Name "uname", Inp_Size 20] ""]
						, [B [] "Email:", 	Input [Inp_Type Inp_Text, Inp_Name "email", Inp_Size 20] "" ]
						, [B [] "Message:", Textarea [Txa_Name "message", Txa_Rows row, Txa_Cols col ] "" ]
						, [Input [Inp_Type Inp_Submit, Inp_Name "submit", Inp_Value (SV "Submit")] ""
						  ,Input [Inp_Type Inp_Reset,  Inp_Name "reset",  Inp_Value (SV "Reset")] ""
						  ]
						]
			] 
	
MailApplicationLink :: String String String -> BodyTag
MailApplicationLink mailaddress subject txtbody
	= A [Lnk_Href ("mailto:" <+++ mailaddress <+++ "?subject=" <+++ subject <+++ "&body=" <+++ txtbody)] [Txt mailaddress]
	
	
	
