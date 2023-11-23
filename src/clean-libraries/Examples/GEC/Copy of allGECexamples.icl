module allGECexamples

/********************************************************************
*                                                                   *
*   This module contains all examples from the AFP 04 paper.      *
*                                                                   *
********************************************************************/

import StdEnv
import StdGEC, StdGECExt, StdAGEC, dynamicAGEC, basicAGEC
import StdDynamic

// TO TEST JUST REPLACE THE EXAMPLE NAME myEditor IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF TYPE ((PSt Void) -> (PSt Void))

Start :: *World -> *World
Start world = startIO MDI Void myEditor5 [ProcessClose closeProcess] world
//Start world = startIO MDI Void (selfGEC "List" id [1]) [ProcessClose closeProcess] world
                                               

// the gGEC{|*|} (= gGECstar defined belwo) defined in the paper is a slightly simplified version of createNGEC 

gGECstar (string,initval,callbackfun) pst = createNGEC string Interactive True initval (\updReason -> callbackfun) pst

// self gec definition

selfGEC :: String (t -> t) t (PSt ps) -> (PSt ps) | gGEC{|*|} t & bimap{|*|} ps
selfGEC s f v env = env1                                                           
where 
	(gec,env1) = gGECstar (s,f v,\x -> gec.gecSetValue NoUpdate  (f x)) env

// Example 1

myEditor1 = selfGEC "Tree" balanceTree (Node Leaf 1 Leaf)
                                               
:: Tree a = Node (Tree a) a (Tree a) | Leaf    
derive gGEC Tree

balanceTree :: ((Tree a) -> (Tree a)) | Ord a
balanceTree = fromListToBalTree o fromTreeToList

fromTreeToList :: (Tree a) -> [a]
fromTreeToList (Node l x r) = fromTreeToList l ++ [x] ++ fromTreeToList r
fromTreeToList Leaf         = []


fromListToBalTree :: [a] -> Tree a | Ord a
fromListToBalTree list = Balance (sort list)
where
	Balance [] = Leaf
	Balance [x] = Node Leaf x Leaf
	Balance xs
		= case splitAt (length xs/2) xs of
			(a,[b:bs]) = Node (Balance bs) b (Balance a)
			(as,[]) = Node Leaf (hd (reverse as)) (Balance (reverse (tl (reverse as))))

        
// Example 2
        
myEditor2a = selfGEC "Counter" myupdCntr (0,MyNeutral)
                                  
:: MyCounter :== (Int,MyUpDown)   				       
:: MyUpDown   = MyUp | MyDown | MyNeutral 		// UpDown is predefined in updownAGEC        

derive gGEC MyUpDown

myupdCntr :: MyCounter -> MyCounter     
myupdCntr (n,MyUp)   = (n+1,MyNeutral)  
myupdCntr (n,MyDown) = (n-1,MyNeutral)  
myupdCntr any      = any            

myEditor2b = selfGEC "Counter" updCntr (0,Neutral)
                                  
:: Counter :== (Int,UpDown)

updCntr :: Counter -> Counter     
updCntr (n,UpPressed)   = (n+1,Neutral)  
updCntr (n,DownPressed) = (n-1,Neutral)  
updCntr any      = any            

                                 
// Manual composition, example 1 : applyGEC

myEditor3 = applyGECs ("List","Balanced Tree") fromListToBalTree [1,5,2]     

applyGECs :: (String,String) (a -> b) a (PSt ps) -> (PSt ps) | gGEC{|*|} a & gGEC{|*|} b & bimap{|*|} ps
applyGECs (sa,sb) f va env                             
   # (gec_b, env) = gGECstar (sb, f va, const id)  env 
   # (gec_a, env) = gGECstar (sa, va, set gec_b f) env     
   = env                                               
                                                       

set :: (GECVALUE b (PSt ps)) (a -> b) a (PSt ps) -> (PSt ps)
set gec f va env = gec.gecSetValue NoUpdate (f va) env 
        
// Manual composition, example 2 : apply2GECs

myEditor4 = apply2GECs ("List1","List2","Balanced Tree") makeBalancedTree [1] [1]      
where                                                                               
    makeBalancedTree l1 l2 = fromListToBalTree (l1 ++ l2)                                

apply2GECs :: (String,String,String) (a -> b -> c) a b (PSt ps) -> (PSt ps)                     
                                                        | gGEC{|*|} a & gGEC{|*|} b & gGEC{|*|} c & bimap{|*|} ps                     
apply2GECs (sa,sb,sc) f va vb env = env3                                                        
where                                                                                           
   (gec_c,env1) = gGECstar (sc,f va vb,const id) env                                                   
   (gec_b,env2) = gGECstar (sb,vb,combine gec_a gec_c (flip f)) env1                                         
   (gec_a,env3) = gGECstar (sa,va,combine gec_b gec_c f) env2                                                
                                                                                                
combine :: (GECVALUE y (PSt ps)) (GECVALUE z (PSt ps))                                                    
           (x -> y -> z) x (PSt ps) -> PSt ps                                                   
combine gy gz f x env                                                                           
   # (y,env) = gy.gecGetValue env                                                               
   # env     = gz.gecSetValue NoUpdate (f x y) env                                              
   = env                                                                                        

// Manual composition, example 3 : selfGEC -> already defined above

// Manual composition, example 4 : mutualGEC, displayed in two sepaprate windows 

myEditor5 = mutualGEC {euros = 3.5} toPounds toEuros      

exchangerate = 1.4                                  
                                                    
:: Pounds = {pounds :: Real}                        
:: Euros  = {euros  :: Real}                        

derive gGEC Pounds, Euros 
                                                    
toPounds :: Euros -> Pounds                         
toPounds {euros} = {pounds = euros / exchangerate}  
                                                    
toEuros :: Pounds -> Euros                          
toEuros {pounds} = {euros = pounds * exchangerate}  


mutualGEC :: a (a -> b) (b -> a) (PSt ps) -> (PSt ps)                                
                                  | gGEC{|*|} a & gGEC{|*|} b & bimap{|*|} ps                     
mutualGEC va a2b b2a env = env2                                                      
where (gec_b,env1) = gGECstar ("Pounds",a2b va,set gec_a b2a) env    
      (gec_a,env2) = gGECstar ("Euros",va,set gec_b a2b) env1   


// Arrow combinators: _C added to the comb names to avoid name conflicts with handmade definitions.

// Arrow combinators, example 1

myEditorX = startCircuit (applyGECs_D ("List","Balanced Tree") (Display o fromListToBalTree)) [1,5,2]        
                                                 
applyGECs_D :: (String,String) (a->b) -> GecCircuit a b | gGEC{|*|} a & gGEC{|*|} b       
applyGECs_D (e1,e2) f 
			= edit e1      >>>                 
              arr f >>>                 
              edit e2                 


applyGECs_C :: GecCircuit [Int] (Tree Int)         
applyGECs_C = edit "List"      >>>                 
              arr fromListToBalTree >>>                 
              edit "Balanced Tree"                 


// Arrow combinators, example 2 ||>> Strange behaviour, BUG !!

myEditor7 = startCircuit apply2GECs_C ([],[])                   
                                                             
apply2GECs_C :: GecCircuit ([Int], [Int]) (Tree Int)           
apply2GECs_C = edit "list1" *** edit "list2" >>>               
               arr makeBalancedTree         >>>                
               edit "Balanced Tree"                            
where                                                        
    makeBalancedTree (l1,l2) = fromListToBalTree (l1 ++ l2) 
    
// Arrow combinators, example 3 

myEditor8 = startCircuit myselfGEC Leaf                   
where                                                       
	myselfGEC :: GecCircuit (Tree Int) (Tree Int)            
	myselfGEC = feedback (arr balanceTree >>>    
                    edit "Self Balancing Tree"    )    

// Arrow combinators, example 4 

myEditor9 = startCircuit myselfGEC (0,Neutral)               
where                                                          
	myselfGEC :: GecCircuit Counter Counter                     
	myselfGEC = feedback (arr updCntr >>> edit "Counter")       

// Arrow combinators, example 5 "funTest" is incomplete !!

// DoubleCounter example, first using a "viewGEC" (i.e. a BimapGEC)

:: ViewGEC a b :== BimapGEC a b

myEditor10 = selfGEC "viewGECs" update (toMyViewModel (myData))
where
	update :: (MyViewModel -> MyViewModel) 
	update = toMyViewModel o myUpdate o fromMyViewModel

	myUpdate :: MyDataModel -> MyDataModel
	myUpdate myrec = {myrec & msum = myrec.mvalue1 + myrec.mvalue2} 

	myData :: MyDataModel 
	myData = {mvalue1 = 0, mvalue2 = 0, msum = 0}

:: MyDataModel = { mvalue1 :: Int
				 , mvalue2 :: Int
				 , msum    :: Int
				 }

:: MyViewModel  = { edvalue1 :: ViewGEC Int Counter                          
                  , edvalue2 :: ViewGEC Int Counter                          
                  , edsum    :: ViewGEC Int (Mode Int) }                  
                                                                             
derive gGEC MyDataModel, MyViewModel 

toMyViewModel :: MyDataModel -> MyViewModel                                  
toMyViewModel rec = { edvalue1 = counterGEC rec.mvalue1                       
                    , edvalue2 = counterGEC rec.mvalue2                       
                    , edsum    = displayGEC rec.msum }                        
                                                                             
fromMyViewModel :: MyViewModel -> MyDataModel                                
fromMyViewModel edrec = { mvalue1 = edrec.edvalue1.value                      
                        , mvalue2 = edrec.edvalue2.value                      
                        , msum    = edrec.edsum.value }   
                        

mkViewGEC:: a (a -> b) (b -> b) (b -> a) -> (BimapGEC a b)
mkViewGEC val toGec updGec fromGec = mkBimapGEC toGec` updGec fromGec val
where
	toGec` nval (Defined oval) =  oval
	toGec` nval _ = toGec nval


counterGEC :: Int -> ViewGEC Int Counter                               
counterGEC i = mkViewGEC i toCounter updCntr fromCounter               

toCounter :: Int -> Counter
toCounter i = (i,Neutral)

fromCounter :: Counter -> Int
fromCounter (a,c) = a
                                                                       
displayGEC :: a -> ViewGEC a (Mode a)                               
displayGEC x = mkViewGEC x toDisplay id fromDisplay                    
where
	toDisplay :: a -> Mode a
	toDisplay x = Display x
	
	fromDisplay :: (Mode a) -> a
	fromDisplay (Display x) = x

// DoubleCounter example, using a AGEC; MyDataModel as before...
                    
displayAGEC val = modeAGEC (Display val)

myEditor11 = selfGEC "AGECs example" update (toMyViewModel` (myData))
where
	update :: (MyViewModel` -> MyViewModel`) 
	update = toMyViewModel` o myUpdate o fromMyViewModel`

	myUpdate :: MyDataModel -> MyDataModel
	myUpdate myrec = {myrec & msum = myrec.mvalue1 + myrec.mvalue2} 

	myData :: MyDataModel 
	myData = {mvalue1 = 0, mvalue2 = 0, msum = 0}
	
:: MyViewModel`      = { edvalue1` :: AGEC Int                              
                       , edvalue2` :: AGEC Int                              
                       , edsum`    :: AGEC Int }                            

derive gGEC MyViewModel`
                                                                           
toMyViewModel` :: MyDataModel -> MyViewModel`                                
toMyViewModel` rec    = { edvalue1` = counterAGEC rec.mvalue1                 
                       , edvalue2`  = counterAGEC rec.mvalue2                 
                       , edsum`     = displayAGEC rec.msum }                  
                                                                           
fromMyViewModel` :: MyViewModel` -> MyDataModel                              
fromMyViewModel` edrec = { mvalue1 = ^^ edrec.edvalue1`                       
                        , mvalue2 = ^^ edrec.edvalue2`                       
                        , msum    = ^^ edrec.edsum` }

// 5.3 Abstract Editors Are Compositional

myEditor12 = myAGECEditor toMyViewModel1
where
	toMyViewModel1 rec                         
   		= 	{ edvalue1` = idAGEC      rec.mvalue1   
     		, edvalue2` = idAGEC      rec.mvalue2   
     		, edsum`    = displayAGEC rec.msum }    

myEditor13 = myAGECEditor toMyViewModel1
where
	toMyViewModel1 rec                         
   		= 	{ edvalue1` = idAGEC      rec.mvalue1   
     		, edvalue2` = counterAGEC rec.mvalue2   
     		, edsum`    = displayAGEC rec.msum }    

myEditor14 = myAGECEditor toMyViewModel1
where
	toMyViewModel1 rec                         
   		= 	{ edvalue1` = counterAGEC  rec.mvalue1   
     		, edvalue2` = sumAGEC      rec.mvalue2   
     		, edsum`    = displayAGEC rec.msum }    


// To choose any "view" the view function is given as parameter...

myAGECEditor toView = selfGEC "AGECs" update (toView (myData))
where
	update = toView o myUpdate o fromMyViewModel`

	myUpdate :: MyDataModel -> MyDataModel
	myUpdate myrec = {myrec & msum = myrec.mvalue1 + myrec.mvalue2} 

	myData :: MyDataModel 
	myData = {mvalue1 = 0, mvalue2 = 0, msum = 0}

sumAGEC :: Int -> AGEC Int 
sumAGEC i = mkAGEC (sumGEC i) "sumGEC"                                            
where sumGEC :: Int -> ViewGEC Int MyViewModel` 
      sumGEC i = mkViewGEC i toGec updGec fromgec                                 
      where toGec   = toMyViewModel` o toMyData                              
            fromgec = fromMyData     o fromMyViewModel`                       
            updGec  = toMyViewModel` o myUpdate o fromMyViewModel`         
                                                                         
			myUpdate :: MyDataModel -> MyDataModel
			myUpdate myrec = {myrec & msum = myrec.mvalue1 + myrec.mvalue2} 

			toMyData :: Int -> MyDataModel
            toMyData   i = {mvalue1 = 0, mvalue2 = i, msum = i}                                

			fromMyData :: MyDataModel -> Int
            fromMyData r = r.msum

// Higher order GEC's: (Example 3), testing any function with one argument 

:: MyRecord = { function :: DynString                                           
              , argument :: DynString                                           
              , result   :: DynString }
              
derive gGEC  MyRecord             
                                                       
myEditor15 = selfGEC "test" guiApply (initval id 0)                               
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

myEditor16 = selfGEC "test" (guiApply o (^^)) (vertlistAGEC [show "expression " 0])
where
    guiApply [f:args]
        = vertlistAGEC [f:check (fromDynStr f) args]
    where
        check (f::a -> b) [arg=:(_,DynStr (x::a) _):args]
            = [arg : check (dynamic f x) args]
        check (f::a -> b) _ = [show "argument " "?"]
        check (x::a)      _ = [show "result "   x]

    show s v = (Display s,mkDynStr v)
    
// Higher order GEC's: (Example 5), testing a function with one argument of statically determined type 

::	MyRecord2 a b = { function` :: AGEC (a -> b)
                    , argument` :: AGEC a
                    , result`   :: AGEC b }

derive gGEC MyRecord2

myEditor17 = selfGEC "test" guiApply (initval ((+) 1.0) 0.0)
where
   initval f v = { MyRecord2
                 | function` = dynamicAGEC f
                 , argument` = dynamicAGEC v
                 , result`   = displayAGEC (f v) }
   guiApply myrec=:{ MyRecord2 | function`=af, argument`=av }
      = {MyRecord2 | myrec & result` = displayAGEC ((^^af) (^^av))}

// Higher order GEC's: (Example 6)

myEditor18 = selfGEC "test" guiApply (initval ((+) 1.0) 0.0)
where
   initval f v = { MyRecord2
                 | function` = dynamicAGEC f
                 , argument` = counterAGEC v
                 , result`   = displayAGEC (f v) }
   guiApply myrec=:{ MyRecord2 | function`=af, argument`=av }
      = {MyRecord2 | myrec & result` = displayAGEC ((^^af) (^^av))}
    
