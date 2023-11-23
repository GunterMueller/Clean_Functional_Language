module balanceTree

import StdEnv
import StdHtml

import tree

derive gForm []
derive gUpd []

derive gForm 	Record
derive gUpd 	Record
derive gParse 	Record
derive gPrint 	Record
derive gerda	Record

//Start world  = doHtmlSubServer (4,1,1,"tree") MyPage5  world
Start world  = doHtmlServer MyPage4  world

:: Record = {name :: String, address :: TextArea, zipcode :: Int}

myrecord :: [Tree Record]
myrecord = createDefault

	
MyPage4 hst
# (myrecord,hst) = mkEditForm (Init,nFormId "bla" myrecord <@ Submit)  hst
//# (myrecord,hst) = vertlistFormButs 5 True (Init,nFormId "bla" myrecord <@ Submit)  hst
=	mkHtml "Example"
	[ H1 [] ""
	, BodyTag myrecord.form
	]  hst

myBalancedTree 	= pDFormId "BalancedTree" 	(fromListToBalTree [0])
mySortedList	= nFormId "SortedList"  	[0]

MyPage hst
# (balancedtree,hst) = mkSelfForm (initID myBalancedTree) balanceTree hst
=	mkHtml "Balanced Tree"
	[ H1 [] "Balanced Tree"
	, BodyTag balancedtree.form
	]  hst

MyPage2 hst
# (sortedlist,hst) = mkSelfForm (initID mySortedList) sort hst
=	mkHtml "Sorted List"
	[ H1 [] "Sorted List"
	, BodyTag sortedlist.form
	, toHtml (reverse sortedlist.value)
	]  hst

MyPage3 hst
# (treef,hst) = startCircuit mycircuit (Node Leaf 112 Leaf) hst
= mkHtml "Self Balancing Tree"
	[ H1 [] "Self Balancing Tree"
	, toBody treef
	] hst
where
	mycircuit = feedback (edit myBalancedTree) (arr  balanceTree)
	
	