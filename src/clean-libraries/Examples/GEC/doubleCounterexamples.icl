module doubleCounterexamples

import StdEnv, StdIO
import basicEditors

// TO TEST JUST REPLACE THE EXAMPLE NAME myEditor IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF TYPE ((PSt Void) -> (PSt Void))

Start :: *World -> *World
Start world = startGEC myEditor5 world

// DoubleCounter example, first using a "viewGEC" (i.e. a BimapGEC)

:: ViewGEC a b :== BimapGEC a b

mkViewGEC:: a (a -> b) (b -> b) (b -> a) -> (ViewGEC a b)
mkViewGEC val toGec updGec fromGec = mkBimapGEC toGec` nupdGec fromGec (\t -> (DontTest,t)) val
where
	toGec` nval (Defined oval) =  oval //toGec nval //oval
	toGec` nval _ = toGec nval

	nupdGec n ps = (True,updGec n,ps)

:: Counter :== (Int,UpDown)

updCntr :: Counter -> Counter     
updCntr (n,UpPressed)   = (n+1,Neutral)  
updCntr (n,DownPressed) = (n-1,Neutral)  
updCntr any      = any            

// data and viewmodel

:: MyDataModel = { dvalue1 :: Int
				 , dvalue2 :: Int
				 , dsum    :: Int
				 }
myInitData :: MyDataModel 
myInitData = {dvalue1 = 0, dvalue2 = 0, dsum = 0}

:: MyViewModel  = { vvalue1 :: ViewGEC Int Counter                          
                  , vvalue2 :: ViewGEC Int Counter                          
                  , vsum    :: ViewGEC Int (Mode Int) }                  
 
derive gGEC MyDataModel, MyViewModel 

// just showing the editor for the data model

myEditor0 = selfGEC "dataGEC" myUpdate myInitData

myUpdate :: MyDataModel -> MyDataModel
myUpdate myrec = {myrec & dsum = myrec.dvalue1 +  myrec.dvalue2} 

// showing the data model differently using a ViewModel

myEditor1 = selfGEC "viewGECs" update (toMyViewModel myInitData)
where
	update :: (MyViewModel -> MyViewModel) 
	update = toMyViewModel o myUpdate o fromMyViewModel

	toMyViewModel :: MyDataModel -> MyViewModel                                  
	toMyViewModel rec = { vvalue1 = counterGEC rec.dvalue1                       
	                    , vvalue2 = counterGEC rec.dvalue2                       
	                    , vsum    = displayGEC rec.dsum }                        
	where
		counterGEC :: Int -> ViewGEC Int Counter                               
		counterGEC i = mkViewGEC i toCounter updCntr fromCounter               
		where
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
                                                                             
	fromMyViewModel :: MyViewModel -> MyDataModel                                
	fromMyViewModel edrec = { dvalue1 = edrec.vvalue1.value                      
	                        , dvalue2 = edrec.vvalue2.value                      
	                        , dsum    = edrec.vsum.value }   

// DoubleCounter example, using a AGEC; MyDataModel as before...
                    
import basicAGEC

:: MyViewModel`      = { vvalue1` :: AGEC Int                              
                       , vvalue2` :: AGEC Int                              
                       , vsum`    :: AGEC Int }                            

derive gGEC MyViewModel`

myEditor2 = selfGEC "AGECs example" update (toMyViewModel` (myData))
where
	update :: (MyViewModel` -> MyViewModel`) 
	update = toMyViewModel` o myUpdate o fromMyViewModel`

	myUpdate :: MyDataModel -> MyDataModel
	myUpdate myrec = {myrec & dsum = myrec.dvalue1 + myrec.dvalue2} 

	myData :: MyDataModel 
	myData = {dvalue1 = 0, dvalue2 = 0, dsum = 0}
                                                                           
toMyViewModel` :: MyDataModel -> MyViewModel`                                
toMyViewModel` rec    = { vvalue1` = counterAGEC rec.dvalue1                 
                       , vvalue2`  = counterAGEC rec.dvalue2                 
                       , vsum`     = displayAGEC rec.dsum }                  
                                                                           
fromMyViewModel` :: MyViewModel` -> MyDataModel                              
fromMyViewModel` edrec = { dvalue1 = ^^ edrec.vvalue1`                       
                        , dvalue2 = ^^ edrec.vvalue2`                       
                        , dsum    = ^^ edrec.vsum` }

// 5.3 Abstract Editors Are Compositional

myEditor3 = myAGECEditor toMyViewModel1
where
	toMyViewModel1 rec                         
   		= 	{ vvalue1` = idAGEC      rec.dvalue1   
     		, vvalue2` = idAGEC      rec.dvalue2   
     		, vsum`    = displayAGEC rec.dsum }    

myEditor4 = myAGECEditor toMyViewModel1
where
	toMyViewModel1 rec                         
   		= 	{ vvalue1` = counterAGEC rec.dvalue1   
     		, vvalue2` = intcalcAGEC rec.dvalue2   
     		, vsum`    = displayAGEC rec.dsum }    

myEditor5 = myAGECEditor toMyViewModel1
where
	toMyViewModel1 rec                         
   		= 	{ vvalue1` = counterAGEC  rec.dvalue1   
     		, vvalue2` = sumAGEC      rec.dvalue2   
     		, vsum`    = displayAGEC rec.dsum }    


// To choose any "view" the view function is given as parameter...

myAGECEditor toView = selfGEC "AGECs" update (toView (myData))
where
	update = toView o myUpdate o fromMyViewModel`

	myUpdate :: MyDataModel -> MyDataModel
	myUpdate myrec = {myrec & dsum = myrec.dvalue1 + myrec.dvalue2} 

	myData :: MyDataModel 
	myData = {dvalue1 = 0, dvalue2 = 0, dsum = 0}

// creating a sumAGEC editor

sumAGEC :: Int -> AGEC Int 
sumAGEC i = mkAGEC (sumGEC i) "sumGEC"                                            
where sumGEC :: Int -> ViewGEC Int MyViewModel` 
      sumGEC i = mkViewGEC i toGec updGec fromgec                                 
      where toGec   = toMyViewModel` o toMyData                              
            fromgec = fromMyData     o fromMyViewModel`                       
            updGec  = toMyViewModel` o myUpdate o fromMyViewModel`         
                                                                         
			myUpdate :: MyDataModel -> MyDataModel
			myUpdate myrec = {myrec & dsum = myrec.dvalue1 + myrec.dvalue2} 

			toMyData :: Int -> MyDataModel
            toMyData   i = {dvalue1 = 0, dvalue2 = 0, dsum = i}                                

			fromMyData :: MyDataModel -> Int
            fromMyData r = r.dsum
   
displayAGEC val = modeAGEC (Display val)
