module loopGEC

import StdEnv
import StdGECExt, StdAGEC
import GecArrow, StdDebug

Start :: !*World -> *World
Start world = goGui feedbackTest5 world  
where
	goGui gui world = startIO MDI Void gui [ProcessClose closeProcess] world

:: T` = C1` (P Int  Bool)
	  | C2` (P Real Bool)
:: P a b = P a b
derive gGEC T`, P

selfTest1 = startCircuit (self (edit "self") (arr test)) (C1` (P 0 False))
where
	 test (C1` (P i b)) = C2` (P (toReal i) b)
	 test (C2` (P r b)) = C1` (P (toInt  r) b)


loopTest1 = startCircuit (edit "edit" >>> loop (arr \(x, y) -> (x + 1, y + 1)) >>> display "display") 42

loopTest2 = startCircuit (edit "edit" >>> loop (first (edit "loop")) >>> display "display") 42

:: LoopTest3 = Reset | Higher | Not_Higher
derive gGEC LoopTest3

loopTest3 = startCircuit (edit "enter number (0 resets)" >>> loop (second (delay []) >>> arr f) >>> display "number higher than all before?") 0
where
	f (x, xs)
		| x == 0 = (Reset, [])
		= (if (all ((>) x) xs) Higher Not_Higher, [x:xs])

loopTest4 = startCircuit (edit "reset" >>> counter >>> display "output") False
where
	counter = fix (second (arr inc >>> delay 0) >>> arr cond)
	cond (True, n) = 0
	cond (False, n) = n

loopTest5 = startCircuit (edit "reset" >>> counter >>> display "output") False
where
	counter // converted automatically from Paterson arrow notation
	  = (loop
	       (arr (\ (reset, out) -> (out, reset)) >>>
		  (first (arr (\ out -> out + 1) >>> delay 0) >>>
		     arr
		       (\ (next, reset) ->
			  case if reset /*then*/ 0 /*else*/ next of
			      out -> (out, out)))))

feedbackTest1 = startCircuit (self (edit "") ((+) 1)) 1
where
	self g f = feedback (g >>> arr f)

feedbackTest2 = startCircuit (self2 ((+) 100) (edit "") ((+) 1)) 0
where
	self2 f1 g f2 = feedback (arr f1 >>> g >>> arr f2)

feedbackTest3 = startCircuit (edit "input" >>> feedback (arr ((+) 1)) >>> display "output") 0

derive gGEC (,)

feedbackTest4 = startCircuit (edit "input" >>> feedback (first (arr ((+) 1))) >>> display "output") (0, 0)

feedbackTest5 = startCircuit (feedback ((edit "+1" >>> arr ((+) 1)) *** (edit "+100" >>> arr ((+) 100)) >>> probe "result")) (0, 0)

//feedbackTest6 = startCircuit (feedback (feedback (edit "edit") >>> arr ((+) 1) >>> display "inner") >>> arr ((+) 100) >>> display "outer") 0

feedbackTest6 = startCircuit (feedback (feedback (edit "edit" >>> arr ((+) 1)) >>> arr ((+) 100) >>> display "display")) 0

sinkTest1 = startCircuit (edit "input" >>> sink >>> arr (\_ -> -1) >>> display "output") 0

choiceTest1 = startCircuit (edit "input" >>> g >>> display "output") (RIght False)
where
	g :: GecCircuit (EIther Int Bool) (EIther Int Bool)
	g = left (arr ((+) 1))

derive gGEC EIther

instance toString (a, b) | toString a & toString b
where
	toString (x, y) = "(" +++ toString x +++ ", " +++ toString y +++ ")"
