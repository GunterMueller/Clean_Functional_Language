module APLAS

/********************************************************************
*                                                                   *
*   This module contains all examples from the APLAS 04 paper.      *
*                                                                   *
********************************************************************/

import StdEnv
import StdGEC, StdGECExt, StdAGEC, dynamicAGEC, basicAGEC
import StdDynamic

// TO TEST JUST REPLACE THE EXAMPLE NAME myEditor IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF TYPE ((PSt Void) -> (PSt Void))

Start :: *World -> *World
Start world = startIO MDI Void myEditor1 [ProcessClose closeProcess] world

selfGEC :: String (t -> t) t (PSt .ps) -> PSt .ps | gGEC{|*|} t & bimap{|*|} ps
selfGEC gui f x0 env = env1
where
    (gec_t,env1)     = createNGEC gui Interactive True x0 (\updReason x -> gec_t.gecSetValue NoUpdate (f x)) env


mkDynStr x = let dx = dynamic x in DynStr dx (ShowValueDynamic dx)

/*  Section 2, Example 1:
    A self-balancing binary tree editor.
*/
myEditor1 = selfGEC "Tree" balanceTree (Node Leaf 1 Leaf)

::  Tree a = Node (Tree a) a (Tree a) | Leaf
derive gGEC Tree

balanceTree :: ((Tree a) -> (Tree a))
balanceTree = toTree o toList
where
    toList (Node l x r) = toList l ++ [x] ++ toList r
    toList Leaf         = []
    
    toTree [] = Leaf
    toTree xs = Node (toTree ls) x (toTree rs)
    where
        (ls,[x:rs]) = splitAt (length xs/2) xs

/*  Section 3.2, Example 2:
*/
::  MyRecord = { function :: DynString
               , argument :: DynString
               , result   :: DynString }
derive gGEC MyRecord

myEditor2 = selfGEC "test" guiApply (initval (\f -> map f [1..5]) ((+) 1))
where
    initval f v = { MyRecord
                  | function = mkDynStr f
                  , argument = mkDynStr v
                  , result   = mkDynStr (f v) }
    guiApply myrec=:{ MyRecord
                    | function = DynStr (f :: a -> b) _
                    , argument = DynStr (v :: a)      _
                    }
       = {MyRecord | myrec & result = mkDynStr (f v)}
    guiApply myrec
       = {MyRecord | myrec & result = mkDynStr "Wrong. Try again."}

/*  Section 3.2, Example 3:
*/
myEditor3 = selfGEC "test" (guiApply o (^^)) (vertlistAGEC [show "expression " 0])
where
    guiApply [f:args]
        = vertlistAGEC [f:check (fromDynStr f) args]
    where
        check (f::a -> b) [arg=:(_,DynStr (x::a) _):args]
            = [arg : check (dynamic f x) args]
        check (f::a -> b) _ = [show "argument " "?"]
        check (x::a)      _ = [show "result "   x]

    show s v = (Display s,mkDynStr v)
    fromDynStr (_,(DynStr d _)) = d

/*	Section 4.1, Example 4:
	This function has already been defined. You can find it in module basicAGEC.icl.
*/

/*	Section 4.2, Example 5:
*/
::	MyRecord2 a b = { function :: AGEC (a -> b)
                    , argument :: AGEC a
                    , result   :: AGEC b }
derive gGEC MyRecord2

myEditor5 = selfGEC "test" guiApply (initval ((+) 1.0) 0.0)
where
   initval f v = { MyRecord2
                 | function = dynamicAGEC f
                 , argument = dynamicAGEC v
                 , result   = displayAGEC (f v) }
   guiApply myrec=:{ MyRecord2 | function=af, argument=av }
      = {MyRecord2 | myrec & result = displayAGEC ((^^af) (^^av))}

displayAGEC x = modeAGEC (Display x)

/*	Section 4.2, Example 6:
*/
myEditor6 = selfGEC "test" guiApply (initval ((+) 1.0) 0.0)
where
   initval f v = { MyRecord2
                 | function = dynamicAGEC f
                 , argument = counterAGEC v
                 , result   = displayAGEC (f v) }
   guiApply myrec=:{ MyRecord2 | function=af, argument=av }
      = {MyRecord2 | myrec & result = displayAGEC ((^^af) (^^av))}
