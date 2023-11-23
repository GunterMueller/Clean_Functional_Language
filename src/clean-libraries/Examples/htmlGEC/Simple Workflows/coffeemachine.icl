module coffeemachine

// (c) MJP 2007
//
// This is just a demo of a coffeemachine programmed with iTasks combinators
// The persistent variant will remember the state in which the coffee machine was left
// Garbage collection of unused tasks will be done automatically

import StdEnv, htmlTask, htmlTrivial

//Start world = doHtmlServer (singleUserTask (foreverTask_GC singleStepCoffeeMachine)) world
//Start world = doHtmlServer (singleUserTask singleStepCoffeeMachine) world
//Start world = doHtmlServer (singleUserTask (foreverTask_GC SimpleCoffee2)) world
Start world = doHtmlServer (singleUserTask 0 True (foreverTask_GC CoffeeMachine )) world
//Start world = doHtmlSubServer (1,0,1,"*.*")(singleUserTask 0 True (foreverTask_GC CoffeeMachine )) world



CoffeeMachine :: Task (String,Int)
CoffeeMachine  
=	[Txt "Choose product:",Br,Br] 
	?>>	chooseTask
		[("Coffee: 100",    return_V (100,"Coffee"))
		,("Cappucino: 150", return_V (150,"Cappucino"))
		,("Tea: 50",        return_V (50, "Tea"))
		,("Chocolate: 100", return_V (100,"Chocolate"))
		] =>> \(toPay,product) ->	
	[Txt ("Chosen product: " <+++ product),Br,Br] 
	?>>	getCoins (toPay,0) =>> \(cancel,returnMoney) ->	
	let nproduct = if cancel "Cancelled" product 
	in
	[Txt ("product = " <+++ nproduct <+++ ", returned money = " <+++ returnMoney),Br,Br] 
	?>>	buttonTask "Thanks" (return_V (nproduct,returnMoney))

getCoins :: (Int,Int) -> Task (Bool,Int)
getCoins (cost,paid) = newTask "getCoins" getCoins`
where
	getCoins`		= [Txt ("To pay: " <+++ cost),Br,Br] 
					  ?>> chooseTask [(c +++> " cents", return_V (False,c)) \\ c <- coins]
						  -||-
						  buttonTask "Cancel" (return_V (True,0))
						  =>> handleMoney 

	handleMoney (cancel,coin)
	| cancel		= return_V (cancel,   paid)
	| cost > coin	= getCoins (cost-coin,paid+coin)
	| otherwise		= return_V (cancel,   coin-cost)

	coins			= [5,10,20,50,100,200]

//	getCoins2 is alternative definition of getCoins, but uses repeatTask instead of direct recursion
getCoins2 :: ((Bool,Int,Int) -> Task (Bool,Int,Int))
getCoins2 			= repeatTask_Std get (\(cancel,cost,paid) -> cancel || cost <= 0)
where
	get (cancel,cost,paid)
					= newTask "pay" ([Txt ("To pay: " <+++ cost),Br,Br]
					  ?>> chooseTask [(c +++> " cents", return_V (False,c)) \\ c <- coins]
					  		-||-
					  	  buttonTask "Cancel" (return_V (True,0))
					  =>> \(cancel,c) -> return_V (cancel,cost-c,paid+c))

	coins			= [5,10,20,50,100,200]

// for the ICFP paper: a single step coffee machine

singleStepCoffeeMachine :: Task (String,Int)
singleStepCoffeeMachine
=	[Txt "Choose product:",Br,Br] 
	?>>	chooseTask	[(p<+++": "<+++c, return_V prod) \\ prod=:(p,c)<-products]=>> \prod=:(p,c) -> 
	[Txt ("Chosen product: "<+++p),Br,Br] 
	?>>	pay prod (buttonTask "Thanks" (return_V prod))
where
	products	= [("Coffee",100),("Tea",50)]
	
//	pay (p,c) t	= buttonTask ("Pay "<+++c<+++ " cents") t
//	version using getCoins:
/*	pay (p,c) t	= getCoins (c,0) =>> \(cancel,returnMoney) ->
				  [Txt ("Product = "<+++if cancel "cancelled" p
				                    <+++". Returned money = "<+++returnMoney),Br,Br] 
				  ?>> t
*/
//	version using getCoins2:
	pay (p,c) t	= getCoins2 (False,c,0) =>> \(cancel,_,paid) ->
				  [Txt ("Product = "<+++if cancel "cancelled" p
				                    <+++". Returned money = "<+++(paid-c)),Br,Br] 
				  ?>> t


// A very simple coffee machine

SimpleCoffee :: Task Void
SimpleCoffee
= 	[Txt "Choose product:",Br,Br] 
	?>>	chooseTask
		[("Coffee: 10",    return_V (10,"Coffee"))
		,("Tea: 10", 		return_V (10,"Tea"))
		]	=>>  \(toPay,product) ->
	buttonTask "10 cts" (return_V Void) #>>
	[Txt ("Enjoy your " <+++ product)]
	?>> buttonTask "OK" (return_V Void)

SimpleCoffee2 :: Task Void
SimpleCoffee2
= 	[Txt "Choose product:",Br,Br] 
	?>>	chooseTask
		[("Coffee: 20",    return_V (20,"Coffee"))
		,("Tea: 10", 		return_V (10,"Tea"))
		]	=>>  \(toPay,product) ->

	payDimes toPay #>>

	[Txt ("Enjoy your " <+++ product)]
	?>> buttonTask "OK" (return_V Void)
where
	payDimes 0 = return_V Void
	payDimes n = buttonTask "10 cts" (return_V Void) #>> payDimes (n - 10)

