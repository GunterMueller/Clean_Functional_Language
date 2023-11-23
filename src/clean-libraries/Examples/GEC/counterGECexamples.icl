module counterGECexamples

/********************************************************************
*                                                                   *
*   This module contains some small examples using selfGEC.         *
*                                                                   *
********************************************************************/

import StdEnv, StdIO
import basicEditors

// TO TEST JUST REPLACE THE EXAMPLE NAME myEditor IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF TYPE ((PSt Void) -> (PSt Void))

Start :: *World -> *World
Start world = startGEC myEditor2 world

// Default representation of a counter
        
myEditor1 = selfGEC "My Counter" myupdCntr (0,MyNeutral)
                                  
import buttonGEC, layoutGEC

:: MyCounter :== (Int,MyUpDown)   				       
:: MyUpDown   = MyUp | MyDown | MyNeutral 		// UpDown is predefined in updownAGEC        

derive gGEC MyUpDown

myupdCntr :: MyCounter -> MyCounter     
myupdCntr (n,MyUp)   = (n+1,MyNeutral)  
myupdCntr (n,MyDown) = (n-1,MyNeutral)  
myupdCntr any      = any            

// Nice representation of a counter

myEditor2 = selfGEC "Nice Counter" updCntr (0,Neutral)
                                  
:: Counter :== (Int,UpDown)

updCntr :: Counter -> Counter     
updCntr (n,UpPressed)   = (n+1,Neutral)  
updCntr (n,DownPressed) = (n-1,Neutral)  
updCntr any      = any            
