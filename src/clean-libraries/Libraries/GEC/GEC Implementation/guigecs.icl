implementation module guigecs

import StdBool, StdFunc, StdList, StdMisc, StdOrdList, StdString, StdTuple
import StdObjectIOExt
import ColourTextControl
import objectloc, gec
import parseprint, GenPrint, StdArray

tipTypeText t :== ":: "+++t 

derive gEq OutputOnly

trivialGECGUIFun :: !Int -> GECGUIFun t (PSt .ps)
trivialGECGUIFun k
	= const (return trivialGECGUI)
where
	trivialGECGUI	= { guiLocs   = repeatn k
					  , guiOpen   = const id
					  , guiClose  = id
					  , guiUpdate = const id
					  }

customGECGUIFun :: (Maybe OBJECTControlId) 
				   [(Id,Maybe ItemPos,Maybe ItemPos)] 
				   ls 
				   (cdef ls (PSt .ps)) 
				   (t (PSt .ps) -> (PSt .ps)) 
				-> GECGUIFun t (PSt .ps) 
				|  Controls cdef
customGECGUIFun maybeOBJECTControlId id_layouts lSt guiDef update = customGECGUIFun` maybeOBJECTControlId id_layouts lSt guiDef update
where
	customGECGUIFun` maybeOBJECTControlId id_layouts lSt guiDef update outputOnly pSt
		# (topId,pSt)	= openId pSt
		# gui			= LayoutControl
							(	guiDef 
							:+:	ListLS 
								[  LayoutControl NilLS 
									[ ControlId id 
									: case itemPos of Just pos = [ControlPos pos]; _ = []
									] 
								\\ (id,itemPos,_) <- id_layouts
								]
							)
							[ ControlId topId
							, hMarginAtt
							, vMarginAtt
							, itemSpaceAtt
// PA--						: if (outputOnly===OutputOnly) [ControlSelectState Unable] []
							]
		# gecGUI		= { guiLocs	  = guilocfun maybeOBJECTControlId id_layouts
						  , guiOpen   = openControlsInGUILoc lSt gui
						  , guiClose  = appPIO (closeControl topId True)
						  , guiUpdate = update
						  }
		= (gecGUI,pSt)
	where
		guilocfun :: (Maybe OBJECTControlId) [(Id,Maybe ItemPos,Maybe ItemPos)] (GUILoc,OBJECTControlId) -> [(GUILoc,OBJECTControlId)]
		guilocfun maybeOBJECTControlId id_layouts (_,objectControlId)
			= [  ({guiId=id,guiItemPos=case itemPos of Just pos = pos; _ = (Left,zero)},objLoc)
			  \\ (id,_,itemPos) <- id_layouts
			  ]
		where
			objLoc	= case maybeOBJECTControlId of
						Just objLoc	= objLoc
						nothing     = objectControlId

basicGECGUI :: !String !(SetValue t (PSt .ps)) -> GECGUIFun t (PSt .ps) | parseprint t
basicGECGUI typeName setValue = basicGECGUI` typeName setValue 
where
	basicGECGUI` typeName setValue outputOnly=:OutputOnly pSt
		# (cId,pSt)	= openColourTextControlId pSt
		# basicGUI	= ColourTextControl cId "" defTextBackColour
						[ ControlTip   (tipTypeText typeName)
		//				, ControlWidth (PixelWidth  defTextWidths)
						, ControlViewSize {w=defCellWidth,h=defCellHeight}
						]
		= customGECGUIFun Nothing [] undef basicGUI (update cId) outputOnly pSt
	where
		update cId v pSt
			= setColourTextControlText cId txt pSt
		where
			txt	= printGEC v
	basicGECGUI` typeName setValue outputOnly=:Interactive pSt
		# (eId,pSt)	= openId  pSt
		# (rId,pSt)	= openRId pSt
		# basicGUI	= { newLS  = ""
					  , newDef =     EditControl "" (PixelWidth defTextWidths) 1
					                     [ ControlId       eId
					                     , ControlKeyboard nlFilter Able (\_ -> construct setValue eId)
					                     , ControlDeactivate             (      construct setValue eId)
					                     , ControlTip      (tipTypeText typeName)
					                     ]
					             :+: Receiver rId (setNewText eId) []
					  }
		= customGECGUIFun Nothing [] undef basicGUI (update rId) outputOnly pSt
	where
		nlFilter (SpecialKey key KeyUp _) = key==returnKey || key==enterKey
		nlFilter _                        = False
		
		update rId v pSt
			= snd (syncSend rId (printGEC v) pSt)
		
		setNewText eId txt (_,pSt)
			= (txt,appPIO (setControlText eId txt) pSt)
	
		construct :: !(SetValue t (PSt .ps)) !Id !(!String,!PSt .ps) -> (!String,!PSt .ps) | parseprint t
		construct setValue eId (prevInput,pSt=:{io})
			= case getParentWindow eId io of
				(Just wSt,io)
					= case getControlText eId wSt of
						(True,Just newInput)
							| newInput==prevInput
								= (prevInput,{pSt & io=beep io})
							| otherwise
								= case parseGEC newInput of
									(Just v)
										= (newInput,setValue YesUpdate v {pSt & io=io})
									nothing
									 	= (prevInput,{pSt & io=setControlText eId prevInput io})
						wrong
							= (prevInput,{pSt & io=io})
				(nothing,io)
					= (prevInput,{pSt & io=io})

unitGECGUI :: GECGUIFun UNIT (PSt .ps)
unitGECGUI = trivialGECGUIFun 0

pairGECGUI :: GECGUIFun (PAIR a b) (PSt .ps)
pairGECGUI = pairGECGUI`
where
	pairGECGUI` outputOnly pSt
		# (ids,pSt)		= openIds 2 pSt
		= customGECGUIFun Nothing [(id,Just (Left,zero),Just (Left,zero)) \\ id<-ids] undef NilLS (const id) outputOnly pSt

eitherGECGUI :: GECGUIFun (EITHER a b) (PSt .ps)
eitherGECGUI = trivialGECGUIFun 2

objectGECGUI :: !GenericTypeDefDescriptor
				                          !(            [ConsPos] (PSt .ps) -> (PSt .ps))
				                          !(Arrangement [ConsPos] (PSt .ps) -> (PSt .ps))
				                          !Bool
				                       -> GECGUIFun (OBJECT a) (PSt .ps)
objectGECGUI t switchFun arrangeFun createOBJECTControl = objectGECGUI` t switchFun arrangeFun 
where
	objectGECGUI` t switchFun arrangeFun outputOnly pSt
		| it_is_a_record t			// Of records we do not want to show the singleton data constructor
			= trivialGECGUIFun 1 outputOnly pSt
		| otherwise					// Of all other OBJECTs, we want to display the OBJECTControl
			# (eId,  pSt)	= openId pSt
			# (objId,pSt)	= openOBJECTControlId pSt
			# objectGUI		= OBJECTControl objId t switchFun arrangeFun createOBJECTControl
		                        [ ControlTip (tipTypeText t.gtd_name)
			                    , ControlSelectState (if (outputOnly===OutputOnly) Unable Able)		// PA: from previous version
			                    ]
			= customGECGUIFun (Just objId) [(eId,Nothing,Just (Left,zero))] undef objectGUI (const id) outputOnly pSt
	where
		it_is_a_record :: !GenericTypeDefDescriptor -> Bool
		it_is_a_record {gtd_conses=[{gcd_fields}]} = not (isEmpty gcd_fields)
		it_is_a_record _                           = False

consGECGUI :: !GenericConsDescriptor -> GECGUIFun (CONS a) (PSt .ps)
consGECGUI c = consGECGUI` c
where
	consGECGUI` c outputOnly pSt
		# (cId,pSt)		= openId pSt
		= customGECGUIFun Nothing [(cId,Nothing,Just (Center,zero))] undef NilLS (const id) outputOnly pSt

fieldGECGUI :: !GenericFieldDescriptor -> GECGUIFun (FIELD a) (PSt .ps)
fieldGECGUI gfd = fieldGECGUI` gfd
where
	fieldGECGUI` {gfd_name,gfd_cons={gcd_fields,gcd_type_def={gtd_name}}} outputOnly pSt
		# (consId, pSt)	= openId pSt
//		# (multiId,pSt)	= openId pSt
		# (multiId,pSt)	= openColourTextControlId pSt
		# ((fontDef,width),pSt)
						= accPIO (accScreenPicture accFontInfo) pSt
		# fieldGUI		= ColourTextControl multiId gfd_name defTextBackColour 
							[ ControlTip   (tipTypeText gtd_name)
						//	, ControlWidth (PixelWidth width)
							, ControlViewSize {w=width,h=defCellHeight}
							]
		= customGECGUIFun Nothing [(consId,Nothing/*Just (RightTo multiId,zero)*/,Nothing)] undef fieldGUI (const id) outputOnly pSt
	where
		allFieldNames	= map (\f -> f.gfd_name) gcd_fields
		accFontInfo picture
			# (font,  picture)	= openDialogFont picture
			# (widths,picture)	= getFontStringWidths font allFieldNames picture
			= ((getFontDef font,maxList [defTextWidths : widths]),picture)
