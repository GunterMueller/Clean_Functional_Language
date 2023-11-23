module HenkEnJanWillemGEC

import StdEnv, StdCircuits
import basicArrowEditors

Start :: *World -> *World
//Start world = startGEC aStarFBb world
Start world = startGEC stackEditor world
//Start world = startGEC simple world

:: Familie	 	 	=	Familie    		Persoon BurgelijkeStaat (Maybe Partner) (Maybe Kinderen)
:: Persoon 			= 	Man 			String 						
					| 	Vrouw 			String
:: BurgelijkeStaat	=	Gehuwd			
					|	Gescheiden		
					|	Samenwonend		
					|	Alleenstaand 
:: Partner			:==	Persoon 
:: Kinderen			:== [Familie]

// simple example

simple = startCircuit mycircuit initvalue
where
	mkval inp out = inp <|> (Button defCellWidth "F", Button defCellWidth "G") <|> out

	mycircuit = 	feedback (edit "simple example" >>> arr fun)

	initvalue = mkval 0 0

	fun (inp <|> (Pressed,_) <|> _) = mkval inp (f inp)
	fun (inp <|> (_,Pressed) <|> _) = mkval inp (g inp)
	fun else = else

	f x = x * x
	g x = 3 * x	

simple2 = startCircuit mycircuit initvalue
where
	mkval nr  = (Button (defCellWidth/2) "0", Button (defCellWidth/2) "1") 
								<|> 
				(Display nr)    <|> 
				(Button defCellWidth "Clear")

	mycircuit = 	feedback (edit "Number editor" >>> arr fun)

	initvalue = mkval " "

	fun ((Pressed,_) <|> (Display d) <|> cb) = mkval (d+++"0 ")
	fun ((_,Pressed) <|> (Display d) <|> cb) = mkval (d+++"1 ")
	fun (_ <|> _ <|> Pressed)                = mkval " "
	fun else = else


// a Stack of integers

:: Stack = Push Int | Pop | Empty | Dup Int

derive gGEC Stack

stackEditor = startCircuit mycircuit initvalue
where
	initvalue = Push 1

	mycircuit = 		okPredEditor "input" check 
					>>> loopstate [] (arr handlestack) 
		            >>> arr vertlistAGEC
		            >>> display "output"

	handlestack (Push i,stack) 	= dup [i:stack]
	handlestack (Pop   ,[])		= dup []
	handlestack (Pop   ,[x:xs])	= dup xs
	handlestack (Empty ,_)		= dup []   
	handlestack (Dup i ,stack)	
	| i < length stack 			= dup [stack!!i:stack]
	| otherwise					= dup stack   

	dup x = (x,x) // just to show internal state to output
	
	check (Push n)  =  n >= 0 && n <= 1 
	check else      =  True
	
// a zero or more A's followed by a B

:: AB = A | B
derive gGEC AB

aStarFBb = startCircuit mycircuit initvalue
where
	initvalue = A
	mycircuit = 	okPredEditor "input" (\_ -> True) 
					>>> loopstate [] (arr handle) 
		            >>> arr vertlistAGEC
		            >>> display "output"

	handle (A,st) = (st ++ [A],st ++ [A])
	handle (B,st) = (st ++ [B],[])

