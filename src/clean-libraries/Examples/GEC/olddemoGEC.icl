module demoGEC

import StdEnv
import StdIO
import genericgecs
import StdGEC, StdGECExt, StdAGEC
import StdGecComb

// TO TEST JUST REPLACE THE EXAMPLE NAME IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF FORM pst -> pst

goGui :: (*(PSt u:Void) -> *(PSt u:Void)) *World -> .World
goGui gui world = startIO MDI Void gui [ProcessClose closeProcess] world

Start :: *World -> *World
Start world 
= 	goGui 
 	example_l1
 	world  

example_l1	= 	CGEC (mkGEC		"Simple List Editor")					[1] 
example_l2  =	CGEC (applyGEC	"Sum of List" sum) 						[1..5]  									
example_l4  =	CGEC (applyGEC	"Sum List Elements" (\(a,b) ->  a + b)) ([1..5],[5,4..1])			
example_l5  =	CGEC (applyGEC2	"Sum of List A and List B" (+)) 		([1..5],[5,4..1]) 							
example_l6  =	CGEC (selfGEC 	"Sorted List" 			sort)			[5,4..1] 									
example_l7	=	CGEC (selfGEC 	"spreadsheet"			updsheet)	    (mksheet inittable) 
where
		updsheet (table <-> _ <|>
		          _ <-> _ )			= mksheet (^^ table)
		mksheet table				= tableGEC table <-> Display (vertlistGEC rowsum) <|>
									  Display (horlistGEC colsum) <-> Display (sum rowsum)
		where
			rowsum					= map sum table
			colsum 					= map sum transpose
			transpose				= [[table!!i!!j \\ i <- [0..(length table)    - 1]]
												    \\ j <- [0..length (table!!0) - 1]
									  ]
		inittable	  				= [map ((+) i) [1..5] \\ i <- [0,5..25]]	

instance + [a] | + a
where
	(+) [a:as] [b:bs] = [a+b:as+bs]
	(+) _ _ = []

// Examples on Trees

derive gGEC   Tree 

::	Tree a  	= Node (Tree a) a (Tree a) 
				| Leaf

example_t1	=	CGEC (mkGEC		"Tree")								(Node Leaf 1 Leaf)									
example_t2	=	CGEC (mkGEC 	"Tree")								(toBalancedTree	 [1,5,2,8,3,9])
example_t3	=	CGEC (mkGEC 	"Tree")			         			(toTree [8,34,2,-4,0,31]) 					
example_t4	=	CGEC (applyGEC 	"Balanced Tree"	 toBalancedTree) 	[1,5,2,8,3,9]
example_t5	=	CGEC (apply2GEC "List to Balanced Tree"(toBalancedTree o toList) toTree) 	[1,5,2,8,3,9]	
example_t6	=	CGEC (mutualGEC "BalancedTree to List" toList toBalancedTree) 				[1..5]   
example_t7	=	CGEC (selfGEC 	"self Balancing Tree" (toBalancedTree o toList))			(toBalancedTree [1,5,2,8,3,9])

toTree ::[a] -> Tree a | Ord a
toTree list = inserts list Leaf
where
	inserts [] tree = tree
	inserts [a:as] tree = inserts as (insert a tree)

	insert a (Node b e o)
		| a <= e	=	Node b e (insert a o)
		| a > e		=	Node (insert a b) e o
	insert a Leaf = Node Leaf a Leaf

toList :: (Tree a) -> [a]
toList Leaf = []
toList (Node b a o) = (toList o) ++ [a] ++ (toList b)	

toBalancedTree :: [a] -> Tree a | Ord a
toBalancedTree list = Balance (sort list)
where
	Balance [] = Leaf
	Balance [x] = Node Leaf x Leaf
	Balance xs
		= case splitAt (length xs/2) xs of
			(a,[b:bs]) = Node (Balance bs) b (Balance a)
			(as,[]) = Node Leaf (hd (reverse as)) (Balance (reverse (tl (reverse as))))

// List to balanced tree, with balanced tree defined as record

derive gGEC   BalancedTree, BalancedNode

::	BalancedTree a  	
				= BNode .(BalancedNode a)
				| BEmpty 
				
::  BalancedNode a =
				{ bigger :: .BalancedTree a
				, bvalue  :: a 
				, smaller:: .BalancedTree a
				} 
example_tr1	=	CGEC (selfGEC 	"Balanced Tree with Records" (toBalTree o BalTreetoList))	(toBalTree [1,5,2,8,3,9])

BalTreetoList :: (BalancedTree a) -> [a]
BalTreetoList BEmpty = []
BalTreetoList (BNode record) = (BalTreetoList record.bigger) ++ [record.bvalue] ++ (BalTreetoList record.smaller)	

toBalTree :: [a] -> BalancedTree a | Ord a
toBalTree list = Balance (sort list)
where
	Balance [] = BEmpty
	Balance [x] = BNode {bigger=BEmpty,bvalue=x,smaller=BEmpty}
	Balance xs
		= case splitAt (length xs/2) xs of
			(a,[b:bs]) = BNode {bigger=Balance bs,bvalue=b,smaller=Balance a}
			(as,[])    = BNode {bigger=BEmpty,bvalue=hd (reverse as),smaller=Balance (reverse (tl (reverse as)))} 

// Example of a simple record

derive gGEC   MyAdminstration, ZipCode 



::	MyAdminstration 
				= 	{ name		::String
					, street	::String
					, zipcode	::String
					, number	::Int
					, age		::Int
					}
::	ZipCode 	= Number Char Char

MyRecord = 	{ name = "rinus plasmeijer"
			, street="knollenberg"
			, number=17
			, zipcode="6585WJ"
			, age = 50
			}

example_r1	=	CGEC (mkGEC "My Database") [MyRecord] 					
example_r2	=	CGEC (predGEC "My Database" checkrecord) [MyRecord]					
where
	checkrecord rs = and (map check rs)
	where
		check r = r.age >= 0 && r.age <= 110 && legal r.zipcode
		legal zipcode = size zipcode >= 6 	&& isDigit zipcode.[0] // 8, string includes CR + LF
											&& isDigit zipcode.[1]
											&& isDigit zipcode.[2]
											&& isDigit zipcode.[3]
											&& isAlpha zipcode.[4]
											&& isAlpha zipcode.[5] //|| zipcode==""

// An more complicated recursive datastructure

derive gGEC   Rose

::  Rose a 		= Rose a  .[Rose a]

example_rose	=	CGEC (mkGEC "Rose") (Rose 1 []) 

// Convert Pounds to Euro's Example

derive gGEC   Pounds, Euros

:: Pounds = {pounds :: Real}
:: Euros  = {euros :: Real}

example_rec1	=	CGEC (mutualGEC  "Exchange Euros to Pounds"  toEuro toPounds) {euros=0.0}   
where
	toPounds {euros} 	= {pounds = euros / exchangerate}
	toEuro {pounds} 	= {euros = pounds * exchangerate}
	exchangerate 		= 1.4


// display lists

example_lists1	= CGEC (mkGEC "InfiniteListDisplay") (listGEC False allprimes) 

allprimes = sieve [2..]

sieve [x:xs] = [x : sieve  (filter x xs)]
where
	filter x [y:ys] | y rem x == 0 = filter x ys
	| otherwise = [y: filter x ys]
	
example_lists2	= CGEC (mkGEC "ListDisplay") (listGEC True initrecords) 
where
	initrecords 	= [MyRecord]
	
example_lists3 = CGEC (applyGEC "Henks demo" (\n -> listGEC True (calcnum n))) 1 
where
	calcnum n | n <= 0 = [0]
	calcnum 1  	= 	[1]
	calcnum n
	| n rem 2 == 0 	= [n2 : calcnum n2 ]	with n2 = n / 2
	| otherwise 	= [n31: calcnum n31]	with n31 = (3 * n) + 1	


// drawing stuf

derive gGEC  Rectangle,Point2,Colour,RGBColour,ShapeAttributes,Shape,Oval,Box 

:: Shape =
	  Box Box
	| Oval Oval

:: ShapeAttributes =
	{ pen_colour 	:: Colour
	, pen_size	 	:: AGEC Int
	, fill_colour	:: Colour
	, x_offset		:: AGEC Int 
	, y_offset		:: AGEC Int
	}
/*
example_draw pst
#	(wid,pst) 	= openId pst
#    pst 		= snd (openWindow Void (Window "Drawings" NilLS [WindowId wid]) pst)
=	selfState_GECps (mydrawfun wid) ("Rectangle Attributes",listGEC True initstates) initstates pst
	
	where
		mydrawfun wid abs_nrects orects pst 
		# nrects = ^^ abs_nrects
		# pst = appPIO (setWindowLook wid True (True,drawfun nrects orects)) pst 
		= (abs_nrects,nrects,pst)
		
		drawfun [Box nrect<|>nattr:nrects] [Box orect<|>oattr:orects]  nx nxx
											=	drawfun nrects orects nx nxx o
												drawshape nrect nattr orect oattr
		drawfun [Oval nrect<|>nattr:nrects] [Oval orect<|>oattr:orects]  nx nxx
											=	drawfun nrects orects nx nxx o
												drawshape nrect nattr orect oattr
		drawfun _ _  _ _					=	setPenColour Black 

		drawshape nshape nattr oshape oattr =	drawAt n_offset nshape o
												setPenSize (^^ nattr.pen_size) o 
												setPenColour nattr.pen_colour o 
												fillAt n_offset nshape o 
												setPenColour nattr.fill_colour o 
												unfillAt o_offset oshape o
												undrawAt o_offset oshape 
		where
			n_offset = {x= ^^ nattr.x_offset,y= ^^ nattr.y_offset}
			o_offset = {x= ^^ oattr.x_offset,y= ^^ oattr.y_offset}
	
		initstates= [initstate]
		initstate= initbox <|> initattr
		initbox = Box {box_w=30,box_h=30}
		initattr = {pen_colour=Black,pen_size=counterGEC 1,fill_colour=White,x_offset=counterGEC 100,y_offset=counterGEC 100}
*/
// Examples on counters

derive gGEC DoubleCounter

example_cnt4 = CGEC (mkGEC "Counter") (counterGEC 0)

:: DoubleCounter = {cntr1::AGEC Int, cntr2::AGEC Int,sum::Int}
example_cnt5 = CGEC (selfGEC "Counter" updateDoubleCounters) {cntr1=counterGEC 0,cntr2=intcalcGEC 0,sum=0}
where
	updateDoubleCounters cntrs = {cntrs & sum = ^^ cntrs.cntr1 + ^^ cntrs.cntr2}

example_cnt6a = CGEC (selfGEC "Counter" updateTwoIntCounters) (intcalcGEC 0 <|> counterGEC 0 <|> 0)
where
	updateTwoIntCounters (i1 <|> i2 <|> sum) = (i1 <|> i2 <|> ^^ i1 + ^^ i2)

example_cnt6 = CGEC (selfGEC "Counter" updateTwoIntCounters) (idGEC 0 <|> idGEC 0 <|> counterGEC 0)
where
	updateTwoIntCounters (i1 <|> i2 <|> sum) = (i1 <|> i2 <|> sum ^= (^^ i1 + ^^ i2))

Mybimap :: (a -> b) (b->a) (b -> b) (CGEC b b) -> CGEC a a
Mybimap fab fba fbb gecbb = fab @| %| (gecbb |@ fbb) |@ fba

example_cnt5` = CGEC mycounter 0

example_cnt6` = CGEC mydoublecounter 0 

:: MyDoubleCounter = {cntrs1::GecComb Int Int, cntrs2::GecComb Int Int ,csum::Int}

example_cnt18 = CGEC (gecEdit "kwadrateer") kwadrateer
where
	kwadrateer = applyAGEC (\x -> x + 1) (applyAGEC (\x -> x * x) (idGEC 0))

example_cnt19 = CGEC kwadrateer 0
where
	kwadrateer = gecloop (f  @| gecEdit "res")
	
	f (0,y) = (100,0)
	f (x,y) = (x - 1,y + 1)


example_cnt7` = CGEC (gecEdit "counter") initcounter 

initcounter = {gec = mydoublecounter, inout = (0,0)}

mycounter = Mybimap toCounter fromCounter updateCounter (gecEdit "scounter")
where
	toCounter i = (i, Neutral)
	fromCounter (i, _) = i
	updateCounter (n,UpPressed) 	= (n+one,Neutral)
	updateCounter (n,DownPressed) 	= (n-one,Neutral)
	updateCounter any 		 	 	= any
mydoublecounter = ((mycounter |>| mycounter) |@ (\(x, y) -> x + y) |&| gecDisplay "scounter" )

example_cnt8 = CGEC (selfGEC "Counter" updateCounter) (Tuple2 0 Neutraal)


:: MyCounter = Tuple2 Int Up_Down
:: Up_Down = GoUp | GoDown | Neutraal

derive gGEC MyCounter, Up_Down

updateCounter (Tuple2 n GoUp) 	= Tuple2 (n+1) Neutraal
updateCounter (Tuple2 n GoDown) = Tuple2 (n-1) Neutraal
updateCounter any 		 = any


//example_calcs

example_calc	= CGEC (selfGEC "Calculator" update_calc) calculator
where
	calculator	= 	zero  	   <|> 
					calc zero  <|> 
					horlistGEC buttons

	update_calc (mem <|> i <|> pressed) = (nmem <|> calc ni <|> horlistGEC buttons)
	where
		(nmem,ni)	= case whichopper (^^ pressed) operators of
							[] 		= (mem,^^ i)
							[f:_]	= (f mem (^^ i),zero)

//	calc		= realcalcGEC			// to obtain a real calculator
	calc		= intcalcGEC 			// to obtain an int calculator
	buttons		= [Button "+", Button "-", Button "*"]
	operators 	= [(+),(-),(*)]
	whichopper buttons operators = [x \\ (Pressed,x) <- (zip2 buttons operators)]

example_timer3 = CGEC (selfGEC "TickTack" clock) (myclock,0<->0<->0)
where
	clock (tick,min<->59<->9) 		= clock (tick,min+1<->0<->0)
	clock (tick,min<->secs<->9) 	= clock (tick,min<->secs+1<->0)
	clock (tick,min<->secs<->msecs) = (tick,min<->secs<->msecs+1)

myclock = Timed (\i -> 100) 100 

example_timer4 = CGEC (selfGEC "TickTack" thisone) (myclock,(2,Hide allprimes))
where
	thisone (tick,(p,Hide [x:xs])) = (tick,(x,Hide xs))


example_const = CGEC (%| ( (gecConst 4 |>| gecEdit "constant") |@ (\(x,y) -> x + y) )) 23 

/*
mkTreeAGEC:: (Tree a) -> AGEC (Tree a) | gGEC {|*|} a 
mkTreeAGEC  tree	= mkAGEC	{	toGEC	= \tree -> mkAtree tree
								,	fromGEC = mktree
								,	value 	= tree
								,	updGEC	= id
								}
where
	mkAtree (Node l v r) _ = v <|>
				  			 mkLTree l <-> mkLTree r
	mkLTree Leaf 		  	= hidGEC Leaf
	mkLTree else			= mkTreeAGEC else
							 
	mktree ( v <|> 	
		 	 l <-> r )		= case (^^ v) of
		 	 					Leaf -> Leaf
		 	 					(Node l v r ) -> Node (mktree l) v (mktree r)
		 	 
		 	 
example_ta	=	mkGEC 		("Tree",mkTreeAGEC (toBalancedTree	 [1,5,2,8,3,9]))
*/		 	 				  
