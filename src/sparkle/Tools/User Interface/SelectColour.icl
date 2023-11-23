/*
** Program: Clean Prover System
** Module:  SelectColour (.icl)
** 
** Author:  Maarten de Mol
** Created: 31 November 2001
*/

implementation module 
   SelectColour

import 
   StdEnv,
   StdIO,
   States
from StdFunc import seq

// ------------------------------------------------------------------------------------------------------------------------   
WindowNames :== [	"Definition Windows"
				,	"Definition List Windows"
				,	"Hint Window"
				,	"Project Center Window"
				,	"Proof Window"
				,	"Section Center Window"
				,	"Tactic Dialogs"
				,	"Tactic List Windows"
				,	"Theorem Windows"
				,	"Theorem List Windows"
				]
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
:: DialogLS =
// ------------------------------------------------------------------------------------------------------------------------   
	{ selectedColours						:: ![ExtendedColour]
	, selectedIndex							:: !Int
	, displayedColour						:: !ExtendedColour
	}

// ------------------------------------------------------------------------------------------------------------------------   
:: Message
// ------------------------------------------------------------------------------------------------------------------------   
	= SelectWindow				!Int
	| Change
	| BackToStored
	| BackToDefault

// ------------------------------------------------------------------------------------------------------------------------   
buildInitialDialogLS :: !*PState -> (!DialogLS, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
buildInitialDialogLS pstate
	# (def_windows_bg, pstate)							= pstate!ls.stDisplayOptions.optDefinitionWindowBG
	# (def_list_windows_bg, pstate)						= pstate!ls.stDisplayOptions.optDefinitionListWindowBG
	# (hint_window_bg, pstate)							= pstate!ls.stDisplayOptions.optHintWindowBG
	# (proj_center_window_bg, pstate)					= pstate!ls.stDisplayOptions.optProjectCenterBG
	# (proof_window_bg, pstate)							= (DummyValue, pstate)
	# (section_center_window_bg, pstate)				= pstate!ls.stDisplayOptions.optSectionCenterBG
	# (tactic_dialogs_bg, pstate)						= (DummyValue, pstate)
	# (tactic_list_windows_bg, pstate)					= pstate!ls.stDisplayOptions.optTacticListBG
	# (theorem_windows_bg, pstate)						= (DummyValue, pstate)
	# (theorem_list_windows_bg, pstate)					= pstate!ls.stDisplayOptions.optTheoremListWindowBG
	# lstate											=	{ selectedColours		=	[ def_windows_bg
																						, def_list_windows_bg
																						, hint_window_bg
																						, proj_center_window_bg
																						, proof_window_bg
																						, section_center_window_bg
																						, tactic_dialogs_bg
																						, tactic_list_windows_bg
																						, theorem_windows_bg
																						, theorem_list_windows_bg
																						]
															, selectedIndex			= 0
															, displayedColour		= def_windows_bg
															}
	= (lstate, pstate)

// ========================================================================================================================
// Definitions found in the standard library of Python:
// ========================================================================================================================
//	def rgb_to_hls(r, g, b):
//	    maxc = max(r, g, b)
//	    minc = min(r, g, b)
//	    # XXX Can optimize (maxc+minc) and (maxc-minc)
//	    l = (minc+maxc)/2.0
//	    if minc == maxc: return 0.0, l, 0.0
//	    if l <= 0.5: s = (maxc-minc) / (maxc+minc)
//	    else: s = (maxc-minc) / (2.0-maxc-minc)
//	    rc = (maxc-r) / (maxc-minc)
//	    gc = (maxc-g) / (maxc-minc)
//	    bc = (maxc-b) / (maxc-minc)
//	    if r == maxc: h = bc-gc
//	    elif g == maxc: h = 2.0+rc-bc
//	    else: h = 4.0+gc-rc
//	    h = (h/6.0) % 1.0
//	    return h, l, s
//	
//	def hls_to_rgb(h, l, s):
//	    if s == 0.0: return l, l, l
//	    if l <= 0.5: m2 = l * (1.0+s)
//	    else: m2 = l+s-(l*s)
//	    m1 = 2.0*l - m2
//	    return (_v(m1, m2, h+ONE_THIRD), _v(m1, m2, h), _v(m1, m2, h-ONE_THIRD))
//	
//	def _v(m1, m2, hue):
//	    hue = hue % 1.0
//	    if hue < ONE_SIXTH: return m1 + (m2-m1)*hue*6.0
//	    if hue < 0.5: return m2
//	    if hue < TWO_THIRD: return m1 + (m2-m1)*(TWO_THIRD-hue)*6.0
//	    return m1
// ========================================================================================================================

// ========================================================================================================================
// Convert (Hue,Lum,Sat) to (Red,Green,Blue)
// Input range: 0..255
// Output range: 0..255
// ------------------------------------------------------------------------------------------------------------------------   
convertToRGB :: !Int !Int !Int -> (!Int, !Int, !Int)
// ------------------------------------------------------------------------------------------------------------------------   
convertToRGB hue lum sat
	| sat == 0											= (lum, lum, lum)
	#! (hue, lum, sat)									= (toReal hue / 255.0, toReal lum / 255.0, toReal sat / 255.0)
	#! m2												= case lum <= 0.5 of
															True	-> lum * (1.0 + sat)
															False	-> lum + sat - (lum * sat)
	#! m1												= 2.0 * lum - m2
	#! red												= value m1 m2 (hue + one_third)
	#! green											= value m1 m2 hue
	#! blue												= value m1 m2 (hue - one_third)
	= (entier (red * 255.0), entier (green * 255.0), entier (blue * 255.0))
	where
		value :: !Real !Real !Real -> Real
		value m1 m2 hue
			#! hue										= moduloOne hue
			| hue < one_sixth							= m1 + (m2-m1)*hue*6.0
			| hue < 0.5									= m2
			| hue < two_third							= m1 + (m2-m1)*(two_third-hue)*6.0
			= m1
		
		two_third										= 2.0 / 3.0
		one_third										= 1.0 / 3.0
		one_sixth										= 1.0 / 6.0

// ========================================================================================================================
// Convert (Red,Green,Blue) to (Hue,Lum,Sat)
// Input range: 0..255
// Output range: 0..255
// ------------------------------------------------------------------------------------------------------------------------   
convertToHLS :: !Int !Int !Int -> (!Int, !Int, !Int)
// ------------------------------------------------------------------------------------------------------------------------   
convertToHLS red green blue
	#! greatest											= the_max red green blue
	#! (red, green, blue)								= (toReal red / 255.0, toReal green / 255.0, toReal blue / 255.0)
	#! max_c											= max red (max green blue)
	#! min_c											= min red (min green blue)
	#! lum												= (min_c + max_c) / 2.0
	| min_c == max_c									= (0, entier (lum * 255.0), 0)
	#! sat												= case lum <= 0.5 of
															True	-> (max_c - min_c) / (max_c + min_c)
															False	-> (max_c - min_c) / (2.0 - max_c - min_c)
	#! red_c											= (max_c - red) / (max_c - min_c)
	#! green_c											= (max_c - green) / (max_c - min_c)
	#! blue_c											= (max_c - blue) / (max_c - min_c)
	#! hue												= case greatest of
															1 /* red */		-> blue_c - green_c
															2 /* green */	-> 2.0 + red_c - blue_c
															3 /* blue */	-> 4.0 + green_c - red_c
	#! hue												= moduloOne (hue / 6.0)
	= (entier (hue * 255.0), entier (lum * 255.0), entier (sat * 255.0))
	where
		the_max red green blue
			| red >= green && red >= blue				= 1
			| green >= red && green >= blue				= 2
			= 3

// ------------------------------------------------------------------------------------------------------------------------   
moduloOne :: !Real -> Real
// ------------------------------------------------------------------------------------------------------------------------   
moduloOne real
	| real <= (-1.0)									= moduloOne (real + 1.0)
	| real >= 1.0										= moduloOne (real - 1.0)
	| real <= 0.0										= 1.0 + real
	= real


























// ------------------------------------------------------------------------------------------------------------------------   
selectColour :: !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
selectColour pstate
	# (dialog_id, pstate)								= accPIO openId pstate
	# (dialog_rid, pstate)								= accPIO openRId pstate
	# (names_rid, pstate)								= accPIO openRId pstate
	# (frame_rid, pstate)								= accPIO openRId pstate
	# (rgb_rid, pstate)									= accPIO openRId pstate
	# (change_bid, pstate)								= accPIO openButtonId pstate
	# (previous_bid, pstate)							= accPIO openButtonId pstate
	# (default_bid, pstate)								= accPIO openButtonId pstate
	# (apply_id, pstate)								= accPIO openId pstate
	# (cancel_id, pstate)								= accPIO openId pstate
	
	# (initial_lstate, pstate)							= buildInitialDialogLS pstate
	# (_, pstate)										= openModalDialog initial_lstate (dialog initial_lstate dialog_id dialog_rid names_rid frame_rid rgb_rid change_bid previous_bid default_bid apply_id cancel_id) pstate
	= pstate
	where
		dialog initial_lstate dialog_id dialog_rid names_rid frame_rid rgb_rid change_bid previous_bid default_bid apply_id cancel_id
			= Dialog "Select Colour"
				(	Receiver							dialog_rid receive
															[]
				:+:	MarkUpControl						(showWindowNames initial_lstate)
															[ MarkUpFontFace				"Times New Roman"
															, MarkUpTextSize				11
															, MarkUpBackgroundColour		getDialogBackgroundColour
															, MarkUpLinkStyle				False DarkGrey getDialogBackgroundColour False Black getDialogBackgroundColour
															, MarkUpLinkStyle				False White getDialogBackgroundColour False LightGrey getDialogBackgroundColour
															, MarkUpReceiver				names_rid
															, MarkUpEventHandler			(sendHandler dialog_rid)
															]
															[]
				:+:	CompoundControl
					(	boxedMarkUp							Black DoNotResize (showWindowFrame initial_lstate)
																[ MarkUpWidth					260
																, MarkUpFontFace				"Times New Roman"
																, MarkUpTextSize				11
																, MarkUpReceiver				frame_rid
																, MarkUpBackgroundColour		(toColour 0 initial_lstate.displayedColour)
																]
																[ ControlPos					(Center, zero)
																]
					:+:	boxedMarkUp							Black DoNotResize (showRGB initial_lstate)
																[ MarkUpWidth					260
																, MarkUpFontFace				"Times New Roman"
																, MarkUpTextSize				10
																, MarkUpReceiver				rgb_rid
																, MarkUpBackgroundColour		(toColour 0 initial_lstate.displayedColour)
																, MarkUpEventHandler			(sendHandler dialog_rid)
																]
																[ ControlPos					(Center, zero)
																]
					:+:	CompoundControl
						(	MarkUpButton						" change " getDialogBackgroundColour (\ps -> snd (syncSend dialog_rid Change ps)) change_bid
																	[]
						:+:	MarkUpButton						" back to stored " getDialogBackgroundColour (\ps -> snd (syncSend dialog_rid BackToStored ps)) previous_bid
																	[]
						:+:	MarkUpButton						" back to default " getDialogBackgroundColour (\ps -> snd (syncSend dialog_rid BackToDefault ps)) default_bid
																	[]
						)	[ ControlHMargin	0 0
							, ControlVMargin	0 0
							, ControlItemSpace	5 5
							, ControlLook		True (\_ {newFrame} -> seq [setPenColour getDialogBackgroundColour, fill newFrame])
							, ControlPos		(Center, zero)
							]
					)	[ ControlHMargin		0 0
						, ControlVMargin		0 0
						, ControlItemSpace		5 5
						, ControlLook			True (\_ {newFrame} -> seq [setPenColour getDialogBackgroundColour, fill newFrame])
						, ControlPos			(RightToPrev, OffsetVector {vx=50, vy=0})
						]
				:+:	CompoundControl
					(	ButtonControl						"Close dialog"
																[ ControlPos					(Right, zero)
																, ControlId						cancel_id
																, ControlFunction				(noLS (closeWindow dialog_id))
																]
					:+:	ButtonControl						"Apply all changes"
																[ ControlPos					(LeftOfPrev, zero)
																, ControlId						apply_id
																, ControlFunction				apply
																]
					)	[ ControlHMargin		0 0
						, ControlVMargin		0 0
						, ControlItemSpace		5 5
						, ControlLook			True (\_ {newFrame} -> seq [setPenColour getDialogBackgroundColour, fill newFrame])
						, ControlPos			(Right, OffsetVector {vx=0, vy=30})
						]
				)
				[ WindowClose							(noLS (closeWindow dialog_id))
				, WindowId								dialog_id
				, WindowCancel							cancel_id
				]
			where
				receive :: !Message !(!DialogLS, !*PState) -> (!DialogLS, !*PState)
				receive BackToDefault (lstate, pstate)
					# current_index						= lstate.selectedIndex
					# default_colour					= case current_index of
															0	-> {exRed = 170, exGreen = 255, exBlue = 255, exHue = 127, exLum = 212, exSat = 255}
															1	-> {exRed = 230, exGreen = 190, exBlue =  40, exHue =  33, exLum = 135, exSat = 201}
															2	-> {exRed = 170, exGreen = 220, exBlue = 170, exHue =  84, exLum = 194, exSat = 106}
															3	-> {exRed = 120, exGreen = 165, exBlue = 222, exHue = 151, exLum = 171, exSat = 154}
															5	-> {exRed = 217, exGreen = 176, exBlue = 183, exHue = 247, exLum = 196, exSat =  89}
															7	-> {exRed = 180, exGreen = 225, exBlue = 140, exHue =  64, exLum = 182, exSat = 149}
															9	-> {exRed = 170, exGreen = 210, exBlue = 100, exHue =  57, exLum = 154, exSat = 140}
															_	-> lstate.displayedColour
					# lstate							= {lstate		& selectedColours		= updateAt current_index default_colour lstate.selectedColours
																		, displayedColour		= default_colour
														  }
					= refresh (lstate, pstate)
				receive BackToStored (lstate, pstate)
					# current_index						= lstate.selectedIndex
					# (stored_colour, pstate)			= case current_index of
															0	-> pstate!ls.stDisplayOptions.optDefinitionWindowBG
															1	-> pstate!ls.stDisplayOptions.optDefinitionListWindowBG
															2	-> pstate!ls.stDisplayOptions.optHintWindowBG
															3	-> pstate!ls.stDisplayOptions.optProjectCenterBG
															5	-> pstate!ls.stDisplayOptions.optSectionCenterBG
															7	-> pstate!ls.stDisplayOptions.optTacticListBG
															9	-> pstate!ls.stDisplayOptions.optTheoremListWindowBG
															_	-> (lstate.displayedColour, pstate)
					# lstate							= {lstate		& selectedColours		= updateAt current_index stored_colour lstate.selectedColours
																		, displayedColour		= stored_colour
														  }
					= refresh (lstate, pstate)
				receive Change (lstate, pstate)
					# current_index						= lstate.selectedIndex
					| not (isMember current_index [0,1,2,3,5,7,9])
														= (lstate, pstate)
					# (new_id, pstate)					= accPIO openId pstate
					# (new_rid, pstate)					= accPIO openRId pstate
					# (slider_id, pstate)				= accPIO openId pstate
					# (current_rid, pstate)				= accPIO openRId pstate
					# (ok_id, pstate)					= accPIO openId pstate
					# (cancel_id, pstate)				= accPIO openId pstate
					# ((_, mb_colour), pstate)			= openModalDialog lstate.displayedColour (pickDialog lstate.displayedColour new_id new_rid slider_id current_rid ok_id cancel_id) pstate
					| isNothing mb_colour				= (lstate, pstate)
					# new_colour						= fromJust mb_colour
					# lstate							= {lstate		& selectedColours		= updateAt current_index new_colour lstate.selectedColours
																		, displayedColour		= new_colour
														  }
					= refresh (lstate, pstate)
				receive (SelectWindow num) (lstate, pstate)
					# old_index							= lstate.selectedIndex
					# old_selected_colour				= toColour (lstate.selectedColours !! old_index)
					# lstate							= {lstate		& selectedIndex			= num
																		, displayedColour		= lstate.selectedColours !! num
														  }
					= refresh (lstate, pstate)
				
				refresh :: !(!DialogLS, !*PState) -> (!DialogLS, !*PState)
				refresh (lstate, pstate)
					#! pstate							= changeMarkUpText names_rid (showWindowNames lstate) pstate
					#! pstate							= setMarkUpBGColour frame_rid False (toColour 0 lstate.displayedColour) pstate
					#! pstate							= changeMarkUpText frame_rid (showWindowFrame lstate) pstate
					#! pstate							= setMarkUpBGColour rgb_rid False (toColour 0 lstate.displayedColour) pstate
					#! pstate							= changeMarkUpText rgb_rid (showRGB lstate) pstate
					= (lstate, pstate)
				
				apply :: !(!DialogLS, !*PState) -> (!DialogLS, !*PState)
				apply (lstate, pstate)
					// definition window bg
					# new_colour						= lstate.selectedColours !! 0
					# (old_colour, pstate)				= pstate!ls.stDisplayOptions.optDefinitionWindowBG
					# pstate							= {pstate & ls.stDisplayOptions.optDefinitionWindowBG = new_colour}
					# (winfos, pstate)					= pstate!ls.stWindows
					# pstate							= update_definition_windows old_colour new_colour winfos pstate
					// definition list window bg
					# new_colour						= lstate.selectedColours !! 1
					# (old_colour, pstate)				= pstate!ls.stDisplayOptions.optDefinitionListWindowBG
					# pstate							= {pstate & ls.stDisplayOptions.optDefinitionListWindowBG = new_colour}
					# pstate							= update_unregistered old_colour new_colour "DefinitionList" pstate
					// hint window bg
					# new_colour						= lstate.selectedColours !! 2
					# (old_colour, pstate)				= pstate!ls.stDisplayOptions.optHintWindowBG
					# pstate							= {pstate & ls.stDisplayOptions.optHintWindowBG = new_colour}
					# pstate							= update_normal old_colour new_colour WinHints pstate
					// project center bg
					# new_colour						= lstate.selectedColours !! 3
					# (old_colour, pstate)				= pstate!ls.stDisplayOptions.optProjectCenterBG
					# pstate							= {pstate & ls.stDisplayOptions.optProjectCenterBG = new_colour}
					# pstate							= update_normal old_colour new_colour WinProjectCenter pstate
					// section center bg
					# new_colour						= lstate.selectedColours !! 5
					# (old_colour, pstate)				= pstate!ls.stDisplayOptions.optSectionCenterBG
					# pstate							= {pstate & ls.stDisplayOptions.optSectionCenterBG = new_colour}
					# pstate							= update_normal old_colour new_colour WinSectionCenter pstate
					// tactic list bg
					# new_colour						= lstate.selectedColours !! 7
					# (old_colour, pstate)				= pstate!ls.stDisplayOptions.optTacticListBG
					# pstate							= {pstate & ls.stDisplayOptions.optTacticListBG = new_colour}
					# pstate							= update_normal old_colour new_colour (WinTacticList 0) pstate
					# pstate							= update_normal old_colour new_colour (WinTacticList 1) pstate
					# pstate							= update_normal old_colour new_colour (WinTacticList 2) pstate
					# pstate							= update_normal old_colour new_colour (WinTacticList 3) pstate
					# pstate							= update_normal old_colour new_colour (WinTacticList 4) pstate
					// theorem list window bg
					# new_colour						= lstate.selectedColours !! 9
					# (old_colour, pstate)				= pstate!ls.stDisplayOptions.optTheoremListWindowBG
					# pstate							= {pstate & ls.stDisplayOptions.optTheoremListWindowBG = new_colour}
					# pstate							= update_unregistered old_colour new_colour "TheoremList" pstate
					= (lstate, pstate)
					where
						update_normal :: !ExtendedColour !ExtendedColour !WindowId !*PState -> *PState
						update_normal old new win_id pstate
							| old == new				= pstate
							# (opened, pstate)			= isWindowOpened win_id False pstate
							| not opened				= pstate
							# (info, pstate)			= get_Window win_id pstate
							# (_, pstate)				= syncSend (fromJust info.wiNormalRId) (CmdRefreshBackground (toColour 0 old) (toColour 0 new)) pstate
							= pstate
						
						update_unregistered :: !ExtendedColour !ExtendedColour !String !*PState -> *PState
						update_unregistered old new name pstate
							| old == new				= pstate
							# (windows, pstate)			= pstate!ls.stUnregisteredWindows
							= send windows pstate
							where
								send :: ![(Id, RId WindowCommand, String)] !*PState -> *PState
								send [(_,rid,window_name):windows] pstate
									| name <> window_name		= send windows pstate
									# (_, pstate)				= syncSend rid (CmdRefreshBackground (toColour 0 old) (toColour 0 new)) pstate
									= send windows pstate
								send [] pstate
									= pstate
						
						update_definition_windows :: !ExtendedColour !ExtendedColour ![WindowInfo] !*PState -> *PState
						update_definition_windows old new [winfo:winfos] pstate
							| old == new				= pstate
							| not (is_def winfo.wiId)	= update_definition_windows old new winfos pstate
							| not winfo.wiOpened		= update_definition_windows old new winfos pstate
							# rid						= fromJust winfo.wiSpecialRId
							# pstate					= changeMarkUpColour rid True (toColour 0 old) (toColour 0 new) pstate
							= update_definition_windows old new winfos pstate
							where
								is_def :: !WindowId -> Bool
								is_def (WinDefinition _)= True
								is_def _				= False
						update_definition_windows old new [] pstate
							= pstate

// ------------------------------------------------------------------------------------------------------------------------   
showRGB :: !DialogLS -> MarkUpText Message
// ------------------------------------------------------------------------------------------------------------------------   
showRGB lstate
	# colour											= lstate.selectedColours !! lstate.selectedIndex
	=	[ CmCenter
		, CmBText		"red: "
		, CmText		(toString colour.exRed)
		, CmNewlineI	False 1 (Just (toColour 20 colour))
		, CmCenter
		, CmBText		"green: "
		, CmText		(toString colour.exGreen)
		, CmNewlineI	False 1 (Just (toColour 20 colour))
		, CmCenter
		, CmBText		"blue: "
		, CmText		(toString colour.exBlue)
		, CmNewlineI	False 5 (Just (toColour 20 colour))
		, CmCenter
		, CmBText		"hue: "
		, CmText		(toString colour.exHue)
		, CmNewlineI	False 1 (Just (toColour 20 colour))
		, CmCenter
		, CmBText		"lum: "
		, CmText		(toString colour.exLum)
		, CmNewlineI	False 1 (Just (toColour 20 colour))
		, CmCenter
		, CmBText		"sat: "
		, CmText		(toString colour.exSat)
		]

// ------------------------------------------------------------------------------------------------------------------------   
showWindowFrame :: !DialogLS -> MarkUpText Int
// ------------------------------------------------------------------------------------------------------------------------   
showWindowFrame lstate
	# colour											= toColour (lstate.selectedColours !! lstate.selectedIndex)
	# name												= WindowNames !! lstate.selectedIndex
	=	[ CmCenter				
		, CmBText				name
		]

// ------------------------------------------------------------------------------------------------------------------------   
showWindowNames :: !DialogLS -> MarkUpText Message
// ------------------------------------------------------------------------------------------------------------------------   
showWindowNames select_state
	= show 0 select_state.selectedIndex WindowNames select_state.selectedColours
	where
		show my_index selected_index [name:names] [colour:colours]
			# white_circle								= [CmAlign "@Icon", CmSize 8, CmFontFace "Wingdings", CmLink2 1 {toChar 108} (SelectWindow my_index), CmEndFontFace, CmEndSize]
			# black_circle								= [CmAlign "@Icon", CmSize 8, CmFontFace "Wingdings", CmColour Black, CmText {toChar 108}, CmEndColour, CmEndFontFace, CmEndSize]
			# icon										= if (my_index == selected_index) black_circle white_circle
			# name										= if (my_index == selected_index) [CmText name] [CmLink name (SelectWindow my_index)]
			= icon ++ [CmHorSpace 10] ++ name ++ [CmNewlineI False 3 Nothing] ++ show (my_index+1) selected_index names colours
		show _ _ [] []
			= []























// ------------------------------------------------------------------------------------------------------------------------   
// pickDialog :: !ExtendedColour -> Dialog _
// ------------------------------------------------------------------------------------------------------------------------   
pickDialog first_colour dialog_id dialog_rid slider_id current_rid ok_id cancel_id
	= Dialog "Pick a colour"
		(	Receiver									dialog_rid receive
															[]
		:+: CompoundControl
		(	CompoundControl									(NilLS)
																[ ControlMouse					(\_ -> True) Able mouse_function_palette
																, ControlViewSize				{w=256,h=256}
																, ControlLook					True showPalette
																, ControlKeyboard				(\_ -> True) Able keyboard_function_ls
																]
			:+:	CompoundControl								(NilLS)
																[ ControlId						slider_id
																, ControlPos					(RightToPrev, OffsetVector {vx=15,vy=0})
																, ControlMouse					(\_ -> True) Able mouse_function_slider
																, ControlViewSize				{w=35, h=256}
																, ControlLook					True (showSlider first_colour)
																, ControlKeyboard				(\_ -> True) Able keyboard_function_ls
																]
			:+:	boxedMarkUp									Black DoNotResize (showShortRGB first_colour)
																[ MarkUpWidth					(256+15+35+5-2)
																, MarkUpReceiver				current_rid
																, MarkUpBackgroundColour		(toColour 0 first_colour)
																, MarkUpFontFace				"Times New Roman"
																, MarkUpTextSize				9
																, MarkUpLinkStyle				False Black (toColour 0 first_colour) False Yellow (toColour 0 first_colour)
																, MarkUpEventHandler			(sendHandler dialog_rid)
																, MarkUpOverrideKeyboard		keyboard_function
																]
																[ ControlPos					(Center, zero)
																]
			:+:	ButtonControl								"Cancel"
																[ ControlPos					(Right, OffsetVector {vx=0, vy=30})
																, ControlId						cancel_id
																, ControlFunction				(\(ls,ps) -> (first_colour, closeWindow dialog_id ps))
																]
			:+:	ButtonControl								"Ok"
																[ ControlPos					(LeftOfPrev, zero)
																, ControlId						ok_id
																, ControlFunction				(noLS (closeWindow dialog_id))
																]
		)	[ ControlHMargin	5 5
			, ControlVMargin	5 5
			, ControlItemSpace	5 5
			, ControlKeyboard	(\_ -> True) Able keyboard_function_ls
			, ControlLook		True (\_ {newFrame} -> seq [setPenColour getDialogBackgroundColour, fill newFrame])
			]
		)
		[ WindowId				dialog_id
		, WindowClose			(\(ls,ps) -> (first_colour, closeWindow dialog_id ps))
		, WindowHMargin			0 0
		, WindowVMargin			0 0
		, WindowOk				ok_id
		, WindowCancel			cancel_id
		]
	where
		keyboard_function :: !KeyboardState !*PState -> *PState
		keyboard_function (CharKey '+' (KeyDown _)) pstate
			= snd (syncSend dialog_rid "+" pstate)
		keyboard_function (CharKey '-' (KeyDown _)) pstate
			= snd (syncSend dialog_rid "-" pstate)
		keyboard_function key pstate
			= pstate

		keyboard_function_ls :: !KeyboardState !(!ExtendedColour, !*PState) -> (!ExtendedColour, !*PState)
		keyboard_function_ls (CharKey '+' (KeyDown _)) (colour, pstate)
			= receive "+" (colour, pstate)
		keyboard_function_ls (CharKey '-' (KeyDown _)) (colour, pstate)
			= receive "-" (colour, pstate)
		keyboard_function_ls key (colour, pstate)
			= (colour, pstate)
		
		mouse_function_palette :: !MouseState !(!ExtendedColour, !*PState) -> (!ExtendedColour, !*PState)
		mouse_function_palette (MouseDown point _ _) (colour, pstate)
			# (h, s)									= (point.x, point.y)
			# l											= colour.exLum
//			# l											= 150
			# (r, g, b)									= convertToRGB h l s
			# new_colour								= {exRed = r, exGreen = g, exBlue = b, exHue = h, exLum = l, exSat = s}
			= refresh (new_colour, pstate)
		mouse_function_palette _ (colour, pstate)
			= (colour, pstate)
		
		mouse_function_slider :: !MouseState !(!ExtendedColour, !*PState) -> (!ExtendedColour, !*PState)
		mouse_function_slider (MouseDown point _ _) (colour, pstate)
			# (h, s)									= (colour.exHue, colour.exSat)
			# l											= point.y
			# (r, g, b)									= convertToRGB h l s
			# new_colour								= {exRed = r, exGreen = g, exBlue = b, exHue = h, exLum = l, exSat = s}
			= refresh (new_colour, pstate)
		mouse_function_slider _ (colour, pstate)
			= (colour, pstate)
		
		receive :: !String !(!ExtendedColour, !*PState) -> (!ExtendedColour, !*PState)
		receive "+" (colour, pstate)
			# (h, l, s)									= (colour.exHue, colour.exLum, colour.exSat)
			# l											= min 255 (l+1)
			# (r, g, b)									= convertToRGB h l s
			# new_colour								= {exRed = r, exGreen = g, exBlue = b, exHue = h, exLum = l, exSat = s}
			= refresh (new_colour, pstate)
		receive "-" (colour, pstate)
			# (h, l, s)									= (colour.exHue, colour.exLum, colour.exSat)
			# l											= max 0 (l-1)
			# (r, g, b)									= convertToRGB h l s
			# new_colour								= {exRed = r, exGreen = g, exBlue = b, exHue = h, exLum = l, exSat = s}
			= refresh (new_colour, pstate)
		receive "RGB" (colour, pstate)
			# (dialog_id, pstate)						= accPIO openId pstate
			# (red_id, pstate)							= accPIO openId pstate
			# (green_id, pstate)						= accPIO openId pstate
			# (blue_id, pstate)							= accPIO openId pstate
			# (ok_id, pstate)							= accPIO openId pstate
			# (cancel_id, pstate)						= accPIO openId pstate
			# (r,g,b, pstate)							= getNumbers dialog_id "Override RGB values" "red" colour.exRed red_id "green" colour.exGreen green_id "blue" colour.exBlue blue_id ok_id cancel_id pstate
			# (h, l, s)									= convertToHLS r g b
			# new_colour								= {exRed = r, exGreen = g, exBlue = b, exHue = h, exLum = l, exSat = s}
			= refresh (new_colour, pstate)
		receive "HLS" (colour, pstate)
			# (dialog_id, pstate)						= accPIO openId pstate
			# (hue_id, pstate)							= accPIO openId pstate
			# (lum_id, pstate)							= accPIO openId pstate
			# (sat_id, pstate)							= accPIO openId pstate
			# (ok_id, pstate)							= accPIO openId pstate
			# (cancel_id, pstate)						= accPIO openId pstate
			# (h,l,s, pstate)							= getNumbers dialog_id "Override HLS values" "hue" colour.exHue hue_id "lum" colour.exLum lum_id "sat" colour.exSat sat_id ok_id cancel_id pstate
			# (r, g, b)									= convertToRGB h l s
			# new_colour								= {exRed = r, exGreen = g, exBlue = b, exHue = h, exLum = l, exSat = s}
			= refresh (new_colour, pstate)

		refresh :: !(!ExtendedColour, !*PState) -> (!ExtendedColour, !*PState)
		refresh (colour, pstate)
			# pstate									= appPIO (setControlLook slider_id True (False, showSlider colour)) pstate
			# pstate									= setMarkUpBGColour current_rid False (toColour 0 colour) pstate
			# pstate									= changeMarkUpText current_rid (showShortRGB colour) pstate
			= (colour, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
showPalette :: !SelectState !UpdateState !*Picture -> *Picture
// ------------------------------------------------------------------------------------------------------------------------   
showPalette _ _ pict
	= draw 0 0 pict
	where
		draw :: !Int !Int !*Picture -> *Picture
		draw x y pict
			#! (r,g,b)									= convertToRGB x 150 y
			#! colour									= RGB {r=r, g=g, b=b}
			#! pict										= setPenColour colour pict
			#! pict										= drawPointAt {x=x,y=y} pict
			| x == 255
				| y == 255								= pict
				= draw 0 (y+1) pict
			= draw (x+1) y pict

// ------------------------------------------------------------------------------------------------------------------------   
showShortRGB :: !ExtendedColour -> MarkUpText String
// ------------------------------------------------------------------------------------------------------------------------   
showShortRGB colour
	=	[ CmCenter
		, CmBold
		, CmLink		"R:" "RGB"
		, CmEndBold
		, CmText		(toString colour.exRed)
		, CmBold
		, CmText		" "
		, CmLink		"G:" "RGB"
		, CmEndBold
		, CmText		(toString colour.exGreen)
		, CmBold
		, CmText		" "
		, CmLink		"B:" "RGB"
		, CmEndBold
		, CmText		(toString colour.exBlue)
		, CmBold
		, CmText		" "
		, CmLink		"H:" "HLS"
		, CmEndBold
		, CmText		(toString colour.exHue)
		, CmBold
		, CmText		" "
		, CmLink		"L:" "HLS"
		, CmEndBold
		, CmText		(toString colour.exLum)
		, CmBold
		, CmText		" "
		, CmLink		"S:" "HLS"
		, CmEndBold
		, CmText		(toString colour.exSat)
		]

// ------------------------------------------------------------------------------------------------------------------------   
showSlider :: !ExtendedColour !SelectState !UpdateState !*Picture -> *Picture
// ------------------------------------------------------------------------------------------------------------------------   
showSlider colour _ {newFrame, updArea} pict
	#! pict												= setPenColour getDialogBackgroundColour pict
	#! left_frame										= {corner1={x=0,y=0}, corner2={x=5,y=255}}
	#! right_frame										= {corner1={x=31,y=0}, corner2={x=36,y=255}}
	#! pict												= fill left_frame pict
	#! pict												= fill right_frame pict
	= draw colour.exHue 0 colour.exSat pict
		where
			draw :: !Int !Int !Int !*Picture -> *Picture
			draw h l s pict
				# draw_colour							= case (255-l) == colour.exLum of
															True	-> Black
															False	-> let (r,g,b) = convertToRGB h (255-l) 150
																		in RGB {r=r, g=g, b=b}
				# draw_rectangle						= case (255-l) == colour.exLum of
															True	-> {corner1={x=0, y=255-l}, corner2={x=36,y=255-l+1}}
															False	-> {corner1={x=5, y=255-l}, corner2={x=31,y=255-l+1}}
				# have_to_draw							= any (haveOverlap draw_rectangle) updArea
				| not have_to_draw						= draw h (l+1) s pict
				#! pict									= setPenColour draw_colour pict
				#! pict									= fill draw_rectangle pict
				| l == 255								= pict
				= draw h (l+1) s pict










// ------------------------------------------------------------------------------------------------------------------------   
getNumbers :: !Id !String !String !Int !Id !String !Int !Id !String !Int !Id !Id !Id !*PState -> (!Int, !Int, !Int, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
getNumbers dialog_id title text1 value1 id1 text2 value2 id2 text3 value3 id3 ok_id cancel_id pstate
	# ((_, mb_numbers), pstate)								= openModalDialog (value1, value2, value3) dialog pstate
	| isNothing mb_numbers									= (value1, value2, value3, pstate)
	# (n1,n2,n3)											= fromJust mb_numbers
	| n1 < 0 || n2 < 0 || n3 < 0							= (value1, value2, value3, pstate)
	= (n1, n2, n3, pstate)
	where
		dialog
			= Dialog title
				(	CompoundControl
					(	MarkUpControl						[CmBText ("Value for " +++ text1 +++ ":")]
																[ MarkUpFontFace				"Times New Roman"
																, MarkUpTextSize				10
																, MarkUpBackgroundColour		getDialogBackgroundColour
																]
																[ ControlPos					(Right, zero)
																]
					:+:	MarkUpControl						[CmBText ("Value for " +++ text2 +++ ":")]
																[ MarkUpFontFace				"Times New Roman"
																, MarkUpTextSize				10
																, MarkUpBackgroundColour		getDialogBackgroundColour
																]
																[ ControlPos					(Right, zero)
																]
					:+:	MarkUpControl						[CmBText ("Value for " +++ text3 +++ ":")]
																[ MarkUpFontFace				"Times New Roman"
																, MarkUpTextSize				10
																, MarkUpBackgroundColour		getDialogBackgroundColour
																]
																[ ControlPos					(Right, zero)
																]
					)	[ ControlHMargin		0 0
						, ControlVMargin		0 0
						, ControlItemSpace		7 7
						, ControlLook			True (\_ {newFrame} -> seq [setPenColour getDialogBackgroundColour, fill newFrame])
						]
				:+:	EditControl								(toString value1) (TextWidth "|1000|") 1
																[ ControlId						id1
																]
				:+:	EditControl								(toString value2) (TextWidth "|1000|") 1
																[ ControlId						id2
																, ControlPos					(Below id1, zero)
																]
				:+:	EditControl								(toString value3) (TextWidth "|1000|") 1
																[ ControlId						id3
																, ControlPos					(Below id2, zero)
																]
				:+:	ButtonControl							"Cancel"
																[ ControlId						cancel_id
																, ControlFunction				(\(ls,ps) -> ((-1,-1,-1), closeWindow dialog_id ps))
																, ControlPos					(Right, OffsetVector {vx=0, vy=20})
																]
				:+:	ButtonControl							"Ok"
																[ ControlId						ok_id
																, ControlPos					(LeftOfPrev, zero)
																, ControlFunction				accept
																]
				)
				[ WindowId								dialog_id
				, WindowClose							(\(ls,ps) -> ((-1,-1,-1), closeWindow dialog_id ps))
				, WindowItemSpace						5 5
				, WindowOk								ok_id
				, WindowCancel							cancel_id
				]
		
		accept :: !((Int,Int,Int), !*PState) -> ((Int,Int,Int), !*PState)
		accept (_, pstate)
			# (mb_wstate, pstate)							= accPIO (getWindow dialog_id) pstate
			| isNothing mb_wstate							= ((-1,-1,-1), pstate)
			# wstate										= fromJust mb_wstate
			# (ok, mb_text_1)								= getControlText id1 wstate
			| not ok || isNothing mb_text_1					= ((-1,-1,-1), pstate)
			# text_1										= fromJust mb_text_1
			# (ok, mb_text_2)								= getControlText id2 wstate
			| not ok || isNothing mb_text_2					= ((-1,-1,-1), pstate)
			# text_2										= fromJust mb_text_2
			# (ok, mb_text_3)								= getControlText id3 wstate
			| not ok || isNothing mb_text_3					= ((-1,-1,-1), pstate)
			# text_3										= fromJust mb_text_3
			= ((toInt text_1, toInt text_2, toInt text_3), closeWindow dialog_id pstate)