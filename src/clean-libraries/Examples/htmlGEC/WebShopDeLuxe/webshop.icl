implementation module webshop

import StdEnv, StdHtml, GenEq
import CDdatabaseHandler

// globally used definitions

derive gForm  CurrentPage, Item, PersonalData
derive gUpd   CurrentPage, Item, PersonalData
derive gPrint CurrentPage, Item, PersonalData
derive gParse CurrentPage, Item, PersonalData

:: CurrentPage 	= HomePage | ShopPage | BasketPage | OrderPage | ThanksPage

derive gEq CurrentPage

:: Basket		:== [Int]			// item nrs selected

// storages which are shared between the pages
// and in this way keep information persistent when the user is switching between pages
// each store can be examined again in any page to get access to its contents

:: SharedForms option
 =	{ currentPage	:: Form CurrentPage				// page to display
	, index			:: Form Int						// current item number to show
	, step			:: Form Int						// numbers of items to display on a page
	, searchString	:: Form String					// current search string 
	, searchOption	:: Form (option -> option,Int)	// current option
 	, basket 		:: Form [Int]					// items stored in basket 
	, personalData	:: Form PersonalData			// all data of the costumer
 	}

sharedForms :: (SearchOptions option) *HSt -> (SharedForms option,!*HSt)
sharedForms options hst
	# (curpage,      hst)	= currentpageForm id hst
	# (index,        hst)	= indexForm id hst
	# (step,         hst)	= stepForm hst
	# (searchString, hst)	= searchForm hst
	# (searchOption, hst)	= optionForm options hst
	# (personalData, hst)	= personalDataForm hst
	# (basket,       hst)	= basketForm id hst	
	= ( { currentPage		= curpage
		, index				= index
		, step				= step
		, searchString		= searchString
		, searchOption		= searchOption
	 	, basket 			= basket 
		, personalData		= personalData
	 	}
	  , hst
	  )

currentpageForm :: (CurrentPage -> CurrentPage) *HSt -> (Form CurrentPage,!*HSt)
currentpageForm f hst = mkStoreForm "curpageswitch" f HomePage hst

indexForm :: (Int -> Int) *HSt -> (Form Int,!*HSt)
indexForm f hst = mkStoreForm "index" f 0 hst

stepForm :: *HSt -> (Form Int,!*HSt)
stepForm hst = mkSelfForm "stepsize" (\step -> if (step > 0 && step < 10) step 5) 5 hst

searchForm :: *HSt -> (Form String,!*HSt)
searchForm hst = mkEditForm "searchstring" Edit "" hst

optionForm :: (SearchOptions option) *HSt -> (Form (option -> option,Int),!*HSt)
optionForm {options} hst = FuncMenu -1 "searchoption" Edit [(label,const option) \\ (label,option) <- options] hst

basketForm :: (Basket -> Basket) *HSt -> (Form Basket,!*HSt)
basketForm f hst = mkStoreForm "zbasket" f [] hst

personalDataForm :: *HSt -> (Form PersonalData,*HSt)
personalDataForm hst = mkEditForm "personal" Edit initPersInfo hst

:: PersonalData
 =	{ name 				:: TextInput
	, address			:: TextInput
	, city				:: TextInput
	, state				:: TextInput
	, zipCode			:: (TextInput,TextInput)
	, country			:: PullDownMenu
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
					[ bTxt "Your Basket is empty."
					, Br
					]
| onlytop = 		BodyTag
				  	[ bTxt "Last Item put into basket:"
					, mkTable (1,length basket) headers [database!!(hd basket)] infobuts deletebuts
					]
| otherwise			= BodyTag
				  	[ bTxt "Contents of your basket:"
					, mkTable (1,length basket) headers [database!!itemnr \\ itemnr <- basket] infobuts deletebuts
					, Br
					, STable [] [[ bTxt "Total Prize:"
								, toHtml (showPrize (sum [(database!!itemnr).item.prize \\ itemnr <- basket]))
								]]
					]

// main entry of the shop

webshopentry :: (SearchOptions option) (ExtendedInfo d) (Headers d) [ItemData d] *HSt -> (Html,*HSt) | searchDB option d
webshopentry options extendedInfo headers database hst
# (selPage,    hst) = pageSelectionForm hst				// is a new page selected
# (curPage,    hst) = currentpageForm selPage.value hst // determine current page
# (sharedForms,hst)	= sharedForms options hst			// include all shared forms
# (page,       hst) = case curPage.value of				// include the selected page
						HomePage 	-> doHomePage                                database sharedForms hst
						ShopPage 	-> doShopPage   options extendedInfo headers database sharedForms hst
						BasketPage 	-> doBasketPage         extendedInfo headers database sharedForms hst
						OrderPage 	-> doOrderPage                       headers database sharedForms hst
						ThanksPage	-> doThanksPage	                             database sharedForms hst
= (mkHtml "My Web Shop"
		[ STable [] [[Img [Img_Src "images/cdshoptitle.gif"]:selPage.body]]
		, Hr []
		, Br
		, BodyTag page		// code of selected page
		, Br
//		, traceHtmlInput
		], hst)
where
	pageSelectionForm hst = ListFuncBut False "pagebut" Edit pagebuttons hst
	where
		pagebuttons  = 
			[ (but "Home", 		const HomePage)
			, (but "Shop",		const ShopPage)
			, (but "Basket", 	const BasketPage)
			, (but "OrderInfo", const OrderPage)
			]

// home page

doHomePage :: [ItemData d] (SharedForms option) *HSt -> ([BodyTag],*HSt)
doHomePage database sf hst
= (	[ maptext 	[ "Welcome to the Clean CD shop!"
				, ""
				, "Our Dean wants that we make more money with Clean, otherwise we will be killed."
				, "We have therefore decided to sell Peter's exquisite CD collection for exquisite prices."
				, ""
				, "By the way, this application also gives a nice demo what you can do with Clean..."
				, "Have fun."
				]
	], hst)

// shop page

doShopPage :: (SearchOptions option) (ExtendedInfo d) (Headers d) [ItemData d] (SharedForms option) *HSt -> ([BodyTag],*HSt) | searchDB option d
doShopPage {options} extendedInfo headers database sf hst
# (found,selection)	= searchDB ((map snd options)!!(snd (sf.searchOption.value))) (sf.searchString.value) database
# (shownext, hst)	= browserForm sf.index.value sf.step.value (length selection) hst
# (nindex,   hst) 	= indexForm (shownext.value o \i -> if (sf.searchString.changed || sf.searchOption.changed) 0 sf.index.value) hst
# (shownext, hst)	= browserForm nindex.value sf.step.value (length selection) hst
# (add,      hst)	= addToBasketForm nindex.value sf.step.value selection hst
# (info,     hst)	= InformationForm "listinfo" ([item.itemnr \\ {item} <- selection]%(nindex.value,nindex.value+sf.step.value)) hst
# (basket,   hst) 	= basketForm add.value hst
# (binfo,    hst)	= InformationForm "basketinfo" basket.value hst
= (	[([ STable [] [[bTxt "Search:",toBody sf.searchOption, Img [Img_Src "images/loep.gif"]]
				  ,[bTxt "Name:",  toBody sf.searchString, if found (bTxt (toString (length selection) +++ " Items Found"))
				                                                    (bTxt "No Items Found")]
				  ,[bTxt "#Items:",toBody sf.step]
				  ]]
	  <=>
		 [STable [] [shownext.body]])
	, Br, Br 
	, mkTable (nindex.value+1,length selection) headers (selection%(nindex.value,nindex.value+sf.step.value)) info.body add.body 
	, Br, Br
	, showBasket True basket.value headers database binfo.body [EmptyBody]
	, if ((info.value -1) < 0) EmptyBody (doScript extendedInfo (database!!(info.value -1)))
	, if ((binfo.value -1) < 0) EmptyBody (doScript extendedInfo (database!!(binfo.value -1)))
	], hst)
where
	browserForm :: !Int !Int !Int *HSt -> (Form (Int -> Int),!*HSt) 
	browserForm index step length hst
		= ListFuncBut False  "browserbuttons" Edit (browserButtons index step length) hst
	where
		browserButtons :: !Int !Int !Int -> [(Button,Int -> Int)]
		browserButtons init step length
			= if (init - range >= 0) [(sbut "--", set (init - range))] [] 
			  	++
			  take nbuttuns [(sbut (toString (i+1)),set i) \\ i <- [startval,startval+step .. length-1]] 
			  	++ 
			  if (startval + range < length - 1) [(sbut "++", set (startval + range))] []
		where
			set j i		= j
			range		= nbuttuns * step
			start i j	= if (i < range) j (start (i-range) (j+range))
			nbuttuns	= 10
			startval	= start init 0

	addToBasketForm :: !Int !Int [ItemData d] *HSt -> (Form (Basket -> Basket),!*HSt)
	addToBasketForm index step selection hst
		= ListFuncBut False "additems" Edit ([(butp "basket.gif" ,\basket -> [data.item.itemnr:basket]) \\ data <- selection]%(index,index+step-1)) hst

InformationForm :: String [Int] *HSt -> (Form (Int -> Int),!*HSt)
InformationForm formid itemlist hst
	= ListFuncBut False formid Edit [(butp "info.gif",const itemnr) \\ itemnr <- itemlist] hst

// basket page

doBasketPage :: (ExtendedInfo d) (Headers d) [ItemData d] (SharedForms option) *HSt -> ([BodyTag],*HSt)
doBasketPage extendedInfo headers database sf hst
# (delete,  hst)	= ListFuncBut False "delitems" Edit [(butp "trash.gif",removeMember itemnr) \\ itemnr <- sf.basket.value] hst
# (nbasket, hst)	= basketForm delete.value hst	
# (info,    hst)	= InformationForm "basketinfo2" nbasket.value hst
# (order,   hst)	= ListFuncBut False "buybut" Edit [(but "toOrder",const OrderPage)] hst	
# (curpage, hst)	= currentpageForm order.value hst
| curpage.value ===  OrderPage = doOrderPage headers database sf hst
= ( [ showBasket False nbasket.value headers database info.body delete.body
	, if ((info.value -1) < 0) EmptyBody (doScript extendedInfo (database!!(info.value -1)))
	, if (isEmpty nbasket.value) EmptyBody (BodyTag [bTxt "Go to order page:\t\t", toBody order])
	]
  , hst
  )

// order page

doOrderPage :: (Headers d) [ItemData d] (SharedForms option) *HSt -> ([BodyTag],*HSt)
doOrderPage headers database sf hst
# persData		= sf.personalData
# (confirm,hst)	= ListFuncBut False "confirm" Edit [(but "confirm",const ThanksPage)] hst	
# (curpage,hst)	= currentpageForm confirm.value hst
| curpage.value ===  ThanksPage
	= doThanksPage database sf hst
| otherwise
	= (	[ showBasket False sf.basket.value headers database (repeat EmptyBody) (repeat EmptyBody)
		, Br
		, bTxt "All fields must be filled with your data:"
		, toBody persData
		, Br
		, if (isEmpty sf.basket.value) EmptyBody (BodyTag [bTxt "Confirm your order:\t\t", toBody confirm])
		], hst)
	
// thanks page

doThanksPage :: [ItemData d] (SharedForms option) *HSt -> ([BodyTag],*HSt)
doThanksPage database sf hst
# (_,hst)	= basketForm (const []) hst				// empty basket
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
	body		= [ STable tableAttr [ [bTxt "Item number:", bTxt (toString item.itemnr)] ]
				  , Br
				  , STable tableAttr (map (map bTxt) (extKey data))
				  , Br
				  , STable tableAttr (map (map bTxt) (extVal data))
				  , Br
				  , STable tableAttr [ [bTxt ("Buy it now for only " +++ showPrize item.prize)] ]
				  ]
	tableAttr	= [Tbl_Border 1, Tbl_Bgcolor (`Colorname Yellow)]


myScript :: [BodyTag] -> Script
myScript body = openWindowScript scriptName 700 400 False False True True False False 
					(mkHtml "CD information window" body)

onloadBody = `Batt_Events [OnLoad (SScript scriptName)]

scriptName = "openwindow()"

// Function to display contents of selected items, database, basket

mkTable :: (Int,Int) (Headers d) [ItemData d] [BodyTag] [BodyTag] -> BodyTag
mkTable (cnt,max) headers items infobuttons deladdbuttons
	= table
		[ empty ++ itemHeader ++ dataHeader ++ empty ++ empty
		: [	CntRow i max ++ itemRow item ++ dataRow headers data ++ mkButtonRow infobutton ++ mkButtonRow deladdbutton
			\\ i           <- [cnt..]
			& {item,data}  <- items 
			& infobutton   <- infobuttons
			& deladdbutton <- deladdbuttons
		  ]
		]				
where
	table rows	 	= Table [Tbl_Width tableWidth, Tbl_Bgcolor (`HexColor bgcolor), Tbl_Border 1] 
						[Tr [] row \\ row <- rows]
	tableWidth		= Percent 100
	(itemW,prizeW)	= (40,100)
	itemHeader	 	= mkRow [(Just itemW,"Item"),(Just prizeW,"Prize")]
	dataHeader 		= mkRow headers.headers

	CntRow i max	= [Td [Td_Width indexW] [bTxt (toString i +++ "/" +++ toString max)]] 
	where indexW	= Pixels 50

	itemRow :: Item -> [BodyTag] 
	itemRow item				= mkRow [(Just itemW,toString item.itemnr),(Just prizeW,showPrize item.prize)]

	dataRow :: (Headers d) d -> [BodyTag]
	dataRow {headers,fields} d	= mkRow [(w,f) \\ f <- fields d & (w,_) <- headers]

	mkRow :: [(Maybe Int,String)] -> [BodyTag]
	mkRow items					= [  Td (if (isNothing width) [] [Td_Width (Pixels (fromJust width))]) [bTxt item] 
								  \\ (width,item) <- items 
								  ]

	mkButtonRow button			= let buttonW = Pixels 50 in [ Td [Td_Width buttonW] [button] ]
	
	empty						= mkButtonRow EmptyBody

// small utility stuf ...

mkHtml s tags 	 	= Html (header s) (body tags)
header s 			= Head [`Hd_Std [Std_Title s]] []
body tags 			= Body [onloadBody] tags
bTxt				= B []

but s				= LButton defpixel s
butp s				= PButton (defpixel/2,defpixel/2) ("images/" +++ s)
sbut s				= LButton (defpixel/3) s

bgcolor 			= (Hexnum H_6 H_6 H_9 H_9 H_C H_C)

ziprow body1 body2	= [b1 <=> b2 \\ b1 <- body1 & b2 <- body2]
maptext	texts		= BodyTag (flatten [[bTxt text, Br] \\ text <- texts])
