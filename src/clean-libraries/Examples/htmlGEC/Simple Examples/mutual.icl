module mutual

import StdEnv
import StdHtml

derive gForm  Pounds, Euros
derive gUpd   Pounds, Euros
derive gPrint Pounds, Euros
derive gParse Pounds, Euros
derive gerda  Pounds, Euros

:: Pounds = {pounds :: Real}                        
:: Euros  = {euros  :: Real}                        

Start world  = doHtmlServer mutual world

myEuroId :: (FormId Euros)
myEuroId	= nFormId "euros"  initEuros

myPoundsId :: (FormId Pounds)
myPoundsId	= nFormId "pounds" {pounds = 0.0}
initEuros	= {euros = 0.0}	

mutual hst
# (mutual,hst) = startCircuit circuit initEuros hst
= mkHtml "Mutual Recursive Form"
	[ H1 [] "Example of a Mutual recursive form"
	, toBody mutual
	]  hst
where
	circuit :: GecCircuit Euros Euros
	circuit = feedback (edit myEuroId) (arr toPounds >>> edit myPoundsId >>> arr toEuros)

	toPounds :: Euros -> Pounds                         
	toPounds {euros} = {pounds = euros / exchangerate}  
	                                                    
	toEuros :: Pounds -> Euros                          
	toEuros {pounds} = {euros = pounds * exchangerate} 
	
	exchangerate = 1.4                                  
