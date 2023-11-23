implementation module basicAGEC

import StdAGEC, modeGEC, buttonGEC, layoutGEC
import StdEnv

// Identity 

nopred n 	= (DontTest,n)
noupdate b ps = (False,b,ps)

idxAGEC :: (TgGEC a *(PSt .ps)) a -> AGEC a 
idxAGEC gGEC j 	= mkxAGEC gGEC (idBimapGEC j) "idGEC"

idAGEC :: a -> AGEC a | gGEC {|*|} a
idAGEC j 	= mkAGEC (idBimapGEC j) "idGEC"

idBimapGEC j =	{ toGEC		= \i _ ->i
				, fromGEC 	= id
				, value		= j
				, updGEC	= noupdate
				, pred		= nopred
				} 

hidAGEC :: a -> AGEC a  // Just a store, does not require any GEC !
hidAGEC j 	= mkAGEC` 	{	toGEC	= \i _ -> Hide i
						,	fromGEC = \(Hide i) -> i
						,	value	= j
						,	updGEC	= noupdate
						,	pred	= nopred
						} "hidGEC"

predAGEC :: (a -> (Bool,a)) a -> AGEC a | gGEC {|*|} a 
predAGEC pred a = mkAGEC 	{	toGEC	= toPred
							,	fromGEC = id
							,	value	= a
							,	updGEC	= noupdate
							,	pred	= \a -> case pred a of
												(True,na)  = (TestStoreUpd,na)
												(False,na) = (TestStore,na)
							}  "predGEC"
where
	toPred nv Undefined    = nv
	toPred nv (Defined oi) = nv


// apply GEC

applyAGEC :: (b -> a) (AGEC b) -> AGEC a | gGEC {|*|} a & gGEC {|*|} b
applyAGEC fba gecb	= mkAGEC 	{	toGEC	= initgec
								,	fromGEC = \(gecb <|> Display olda) -> fba (^^ gecb)
								,	value	= inita
								,	updGEC	= \(gecb <|> Display olda) ps -> (True,(gecb <|> Display (fba (^^ gecb))),ps)
								,	pred	= nopred
								} "applyAGEC"
where
	inita = fba (^^ gecb)									

	initgec _ Undefined = gecb <|> Display inita
	initgec _ (Defined b) = b

// convert mode to agec

modeAGEC :: (Mode a) -> AGEC a | gGEC {|*|} a
modeAGEC mode =  mkAGEC 	{ toGEC 	= mkmode mode
							, fromGEC 	= demode
							, updGEC 	= noupdate
							, value 	= demode mode
							, pred		= nopred } "modeGEC"
where
	demode (Display a) = a
	demode (Edit a) =  a
	demode (Hide a) =  a
	demode EmptyMode =  abort "EmptyMode inspected"

	mkmode (Display om) nm Undefined = Display nm
	mkmode (Edit om)    nm Undefined = Edit nm
	mkmode (Hide om)    nm Undefined = Hide nm
	mkmode mode nm         (Defined om) = mkmode mode nm Undefined

// Integer with up down counter

counterAGEC :: a -> AGEC a | gGEC {|*|} a & IncDec a
counterAGEC j = mkAGEC 	{	toGEC	= \i _ ->(i,Neutral)
						,	fromGEC = fst
						,	value	= j
						,	updGEC	= \j ps -> (True, updateCounter j,ps)
						,	pred	= nopred
						} "counterGEC"
where
	updateCounter (n,UpPressed) 	= (n+one,Neutral)
	updateCounter (n,DownPressed) 	= (n-one,Neutral)
	updateCounter any 		 	 	= any


// All elements of a list shown in a row

horlistAGEC :: [a] -> AGEC [a] | gGEC {|*|} a  
horlistAGEC  list	= mkAGEC	{	toGEC	= tohorlist
								,	fromGEC = fromhorlist
								,	value 	= list
								,	updGEC	= noupdate
								,	pred	= nopred
								}  ("horlistGEC" +++ len)
where
	tohorlist []	 _ = EmptyMode <-> hidAGEC []
	tohorlist [x:xs] _ = Edit x    <-> horlistAGEC xs

	fromhorlist (EmptyMode <-> xs) = []  
	fromhorlist (Edit x <-> xs)    = [x: ^^ xs]  

	len = (toString (length list))


// All elements of a list shown in a column

vertlistAGEC :: [a] -> AGEC [a] | gGEC {|*|} a  
vertlistAGEC  list = vertlistGEC` True list

vertlistGEC` update list = mkAGEC	{	toGEC	= tovertlist
									,	fromGEC = fromvertlist
									,	value 	= list
									,	updGEC	= noupdate 
									,	pred	= nopred
									} ("vertlistGEC" +++ len)
where
	tovertlist []	 _ 	= EmptyMode <|> hidAGEC []
	tovertlist [x:xs] _ = Edit x    <|> vertlistGEC` False xs

	fromvertlist (EmptyMode <|> xs)	= []  
	fromvertlist (Edit x <|> xs)	= [x: ^^ xs]  

	len = (toString (length list))

hor2listAGEC :: a [a] -> AGEC [a] | gGEC {|*|} a  
hor2listAGEC defaultval list  
	= 	mkAGEC	{	toGEC	= mkdisplay
				,	fromGEC = fetchlist
				,	value 	= list
				,	updGEC	= \list ps -> (False,adjustdisplay list,ps)
				,	pred	= nopred
				} "list2AGEC"
where
	mkdisplay list Undefined 	= display list
	mkdisplay list (Defined _) 	= display list

	display list =  mlbuttons <|*|> horlistAGEC list
	where
		mlbuttons 	= (Button width "-", Button width "+")
		width 		= defCellWidth / 10

	adjustdisplay ((_,Pressed) <|*|> alist) = display (^^ alist ++ [defaultval])
	adjustdisplay ((Pressed,_) <|*|> alist) = display (init (^^ alist))
	adjustdisplay (       _    <|*|> alist) = display (^^ alist)

	fetchlist (_ <|*|> alist ) = ^^ alist


vert2listAGEC :: a [a] -> AGEC [a] | gGEC {|*|} a  
vert2listAGEC defaultval list  
	= 	mkAGEC	{	toGEC	= mkdisplay
				,	fromGEC = fetchlist
				,	value 	= list
				,	updGEC	= (\list ps -> (False,adjustdisplay list,ps))
				,	pred	= nopred
				} "list2AGEC"
where
	mkdisplay list Undefined 	= display list
	mkdisplay list (Defined _) 	= display list

	display list =  mlbuttons <|> vertlistAGEC list
	where
		mlbuttons 	= (Button width "-", Button width "+")
		width 		= defCellWidth / 10

	adjustdisplay ((_,Pressed) <|> alist) = display (^^ alist ++ [defaultval])
	adjustdisplay ((Pressed,_) <|> alist) = display (init (^^ alist))
	adjustdisplay (       _    <|> alist) = display (^^ alist)

	fetchlist (_ <|> alist ) = ^^ alist


// list components

derive gGEC Actions,Action

:: Action 	= 	{ element_nr :: AGEC Int
				, goto		 :: (Button,Button)
				, actions	 :: Actions
				}
:: Actions  =	Append 
			|	Insert 
			|	Delete 
			|	Copy 
			|	Paste
			|	Choose	


listAGEC :: Bool [a] -> AGEC [a] | gGEC {|*|} a  
listAGEC finite list  
	= 	mkAGEC	{	toGEC	= mkdisplay
				,	fromGEC = \(_,Hide (_,(list,_))) -> list
				,	value 	= list
				,	updGEC	= \b ps -> (True,edit (parseListEditor b),ps)
				,	pred	= nopred
				} "listGEC"
where
	mkdisplay list Undefined 							= display 0 list (list!!0)
	mkdisplay list (Defined(_,Hide (clipboard,(_,i)))) 	= display i list clipboard

	display i list clipboard = (mklistEditor list i,Hide (clipboard,(list,i)))

	mklistEditor list i = 	 list!!ni <|> 
							 mkaction ni  
	where
		mkaction nr			= {	element_nr 	= counterAGEC nr
							  , goto		= (Button (defCellWidth/2) "0",Button (defCellWidth/2) (toString next))
							  , actions 	= Choose 
							  }
		ni					
		| finite			= if (i >= 0 && i <= (length list - 1)) i (if (i<0) (length list - 1) 0)
		| otherwise			= if (i >= 0) i 0

		next
		| finite			= length list - 1
		| otherwise			= i + 100

	parseListEditor  ( listelement <|>
				       {element_nr,goto,actions}, Hide (clipboard,(list,j))) 
		=	((fst goto,snd goto),actions,^^ element_nr,listelement,clipboard,list,j)

	edit ((first,last),_,i,_,clipboard,list,j)	
		| isPressed first	= display 0 list clipboard
		| isPressed last	= display (if finite (length list - 1) (i + 100)) list clipboard
		| i <> j			= display i list clipboard
	edit (_,Insert,i,_,clipboard,list,_)	
							= display i (insertAt i clipboard list) clipboard
	edit (_,Append,i,_,clipboard,list,_)	
							= display (i+1) (insertAt (i+1) clipboard list) clipboard
	edit (_,Delete,i,_,clipboard,list,_)	
							= display i (removeAt i list) clipboard
	edit (_,Copy,i,listelement,_,list,_)	
							= display i list listelement
	edit (_,Paste,i,_,clipboard,list,_)	
							= display i (updateAt i clipboard list) clipboard
	edit (_,_,i,listelement,clipboard,list,_)	
							= display i (updateAt i listelement list) clipboard
	
	isPressed Pressed = True
	isPressed _ = False


// All elements of a list shown in a column

table_hv_AGEC :: [[a]] -> AGEC [[a]] | gGEC {|*|} a  
table_hv_AGEC  list		= mkAGEC	{	toGEC	= \newlist -> mktable newlist
								,	fromGEC = \table   -> mklist (^^ table)
								,	value 	= list
								,	updGEC	= noupdate
								,	pred	= nopred
								} "tableGEC"
where
	mktable list	  _ = vertlistAGEC [(horlistAGEC xs) \\ xs <- list]
	mklist  []			= []	
	mklist  [hor:hors]	= [^^ hor: mklist hors]	

table_vh_AGEC :: [[a]] -> AGEC [[a]] | gGEC {|*|} a  
table_vh_AGEC  list		= mkAGEC	{	toGEC	= \newlist -> mktable newlist
								,	fromGEC = \table   -> mklist (^^ table)
								,	value 	= list
								,	updGEC	= noupdate
								,	pred	= nopred
								} "tableGEC"
where
	mktable list	  _ = horlistAGEC [(vertlistAGEC xs) \\ xs <- list]
	mklist  []			= []	
	mklist  [hor:hors]	= [^^ hor: mklist hors]
	
// buttons with functions attached

calcAGEC :: a [[(Button,a->a)]] -> AGEC a | gGEC {|*|} a 
calcAGEC a butfun
	= mkAGEC { toGEC   = \a _ -> a <|> table_hv_AGEC buts
	         , fromGEC = \(na <|> _) -> na
	         , value   = a
	         , updGEC  = \c ps -> (True,calcnewa c,ps)
			 , pred	   = nopred
	         } "calcGEC"
where
	(buts,funs) = ([map fst list \\ list <- butfun],[map snd list \\ list <- butfun])

	calcnewa (na <|> nbuts) = case [f \\ (f,Pressed) <- zip2 (flatten funs) (flatten (^^nbuts))] of
								[]    ->   na <|> nbuts
								[f:_] -> f na <|> table_hv_AGEC buts

// Integer with calculator buttons

intcalcAGEC :: Int -> AGEC Int
intcalcAGEC i = 	mkAGEC	{ toGEC	= \ni _ -> calcAGEC ni buttons
							, fromGEC = \b -> ^^ b
							, value 	= i
							, updGEC	= noupdate
							, pred	   = nopred
							} "intcalcGEC"
where
	buttons	  =  [ map mkBut [7..9]
				 , map mkBut [4..6]
				 , map mkBut [1..3]
				 , [mkBut 0, (Button (defCellWidth/3) "C",\_->0), (Button (defCellWidth/3) "N", \v -> 0 - v)]
				 ]

	mkBut i = (Button (defCellWidth/3) (toString i),\v -> v*10 + i)

realcalcAGEC :: Real -> AGEC Real
realcalcAGEC i = 	mkAGEC	{	toGEC	= newGEC
							,	fromGEC = \b -> fst (^^ b)
							,	value 	= i
							,	updGEC	= noupdate
			 				, 	pred	= nopred
							} "realcalcGEC"
where
	newGEC ni Undefined 	 = calcAGEC (ni ,Hide (True,1.0)) buttons
	newGEC 0.0 (Defined oval)= calcAGEC (0.0,Hide (True,1.0)) buttons
	newGEC ni  (Defined oval)= calcAGEC (ni,snd (^^ oval)) buttons 

	buttons	  =  [ map mkBut [7..9]
				 , map mkBut [4..6]
				 , map mkBut [1..3]
				 , [mkBut 0]
				 , [ (Button (defCellWidth/3) ".", \(v,Hide (_,_))	-> (v,  Hide (False,1.0)))
				   , (Button (defCellWidth/3) "C", \(_,hide) 		-> (0.0,Hide (True,1.0)))
				   , (Button (defCellWidth/3) "N", \(v,hide) 		-> (0.0 - v,hide))
				   ]
				 ]

	mkBut i =  (  Button (defCellWidth/3) (toString i)
				, \(v,Hide (cond,base)) -> if cond (v*10.0 + toReal i,Hide (cond,base))
											     (v+(toReal i/(base*10.0)),Hide(cond,(base*10.0)))
				)
		
textAGEC :: a -> AGEC a | gGEC {|*|} a & toString a
textAGEC v 	= mkAGEC (textBimapGEC v) "textGEC"

textBimapGEC v =	{ toGEC		= \v _ -> Text (toString v)
				, fromGEC 	= \_ -> v
				, value		= v
				, updGEC	= \v pst -> (True,v,pst)
				, pred		= nopred
				} 
