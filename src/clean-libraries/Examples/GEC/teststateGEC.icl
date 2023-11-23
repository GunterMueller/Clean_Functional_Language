module teststateGEC

import StdEnv, StdIO
import StdGEC

Start :: *World -> *World
Start world = startGEC testcoffee world
//Start world = startGEC testbitprotocol world


// Circuit to test a typical "GAST" state transition system

stateMachineEditor statefun initstate initvalue = startCircuit mycircuit initvalue
where
    mycircuit =     	okPredEditor "input" (\_ -> True)
	                >>> loopstate initstate
                    (   	arr (convert statefun)
                        >>> second (display "state")
                    )
	                >>> arr vertlistAGEC
	                >>> display "output"
    convert f = g
    where
            g (i,st) = case (f st i) of 
                            []               -> ([],st )
                            [(nst,lo):_]     -> (lo,nst)

// a simple coffee machine... 

testcoffee      = stateMachineEditor m2 S0 Dime

derive gGEC State, IO

:: State = S0 | S5 | S10

:: IO = Nickel | Dime | Coffee 

m2 :: State IO -> [(State , [IO])]
m2 S0 Nickel    = [(S5  , [])]
m2 S0 Dime              = [(S10 , [])]
m2 S5 Nickel    = [(S10 , [])]
m2 S10 Coffee   = [(S0  , [Coffee]), (S10,[])]
m2 s i                  = []

// Alternate Bit protocol...

testbitprotocol = stateMachineEditor abp2 (Idle O) (New "Message")

derive gGEC In, Out, Bit, S

:: In = New Message | Ack Bit
:: Out = Out Bit Message
:: Bit = O | I
:: Message :== String
:: S = Busy Bit Message | Idle Bit

abp2 :: S In -> [(S,[Out])]
abp2 (Idle b) (New m) = [(Busy b m,[Out b m])]
abp2 (Busy b m) (Ack c)
        | b === c
                = [(Idle (~b),[])]
                = [(Busy b m,[Out b m])]
abp2 s i = [(s,[])]

derive gEq Bit

instance ~ Bit
where
        ~ O = I
        ~ I = O

