implementation module htmlButtons

import StdFunc, StdList, StdString
import htmlFormlib, htmlHandler, htmlStylelib, htmlTrivial

derive gUpd  	(,), (,,), (,,,), (<->), <|>, HtmlDate, HtmlTime, DisplayMode/*, Button, CheckBox*/, RadioButton /*, PullDownMenu, TextInput , TextArea, PasswordBox*/
derive gPrint 	(,), (,,), (,,,), (<->), <|>, HtmlDate, HtmlTime, DisplayMode, Button, CheckBox, RadioButton, PullDownMenu, TextInput, TextArea, PasswordBox
derive gParse 	(,), (,,), (,,,), (<->), <|>, HtmlDate, HtmlTime, DisplayMode, Button, CheckBox, RadioButton, PullDownMenu, TextInput, TextArea, PasswordBox
derive gerda 	(,), (,,), (,,,), (<->), <|>, HtmlDate, HtmlTime, DisplayMode, Button, CheckBox, RadioButton, PullDownMenu, TextInput, TextArea, PasswordBox

:: TextInput	= TI Int Int						// Input box of size Size for Integers
				| TR Int Real						// Input box of size Size for Reals
				| TS Int String						// Input box of size Size for Strings


// Types that have an effect on lay-out

:: HTML = HTML [BodyTag]

gForm {|HTML|} (init,formid ) hst	= specialize myeditor (Set,formid) hst
where
	myeditor (init,formid ) hst
	# (HTML bodytag)				= formid.ival
	= ({changed = False, form = bodytag, value = formid.ival},hst)

gUpd  {|HTML|} mode v				= (mode,v)

gPrint{|HTML|} (HTML x) st			= st <<- "XYX" 

gParse{|HTML|} st					= case gParse {|*|} st of
										Just "XYX" -> Just (HTML [EmptyBody])
										_          -> Just (HTML [EmptyBody])

gerda{|HTML|}  = undef

// Tuples are placed next to each other, pairs below each other ...
layoutTableAtts	:== [Tbl_CellPadding (Pixels 0), Tbl_CellSpacing (Pixels 0)]	// default table attributes for arranging layout

gForm{|(,)|} gHa gHb (init,formid) hst
# (na,hst)				= gHa (init,reuseFormId formid a) (incrHSt 1 hst)   	// one more for the now invisible (,) constructor 
# (nb,hst)				= gHb (init,reuseFormId formid b) hst
= (	{ changed			= na.changed || nb.changed
	, value				= (na.value,nb.value)
	, form				= [STable layoutTableAtts [[BodyTag na.form, BodyTag nb.form]]]
	},hst)
where
	(a,b)				= formid.ival

gForm{|(,,)|} gHa gHb gHc (init,formid) hst
# (na,hst)				= gHa (init,reuseFormId formid a) (incrHSt 1 hst)   	// one more for the now invisible (,,) constructor 
# (nb,hst)				= gHb (init,reuseFormId formid b) hst
# (nc,hst)				= gHc (init,reuseFormId formid c) hst
= (	{ changed			= na.changed || nb.changed || nc.changed
	, value				= (na.value,nb.value,nc.value)
	, form				= [STable layoutTableAtts [[BodyTag na.form,BodyTag nb.form,BodyTag nc.form]]]
	},hst)
where
	(a,b,c)				= formid.ival

gForm{|(,,,)|} gHa gHb gHc gHd (init,formid) hst
# (na,hst)				= gHa (init,reuseFormId formid a) (incrHSt 1 hst)   	// one more for the now invisible (,,) constructor 
# (nb,hst)				= gHb (init,reuseFormId formid b) hst
# (nc,hst)				= gHc (init,reuseFormId formid c) hst
# (nd,hst)				= gHd (init,reuseFormId formid d) hst
= (	{ changed			= na.changed || nb.changed || nc.changed || nd.changed
	, value				= (na.value,nb.value,nc.value,nd.value)
	, form				= [STable layoutTableAtts [[BodyTag na.form,BodyTag nb.form,BodyTag nc.form, BodyTag nd.form]]]
	},hst)
where
	(a,b,c,d)			= formid.ival

// <-> works exactly the same as (,) and places its arguments next to each other, for compatibility with GEC's

gForm{|(<->)|} gHa gHb (init,formid) hst
# (na,hst)				= gHa (init,reuseFormId formid a) (incrHSt 1 hst)   	// one more for the now invisible <-> constructor 
# (nb,hst)				= gHb (init,reuseFormId formid b) hst
= (	{ changed			= na.changed || nb.changed 
	, value				= na.value <-> nb.value
	, form				= [STable layoutTableAtts [[BodyTag na.form, BodyTag nb.form]]]
	},hst)
where
	(a <-> b)			= formid.ival

// <|> works exactly the same as PAIR and places its arguments below each other, for compatibility with GEC's

gForm{|(<|>)|} gHa gHb (init,formid) hst 
# (na,hst)				= gHa (init,reuseFormId formid a) (incrHSt 1 hst)		// one more for the now invisible <|> constructor
# (nb,hst)				= gHb (init,reuseFormId formid b) hst
= (	{ changed			= na.changed || nb.changed 
	, value				= na.value <|> nb.value
	, form				= [STable layoutTableAtts [na.form, nb.form]]
	},hst)
where
	(a <|> b)			= formid.ival

// to switch between modes within a type ...

gForm{|DisplayMode|} gHa (init,formid) hst 	
= case formid.ival of
	(HideMode a)
		# (na,hst)		= gHa (init,reuseFormId formid a <@ Display) (incrHSt 1 hst)
		= (	{ changed	= na.changed 
			, value		= HideMode na.value
			, form		= [EmptyBody]
			},hst)
	(DisplayMode a)
		# (na,hst)		= gHa (init,reuseFormId formid a <@ Display) (incrHSt 1 hst)
		= (	{ changed	= False
			, value		= DisplayMode na.value
			, form		= na.form
			},hst)
	(EditMode a) 
		# (na,hst)		= gHa (init,reuseFormId formid a <@ Edit) (incrHSt 1 hst)
		= (	{ changed	= na.changed
			, value		= EditMode na.value
			, form		= na.form
			},hst)
	EmptyMode
		= (	{ changed	= False
			, value		= EmptyMode
			, form		= [EmptyBody]
			},incrHSt 1 hst)

// Buttons to press

gForm{|Button|} (init,formid) hst 
# (cntr,hst)			= CntrHSt hst
= case formid.ival of
	v=:(LButton size bname)
	= (	{ changed		= False
		, value			= v
		, form			= [Input (onMode formid.mode [] [] [Inp_Disabled Disabled] [] ++
							[ Inp_Type		Inp_Button
							, Inp_Value		(SV bname)
							, Inp_Name		(encodeTriplet (formid.id,cntr,UpdS bname))
							, `Inp_Std		[Std_Style ("width:" <+++ size)]
							, `Inp_Events	(callClean OnClick Edit "")
							]) ""]
		},(incrHSt 1 hst))
	v=:(PButton (height,width) ref)
	= (	{ changed		= False
		, value			= v
		, form			= [Input (onMode formid.mode [] [] [Inp_Disabled Disabled] [] ++
							[ Inp_Type		Inp_Image
							, Inp_Value		(SV ref)
							, Inp_Name		(encodeTriplet (formid.id,cntr,UpdS ref))
							, `Inp_Std		[Std_Style ("width:" <+++ width <+++ " height:" <+++ height)]
							, `Inp_Events	(callClean OnClick Edit "")
							, Inp_Src ref
							]) ""]
		},incrHSt 1 hst)
	Pressed
	= gForm {|*|} (init,(setFormId formid (LButton defpixel "??"))) hst // end user should reset button

gForm{|CheckBox|} (init,formid) hst 
# (cntr,hst)			= CntrHSt hst
= case formid.ival of
	v=:(CBChecked name) 
	= (	{ changed		= False
		, value			= v
		, form			= [Input (onMode formid.mode [] [] [Inp_Disabled Disabled] [] ++
							[ Inp_Type		Inp_Checkbox
							, Inp_Value		(SV name)
							, Inp_Name		(encodeTriplet (formid.id,cntr,UpdS name))
							, Inp_Checked	Checked
							, `Inp_Events	(callClean OnClick formid.mode "")
							]) ""]
		},incrHSt 1 hst)
	v=:(CBNotChecked name)
	= (	{ changed		= False
		, value			= v
		, form			= [Input (onMode formid.mode [] [] [Inp_Disabled Disabled] [] ++
							[ Inp_Type		Inp_Checkbox
							, Inp_Value		(SV name)
							, Inp_Name		(encodeTriplet (formid.id,cntr,UpdS name))
							, `Inp_Events	(callClean OnClick formid.mode "")
							]) ""]
		},incrHSt 1 hst)

gForm{|RadioButton|} (init,formid) hst 
# (cntr,hst)			= CntrHSt hst
= case formid.ival of
	v=:(RBChecked name)
	= (	{ changed		= False
		, value			= v
		, form			= [Input (onMode formid.mode [] [] [Inp_Disabled Disabled] [] ++
							[ Inp_Type			Inp_Radio
							, Inp_Value			(SV name)
							, Inp_Name			(encodeTriplet (formid.id,cntr,UpdS name))
							, Inp_Checked		Checked
							, `Inp_Events		(callClean OnClick formid.mode "")
							]) ""]
		},incrHSt 1 hst)
	v=:(RBNotChecked name)
	= (	{ changed		= False
		, value			= v
		, form			= [Input (onMode formid.mode [] [] [Inp_Disabled Disabled] [] ++
							[ Inp_Type			Inp_Radio
							, Inp_Value			(SV name)
							, Inp_Name			(encodeTriplet (formid.id,cntr,UpdS name))
							, `Inp_Events		(callClean OnClick formid.mode "")
							]) ""]
		},incrHSt 1 hst)

gForm{|PullDownMenu|} (init,formid) hst=:{submits}
# (cntr,hst)			= CntrHSt hst
= case formid.ival of
	v=:(PullDown (size,width) (menuindex,itemlist))
	= (	{ changed		= False
		, value			= v
		, form			= [Select (onMode formid.mode [] [] [Sel_Disabled Disabled] [] ++
							[ Sel_Name			(selectorInpName +++ encodeString 
													(if (menuindex >= 0 && menuindex < length itemlist) (itemlist!!menuindex) ""))
							, Sel_Size			size
							, `Sel_Std			[Std_Style ("width:" <+++ width <+++ "px")]
							, `Sel_Events		(if submits [] (callClean OnChange formid.mode formid.id))
							])
							[ Option 
								[ Opt_Value (encodeTriplet (formid.id,cntr,UpdC (itemlist!!j)))
								: if (j == menuindex) [Opt_Selected Selected] [] 
								]
								elem
								\\ elem <- itemlist & j <- [0..]
							]]
		},incrHSt 1 hst)

gForm{|TextInput|} (init,formid) hst 	
# (cntr,hst)			= CntrHSt hst
# (body,hst)			= mkInput size (init,formid) v updv hst
= ({changed=False, value=formid.ival, form=[body]},incrHSt 2 hst)
where
	(size,v,updv)		= case formid.ival of
							(TI size i) = (size,IV i,UpdI i)
							(TR size r) = (size,RV r,UpdR r)
							(TS size s) = (size,SV s,UpdS s)

gForm{|TextArea|} (init,formid) hst 
# (cntr,hst)			= CntrHSt hst
= (	{ changed			= False
	, value				= formid.ival
	, form				= [myTable [	[ Textarea 	[ Txa_Name (encodeTriplet (formid.id,cntr,UpdS string))
						  				, Txa_Rows (if (row == 0) 10 row)
						  				, Txa_Cols (if (col == 0) 50 col)
						  				] string ]
						  			]
						  ]
	},incrHSt 1 hst)
where
	(TextArea row col string) = formid.ival

	myTable table
	= Table []	(mktable table)
	where
		mktable table 	= [Tr [] (mkrow rows) \\ rows <- table]	
		mkrow rows 		= [Td [Td_VAlign Alo_Top, Td_Width (Pixels defpixel)] [row] \\ row <- rows] 

gUpd{|TextArea|}       (UpdSearch (UpdS name) 0) (TextArea r c s) 	= (UpdDone,                TextArea r c (urlDecode name))									// update button value
gUpd{|TextArea|}       (UpdSearch val cnt)       t					= (UpdSearch val (cnt - 1),t)										// continue search, don't change
gUpd{|TextArea|}       (UpdCreate l)             _					= (UpdCreate l,            TextArea defsize defsize "")					// create default value
gUpd{|TextArea|}       mode                      t					= (mode,                   t)										// don't change

gForm{|PasswordBox|} (init,formid) hst 	
= case formid.ival of
	(PasswordBox password) 
	# (body,hst)		= mkPswInput defsize (init,formid) password (UpdS password) hst
	= ({ changed		= False
	   , value			= PasswordBox password
	   , form			= [body]
	   },incrHSt 1 hst)
where
	mkPswInput :: !Int !(InIDataId d) String UpdValue !*HSt -> (!BodyTag,!*HSt) 
	mkPswInput size (init,formid=:{mode}) sval updval hst=:{cntr,submits}
	| mode == Edit || mode == Submit
		= ( Input 	[ Inp_Type		Inp_Password
					, Inp_Value		(SV sval)
					, Inp_Name		(encodeTriplet (formid.id,cntr,updval))
					, Inp_Size		size
					, `Inp_Std		[EditBoxStyle, Std_Title "::Password"]
					, `Inp_Events	if (mode == Edit && not submits) (callClean OnChange Edit "") []
					] ""
			,incrHSt 1 hst)
	| mode == Display
		= ( Input 	[ Inp_Type		Inp_Password
					, Inp_Value		(SV sval)
					, Inp_ReadOnly	ReadOnly
					, `Inp_Std		[DisplayBoxStyle]
					, Inp_Size		size
					] ""
			,incrHSt 1 hst)
	= ( EmptyBody,incrHSt 1 hst )


// time and date

import StdTime

getTimeAndDate :: !*HSt -> *(!(!HtmlTime,!HtmlDate),!*HSt)
getTimeAndDate hst
# (time,hst)				= accWorldHSt getCurrentTime hst
# (date,hst)				= accWorldHSt getCurrentDate hst
= ((Time time.hours time.minutes time.seconds,Date date.day date.month date.year),hst)

gForm {|HtmlTime|} (init,formid) hst
	= specialize (flip mkBimapEditor {map_to = toPullDown, map_from = fromPullDown}) (init,formid <@ Page) hst
where
	toPullDown (Time h m s)	= (hv,mv,sv)
	where
		hv					= PullDown (1, defpixel/2) (h,[toString i \\ i <- [0..23]])
		mv					= PullDown (1, defpixel/2) (m,[toString i \\ i <- [0..59]])
		sv					= PullDown (1, defpixel/2) (s,[toString i \\ i <- [0..59]])

	fromPullDown (hv,mv,sv)	= Time (convert hv) (convert mv) (convert sv)
	where
		convert x			= toInt (toString x)

gForm {|HtmlDate|} (init,formid) hst 
	= specialize (flip mkBimapEditor {map_to = toPullDown, map_from = fromPullDown}) (init,formid <@ Page) hst
where
	toPullDown (Date d m y)	= (dv,mv,yv)
	where
		dv					= PullDown (1,  defpixel/2) (md-1,   [toString i \\ i <- [1..31]])
		mv					= PullDown (1,  defpixel/2) (mm-1,   [toString i \\ i <- [1..12]])
		yv					= PullDown (1,2*defpixel/3) (my-1950,[toString i \\ i <- [1950..2015]])

		my					= if (y >= 2006 && y <= 2015) y 2006
		md					= if (d >= 1    && d <= 31)   d 1
		mm					= if (m >= 1    && m <= 12)   m 1

	fromPullDown (dv,mv,yv)	= Date (convert dv) (convert mv) (convert yv)
	where
		convert x			= toInt (toString x)

// Updates that have to be treated specially:

gUpd{|PullDownMenu|} (UpdSearch (UpdC cname) 0) (PullDown dim (menuindex,itemlist)) 
																= (UpdDone,                PullDown dim (itemlist??cname,itemlist))	// update integer value
gUpd{|PullDownMenu|} (UpdSearch val cnt)       v				= (UpdSearch val (cnt - 1),v)										// continue search, don't change
gUpd{|PullDownMenu|} (UpdCreate l)             _				= (UpdCreate l,            PullDown (1,defpixel) (0,["error"]))		// create default value
gUpd{|PullDownMenu|} mode                      v				= (mode,                   v)										// don't change

gUpd{|Button|}       (UpdSearch (UpdS name) 0) _				= (UpdDone,                Pressed)									// update button value
gUpd{|Button|}       (UpdSearch val cnt)       b				= (UpdSearch val (cnt - 1),b)										// continue search, don't change
gUpd{|Button|}       (UpdCreate l)             _				= (UpdCreate l,            LButton defsize "Press")					// create default value
gUpd{|Button|}       mode                      b				= (mode,                   b)										// don't change

gUpd{|CheckBox|}     (UpdSearch (UpdS name) 0) (CBChecked    s)	= (UpdDone,                CBNotChecked s)							// update CheckBox value
gUpd{|CheckBox|}     (UpdSearch (UpdS name) 0) (CBNotChecked s)	= (UpdDone,                CBChecked    s)							// update CheckBox value
gUpd{|CheckBox|}     (UpdSearch val cnt)       b				= (UpdSearch val (cnt - 1),b)										// continue search, don't change
gUpd{|CheckBox|}     (UpdCreate l)             _				= (UpdCreate l,            CBNotChecked "defaultCheckboxName")		// create default value
gUpd{|CheckBox|}     mode                      b				= (mode,                   b)										// don't change

gUpd{|TextInput|}    (UpdSearch (UpdI ni) 0)   (TI size i)		= (UpdDone,                TI size ni)								// update integer value
gUpd{|TextInput|}    (UpdSearch (UpdR nr) 0)   (TR size r)		= (UpdDone,                TR size nr)								// update real    value
gUpd{|TextInput|}    (UpdSearch (UpdS ns) 0)   (TS size s)		= (UpdDone,                TS size ns)								// update string  value
gUpd{|TextInput|}    (UpdSearch val cnt)       i				= (UpdSearch val (cnt - 3),i)										// continue search, don't change
gUpd{|TextInput|}    (UpdCreate l)             _				= (UpdCreate l,            TI defsize 0)							// create default value
gUpd{|TextInput|}    mode                      i				= (mode,                   i)										// don't change

gUpd{|PasswordBox|}  (UpdSearch (UpdS name) 0) _				= (UpdDone,                PasswordBox name)						// update password value
gUpd{|PasswordBox|}  (UpdSearch val cnt)       b				= (UpdSearch val (cnt - 2),b)										// continue search, don't change
gUpd{|PasswordBox|}  (UpdCreate l)             _				= (UpdCreate l,            PasswordBox "")							// create default value
gUpd{|PasswordBox|}  mode                      b				= (mode,                   b)										// don't change

// small utility stuf

instance toBool RadioButton where
	toBool (RBChecked _)					= True
	toBool _								= False

instance toBool CheckBox where
	toBool (CBChecked _)					= True
	toBool _								= False

instance toBool Button where
	toBool Pressed							= True
	toBool _								= False

instance toInt PullDownMenu where
	toInt (PullDown _ (i,_))				= i

instance toString PullDownMenu where
	toString (PullDown _ (i,s))				= if (i>=0 && i <=length s) (s!!i) ""

derive gEq PasswordBox, HtmlTime, HtmlDate
instance == PasswordBox where (==) pb1 pb2	= pb1 === pb2
instance == HtmlTime    where (==) ht1 ht2	= ht1 === ht2
instance == HtmlDate    where (==) hd1 hd2	= hd1 === hd2

instance == (DisplayMode a) | == a
where 
	(==) (DisplayMode a) (DisplayMode b)	= a == b
	(==) (EditMode a) (EditMode b)			= a == b
	(==) (HideMode a) (HideMode b)			= a == b
	(==) EmptyMode EmptyMode				= True
	(==) _ _								= False

derive gLexOrd HtmlTime, HtmlDate
instance < HtmlTime where (<) ht1 ht2		= gEq{|*|} (gLexOrd{|*|} ht1 ht2) LT
instance + HtmlTime where (+) (Time h1 m1 s1) (Time h2 m2 s2)
											= Time (h1 + h2) (m1 + m2) (s1 + s2)
instance - HtmlTime where (-) (Time h1 m1 s1) (Time h2 m2 s2)
											= Time (h1 - h2) (m1 - m2) (s1 - s2)
instance < HtmlDate where (<) hd1 hd2		= gEq{|*|} (gLexOrd{|*|} hd1 hd2) LT

instance toString HtmlTime where
	toString (Time hrs min sec)				= toString hrs <+++ ":" <+++ min <+++ ":" <+++ sec
instance toString HtmlDate where
	toString (Date day month year)			= toString day <+++ "/" <+++ month <+++ "/" <+++ year
