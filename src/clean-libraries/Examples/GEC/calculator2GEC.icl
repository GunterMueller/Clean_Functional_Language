module calculator2GEC

import StdEnv
import StdIO
import StdGEC

// change comment line to switch between calculator for Reals to Int 

goGui :: (*(PSt u:Void) -> *(PSt u:Void)) *World -> .World
goGui gui world = startIO MDI Void gui [ProcessClose closeProcess] world

Start :: *World -> *World
Start world 
= 	goGui 
 	calcEditor
 	world  

example_calc	= startCircuit (feedback (edit "Calculator" >>> arr update_calc)) calculator
where
	calculator	= 	zero  	   <|> 
					calc zero  <|> 
					horlistAGEC buttons

	update_calc (mem <|> i <|> pressed) = (nmem <|> calc ni <|> horlistAGEC buttons)
	where
		(nmem,ni)	= case whichopper (^^ pressed) operators of
							[] 		= (mem,^^ i)
							[f:_]	= (f mem (^^ i),zero)

	calc		= realcalcAGEC			// to obtain a real calculator
//	calc		= intcalcAGEC 			// to obtain an int calculator
	buttons		= [Button buttonWidth "+", Button buttonWidth "-", Button buttonWidth "*"]
	operators 	= [(+),(-),(*)]
	whichopper buttons operators = [x \\ (Pressed,x) <- (zip2 buttons operators)]

:: ButtonEditor 	:== [(String,AGEC (Int Int -> Int))]
:: MyButtonFuns 	:== ([Button],[Int Int -> Int])
:: MoreOrLess = AddOneMore | DeleteOneMore | EndOfList
:: MyCalculatorType :== ((<|> Int (<|> (AGEC Int) (AGEC [Button]))),AGEC MyButtonFuns)

derive gGEC MoreOrLess

derive generate MoreOrLess

calcEditor	= startCircuit (designButtons >>> arr convert >>> myCalculator) init
where
	init:: ButtonEditor
	init = [("+",dynamicAGEC (+))]

	designButtons ::  GecCircuit ButtonEditor ButtonEditor
	designButtons =  feedback (arr toDesignButtons
								 >>> edit "design buttons" 
								 >>> arr fromDesignButtons)
	
	toDesignButtons :: ButtonEditor -> (<|> (AGEC ButtonEditor) MoreOrLess)							 
	toDesignButtons list = vertlistAGEC list <|> EndOfList 							 

	fromDesignButtons :: (<|> (AGEC ButtonEditor) MoreOrLess) -> ButtonEditor 							 
	fromDesignButtons (list <|> AddOneMore) = (^^ list) ++ init							 
	fromDesignButtons (list <|> DeleteOneMore) = (^^ list) % (0,length (^^ list) - 2)							 
	fromDesignButtons (list <|> _) = (^^ list)							 


	convert :: ButtonEditor -> MyCalculatorType 
	convert editbuttons =  initCalculator 0 0 mybuttons
	where
		mybuttons :: MyButtonFuns
		mybuttons = unzip [(Button buttonWidth string,^^ fun)\\ (string,fun) <- editbuttons]

	myCalculator :: GecCircuit MyCalculatorType MyCalculatorType
	myCalculator =  feedback (edit "calculator" >>> arr updateCalculator)


							 
updateCalculator :: MyCalculatorType -> MyCalculatorType 
updateCalculator((mem <|> i <|> buttons),butsfun) = initCalculator nmem ni (^^ butsfun)
where
	(nmem,ni)	= case whichopper (^^ buttons) fun of
						[] 		= (mem,^^ i)
						[f:_]	= (f mem (^^ i),0)
	fun =  snd (^^ butsfun)

	whichopper buttons operators = [x \\ (Pressed,x) <- (zip2 buttons operators)]

initCalculator :: Int Int MyButtonFuns -> MyCalculatorType
initCalculator mem ival (mybuttons,myfunctions) 
	= (mem <|> 
	   intcalcAGEC ival <|>
	   horlistAGEC mybuttons, hidAGEC (mybuttons,myfunctions))		
	
buttonWidth	:== defCellWidth / 3	
	
