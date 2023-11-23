implementation module buttonGEC

import genericgecs, guigecs, infragecs
import StdPSt
import StdEnv
// Buttons :
	
instance toInt Button where
	toInt any = 0

derive ggen Button
instance parseprint Button where
	parseGEC any = Just undef
	printGEC any = "Button"

gGEC{|Button|} gecArgs=:{gec_value=mv} pSt
	= basicGEC typeName tGEC (buttonGECGUI typeName (setGECvalue tGEC)) gecArgs pSt1
where
	(tGEC,pSt1)	= openGECId pSt
	typeName	= "Button"
	(bwidth,buttonname)	= case mv of Just (Button w name) = (w,name)
							         Nothing              = (defCellWidth,"??")
	
	buttonGECGUI typeName setValue outputOnly pSt
		# (sId,pSt) = openId  pSt
		# (rId,pSt)	= openRId pSt
		# buttonGUI	=     ButtonControl buttonname  [ ControlTip      (":: "+++typeName)
	                                                , ControlId       sId
	                                                , ControlFunction setButton
	                                                , ControlViewSize {w=bwidth,h=defCellHeight}
	                                                ]
					  :+: Receiver rId (setButton2 sId) []
	    = customGECGUIFun Nothing [] undef buttonGUI (update rId) outputOnly pSt
	where
		setButton (ls,pSt)
			= (ls,setValue YesUpdate Pressed pSt)
		setButton2 sId (Button _ name) (ls,pSt)
			= (ls,appPIO (setControlText sId name) pSt)
		setButton2 sId Pressed (ls,pSt)
			= (ls,pSt)
		update rId b pSt
			= snd (syncSend rId b pSt)

// Up Down button ...

derive ggen UpDown

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

// Checkbox ...

derive ggen Checkbox
instance parseprint Checkbox where
	parseGEC "Checked" =  Just Checked
	parseGEC any		= Just NotChecked
	printGEC Checked = "Checked"
	printGEC any = "NotChecked"

gGEC{|Checkbox|} gecArgs=:{gec_value=mv} pSt
	= basicGEC typeName tGEC (checkGECGUI typeName (setGECvalue tGEC)) gecArgs pSt1
where
	(tGEC,pSt1)			= openGECId pSt
	typeName			= "Checkbox"
	mark = case mv of
				Just Checked 	= Mark
				Just NotChecked = NoMark
				any				= NoMark 
	
	checkGECGUI typeName setValue outputOnly pSt
		# (sId,pSt) = openId  pSt
		# (rId,pSt)	= openRId pSt
		# buttonGUI	=     CheckControl  [("", Just (PixelWidth (defCellWidth / 8)), mark, setCheckbox)] (Rows 0)
										[ ControlTip      (":: "+++typeName)
	                                    , ControlId       sId
	                                    , ControlFunction setCheckbox
	                                    , ControlViewSize {w=defCellWidth / 8,h=defCellHeight}
	                                    ]
					  :+: Receiver rId (setCheckbox2 sId) []
	    = customGECGUIFun Nothing [] undef buttonGUI (update rId) outputOnly pSt
	where
		setCheckbox (Checked,pSt)
			= (NotChecked,setValue YesUpdate NotChecked pSt)
		setCheckbox (NotChecked,pSt)
			= (Checked,setValue YesUpdate Checked pSt)
		setCheckbox2 sId Checked (ls,pSt)
			= (Checked,appPIO (markCheckControlItems sId [1]) pSt)
		setCheckbox2 sId NotChecked (ls,pSt)
			= (NotChecked,appPIO (unmarkCheckControlItems sId [1]) pSt)
		update rId b pSt
			= snd (syncSend rId b pSt)

// Simple text ...

derive ggen Text
instance parseprint Text where
	parseGEC any 	=  Just (Text "")
	printGEC (Text t) = t
	printGEC any 	= ""

gGEC{|Text|} gecArgs=:{gec_value=mv} pSt
	= basicGEC typeName tGEC (checkGECGUI typeName (setGECvalue tGEC)) gecArgs pSt1
where
	(tGEC,pSt1)			= openGECId pSt
	typeName			= "Checkbox"
	mytext = case mv of
				Just (Text any) = any
				any				= "" 
	
	checkGECGUI typeName setValue outputOnly pSt
		# (sId,pSt) = openId  pSt
		# (rId,pSt)	= openRId pSt
		# buttonGUI	= TextControl  mytext 	[ ControlTip      (":: "+++typeName)
	                                    		, ControlId       sId
	                                    		]
					  :+: Receiver rId (setCheckbox2 sId) []
	    = customGECGUIFun Nothing [] undef buttonGUI (update rId) outputOnly pSt
	where
		setCheckbox (newtext,pSt)
			= (newtext,setValue YesUpdate newtext pSt)
		setCheckbox2 sId newtext (ls,pSt)
			= (newtext,appPIO (setControlText sId newtext) pSt)
		update rId (Text b) pSt
			= snd (syncSend rId b pSt)			