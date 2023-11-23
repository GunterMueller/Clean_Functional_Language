implementation module StdWebshop

import StdEnv, StdHtml, GenEq
import CDdatabaseHandler

// globally used definitions

derive gForm  CurrentPage, Item, PersonalData
derive gUpd   CurrentPage, Item, PersonalData
derive gPrint CurrentPage, Item, PersonalData
derive gParse CurrentPage, Item, PersonalData
derive gerda CurrentPage, Item, PersonalData

:: CurrentPage 	= HomePage | ShopPage | BasketPage | OrderPage | ThanksPage

derive gEq CurrentPage

:: Basket		:== [Int]			// item nrs selected

// session forms:

indexForm :: (Int -> Int) *HSt -> (Form Int,!*HSt)
indexForm f hst = mkStoreForm (Init, sFormId "index" 0) f hst

stepForm :: *HSt -> (Form Int,!*HSt)
stepForm hst = mkSelfForm (Init, sFormId "stepsize" 5) (\step -> if (step > 0 && step < 10) step 5) hst

searchForm :: *HSt -> (Form String,!*HSt)
searchForm hst = mkEditForm (Init, sFormId "searchstring" "") hst

searchOptionForm :: (SearchOptions option) *HSt -> (Form (option -> option,Int),!*HSt)
searchOptionForm {options} hst = FuncMenu (Init, sFormId "searchoption"(1,[(label,const option) \\ (label,option) <- options])) hst

personalDataForm :: *HSt -> (Form PersonalData,*HSt)
personalDataForm hst = mkEditForm (Init, sFormId "personal" initPersInfo <@ Submit) hst

// session stores:

currentpageStore :: (CurrentPage -> CurrentPage) *HSt -> (Form CurrentPage,!*HSt)
currentpageStore f hst = mkStoreForm (Init, sFormId "curpageswitch" HomePage)  f hst

basketStore :: (Basket -> Basket) *HSt -> (Form Basket,!*HSt)
basketStore f hst = mkStoreForm (Init,sFormId "zbasket" []) f hst


:: PersonalData
 =	{ name 				:: TextInput
	, address			:: TextInput
	, city				:: TextInput
	, state				:: TextInput
	, zipCode			:: (TextInput,TextInput)
	, country			:: PullDownMenu
	, email				:: TextInput
	, ccCompagny		:: PullDownMenu
	, ccNumber			:: (TextInput,TextInput,TextInput,TextInput)
	, ccExpiringDate	:: (PullDownMenu,PullDownMenu)
	, cardholdersName	:: TextInput
	}	

initPersInfo
 =	{ name 				= TS 30 ""
	, address			= TS 30 ""
	, city				= TS 30 ""
	, state				= TS 30 ""
	, zipCode			= (TI 2 1234,TS 1 "")
	, country			= PullDown (1,100) (0,["Belgium", "Netherlands","United Kingdom"])
	, email				= TS 30 ""
	, ccCompagny		= PullDown (1,100) (0,["MasterCard", "VisaCard"])
	, ccNumber			= (TI 2 1234, TI 2 1234, TI 2 1234,TI 2 1234)
	, ccExpiringDate	= ( PullDown (1,40) (0,[toString m \\ m <- [1 .. 12]])
						  , PullDown (1,60) (0,[toString y \\ y <- [2005 .. 2014]])
						  )
	, cardholdersName	= TS 30 ""
	}	

showBasket :: Bool [Int] (Headers d) [ItemData d] [BodyTag] [BodyTag] -> BodyTag
showBasket onlytop basket headers database infobuts deletebuts
| isEmpty basket = 	BodyTag
					[ Txt "Your Basket is empty."
					, Br
					]
| onlytop = 		BodyTag
				  	[ Txt "Last Item put into basket:"
				  	, Br, Br
					, mkShopTable (1,length basket) headers [database!!(hd basket)] infobuts deletebuts
					]
| otherwise			= BodyTag
				  	[ Txt "Contents of your basket:"
				  	, Br, Br
					, mkShopTable (1,length basket) headers [database!!itemnr \\ itemnr <- basket] infobuts deletebuts
					, Br, Br
					, myTable 	[[ Txt "Total Prize:"]
								, [Txt (showPrize (sum [(database!!itemnr).item.prize \\ itemnr <- basket]))]
								]
					]

// main entry of the shop

webshopentry :: (SearchOptions option) (ExtendedInfo d) (Headers d) [ItemData d] *HSt -> (Html,*HSt) | searchDB option d
webshopentry options extendedInfo headers database hst
# (selPage,    hst) = pageSelectionForm hst					// is a new page selected
# (currentPage,hst) = currentpageStore selPage.value hst 	// set current page
# (page,       hst) = case currentPage.value of					// include the selected page
						HomePage 	-> doHomePage                                database hst
						ShopPage 	-> doShopPage   options extendedInfo headers database hst
						BasketPage 	-> doBasketPage         extendedInfo headers database hst
						OrderPage 	-> doOrderPage                       headers database hst
						ThanksPage	-> doThanksPage	                             database hst
= (mkxHtml "My Web Shop"
		[ STable [] [[Img [Img_Src "images/cdshoptitle.gif"]:selPage.form]]
		, Hr []
		, Br
		, BodyTag page		// code of selected page
		], hst)
where
	pageSelectionForm hst = ListFuncBut (Init, nFormId "pagebut" pagebuttons) hst
	where
		pagebuttons  = 
			[ (but "Home", 		const HomePage)
			, (but "Shop",		const ShopPage)
			, (but "Basket", 	const BasketPage)
			, (but "OrderInfo", const OrderPage)
			]

// home page

doHomePage :: [ItemData d] *HSt -> ([BodyTag],*HSt)
doHomePage database hst
= (	[ maptext 	[ "Welcome to the Clean CD shop!"
				, ""
				, "The time has come to become rich in a Clean way."
				, "We have therefore decided to sell Peter's exquisite CD collection for exquisite prices."
				, ""
				, "By the way, this application also gives a nice demo what you can do with Clean..."
				, ""
				, "Have fun."
				]
	, Br
	, mediaPlayer (50,200) True "images/06 - Tea.mp3"
	, Br
	], hst)

// shop page

doShopPage :: (SearchOptions option) (ExtendedInfo d) (Headers d) [ItemData d] *HSt -> ([BodyTag],*HSt) | searchDB option d
doShopPage soptions extendedInfo headers database hst
# (searchString,hst)= searchForm hst				// read current search string
# (searchOption,hst)= searchOptionForm soptions hst	// read current search option
													// search these items in database
# (found,selection)	= searchDB ((map snd soptions.options)!!(snd (searchOption.value))) (searchString.value) database

# (index,hst)		= indexForm id hst				// read current index
# index		= if (searchString.changed || searchOption.changed) 
							0				// reset index 
							index.value		// use old index
# (step,hst)		= stepForm hst					// read current step
# (shownext, hst)	= browseButtons (Init, nFormId "browsebuts" index) step.value (length selection) nbuttuns hst
# (nindex,hst) 		= indexForm (\_ -> shownext.value) hst
# (add,      hst)	= addToBasketForm nindex.value step.value selection hst
# (basket,   hst) 	= basketStore add.value hst
# (info,     hst)	= InformationForm "listinfo" ([item.itemnr \\ {item} <- selection]%(nindex.value,nindex.value+step.value)) hst
# (binfo,    hst)	= InformationForm "basketinfo" basket.value hst
= (	[ (myTable 	[[Txt "Category:",Txt "Search for:",Txt "#Items found",Txt "#Items / page:"]
				,[toBody searchOption,toBody searchString
				,if found (Txt (toString (length selection)))
				          (Txt "No Items Found")
				,toBody step]
				]  <.=.>
		 STable [] [shownext.form])

	, Br, Br 
	, mkShopTable (nindex.value+1,length selection) headers (selection%(nindex.value,nindex.value+step.value)) info.form add.form 
	, Br, Br
	, showBasket True basket.value headers database binfo.form [EmptyBody]
	, if (info.value -1 < 0) EmptyBody (doScript extendedInfo (database!!(info.value -1)))
	, if (binfo.value -1 < 0) EmptyBody (doScript extendedInfo (database!!(binfo.value -1)))
	], hst)
where
	nbuttuns = 10

	addToBasketForm :: !Int !Int [ItemData d] *HSt -> (Form (Basket -> Basket),!*HSt)
	addToBasketForm index step selection hst
		= ListFuncBut  (Init, nFormId "additems" ([(butp "basket.gif" ,\basket -> [data.item.itemnr:basket]) \\ data <- selection]%(index,index+step-1))) hst

InformationForm :: String [Int] *HSt -> (Form (Int -> Int),!*HSt)
InformationForm name itemlist hst
	= ListFuncBut (Init,nFormId name [(butp "info.gif",const itemnr) \\ itemnr <- itemlist]) hst

// basket page

doBasketPage :: (ExtendedInfo d) (Headers d) [ItemData d] *HSt -> ([BodyTag],*HSt)
doBasketPage extendedInfo headers database hst
# (basket,   hst) 	= basketStore id hst
# (delete,  hst)	= ListFuncBut (Init, nFormId "delitems" [(butp "trash.gif",removeMember itemnr) \\ itemnr <- basket.value])  hst
# (nbasket, hst)	= basketStore delete.value hst	
# (info,    hst)	= InformationForm "basketinfo2" nbasket.value hst
# (order,   hst)	= ListFuncBut (Init, nFormId "buybut" [(but "Order",const OrderPage)]) hst	
# (curpage, hst)	= currentpageStore order.value hst
| curpage.value ===  OrderPage = doOrderPage headers database hst
= ( [ showBasket False nbasket.value headers database info.form delete.form
	, if (info.value -1 < 0) EmptyBody (doScript extendedInfo (database!!(info.value -1)))
	, Br
	, if (isEmpty nbasket.value) EmptyBody (BodyTag [Txt "Go to order page:\t\t", toBody order])
	]
  , hst
  )

// order page

doOrderPage :: (Headers d) [ItemData d] *HSt -> ([BodyTag],*HSt)
doOrderPage headers database hst
# (persData, hst)	= personalDataForm hst
# (confirm,	 hst)	= ListFuncBut (Init, nFormId "confirm" [(but "confirm",const ThanksPage)]) hst	
# (curpage,	 hst)	= currentpageStore confirm.value hst
# (basket,   hst) 	= basketStore id hst
| curpage.value ===  ThanksPage
	= doThanksPage database hst
| otherwise
	= (	[ showBasket False basket.value headers database (repeat EmptyBody) (repeat EmptyBody)
		, Br
		, Txt "All fields must be filled with your data:"
		, toBody persData
		, Br
		, if (isEmpty basket.value) EmptyBody (BodyTag [Txt "Confirm your order:\t\t", toBody confirm])
		], hst)
	
// thanks page

doThanksPage :: [ItemData d] *HSt -> ([BodyTag],*HSt)
doThanksPage database hst
# (_,hst)	= basketStore (const []) hst				// empty basket
= ( [ maptext 	[ "Your order has been processed!"
				, "Thanks for playing with our demo shop."
				, ""
				, "Probably we have to find another way to earn money."
				]
	],hst)
	
// page showing CD information will appear in extra window

doScript :: (ExtendedInfo d) (ItemData d) -> BodyTag
doScript {extKey,extVal} {item,data}
	= Script [] (myScript body)
where
	body		= [ STable tableAttr [ [Txt "Item number:", Txt (toString item.itemnr)] ]
				  , Br
				  , STable tableAttr (map (map (Txt)) (extKey data))
				  , Br
				  , STable tableAttr (map (map (Txt)) (extVal data))
				  , Br
				  , STable tableAttr [ [Txt ("Buy it now for only " +++ showPrize item.prize)] ]
				  ]
	tableAttr	= [Tbl_Border 1, Tbl_Bgcolor (`Colorname Lime)]

// Function to display contents of selected items, database, basket

mkShopTable :: (Int,Int) (Headers d) [ItemData d] [BodyTag] [BodyTag] -> BodyTag
mkShopTable (cnt,max) headers items infobuttons deladdbuttons
	= 	table
		[ empty ++ itemHeader ++ dataHeader ++ empty ++ empty
		: [	CntRow i max ++ itemRow item ++ dataRow headers data ++ mkButtonRow infobutton ++ mkButtonRow deladdbutton
			\\ i           <- [cnt..]
			& {item,data}  <- items 
			& infobutton   <- infobuttons
			& deladdbutton <- deladdbuttons
		  ]
		]				
where
	table rows	 	= Table [Tbl_Width tableWidth, Tbl_Border 0] 
						[Tr [tablestyle j] row \\ row <- rows & j <- [0..]]
	tableWidth		= Percent 100
	(itemW,prizeW)	= (40,100)
	itemHeader	 	= mkRow [(Just itemW,"Item"),(Just prizeW,"Prize")]
	dataHeader 		= mkRow headers.headers
	tablestyle i
	| i == 0		= `Tr_Std [TableHeaderStyle]
	| otherwise		= `Tr_Std [TableRowStyle]

	CntRow i max	= [Td [Td_Width indexW] [Txt (toString i +++ "/" +++ toString max)]] 
	where indexW	= Pixels 50

	itemRow :: Item -> [BodyTag] 
	itemRow item				= mkRow [(Just itemW,toString item.itemnr),(Just prizeW,showPrize item.prize)]

	dataRow :: (Headers d) d -> [BodyTag]
	dataRow {headers,fields} d	= mkRow [(w,f) \\ f <- fields d & (w,_) <- headers]

	mkRow :: [(Maybe Int,String)] -> [BodyTag]
	mkRow items					= [  Td (if (isNothing width) [] [Td_Width (Pixels (fromJust width))]) [Txt item] 
								  \\ (width,item) <- items 
								  ]

	mkButtonRow button			= let buttonW = Pixels 50 in [ Td [Td_Width buttonW] [button] ]
	
	empty						= mkButtonRow EmptyBody

// small utility stuf ...

mkxHtml s tags 	 	= Html (header s) (body tags)
header s 			= Head [`Hd_Std [Std_Title s]] []
body tags 			= Body [onloadBody] tags
mksHtml s tags 	 	= Html (Head [`Hd_Std [Std_Title s]] []) (Body [] tags)

//[Hd_Script [] (autoRefresh 0 10)]

myScript :: [BodyTag] -> Script
myScript body = openWindowScript scriptName 700 400 False False True True False False 
					(mksHtml "InformationWindow" body)

onloadBody = `Batt_Events [OnLoad (SScript scriptName)]

scriptName = "OpenMyWindow()"

but s				= LButton defpixel s
butp s				= PButton (defpixel/2,defpixel/2) ("images/" +++ s)
sbut s				= LButton (defpixel/3) s

bgcolor 			= (Hexnum H_6 H_6 H_9 H_9 H_C H_C)

ziprow body1 body2	= [b1 <=> b2 \\ b1 <- body1 & b2 <- body2]
maptext	texts		= BodyTag (flatten [[Txt text, Br] \\ text <- texts])

myTable table = Table [] [Tr [tablestyle j] (mkrow rows) \\ rows <- table & j <- [0..]]	
where
	mkrow rows 		= [Td [Td_VAlign Alo_Top] [row] \\ row <- rows] 
	tablestyle i
	| i == 0		= `Tr_Std [TableHeaderStyle]
	| otherwise		= `Tr_Std [TableRowStyle]


