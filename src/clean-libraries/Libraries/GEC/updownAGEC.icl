implementation module updownAGEC

import genericgecs, guigecs, infragecs
import StdPSt

// some handy buttons

derive generate UpDown

instance parseprint UpDown where
	parseGEC "UpPressed" 	= Just UpPressed
	parseGEC "DownPressed" 	= Just DownPressed
	parseGEC "Neutral"   	= Just Neutral
	
	printGEC UpPressed 		= "UpPressed"
	printGEC DownPressed 	= "DownPressed"
	printGEC Neutral    	= "Neutral"

gGEC{|UpDown|} gecArgs=:{outputOnly} pSt
	= basicGEC typeName tGEC (updownGECGUI typeName (setGECvalue tGEC)) gecArgs pSt1
where
	(tGEC,pSt1)	= openGECId pSt
	typeName	= "UpDown"
	updownGECGUI typeName setValue outputOnly pSt
		# (sId,pSt) = openId  pSt
		# (rId,pSt)	= openRId pSt
		# updownGUI	= { newLS  = 0
					  , newDef =     SliderControl Vertical (PixelWidth 16) {sliderMin = -2^31,sliderMax = 2^31,sliderThumb=0} 
					                               (sliderFun sId)
                                                   [ ControlTip      (":: "+++typeName)
                                                   , ControlId       sId
                                                   ]
				                 :+: Receiver rId (setNewThumb sId) []
	                  }
	    = customGECGUIFun Nothing [] undef updownGUI (update rId) outputOnly pSt
	where
		sliderFun sId sliderMove (v,pSt)
			= case sliderMove of
				SliderDecSmall	= (v+1,setValue YesUpdate UpPressed (appPIO (setSliderThumb sId (v+1)) pSt))
				SliderIncSmall  = (v-1,setValue YesUpdate DownPressed (appPIO (setSliderThumb sId (v-1)) pSt))
		setNewThumb sId b (v,pSt)
			= (v+toInt b,appPIO (setSliderThumb sId (v+toInt b)) pSt)
		update rId b pSt
			= snd (syncSend rId b pSt)
		
instance toInt UpDown where
	toInt UpPressed = 1
	toInt DownPressed = -1
	toInt Neutral    = 0
