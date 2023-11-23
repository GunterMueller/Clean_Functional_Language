module functionTestexamples

import StdEnv, StdIO
import basicEditors

// TO TEST JUST REPLACE THE EXAMPLE NAME myEditor IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF TYPE ((PSt Void) -> (PSt Void))


/* !!!!!!!!!!!!!! READ THIS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

If you test functions, no functions are read from disk.
Only build in functions can be used (+, -, map, etc) and functions you define yourself.

Some results will look strange.
Notice that \x y -> x + y is overloaded in Esther.
A standard dynamic apply will not resolve this overloading like Esther.
So, you have to ensure that expressions are not overloaded,
e.g. by defining it like  \x y -> x + y + 0 
*/


Start :: *World -> *World
Start world = startGEC myEditor3 world

displayAGEC val = modeAGEC (Display val)

// Higher order GEC's: (Example 3), testing any function with one argument 

:: MyRecord = { function :: DynString                                           
              , argument :: DynString                                           
              , result   :: DynString }
              
derive gGEC  MyRecord             
                                                       
myEditor1 = selfGEC "test" guiApply (initval id 0)                               
where                                                                           
   initval f v = { function = mkDynStr f                                        
                 , argument = mkDynStr v                                        
                 , result   = mkDynStr (f v) }                                  
   guiApply  r=:{ function = DynStr (f::a -> b) _              
                 , argument = DynStr (v::a)     _ }                             
               = {r & result = mkDynStr (f v)}                 
   guiApply  r = r                                                                          

mkDynStr x = let dx = dynamic x in DynStr dx (ShowValueDynamic dx)
fromDynStr (_,(DynStr d _)) = d


// Higher order GEC's: (Example 4), testing any function with any number of arguments 

myEditor2 = selfGEC "test" (guiApply o (^^)) (vertlistAGEC [show "expression" 0])
where
    guiApply [f:args]
        = vertlistAGEC [f:check 0 (fromDynStr f) args]
    where
        check i (f::a -> b) [arg=:(_,dynstr =: (DynStr (x::a) _)):args]
            = [show2 ("argument " +++ toString i) dynstr : check (i+1)(dynamic f x) args]
        check i (f::a -> b) _ = [show ("argument " +++ toString i) "?"]
        check _ (x::a)      _ = [show "result"   x]

    show s v =  (Display (s +++ " "),mkDynStr v)
    show2 s v = (Display (s +++ " "),v)
    
// Higher order GEC's: (Example 5), testing a function with one argument of statically determined type 

::	MyRecord2 a b = { function` :: AGEC (a -> b)
                    , argument` :: AGEC a
                    , result`   :: AGEC b }

derive gGEC MyRecord2

myEditor3 = selfGEC "test" guiApply (initval (id) 3)
where
   initval f v = { MyRecord2
                 | function` = dynamicAGEC f
                 , argument` = dynamicAGEC v
                 , result`   = displayAGEC (f v) }
   guiApply myrec=:{ MyRecord2 | function`=af, argument`=av }
      = {MyRecord2 | myrec & result` = displayAGEC ((^^af) (^^av))}

// Higher order GEC's: (Example 6)

myEditor4 = selfGEC "test" guiApply (initval ((+) 1.0) 0.0)
where
   initval f v = { MyRecord2
                 | function` = dynamicAGEC f
                 , argument` = counterAGEC v
                 , result`   = displayAGEC (f v) }
   guiApply myrec=:{ MyRecord2 | function`=af, argument`=av }
      = {MyRecord2 | myrec & result` = displayAGEC ((^^af) (^^av))}
    
