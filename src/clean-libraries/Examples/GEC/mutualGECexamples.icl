module mutualGECexamples

import StdEnv, StdIO
import basicEditors

// TO TEST JUST REPLACE THE EXAMPLE NAME myEditor IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF TYPE ((PSt Void) -> (PSt Void))

Start :: *World -> *World
Start world = startGEC myEditor1 world

myEditor1 = mutualGEC ("Euros","Pounds") toPounds toEuros {euros = 3.5}      

exchangerate = 1.4                                  
                                                    
:: Pounds = {pounds :: Real}                        
:: Euros  = {euros  :: Real}                        

derive gGEC Pounds, Euros 
                                                    
toPounds :: Euros -> Pounds                         
toPounds {euros} = {pounds = euros / exchangerate}  
                                                    
toEuros :: Pounds -> Euros                          
toEuros {pounds} = {euros = pounds * exchangerate}  