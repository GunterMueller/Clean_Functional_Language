definition module htmlTestHandler

// Variant of htmlHandler special made for testing with Gast
// (c) MJP 2005 *** under construction

import StdHtml

:: Triplet 		:== (String,Int,UpdValue)
:: *TestEvent	:== (Triplet,UpdValue,*FormStates) // chosen triplet, its new value 

doHtmlTest :: (Maybe *TestEvent) (*HSt -> (Html,!*HSt)) *NWorld -> (Html,*FormStates,*NWorld)
fetchInputOptions :: Html -> [(InputType,Value,Maybe (String,Int,UpdValue))] // determine from html code which inputs can be given next time
