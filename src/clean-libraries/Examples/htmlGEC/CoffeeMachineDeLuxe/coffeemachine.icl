module coffeemachine

import StdEnv
import StdiData

derive gForm  MachineState, Output, Product
derive gUpd   MachineState, Output, Product
derive gPrint MachineState, Output, Product
derive gParse MachineState, Output, Product
derive gerda  MachineState, Output, Product


//Start world  = doHtml coffeemachine world
Start world  = doHtmlServer coffeemachine world

myCommandsId :: (InIDataId [(Button,(MachineState -> MachineState))])
myCommandsId = (Init,nFormId "cb" allbuttons)
where
	allbuttons  = 
		[ (butp "CoffeeBeans.jpg",  \m -> CoffeeMachine (AddBeans,		m))
		, (but "Empty_Trash", 		\m -> CoffeeMachine (EmptyTrash,	m))
		, (but "Coffee",			\m -> CoffeeMachine (Ask Coffee,	m))
		, (but "Capuccino", 		\m -> CoffeeMachine (Ask Capuccino,	m))
		, (but "Espresso", 			\m -> CoffeeMachine (Ask Espresso,	m))
		]
		++
		[moneybuttons n \\ n <- [200, 100, 50, 10, 5]]
		where
			moneybuttons n = (butp (toString n +++ ".gif"), \m -> CoffeeMachine (InsertCoin n, m))

			but s	= LButton defpixel s
			butp s	= PButton (defpixel/2,defpixel/2) ("images/" +++ s)

myOptionsId :: Init Bool Bool -> (InIDataId [(CheckBox,(Bool [Bool] MachineState -> MachineState))])
myOptionsId init milk sugar = (init,nFormId "ob" optionbuttons) 
where
	optionbuttons  = 
		[ (check milk  "Milk",  \b _ m -> CoffeeMachine (AskMilk b,  m))
		, (check sugar "Sugar", \b _ m -> CoffeeMachine (AskSugar b, m))
		]
	where
		check True = CBChecked
		check False = CBNotChecked

myMachineId :: (InIDataId MachineState)
myMachineId = (Init, nFormId "hidden" initmachine)

coffeemachine hst
# (input	,hst) 		= ListFuncBut myCommandsId hst	
# (options	,hst) 		= ListFuncCheckBox (myOptionsId Init False False)  hst	
# (optionfun,optionbool)= options.value
# (machine	,hst) 		= mkStoreForm myMachineId (optionfun o input.value) hst
# (checkboxf,hst) 		= ListFuncCheckBox (myOptionsId Set machine.value.milk machine.value.sugar) hst	
= mkHtml "Coffee Machine"
		[ H1 [] "Fancy Coffee Machine ..."
		, Br
		, 	[ mkSTable [[bTxt "Content:", bTxt "Value:",bTxt "Input:"]]
			, toHtml ("money ",machine.value.money) <.=.> mkRowForm (input.form%MoneyButtons)
			, toHtml ("beans ",machine.value.beans) <.=.> input.form!!BeansButton
			, toHtml ("trash ",machine.value.trash) <.=.> input.form!!TrashButton
			, Br
			, bTxt "Options: "
			, Br
			, checkboxf.form!!MilkOption  <.=.> bTxt "Milk"
			, checkboxf.form!!SugarOption <.=.> bTxt "Sugar"
			, Br
			, mkSTable [[bTxt "Product:", bTxt "Prize:"]]
			, mkColForm (input.form%ProductButtons) <.=.> mkColForm (map toHtml prizes)
			, Br
			, bTxt "Message: ", bTxt (print machine.value.out optionbool)
			] <=> [displayMachineImage machine.value.out] 
		] hst
where
	prizes = [cost Coffee,cost Capuccino, cost Espresso]
	
	displayMachineImage (Prod x) 	= machineImage 4
	displayMachineImage (Message s) = machineImage 0

	machineImage i	= Img [Img_Src ("images/coffeemachine0" +++ toString i +++ ".jpg"), Img_Width (RelLength 560) ,Img_Height (RelLength 445)]

	bTxt				= B []

	print output [milkoption,sugaroption] 
	= printoutput output
	where
		printoutput (Message s)      = s
		printoutput (Prod Coffee)    = "Enjoy your coffee" 		+++ printoptions milkoption sugaroption
		printoutput (Prod Capuccino) = "Enjoy your capuccino"	+++ printoptions milkoption sugaroption
		printoutput (Prod Espresso)  = "Enjoy your espresso"	+++ printoptions milkoption sugaroption

		printoptions milk sugar 
		| milk && sugar = " with milk and sugar"
		| milk  		= " with milk"
		| sugar 		= " with sugar"
		printoptions _ _  = ""
	
	BeansButton		= 0
	TrashButton		= 1
	ProductButtons	= (2,4)
	MoneyButtons 	= (5,9)
	MilkOption		= 0
	SugarOption		= 1


// Coffee machine with standard options ...

::	Client					// Client actions:
	=	InsertCoin Int		// insert a coin of int cents
	|	Ask Product			// ask for product
	|	AddBeans			// add beans in machine
	|	EmptyTrash			// empty bean trash of machine
	|	AskMilk Bool		// milk yes or no
	|	AskSugar Bool		// sugar yes or no
	|	Idle				// does nothing

::	MachineState			// CoffeeMachine:
	=	{ money	:: Int		// nr of coins (maxCoins)
		, beans	:: Int		// amount of beans (maxBeans)
		, trash	:: Int		// amount of bean-trash (maxTrash)
		, milk	:: Bool		// milk wanted
		, sugar :: Bool		// sugar wanted
		, out	:: Output	// output of machine
		}

::	Product	=   Coffee | Capuccino | Espresso
::	Msg		:== String		// Errors or customer-friendly information
::	Output	=   Message Msg | Prod Product

initmachine = 	{ money = 0
				, beans = 6
				, trash = 0
				, milk  = False
				, sugar = False
				, out 	= Message "Welcome."
				} 

//	Finite State Handling of this Coffee Machine

CoffeeMachine :: (Client,MachineState) -> MachineState
CoffeeMachine (InsertCoin n, m=:{money})
	| money >= maxCoins				= { m &                        out = Message "Coin not accepted." }
	| otherwise						= { m & money = money+n,       out = Message "Thank you." }
CoffeeMachine (EmptyTrash, m)		= { m & trash = 0,             out = Message "Trash emptied." }
CoffeeMachine (AddBeans, m=:{beans})                
	| beans > maxBeans-beanBag		= { m &                        out = Message "Too many beans." }
	| otherwise						= { m & beans = beans+beanBag, out = Message "Beans refilled." }
CoffeeMachine (AskMilk b, m)		= { m & milk = b,              out = Message (if b "Milk will be added" "No Milk")}
CoffeeMachine (AskSugar b, m)		= { m & sugar = b,             out = Message (if b "Sugar will be added" "No Sugar")}
CoffeeMachine (Ask p,m=:{money,beans,trash})
	| beans < beancost p			= { m &                        out = Message "Not enough Beans." }
	| money < cost p				= { m &                        out = Message "Not enough money inserted." }
	| trash + ptrash p > maxTrash	= { m &                        out = Message "Trash full." }
	| otherwise						= { m & out   = Prod p
									      , beans = beans - beancost p
									      , money = money - cost p
									      , trash = trash + ptrash p
									      , milk  = False
									      , sugar = False
									  }
CoffeeMachine (_,m)					= m

maxCoins	:== 1000	// max. number of money in machine
maxBeans	:== 20		// max. amount of coffeebeans in machine
maxTrash	:== 5		// max. amount of coffeetrash in machine
beanBag		:== 10		// unit of bean refill

// The number of coins that a product costs
cost :: Product -> Int 
cost Coffee     = 100
cost Capuccino  = 175
cost Espresso   = 150

// The number of beans that a product costs
beancost :: Product -> Int 
beancost Coffee    = 2
beancost Capuccino = 3
beancost Espresso  = 3

// Amount of trash generated by product
ptrash :: Product -> Int 
ptrash _ = 1                      

