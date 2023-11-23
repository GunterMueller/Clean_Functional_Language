implementation module
	MarkUpText

import
	StdEnv,
	StdIO,
	ossystem,
	ControlMaybe,
	MdM_IOlib
	, RWSDebug

// -----------------------------------------------------------------------------------------------------------------------
:: MarkUpCommand a =
// -----------------------------------------------------------------------------------------------------------------------
	  CmText				!String			
	| CmBText				!String				| CmIText				!String		| CmUText		!String
	| CmNewlineI			!Bool !Int !(Maybe Colour)
	| CmFillLine								| CmStartOfLine
	| CmScope									| CmEndScope
	| CmAlignI				!String !Colour
	| CmCenter									| CmBGCenter			!Colour
	| CmRight									| CmBGRight				!Colour
	| CmHorSpace			!Int				| CmSpaces				!Int
	| CmBold									| CmEndBold
	| CmItalic									| CmEndItalic
	| CmUnderline								| CmEndUnderline
	| CmSize				!Int				| CmChangeSize			!Int		| CmEndSize
	| CmColour				!Colour				| CmEndColour
	| CmBackgroundColour	!Colour				| CmEndBackgroundColour
	| CmFont				!FontDef			| CmEndFont
	| CmFontFace			!String				| CmEndFontFace
	| CmLink				!String a			| CmLink2				!Int !String !a
	| CmId					!a					| CmTextId				!String		| CmEndId
	| CmLabel				!String !Bool

	| Cm_Word				!String !Font !FontMetrics !Int !Colour !Colour								    // word, font, fontmetrics, width, colour, bgcolour
	| Cm_Link				!String a !FontMetrics !Int (!Font, !Colour, !Colour) (!Font, !Colour, !Colour) // as above, but 2 styles: one for normal link, one for selected link
	| Cm_HorSpace			!Int !Colour																    // width, bgcolour (if width = -1, fill to end of line)
CmAlign t  :== CmAlignI t Black
CmTabSpace :== CmSpaces 4
CmNewline  :== CmNewlineI False 0 Nothing

// -----------------------------------------------------------------------------------------------------------------------
:: ButtonId						:== !(!Id, !RId (MarkUpMessage Bool), !RId Bool)
:: MarkUpText a					:== [MarkUpCommand a]
// -----------------------------------------------------------------------------------------------------------------------

// -----------------------------------------------------------------------------------------------------------------------
:: MarkUpAttribute a ps =
// -----------------------------------------------------------------------------------------------------------------------
	  MarkUpWidth				!Int
	| MarkUpMaxWidth			!Int
	| MarkUpHeight				!Int
	| MarkUpMaxHeight			!Int
	| MarkUpHScroll
	| MarkUpVScroll
	| MarkUpTextColour			!Colour
	| MarkUpTextSize			!Int
	| MarkUpBackgroundColour	!Colour
	| MarkUpFont				!FontDef
	| MarkUpFontFace			!String
	| MarkUpFixMetrics			!FontDef
	| MarkUpLinkStyle			!Bool !Colour !Colour !Bool !Colour !Colour
	| MarkUpSpecialClick		!(ps -> ps) !(ps -> ps)
	| MarkUpEventHandler		!((MarkUpEvent a) -> ps -> ps)
	| MarkUpNrLinesI			!Int !Int
	| MarkUpIgnoreMultipleSpaces
	| MarkUpReceiver			!(RId (MarkUpMessage a))
	| MarkUpInWindow			!Id
	| MarkUpOverrideKeyboard	!(KeyboardState -> ps -> ps)
MarkUpNrLines nr_lines :== MarkUpNrLinesI nr_lines 0

// -----------------------------------------------------------------------------------------------------------------------
:: MarkUpEvent a =
// -----------------------------------------------------------------------------------------------------------------------
	{ meSelectEvent				:: !Bool
	, meClickEvent				:: !Bool
	, meNrClicks				:: !Int
	, meLink					:: !a
	, meLinkIndex				:: !Maybe Int
	, meOwnRId					:: !(RId (MarkUpMessage a))
	, meModifiers				:: !Maybe Modifiers
	}

// -----------------------------------------------------------------------------------------------------------------------
:: MarkUpState a ls ps =
// -----------------------------------------------------------------------------------------------------------------------
	{ musCommands				:: ![MarkUpCommand a]
	, musCustomAttributes		:: ![MarkUpAttribute a ps]
	, musControlAttributes		:: ![ControlAttribute *(MarkUpLocalState a ps, ps)]
	, musWindowAttributes		:: ![WindowAttribute *(MarkUpLocalState a ps, ps)]
	, musIsControl				:: !Bool
	}

// -----------------------------------------------------------------------------------------------------------------------
:: MarkUpMessage a =
// -----------------------------------------------------------------------------------------------------------------------
	  MarkUpChangeText			!(MarkUpText a)
	| MarkUpChangeDraw			!Bool !((SmartId a) -> (SmartDrawArea a) -> (Bool, SmartDrawArea a))
	| MarkUpDeactivate
	| MarkUpDrawAtLabel			!String (*Picture -> *Picture)
	| MarkUpJumpTo				!String
	| MarkUpResetSliders
	| MarkUpTrigger				!a
	| MarkUpScrollLeftBottom

// -----------------------------------------------------------------------------------------------------------------------
:: MarkUpLocalState a ps =
// -----------------------------------------------------------------------------------------------------------------------
	{ mulIsControl					:: !Bool
	, mulId							:: !Id					// always generated; used internally
	, mulOuterId					:: !Id					// user given; used for layout
	, mulScrollIds					:: !(!Id, !Id)			// always generated; not always used
	, mulReceiverId					:: (!RId (MarkUpMessage a))
	, mulCommands					:: ![MarkUpCommand a]
	, mulViewDomain					:: !ViewDomain
	, mulScroll						:: !(!Bool, !Bool)		// (needs horizontal scrollbar, needs vertical scrollbar)
	, mulResize						:: Size -> Size -> Size -> Size
	, mulViewSize					:: !Size
	, mulKeyboard					:: !KeyboardState -> ps -> ps
	, mulDrawFunctions				:: ![SmartDrawArea a]
	, mulHighlightDrawFunctions		:: ![(a, SmartDrawArea a)]
	, mulActiveLink					:: !Int
	, mulWidth						:: !Int
	, mulMaxWidth					:: !Int
	, mulHeight						:: !Int
	, mulMaxHeight					:: !Int
	, mulIgnoreMultipleSpaces		:: !Bool
	, mulFixedMetrics				:: !Maybe FontMetrics
	, mulNrLines					:: !(!Int, !Int)
	, mulLinkStyles					:: [(!Bool, !Colour, !Colour, !Bool, !Colour, !Colour)]
	, mulSpecialClick				:: !Maybe ((ps->ps),(ps->ps))
	, mulInitialColour				:: !Colour
	, mulInitialFontDef				:: !FontDef
	, mulInitialBackgroundColour	:: !Colour
	, mulPreviousMouseMove			:: !Point2				// ignore duplicate move commands (generated by Object I/O)
	, mulEventHandler				:: ((MarkUpEvent a) -> ps -> ps)
	, mulBaselines					:: ![Int]				// for each line: fAscent + fDescent of largest font
	, mulSkips						:: ![Int]				// for each line: fLeading of largest font
	, mulScopes						:: ![Scope]
	, mulLabels						:: ![(String, Int, Int)]
	}

// -----------------------------------------------------------------------------------------------------------------------
:: RelativeX =
// -----------------------------------------------------------------------------------------------------------------------
	  RX_Solved		!Int									// absolute x-coordinate
	| RX_Align		!Int !String !Int						// 1=scope of align, 2=name of align, 3=added absolute x

// -----------------------------------------------------------------------------------------------------------------------
(+~) infixl 7 :: !RelativeX !Int -> !RelativeX
// -----------------------------------------------------------------------------------------------------------------------
(+~) (RX_Solved x) add				= RX_Solved (x + add)
(+~) (RX_Align scope align x) add	= RX_Align scope align (x + add)

// -----------------------------------------------------------------------------------------------------------------------
eqFont :: !Font !Font -> Bool
// -----------------------------------------------------------------------------------------------------------------------
eqFont font1 font2
	# fontdef1							= getFontDef font1
	# fontdef2							= getFontDef font2
	| fontdef1.fName <> fontdef2.fName	= False
	| fontdef1.fSize <> fontdef2.fSize	= False
	= fontdef1.fStyles == fontdef2.fStyles

// -----------------------------------------------------------------------------------------------------------------------
:: AlignInfo =
// -----------------------------------------------------------------------------------------------------------------------
	{ aliName		:: !String
	, aliRelativeX	:: ![RelativeX]
	, aliAbsoluteX	:: !Int
	}

// -----------------------------------------------------------------------------------------------------------------------
:: Scope :== ![AlignInfo]
// -----------------------------------------------------------------------------------------------------------------------

// -----------------------------------------------------------------------------------------------------------------------
filterTab :: !String -> !String
// -----------------------------------------------------------------------------------------------------------------------
filterTab text
	= filter_tabs text 0
	where
		filter_tabs text index
			| index >= size text			= text
			| text.[index] == '\t'			= filter_tabs (text := (index, ' ')) (index+1)
			= filter_tabs text (index+1)

// -----------------------------------------------------------------------------------------------------------------------
filterTabs :: ![MarkUpCommand a] -> ![MarkUpCommand a]
// -----------------------------------------------------------------------------------------------------------------------
filterTabs [CmText text: cmds]
	= [CmText (filterTab text): filterTabs cmds]
filterTabs [other: cmds]
	= [other: filterTabs cmds]
filterTabs []
	= []

// -----------------------------------------------------------------------------------------------------------------------
addConstraint :: !Int !String !RelativeX ![Scope] -> ![Scope]
// -----------------------------------------------------------------------------------------------------------------------
addConstraint scope align relx scopes
	# the_scope						= scopes !! scope
	# the_scope						= add_constraint align relx the_scope
	= (take scope scopes) ++ [the_scope: drop (scope+1) scopes]
	where
		add_constraint align relx [aligninfo: aligninfos]
			| aligninfo.aliName <> align	= [aligninfo: add_constraint align relx aligninfos]
			# aligninfo						= {aligninfo & aliRelativeX = [relx: aligninfo.aliRelativeX]}
			= [aligninfo: aligninfos]
		add_constraint align relx []
			= [{aliName = align, aliRelativeX = [relx], aliAbsoluteX = -1}]

// -----------------------------------------------------------------------------------------------------------------------
replaceRelativeConstraint :: ![Scope] !Int !String !Int -> ![Scope]
// -----------------------------------------------------------------------------------------------------------------------
replaceRelativeConstraint scopes scope align absx
	= map (map (replaceA scope align absx)) scopes
	where
		replaceA scope align absx aligninfo
			= {aligninfo & aliRelativeX = map (replaceR scope align absx) aligninfo.aliRelativeX}
	
		replaceR scope align absx   (RX_Solved x) 					= RX_Solved x
		replaceR scope2 align2 absx	(RX_Align scope1 align1 x)		= case (scope1 == scope2) && (align1 == align2) of
																		True	-> RX_Solved (x + absx)
																		False	-> RX_Align scope1 align1 x

// -----------------------------------------------------------------------------------------------------------------------
getAbsoluteConstraint :: ![Scope] !Int !String -> !Int
// -----------------------------------------------------------------------------------------------------------------------
getAbsoluteConstraint scopes scope align
	= get_absolute_constraint (scopes !! scope) align
	where
		get_absolute_constraint [aligninfo: aligninfos] align
			| aligninfo.aliName == align		= aligninfo.aliAbsoluteX
			| otherwise							= get_absolute_constraint aligninfos align
		get_absolute_constraint [] align
			= (-1)

// -----------------------------------------------------------------------------------------------------------------------
initialMarkUpLocalState :: (!MarkUpState a .ls (*PSt .ps)) (*PSt .ps) -> (!MarkUpLocalState a (*PSt .ps), *PSt .ps)
// -----------------------------------------------------------------------------------------------------------------------
initialMarkUpLocalState mstate state
	# (outer_id, state)				= case mstate.musIsControl of
										True	-> get_cid mstate.musControlAttributes state
										False	-> get_wid mstate.musWindowAttributes state
	# (hscroll_id, state)			= accPIO openId state
	# (vscroll_id, state)			= accPIO openId state
	# (the_id, state)				= accPIO openId state
	# the_id						= case mstate.musIsControl of
										True	-> the_id
										False	-> outer_id
//	# maybe_iid						= get_iid mstate.musCustomAttributes
//	# iid							= if (isJust maybe_iid) (fromJust maybe_iid) (abort "Error: did not give MarkUpInWindow attribute")
	# (the_rid, state)				= get_rid mstate.musCustomAttributes state
	# (metrics, state)				= get_fixed_metrics mstate.musCustomAttributes state
	# (font, state)					= accPIO (accScreenPicture openDialogFont) state
	# fontdef						= getFontDef font
	# initial_mstate				= 	{ mulIsControl					= mstate.musIsControl
										, mulId							= the_id
										, mulOuterId					= outer_id
										, mulScrollIds					= (hscroll_id, vscroll_id)
										, mulReceiverId					= the_rid
										, mulCommands					= filterTabs mstate.musCommands
										, mulViewDomain					= zero
										, mulScroll						= (False, False)
										, mulResize						= get_resize mstate.musControlAttributes
										, mulViewSize					= zero
										, mulKeyboard					= \_ state -> state
										, mulDrawFunctions				= []
										, mulHighlightDrawFunctions		= []
										, mulActiveLink					= -1						// index in mulDrawFunctions
										, mulWidth						= 0
										, mulMaxWidth					= 0
										, mulHeight						= 0
										, mulMaxHeight					= 0
										, mulIgnoreMultipleSpaces		= False
										, mulFixedMetrics				= metrics
										, mulNrLines					= (-1, -1)
										, mulLinkStyles					= []
										, mulSpecialClick				= Nothing
										, mulInitialColour				= Black
										, mulInitialFontDef				= fontdef
										, mulInitialBackgroundColour	= White
										, mulPreviousMouseMove			= zero
										, mulEventHandler				= (\event ps -> ps)
										, mulBaselines					= []
										, mulSkips						= []
										, mulScopes						= [[{aliName = "_START_", aliRelativeX = [RX_Solved 0], aliAbsoluteX = (-1)}]]
										, mulLabels						= []
										}
	# (override, initial_mstate)	= checkAttributes initial_mstate False mstate.musCustomAttributes
	# initial_mstate				= if (not override) {initial_mstate & mulLinkStyles = [(True,Blue,initial_mstate.mulInitialBackgroundColour,True,Red,initial_mstate.mulInitialBackgroundColour)]} initial_mstate
	# initial_mstate				= {initial_mstate & mulLinkStyles = reverse initial_mstate.mulLinkStyles}
	= (initial_mstate, state)
	where
		get_cid [] state							= accPIO openId state
		get_cid [ControlId the_id: rest] state		= (the_id, state)
		get_cid [other: rest] state					= get_cid rest state
		
		get_wid [] state							= accPIO openId state
		get_wid [WindowId the_id: rest] state		= (the_id, state)
		get_wid [other: rest] state					= get_wid rest state
		
		get_rid [] state							= accPIO openRId state
		get_rid [MarkUpReceiver rid: rest] state	= (rid, state)
		get_rid [other: rest] state					= get_rid rest state
		
		get_fixed_metrics [] state
			= (Nothing, state)
		get_fixed_metrics [MarkUpFixMetrics fontdef:_] state
			# ((_,font),state)						= accPIO (accScreenPicture (openFont fontdef)) state
			# (metrics, state)						= accPIO (accScreenPicture (getFontMetrics font)) state
			= (Just metrics, state)
		get_fixed_metrics [_:rest] state
			= get_fixed_metrics rest state
		
		get_resize [ControlResize fun:rest]			= fun
		get_resize [other:rest]						= get_resize rest
		get_resize []								= (\current old new -> current)
		
//		get_iid []									= Nothing
//		get_iid [MarkUpInWindow id: rest]			= Just id
//		get_iid [other: rest]						= get_iid rest
	
		change3 to (a, b, c) = (a, b, to)
	
		checkAttributes mstate override_link [MarkUpWidth width: attrs]
			= checkAttributes {mstate & mulWidth = width} override_link attrs
		checkAttributes mstate override_link [MarkUpMaxWidth width: attrs]
			= checkAttributes {mstate & mulMaxWidth = width} override_link attrs
		checkAttributes mstate override_link [MarkUpHeight height: attrs]
			= checkAttributes {mstate & mulHeight = height} override_link attrs
		checkAttributes mstate override_link [MarkUpMaxHeight height: attrs]
			= checkAttributes {mstate & mulMaxHeight = height} override_link attrs
		checkAttributes mstate override_link [MarkUpHScroll: attrs]
			= checkAttributes {mstate & mulScroll = (True, snd mstate.mulScroll)} override_link attrs
		checkAttributes mstate override_link [MarkUpVScroll: attrs]
			= checkAttributes {mstate & mulScroll = (fst mstate.mulScroll, True)} override_link attrs
		checkAttributes mstate override_link [MarkUpTextColour colour: attrs]
			= checkAttributes {mstate & mulInitialColour = colour} override_link attrs
		checkAttributes mstate override_link [MarkUpTextSize size: attrs]
			= checkAttributes {mstate & mulInitialFontDef = {mstate.mulInitialFontDef & fSize = size}} override_link attrs
		checkAttributes mstate override_link [MarkUpBackgroundColour colour: attrs]
			= checkAttributes {mstate & mulInitialBackgroundColour = colour} override_link attrs
		checkAttributes mstate override_link [MarkUpFont fontdef: attrs]
			= checkAttributes {mstate & mulInitialFontDef = fontdef} override_link attrs
		checkAttributes mstate override_link [MarkUpFontFace fontface: attrs]
			= checkAttributes {mstate & mulInitialFontDef = {mstate.mulInitialFontDef & fName = fontface}} override_link attrs
		checkAttributes mstate override_link [MarkUpLinkStyle nunderline ncolour nbgcolour sunderline scolour sbgcolour: attrs]
			= checkAttributes {mstate & mulLinkStyles = [(nunderline, ncolour, nbgcolour, sunderline, scolour, sbgcolour):mstate.mulLinkStyles]} True attrs
		checkAttributes mstate override_link [MarkUpSpecialClick activate deactivate: attrs]
			= checkAttributes {mstate & mulSpecialClick = Just (activate, deactivate)} override_link attrs
		checkAttributes mstate override_link [MarkUpEventHandler eventhandler: attrs]
			= checkAttributes {mstate & mulEventHandler = eventhandler} override_link attrs
		checkAttributes mstate override_link [MarkUpNrLinesI nrlines extra: attrs]
			= checkAttributes {mstate & mulNrLines = (nrlines, extra)} override_link attrs
		checkAttributes mstate override_link [MarkUpIgnoreMultipleSpaces: attrs]
			= checkAttributes {mstate & mulIgnoreMultipleSpaces = True} override_link attrs
		checkAttributes mstate override_link [MarkUpReceiver rid: attrs]
			= checkAttributes mstate override_link attrs
		checkAttributes mstate override_link [MarkUpFixMetrics fontdef:attrs]
			= checkAttributes mstate override_link attrs
		checkAttributes mstate override_link [MarkUpOverrideKeyboard fun:attrs]
			= checkAttributes {mstate & mulKeyboard = fun} override_link attrs
		checkAttributes mstate override_link []
			= (override_link, mstate)

// -----------------------------------------------------------------------------------------------------------------------
makeCm_s :: (!MarkUpLocalState a (*PSt .ps)) (*PSt .ps) -> (!MarkUpLocalState a (*PSt .ps), *PSt .ps)
// -----------------------------------------------------------------------------------------------------------------------
makeCm_s mstate=:{mulCommands, mulInitialFontDef, mulInitialColour, mulInitialBackgroundColour, mulIgnoreMultipleSpaces, mulFixedMetrics} state
	# (new_commands, state)			= accPIO (accScreenPicture (check_commands mulCommands [mulInitialFontDef] [mulInitialColour] [mulInitialBackgroundColour] False)) state
	# mstate						= {mstate & mulCommands = new_commands}
	= (mstate, state)
	where
		// changed this function: now it is not the STATE that is passed, but the PICTURE (still named state though)
		check_commands [CmText text: commands] [fontdef: fontdefs] [colour: colours] [bgcolour: bgcolours] no_leading_spaces state
			# list_text				= [c \\ c <-: text]
			# new_no_leading_spaces	= case mulIgnoreMultipleSpaces of
										False		-> False
										True		-> case isEmpty list_text of
														False		-> last list_text == ' '
														True		-> no_leading_spaces
			# list_text				= remove_leading_spaces no_leading_spaces list_text
			# (commands, state)		= check_commands commands [fontdef: fontdefs] [colour: colours] [bgcolour: bgcolours] new_no_leading_spaces state
			# ((ok, font), state)	= openFont fontdef state
			| isMember "Underline" fontdef.fStyles
									= let (wordcmd, state1)		= make_word_command text font state
									   in ([wordcmd: commands], state1)
			# (space_width, state)	= getFontCharWidth font ' ' state
			# (wordcmds, state)		= make_commands "" 0 list_text font space_width state
			= (wordcmds ++ commands, state)
			where
				remove_leading_spaces False list		= list
				remove_leading_spaces True [' ': cs]	= remove_leading_spaces True cs
				remove_leading_spaces True [c:cs]		= [c:cs]
				remove_leading_spaces True []			= []
				
				// HACK -- one can use \0 to override the splitting of different words
				specialToString :: !Char -> String
				specialToString c
					| c == '\0'							= " "
					= toString c
				
				make_commands wordsofar spacessofar [c: cs] font space_width state
					# spacessofar					= if (mulIgnoreMultipleSpaces && spacessofar > 1) 1 spacessofar
					| c == ' ' && wordsofar == ""	= make_commands wordsofar (spacessofar+1) cs font space_width state
					| c == ' ' && wordsofar <> ""	= let (commands, state1)	= make_commands "" 1 cs font space_width state
														  (wordcmd, state2)		= make_word_command wordsofar font state1
													   in ([wordcmd: commands], state2)
					| c <> ' ' && spacessofar == 0	= make_commands (wordsofar +++ specialToString c) spacessofar cs font space_width state
					| c <> ' ' && spacessofar <> 0	= let (commands, state1)	= make_commands (specialToString c) 0 cs font space_width state
														  space_cmd				= Cm_HorSpace (space_width * spacessofar) bgcolour
													   in ([space_cmd: commands], state1)
					= abort "1 == 2 according to the Clean compiler (MarkUpText, make_command)"
				make_commands wordsofar spacessofar [] font space_width state
					# spacessofar					= if (mulIgnoreMultipleSpaces && spacessofar > 1) 1 spacessofar
					| spacessofar <> 0				= ([Cm_HorSpace (space_width * spacessofar) bgcolour], state)
					| wordsofar <> ""				= let (word_cmd, state1)		= make_word_command wordsofar font state
													   in ([word_cmd], state1)
					| otherwise						= ([], state)
				
				make_word_command word font state
					# (width, state)				= getFontStringWidth font word state
					# (metrics, state)				= case mulFixedMetrics of
														(Just metrics)	-> (metrics, state)
														Nothing			-> getFontMetrics font state
					# cm_word						= Cm_Word word font metrics width colour bgcolour
					= (cm_word, state)
		check_commands [CmNewlineI ignore extra_skip mb_colour: commands] fontdefs colours bgcolours no_leading_spaces state
			# (commands, state)		= check_commands commands fontdefs colours bgcolours False state
			= ([CmNewlineI ignore extra_skip mb_colour: commands], state)
		check_commands [CmStartOfLine: commands] fontdefs colours bgcolours no_leading_spaces state
			# (commands, state)		= check_commands commands fontdefs colours bgcolours False state
			= ([CmStartOfLine: commands], state)
		check_commands [CmAlignI name _: commands] fontdefs colours [bgcolour:bgcolours] no_leading_spaces state
			# (commands, state)		= check_commands commands fontdefs colours [bgcolour:bgcolours] False state
			= ([CmAlignI name bgcolour: commands], state)
		check_commands [CmCenter: commands] fontdefs colours bgcolours no_leading_spaces state
			# (commands, state)		= check_commands commands fontdefs colours bgcolours no_leading_spaces state
			= ([CmBGCenter mstate.mulInitialBackgroundColour: commands], state)
		check_commands [CmRight: commands] fontdefs colours bgcolours no_leading_spaces state
			# (commands, state)		= check_commands commands fontdefs colours bgcolours no_leading_spaces state
			= ([CmBGRight mstate.mulInitialBackgroundColour: commands], state)
		check_commands [CmBText text: commands] fontdefs colours bgcolours no_leading_spaces state
			= check_commands [CmBold, CmText text, CmEndBold: commands] fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmIText text: commands] fontdefs colours bgcolours no_leading_spaces state
			= check_commands [CmItalic, CmText text, CmEndItalic: commands] fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmUText text: commands] fontdefs colours bgcolours no_leading_spaces state
			= check_commands [CmUnderline, CmText text, CmEndUnderline: commands] fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmFillLine: commands] fontdefs colours [bgcolour: bgcolours] no_leading_spaces state
			# (commands, state)		= check_commands commands fontdefs colours [bgcolour: bgcolours] no_leading_spaces state
			= ([Cm_HorSpace (-1) bgcolour: commands], state)
		check_commands [CmHorSpace width: commands] fontdefs colours [bgcolour: bgcolours] no_leading_spaces state
			# (commands, state)		= check_commands commands fontdefs colours [bgcolour: bgcolours] False state
			= ([Cm_HorSpace width bgcolour: commands], state)
		check_commands [CmSpaces nr: commands] [fontdef: fontdefs] colours [bgcolour: bgcolours] no_leading_spaces state
			# (commands, state)		= check_commands commands [fontdef: fontdefs] colours [bgcolour: bgcolours] False state
			# ((_, font), state)	= openFont fontdef state
			# text					= {c \\ c <- repeatn nr 'a'}
			# (width, state)		= getFontStringWidth font text state
			= ([Cm_HorSpace width bgcolour: commands], state)
		check_commands [CmBold: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands [{fontdef & fStyles = ["Bold": fontdef.fStyles]}: [fontdef: fontdefs]] colours bgcolours no_leading_spaces state
		check_commands [CmEndBold: commands] fontdefs colours bgcolours no_leading_spaces state
			# fontdefs				= if (length fontdefs < 2) fontdefs (tl fontdefs)
			= check_commands commands fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmItalic: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands [{fontdef & fStyles = ["Italic": fontdef.fStyles]}: [fontdef: fontdefs]] colours bgcolours no_leading_spaces state
		check_commands [CmEndItalic: commands] fontdefs colours bgcolours no_leading_spaces state
			# fontdefs				= if (length fontdefs < 2) fontdefs (tl fontdefs)
			= check_commands commands fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmUnderline: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands [{fontdef & fStyles = ["Underline": fontdef.fStyles]}: [fontdef: fontdefs]] colours bgcolours no_leading_spaces state
		check_commands [CmEndUnderline: commands] fontdefs colours bgcolours no_leading_spaces state
			# fontdefs				= if (length fontdefs < 2) fontdefs (tl fontdefs)
			= check_commands commands fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmSize size: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands [{fontdef & fSize = size}: [fontdef: fontdefs]] colours bgcolours no_leading_spaces state
		check_commands [CmChangeSize size: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands [{fontdef & fSize = fontdef.fSize + size}: [fontdef: fontdefs]] colours bgcolours no_leading_spaces state
		check_commands [CmEndSize: commands] fontdefs colours bgcolours no_leading_spaces state
			# fontdefs				= if (length fontdefs < 2) fontdefs (tl fontdefs)
			= check_commands commands fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmColour colour: commands] fontdefs colours bgcolours no_leading_spaces state
			= check_commands commands fontdefs [colour: colours] bgcolours no_leading_spaces state
		check_commands [CmEndColour: commands] fontdefs [colour: colours] bgcolours no_leading_spaces state
			= check_commands commands fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmBackgroundColour bgcolour: commands] fontdefs colours bgcolours no_leading_spaces state
			= check_commands commands fontdefs colours [bgcolour: bgcolours] no_leading_spaces state
		check_commands [CmEndBackgroundColour: commands] fontdefs colours [bgcolour: bgcolours] no_leading_spaces state
			= check_commands commands fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmFont newfontdef: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands [newfontdef: [fontdef: fontdefs]] colours bgcolours no_leading_spaces state
		check_commands [CmEndFont: commands] fontdefs colours bgcolours no_leading_spaces state
			# fontdefs				= if (length fontdefs < 2) fontdefs (tl fontdefs)
			= check_commands commands fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmFontFace face: commands] [fontdef:fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands [{fontdef & fName = face}: [fontdef: fontdefs]] colours bgcolours no_leading_spaces state
		check_commands [CmEndFontFace: commands]  fontdefs colours bgcolours no_leading_spaces state
			# fontdefs				= if (length fontdefs < 2) fontdefs (tl fontdefs)
			= check_commands commands fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmLink text value: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			# (n_underline, n_colour, n_bgcolour, s_underline, s_colour, s_bgcolour)
									= hd mstate.mulLinkStyles
			# (commands, state)		= check_commands commands [fontdef: fontdefs] colours bgcolours False state
			# normal_fontdef		= if n_underline {fontdef & fStyles = ["Underline": fontdef.fStyles]} fontdef
			# selected_fontdef		= if s_underline {fontdef & fStyles = ["Underline": fontdef.fStyles]} fontdef
			# ((_, n_font), state)	= openFont normal_fontdef state
			# ((_, s_font), state)	= openFont selected_fontdef state
			# (metrics, state)		= case mulFixedMetrics of
										(Just metrics)	-> (metrics, state)
										Nothing			-> getFontMetrics n_font state
			# (width, state)		= getFontStringWidth n_font text state
			# cm_link				= Cm_Link text value metrics width (n_font, n_colour, n_bgcolour)
															 		   (s_font, s_colour, s_bgcolour)
			= ([cm_link: commands], state)
		check_commands [CmLink2 num text value: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			# (n_underline, n_colour, n_bgcolour, s_underline, s_colour, s_bgcolour)
									= mstate.mulLinkStyles !! num
			# (commands, state)		= check_commands commands [fontdef: fontdefs] colours bgcolours False state
			# normal_fontdef		= if n_underline {fontdef & fStyles = ["Underline": fontdef.fStyles]} fontdef
			# selected_fontdef		= if s_underline {fontdef & fStyles = ["Underline": fontdef.fStyles]} fontdef
			# ((_, n_font), state)	= openFont normal_fontdef state
			# ((_, s_font), state)	= openFont selected_fontdef state
			# (metrics, state)		= case mulFixedMetrics of
										(Just metrics)	-> (metrics, state)
										Nothing			-> getFontMetrics n_font state
			# (width, state)		= getFontStringWidth n_font text state
			# cm_link				= Cm_Link text value metrics width (n_font, n_colour, n_bgcolour)
															 		   (s_font, s_colour, s_bgcolour)
			= ([cm_link: commands], state)
		check_commands [other: commands] fontdefs colours bgcolours no_leading_spaces state
			# (commands, state) 		= check_commands commands fontdefs colours bgcolours no_leading_spaces state
			= ([other: commands], state)
		check_commands [] _ _ _ _ state
			= ([], state)

// -----------------------------------------------------------------------------------------------------------------------
computeMetrics :: (!MarkUpLocalState a (*PSt .ps)) -> !MarkUpLocalState a (*PSt .ps)
// -----------------------------------------------------------------------------------------------------------------------
computeMetrics mstate
	# (baselines, skips)				= compute_metrics (0, 0) mstate.mulCommands
	= {mstate & mulBaselines = baselines, mulSkips = skips}
	where
		compute_metrics (baseline, skip) [Cm_Word word font metrics width colour bgcolour: commands]
//			| ignore_font				= compute_metrics (baseline, skip) commands
			# new_baseline				= metrics.fAscent + metrics.fLeading
			# new_skip					= metrics.fDescent
//			# new_baseline				= if (mulOverrideLineHeight >= 0 && new_baseline + new_skip > mulOverrideLineHeight)
//											(mulOverrideLineHeight - new_skip)
//											new_baseline
//			# new_skip					= if (new_baseline + new_skip < mulOverrideLineHeight)
//											(mulOverrideLineHeight - new_baseline)
//											new_skip
 			# new_total					= new_baseline + new_skip
			# old_total					= baseline + skip
			| old_total < new_total		= compute_metrics (new_baseline, new_skip) commands
			= compute_metrics (baseline, skip) commands
		compute_metrics (baseline, skip) [Cm_Link _ _ metrics width _ _: commands]
			# new_baseline				= metrics.fAscent + metrics.fLeading
			# new_skip					= metrics.fDescent
			# new_total					= new_baseline + new_skip
			# old_total					= baseline + skip
			| old_total < new_total		= compute_metrics (new_baseline, new_skip) commands
			= compute_metrics (baseline, skip) commands
		compute_metrics (baseline, skip) [CmNewlineI ignore extra_skip mb_colour: commands]
			# (baselines, skips)		= compute_metrics (0, 0) commands
			= ([baseline: baselines], [skip: skips])
		compute_metrics (baseline, skip) [other: commands]
			= compute_metrics (baseline, skip) commands
		compute_metrics (baseline, skip) []
			= ([baseline], [skip])

// -----------------------------------------------------------------------------------------------------------------------
getAlignConstraints :: (!MarkUpLocalState a (*PSt .ps)) -> !MarkUpLocalState a (*PSt .ps)
// -----------------------------------------------------------------------------------------------------------------------
getAlignConstraints mstate
	# scopes		= check_aligns [0] 1 mstate.mulScopes (RX_Align 0 "_START_" 0) mstate.mulCommands
	= {mstate & mulScopes = scopes}
	where
		check_aligns scope_stack next_scope scopes relx [Cm_Word _ _ _ width _ _: commands]
			= check_aligns scope_stack next_scope scopes (relx +~ width) commands
		check_aligns scope_stack next_scope scopes relx [Cm_Link _ _ _ width _ _: commands]
			= check_aligns scope_stack next_scope scopes (relx +~ width) commands
		check_aligns scope_stack next_scope scopes relx [Cm_HorSpace width _: commands]
			# width						= if (width == (-1)) 0 width
			= check_aligns scope_stack next_scope scopes (relx +~ width) commands
		check_aligns scope_stack next_scope scopes relx [CmScope: commands]
			# scopes					= scopes ++ [[]]
			# scopes					= addConstraint next_scope "_START_" relx scopes
			= check_aligns [next_scope: scope_stack] (next_scope+1) scopes (RX_Align next_scope "_START_" 0) commands
		check_aligns scope_stack next_scope scopes relx [CmEndScope: commands]
			= check_aligns (tl scope_stack) next_scope scopes relx commands
		check_aligns scope_stack next_scope scopes relx [CmNewlineI ignore extra_skip mb_colour: commands]
			= check_aligns scope_stack next_scope scopes (RX_Align (hd scope_stack) "_START_" 0) commands
		check_aligns scope_stack next_scope scopes relx [CmStartOfLine: commands]
			= check_aligns scope_stack next_scope scopes (RX_Align (hd scope_stack) "_START_" 0) commands
		check_aligns scope_stack next_scope scopes relx [CmAlignI align clr: commands]
			# scopes					= addConstraint (hd scope_stack) align relx scopes
			= check_aligns scope_stack next_scope scopes (RX_Align (hd scope_stack) align 0) commands
		check_aligns scope_stack next_scope scopes relx [CmBGRight bgcolour: commands]
			= check_aligns scope_stack next_scope scopes relx commands
		check_aligns scope_stack next_scope scopes relx [CmBGCenter bgcolour: commands]
			= check_aligns scope_stack next_scope scopes relx commands
		check_aligns scope_stack next_scope scopes relx [CmLabel label base: commands]
			= check_aligns scope_stack next_scope scopes relx commands
		check_aligns scope_stack next_scope scopes relx [CmId _: commands]
			= check_aligns scope_stack next_scope scopes relx commands
		check_aligns scope_stack next_scope scopes relx [CmTextId _: commands]
			= check_aligns scope_stack next_scope scopes relx commands
		check_aligns scope_stack next_scope scopes relx [CmEndId: commands]
			= check_aligns scope_stack next_scope scopes relx commands
		check_aligns _ _ scopes _ []
			= scopes
		check_aligns _ _ _ _ [other: rest]
			#! text				= "" ->> other
			= abort (text +++ "check_aligns in module MarkUpText: found a MarkUpCommand which should have been filtered")

// -----------------------------------------------------------------------------------------------------------------------
solveAlignConstraints :: (!MarkUpLocalState a (*PSt .ps)) -> !MarkUpLocalState a (*PSt .ps)
// -----------------------------------------------------------------------------------------------------------------------
solveAlignConstraints mstate
	# (changed, scopes)				= solveScopes mstate.mulScopes
	# mstate						= {mstate & mulScopes = scopes}
	| not changed					= mstate
	| otherwise						= solveAlignConstraints mstate
	where
		// ------------------------------------------
		solveScopes :: ![Scope] -> (!Bool, ![Scope])
		// ------------------------------------------
		solveScopes scopes
			# (scopes, finished)	= collect_finished_aligns_in_scope 0 scopes
			| isEmpty finished		= (False, scopes)
			# scopes				= change_all finished scopes
			= (True, scopes)
		
		// --------------------------------------------------------
		change_all :: [(!Int, !String, !Int)] ![Scope] -> ![Scope]
		// --------------------------------------------------------
		change_all [(scope, align, absx): changes] scopes
			# scopes					= replaceRelativeConstraint scopes scope align absx
			= change_all changes scopes
		change_all [] scopes
			= scopes
		
		// --------------------------------------------------------------------------------------
		collect_finished_aligns_in_scope :: !Int ![Scope] -> (![Scope], [(!Int, !String, !Int)])
		// --------------------------------------------------------------------------------------
		collect_finished_aligns_in_scope num [scope: scopes]
			# (scope, finished1)		= collect_finished_aligns num scope
			# (scopes, finished2)		= collect_finished_aligns_in_scope (num+1) scopes
			= ([scope: scopes], finished1 ++ finished2)
		collect_finished_aligns_in_scope num []
			= ([], [])
		
		// -------------------------------------------------------------------------------------
		collect_finished_aligns :: !Int ![AlignInfo] -> (![AlignInfo], [(!Int, !String, !Int)])
		// -------------------------------------------------------------------------------------
		collect_finished_aligns num [align: aligns]
			# (aligns, finished)		= collect_finished_aligns num aligns
			| isEmpty align.aliRelativeX= ([align: aligns], finished)
			# absx						= compute_abs_x 0 align.aliRelativeX
			| absx < 0					= ([align: aligns], finished)
			# align						= {align & aliRelativeX = [], aliAbsoluteX = absx}
			= ([align: aligns], [(num, align.aliName, absx): finished])
		collect_finished_aligns num []
			= ([], [])
		
		// ----------------------------------------
		compute_abs_x :: !Int ![RelativeX] -> !Int
		// ----------------------------------------
		compute_abs_x sofar [RX_Solved x: rest]		= compute_abs_x (max sofar x) rest
		compute_abs_x sofar [RX_Align _ _ _: rest]	= (-1)
		compute_abs_x sofar []						= sofar

// -----------------------------------------------------------------------------------------------------------------------
removeCmCenterRight :: (!MarkUpLocalState a (*PSt .p)) -> !MarkUpLocalState a (*PSt .p)
// -----------------------------------------------------------------------------------------------------------------------
removeCmCenterRight mstate
	= {mstate & mulCommands = remove_cms 0 [0] 1 mstate.mulCommands}
	where
		// ---------------------------------------------------------------------
		remove_cms :: !Int ![Int] !Int ![MarkUpCommand a] -> ![MarkUpCommand a]
		// ---------------------------------------------------------------------
		remove_cms x scopes free_scope [command=:(Cm_Word _ _ _ width _ _): commands]
			= [command: remove_cms (x+width) scopes free_scope commands]
		remove_cms x scopes free_scope [command=:(Cm_Link _ _ _ width _ _): commands]
			= [command: remove_cms (x+width) scopes free_scope commands]
		remove_cms x scopes free_scope [command=:(Cm_HorSpace width _): commands]
			= [command: remove_cms (x+width) scopes free_scope commands]
		remove_cms x scopes free_scope [command=:CmScope: commands]
			= [command: remove_cms x [free_scope: scopes] (free_scope+1) commands]
		remove_cms x scopes free_scope [command=:CmEndScope: commands]
			= [command: remove_cms x (tl scopes) free_scope commands]
		remove_cms x scopes free_scope [command=:CmNewlineI ignore extra_skip mb_colour: commands]
			# x											= getAbsoluteConstraint mstate.mulScopes (hd scopes) "_START_"
			= [command: remove_cms x scopes free_scope commands]
		remove_cms x scopes free_scope [command=:CmStartOfLine: commands]
			# x											= getAbsoluteConstraint mstate.mulScopes (hd scopes) "_START_"
			= [command: remove_cms x scopes free_scope commands]
		remove_cms x scopes free_scope [command=:CmAlignI name clr: commands]
			# newx			= getAbsoluteConstraint mstate.mulScopes (hd scopes) name
			= [command: remove_cms newx scopes free_scope commands]
		remove_cms x scopes free_scope [command=:(CmBGRight bgcolour): commands]
			# (width, finalx, _, _)						= get_width_to_align (hd scopes) 0 commands
			| finalx < 0								= remove_cms x scopes free_scope commands
			# newx										= finalx - width
			# skipx										= newx - x
			# space_cmd									= Cm_HorSpace skipx bgcolour
			# commands									= [space_cmd: commands]
			= remove_cms x scopes free_scope commands
		remove_cms x scopes free_scope [command=:(CmBGCenter bgcolour): commands]
			# (width, finalx, commands1, commands2)		= get_width_to_align (hd scopes) 0 commands
			| finalx < 0								= remove_cms x scopes free_scope commands
			# skipx1									= ((finalx - x) - width) / 2
			# space_cmd1								= Cm_HorSpace skipx1 bgcolour
			# skipx2									= ((finalx - x) - width) - skipx1
			# space_cmd2								= Cm_HorSpace skipx2 bgcolour
			# commands									= [space_cmd1: commands1] ++ [space_cmd2: commands2]
			= remove_cms x scopes free_scope commands
		remove_cms x scopes free_scope [CmLabel label base: commands]
			= [CmLabel label base: remove_cms x scopes free_scope commands]
		remove_cms x scopes free_scope [CmId a: commands]
			= [CmId a: remove_cms x scopes free_scope commands]
		remove_cms x scopes free_scope [CmTextId a: commands]
			= [CmTextId a: remove_cms x scopes free_scope commands]
		remove_cms x scopes free_scope [CmEndId: commands]
			= [CmEndId: remove_cms x scopes free_scope commands]
		remove_cms x scopes free_scope []
			= []
		
		// --------------------------------------------------------------------------------------------------------
		get_width_to_align :: !Int !Int ![MarkUpCommand a] -> (!Int, !Int, ![MarkUpCommand a], ![MarkUpCommand a])
		// --------------------------------------------------------------------------------------------------------
		get_width_to_align scope width [command=:(Cm_Word _ _ _ wordwidth _ _): commands]
			# (width, finalx, commands1, commands2)		= get_width_to_align scope (width+wordwidth) commands
			= (width, finalx, [command: commands1], commands2)
		get_width_to_align scope width [command=:(Cm_Link _ _ _ linkwidth _ _): commands]
			# (width, finalx, commands1, commands2)		= get_width_to_align scope (width+linkwidth) commands
			= (width, finalx, [command: commands1], commands2)
		get_width_to_align scope width [command=:(Cm_HorSpace spacewidth _): commands]
			# (width, finalx, commands1, commands2)		= get_width_to_align scope (width+spacewidth) commands
			= (width, finalx, [command: commands1], commands2)
		get_width_to_align scope width [command=:(CmAlignI name clr): commands]
			# finalx									= getAbsoluteConstraint mstate.mulScopes scope name
			= (width, finalx, [], [command: commands])
		get_width_to_align scope width [command=:CmNewlineI ignore extra_skip mb_colour: commands]
			| mstate.mulWidth == 0						= (-1, -1, [], [])
			= (width, mstate.mulWidth, [], [command: commands])
		get_width_to_align scope width [command=:CmStartOfLine: commands]
			| mstate.mulWidth == 0						= (-1, -1, [], [])
			= (width, mstate.mulWidth, [], [command: commands])
		get_width_to_align scope width [other: commands]
			= (-1, -1, [], [])
		get_width_to_align scope width []
			| mstate.mulWidth == 0						= (-1, -1, [], [])
			= (width, mstate.mulWidth, [], [])

// -----------------------------------------------------------------------------------------------------------------------
makeDrawFunctions :: !Font (!MarkUpLocalState a (*PSt .p)) -> !MarkUpLocalState a (*PSt .p)
// -----------------------------------------------------------------------------------------------------------------------
makeDrawFunctions dummy_font mstate
	# (drawfuns, highlightdrawfuns, labels)	= walk_through S_NoId mstate.mulBaselines mstate.mulSkips [0] 1 0 zero mstate.mulCommands 0
	# drawfuns								= optimizeSmartDrawAreas drawfuns
	# mstate								= {mstate & mulDrawFunctions = drawfuns, mulHighlightDrawFunctions = highlightdrawfuns, mulLabels = labels}
	= mstate
	where
		walk_through :: !(SmartId c) ![Int] ![Int] ![Int] !Int !Int !Point2 ![MarkUpCommand c] !Int 
					 -> (![SmartDrawArea c],![(c,SmartDrawArea c)], [(!String, !Int, !Int)])
		walk_through smart_id [baseline: baselines] [skip: skips] scopestack nextscope line point=:{x, y} [CmNewlineI ignore extra_skip Nothing: rest] num
			# x								= getAbsoluteConstraint mstate.mulScopes (hd scopestack) "_START_"
			# y								= y + baseline + skip + extra_skip
			= walk_through smart_id baselines skips scopestack nextscope (line+1) {x=x, y=y} rest num
		walk_through smart_id [baseline: baselines] [skip: skips] scopestack nextscope line point=:{x, y} [CmNewlineI ignore extra_skip (Just colour): rest] num
			# x								= getAbsoluteConstraint mstate.mulScopes (hd scopestack) "_START_"
			# between_lines_draw			=	{ smartRectangle		= {corner1={x=0,y=y+baseline+skip+1}, corner2={x=10000,y=y+baseline+skip+extra_skip+1}}
												, smartJustBG			= True
												, smartColour			= toRGBColour Black
												, smartBGColour			= toRGBColour colour
												, smartFont				= dummy_font
												, smartFontDef			= {fName = "Dummy", fSize = 10, fStyles = []}
												, smartDraw				= \x -> x
												, smartDrawText			= ""
												, smartKey				= num
												, smartId				= smart_id
												}
			# y								= y + baseline + skip + extra_skip
			# (normals, highlights, labels)	= walk_through smart_id baselines skips scopestack nextscope (line+1) {x=x, y=y} rest (num+1)
			= ([between_lines_draw: normals], highlights, labels)
		walk_through smart_id baselines skips scopestack nextscope line point=:{x,y} [CmStartOfLine: rest] num
			# x								= getAbsoluteConstraint mstate.mulScopes (hd scopestack) "_START_"
			= walk_through smart_id baselines skips scopestack nextscope line {x=x, y=y} rest num
		walk_through smart_id baselines skips scopestack nextscope line point=:{x,y} [CmScope: rest] num
			# scopestack					= [nextscope: scopestack]
			= walk_through smart_id baselines skips scopestack (nextscope+1) line point rest num
		walk_through smart_id baselines skips scopestack nextscope line point=:{x,y} [CmEndScope: rest] num
			= walk_through smart_id baselines skips (tl scopestack) nextscope line point rest num
		walk_through smart_id [baseline:baselines] [skip:skips] scopestack nextscope line point=:{x,y} [CmAlignI name colour: rest] num
			# new_x							= getAbsoluteConstraint mstate.mulScopes (hd scopestack) name
			# rectangle						= {corner1 = {x=x, y=y+1}, corner2 = {x=new_x, y=y+baseline+skip+1}}
			# smart_draw					=	{ smartRectangle		= rectangle
												, smartJustBG			= True
												, smartColour			= toRGBColour Black
												, smartBGColour			= toRGBColour colour
												, smartFont				= dummy_font
												, smartFontDef			= {fName = "Dummy", fSize = 10, fStyles = []}
												, smartDraw				= \x -> x
												, smartDrawText			= ""
												, smartKey				= num
												, smartId				= smart_id
												}
			# (normals, highlights, labels)	= walk_through smart_id [baseline: baselines] [skip: skips] scopestack nextscope line {x=new_x,y=y} rest (num+1)
			= ([smart_draw:normals], highlights, labels)
		walk_through smart_id [baseline: baselines] [skip: skips] scopestack nextscope line point=:{x,y} [Cm_Word word font metrics width colour bgcolour: rest] num
			# rectangle						= case ignore rest of
												True	-> {corner1 = {x=x,y=y+1}, corner2 = {x=10000, y=y+baseline+skip+1}}
												False	-> {corner1 = {x=x,y=y+1}, corner2 = {x=x+width, y=y+baseline+skip+1}}
			# smart_draw					=	{ smartRectangle		= rectangle
												, smartJustBG			= False
												, smartColour			= toRGBColour colour
												, smartBGColour			= toRGBColour bgcolour
												, smartFont				= font
												, smartFontDef			= getFontDef font
												, smartDraw				= drawAt {x=x, y=y+baseline} word
												, smartDrawText			= word
												, smartKey				= num
												, smartId				= smart_id
												}
			# (normals, highlights, labels)	= walk_through smart_id [baseline: baselines] [skip: skips] scopestack nextscope line {x=x+width,y=y} rest (num+1)
			= ([smart_draw: normals], highlights, labels)
			where
				ignore :: ![MarkUpCommand .e] -> !Bool
				ignore [CmNewlineI True extra_skip _:_]	= True
				ignore _								= False
		walk_through smart_id [baseline: baselines] [skip: skips] scopestack nextscope line point=:{x,y} [Cm_Link word value _ width (font1, colour1, bgcolour1) (font2, colour2, bgcolour2): rest] num
			# rectangle						= {corner1 = {x=x, y=y+1}, corner2 = {x=x+width, y=y+baseline+skip+1}}
			# smart_drawnormal				=	{ smartRectangle		= rectangle
												, smartJustBG			= False
												, smartColour			= toRGBColour colour1
												, smartBGColour			= toRGBColour bgcolour1
												, smartFont				= font1
												, smartFontDef			= getFontDef font1
												, smartDraw				= drawAt {x=x,y=y+baseline} word
												, smartDrawText			= word
												, smartKey				= num
												, smartId				= smart_id
												}
			# smart_drawselected			=	{ smartRectangle		= rectangle
												, smartJustBG			= False
												, smartColour			= toRGBColour colour2
												, smartBGColour			= toRGBColour bgcolour2
												, smartFont				= font2
												, smartFontDef			= getFontDef font2
												, smartDraw				= drawAt {x=x,y=y+baseline} word
												, smartDrawText			= word
												, smartKey				= num
												, smartId				= smart_id
												}
			# (normals, highlights, labels)	= walk_through smart_id [baseline: baselines] [skip: skips] scopestack nextscope line {x=x+width,y=y} rest (num+1)
			= ([smart_drawnormal: normals], [(value, smart_drawselected): highlights], labels)
		walk_through smart_id [baseline: baselines] [skip: skips] scopestack nextscope line point=:{x,y} [Cm_HorSpace width colour: rest] num
			# rectangle						= {corner1 = {x=x, y=y+1}, corner2 = {x=x+width, y=y+baseline+skip+1}}
			# fill_rectangle				= if (width >= 0) rectangle {rectangle & corner2.x = 10000}
			# smart_draw					=	{ smartRectangle		= fill_rectangle
												, smartJustBG			= True
												, smartColour			= toRGBColour Black
												, smartBGColour			= toRGBColour colour
												, smartFont				= dummy_font
												, smartFontDef			= {fName = "Dummy", fSize = 10, fStyles = []}
												, smartDraw				= \x -> x
												, smartDrawText			= ""
												, smartKey				= num
												, smartId				= smart_id
												}
			# (normals, highlights, labels)	= walk_through smart_id [baseline: baselines] [skip: skips] scopestack nextscope line {x=x+width,y=y} rest (num+1)
			= ([smart_draw:normals], highlights, labels)
		walk_through smart_id [baseline:baselines] skips scopestack nextscope line point=:{x,y} [CmLabel label base: rest] num
			# (normals, highlights, labels)	= walk_through smart_id [baseline:baselines] skips scopestack nextscope line point rest num
			# use_y							= if base (y+baseline) y
			= (normals, highlights, [(label,x,use_y): labels])
		walk_through smart_id baselines skips scopestack nextscope line point=:{x,y} [CmId a: rest] num
			= walk_through (S_LinkId a) baselines skips scopestack nextscope line point rest num
		walk_through smart_id baselines skips scopestack nextscope line point=:{x,y} [CmTextId text: rest] num
			= walk_through (S_TextId text) baselines skips scopestack nextscope line point rest num
		walk_through smart_id baselines skips scopestack nextscope line point=:{x,y} [CmEndId: rest] num
			= walk_through S_NoId baselines skips scopestack nextscope line point rest num
		walk_through smart_id baselines skips scopestack nextscope line point=:{x,y} [other: rest] num
			= walk_through smart_id baselines skips scopestack nextscope line point rest num
		walk_through smart_id baselines skips scopestack nextscope line point=:{x,y} [] num
			= ([], [], [])

// =======================================================================================================================
// For each CmFillLine a Cm_HorSpace with a negative width is created. This leads to an invalid rectangle. 
// These are corrected here, using the computed width of the control.
// -----------------------------------------------------------------------------------------------------------------------
replaceInvalidDrawFunctions :: !Int !(MarkUpLocalState a .ps) -> !MarkUpLocalState a .ps
// -----------------------------------------------------------------------------------------------------------------------
replaceInvalidDrawFunctions goodwidth mstate
	= {mstate & mulDrawFunctions = replace_drawfunctions goodwidth mstate.mulDrawFunctions}
	where
		replace_drawfunctions goodwidth [area:areas]
			# rect			= area.smartRectangle
			# rect			= if (rect.corner2.x >= rect.corner1.x) rect {rect & corner2.x = goodwidth}
			# area			= {area & smartRectangle = rect}
			= [area: replace_drawfunctions goodwidth areas]
		replace_drawfunctions _ []
			= []

// =======================================================================================================================
// Sorts the draw areas, such that texts in the same font will be drawn consecutively.
// -----------------------------------------------------------------------------------------------------------------------
optimizeSmartDrawAreas :: ![SmartDrawArea a] -> [SmartDrawArea a]
// -----------------------------------------------------------------------------------------------------------------------
optimizeSmartDrawAreas areas
	= sortBy smaller_area areas
	where
		smaller_area :: !(SmartDrawArea a) !(SmartDrawArea a) -> Bool
		smaller_area area1 area2
			| area1.smartJustBG			= True
			| area2.smartJustBG			= False
			# fonts_compared			= compare_fonts area1.smartFontDef area2.smartFontDef
			| fonts_compared == 0		= True
			| fonts_compared == 2		= False
			# colours_compared			= compare_colours area1.smartColour area2.smartColour
			| colours_compared == 0		= True
			| colours_compared == 2		= False
			= True
		
		compare_fonts :: !FontDef !FontDef -> Int
		compare_fonts f1 f2
			| f1.fName < f2.fName		= 0
			| f1.fName > f2.fName		= 2
			| f1.fSize < f2.fSize		= 0
			| f1.fSize > f2.fSize		= 2
			# w1						= style_weight f1.fStyles
			# w2						= style_weight f2.fStyles
			| w1 < w2					= 0
			| w1 > w2					= 2
			= 1
		
		style_weight :: ![String] -> Int
		style_weight ["Bold":styles]
			= style_weight styles + 1
		style_weight ["Italic":styles]
			= style_weight styles + 2
		style_weight ["Underline":styles]
			= style_weight styles + 4
		style_weight []
			= 0
		
		compare_colours :: !RGBColour !RGBColour -> Int
		compare_colours {r=r1,g=g1,b=b1} {r=r2,g=g2,b=b2}
			| r1 < r2					= 0
			| r1 > r2					= 2
			| g1 < g2					= 0
			| g1 > g2					= 2
			| b1 < b2					= 0
			| b1 > b2					= 2
			= 1

// -----------------------------------------------------------------------------------------------------------------------
setDefaultLabels :: !Rectangle !Size !(MarkUpLocalState a .ps) -> !MarkUpLocalState a .ps
// -----------------------------------------------------------------------------------------------------------------------
setDefaultLabels viewdomain viewsize mstate=:{mulLabels}
	= {mstate & mulLabels =	[ ("@LeftTop",0,0)
							, ("@RightTop",viewdomain.corner2.x,0)
							, ("@LeftBottom",0,viewdomain.corner2.y)
							, ("@RightBottom",viewdomain.corner2.x,viewdomain.corner2.y)
							, ("@LastScreen",0,viewdomain.corner2.y-viewsize.h)
							: mulLabels
							]}

// -----------------------------------------------------------------------------------------------------------------------
getArea :: !Point2 (!MarkUpLocalState a .ps) -> (!Int, !Maybe (a, SmartDrawArea a))
// -----------------------------------------------------------------------------------------------------------------------
getArea point {mulHighlightDrawFunctions}
	= get_area point mulHighlightDrawFunctions
	where
		get_area point [(value, area): rest]
			# rect								= area.smartRectangle
			| inRectangle point rect			= (area.smartKey, Just (value, area))
			= get_area point rest
		get_area point []
			= (-1, Nothing)

// -----------------------------------------------------------------------------------------------------------------------
findIndex :: !Int ![(a, SmartDrawArea a)] -> !Int
// -----------------------------------------------------------------------------------------------------------------------
findIndex i draw_funs
	= find i 0 draw_funs
	where
		find :: !Int !Int ![(a, SmartDrawArea a)] -> !Int
		find i1 index [(_, area):rest]
			# i2						= area.smartKey
			| i1 == i2					= index
			= find i1 (index+1) rest
		find i1 index []
			= -1

// Warning: partial function
// -----------------------------------------------------------------------------------------------------------------------
findDrawFun :: !Int ![SmartDrawArea a] -> (SmartDrawArea a)
// -----------------------------------------------------------------------------------------------------------------------
findDrawFun key [area:areas]
	| area.smartKey == key				= area
	= findDrawFun key areas

// -----------------------------------------------------------------------------------------------------------------------
updateLookFun :: !Bool !Id ![SmartDrawArea a] !Colour ![SmartDrawArea a] (*PSt .ps) -> *PSt .ps
// -----------------------------------------------------------------------------------------------------------------------
updateLookFun True controlid areas colour newlook state
	# state						= appPIO (appControlPicture controlid (ImmediateDraw areas)) state
	# state						= appPIO (setControlLook controlid False (False, DrawSmartAreas newlook (toRGBColour colour))) state
	= state
updateLookFun False windowid areas colour newlook state
	# state						= appPIO (appWindowPicture windowid (ImmediateDraw areas)) state
	# state						= appPIO (setWindowLook windowid False (True, DrawSmartAreas newlook (toRGBColour colour))) state
	= state

// -----------------------------------------------------------------------------------------------------------------------
KeyboardFunction :: !(KeyboardState -> *(PSt .ps) -> *(PSt .ps)) KeyboardState (MarkUpLocalState a *(PSt .ps), *(PSt .ps)) -> (MarkUpLocalState a *(PSt .ps), *PSt .ps)
// -----------------------------------------------------------------------------------------------------------------------
KeyboardFunction def_action (CharKey 'P' (KeyDown _)) (mstate, state)
	# lookFunction				= DrawSmartAreas mstate.mulDrawFunctions (toRGBColour mstate.mulInitialBackgroundColour) Able
	# (printsetup, state)		= defaultPrintSetup state
	# size						= mstate.mulViewDomain
	# (printsetup, state)		= printUpdateFunction True lookFunction [size] printsetup state
	= (mstate, state)
// matching on 'KeyDown True'; seems to be bug in Object I/O (generates two events for one keydown)
KeyboardFunction def_action k=:(SpecialKey key (KeyDown True) modifiers) (mstate, pstate)
	| key == downKey			= sliderVertical SliderIncSmall (mstate, pstate)
	| key == upKey				= sliderVertical SliderDecSmall (mstate, pstate)
	| key == leftKey			= sliderHorizontal SliderDecSmall (mstate, pstate)
	| key == rightKey			= sliderHorizontal SliderIncSmall (mstate, pstate)
	= (mstate, def_action k pstate)
KeyboardFunction def_action other (mstate, state)
	= (mstate, def_action other state)

// -----------------------------------------------------------------------------------------------------------------------
// The type between comments (extra * before second arguments) is correct, but causes incorrect code
// when 'reuse unique nodes' is on.
//MouseFunction :: .MouseState *(.MarkUpLocalState a *(PSt .b),*PSt .b) -> *(MarkUpLocalState a *(PSt .b),*PSt .b)
MouseFunction :: .MouseState /* * */(.MarkUpLocalState a *(PSt .b),*PSt .b) -> *(MarkUpLocalState a *(PSt .b),*PSt .b)
// -----------------------------------------------------------------------------------------------------------------------
MouseFunction (MouseMove point modifiers) (mstate=:{mulIsControl, mulId, mulReceiverId, mulActiveLink, mulDrawFunctions, mulInitialBackgroundColour}, state)
	// HACK -- if activeWindow is in another process (getActiveWindow will fail then), no window update should be made
	# (mb_active_id, state)				= accPIO getActiveWindow state
	| isNothing mb_active_id			= (mstate, state)
	// END HACK
	# stupid_event						= point == mstate.mulPreviousMouseMove
	| stupid_event						= (mstate, state)
	# mstate							= {mstate & mulPreviousMouseMove = point}
	# (area, mb_highlight)				= getArea point mstate
	| area == mulActiveLink				= (mstate, state)
	# mstate							= {mstate & mulActiveLink = area}
	# old_normdrawfun					= findDrawFun mulActiveLink mulDrawFunctions
	| isNothing mb_highlight			= (mstate, updateLookFun mulIsControl mulId [old_normdrawfun] mulInitialBackgroundColour mulDrawFunctions state)
	# (value, seldrawfun)				= fromJust mb_highlight
	# new_draws							= [seldrawfun: [smart_area \\ smart_area <- mulDrawFunctions | smart_area.smartKey <> area]]
	# direct_update						= if (mulActiveLink == (-1)) [seldrawfun] [seldrawfun, old_normdrawfun]
	# state								= updateLookFun mulIsControl mulId direct_update mulInitialBackgroundColour new_draws state
	# event								=	{ meSelectEvent			= True
											, meClickEvent			= False
											, meNrClicks			= 0
											, meLink				= value
											, meLinkIndex			= Just (findIndex area mstate.mulHighlightDrawFunctions)
											, meOwnRId				= mulReceiverId
											, meModifiers			= Just modifiers
											}
	# state								= mstate.mulEventHandler event state
	= (mstate, state)
MouseFunction (MouseUp point modifiers) (mstate=:{mulIsControl, mulId, mulReceiverId, mulInitialBackgroundColour, mulDrawFunctions, mulSpecialClick}, state)
	| isJust mstate.mulSpecialClick		= (mstate, snd (fromJust mstate.mulSpecialClick) state)
	| mstate.mulActiveLink == (-1)		= (mstate, state)
	# values							= [value \\ (value,area) <- mstate.mulHighlightDrawFunctions | area.smartKey == mstate.mulActiveLink]
	| isEmpty values					= (mstate, state)
	# old_normdrawfun					= findDrawFun mstate.mulActiveLink mulDrawFunctions
	# state								= updateLookFun mulIsControl mulId [old_normdrawfun] mulInitialBackgroundColour mulDrawFunctions state
	# event								=	{ meSelectEvent			= False
											, meClickEvent			= True
											, meNrClicks			= 1 // nr_clicks
											, meLink				= hd values
											, meLinkIndex			= Just (findIndex mstate.mulActiveLink mstate.mulHighlightDrawFunctions)
											, meOwnRId				= mulReceiverId
											, meModifiers			= Just modifiers
											}
	# mstate							= {mstate & mulActiveLink = -1}
	# state								= mstate.mulEventHandler event state
	= (mstate, state)
MouseFunction (MouseDown point modifiers nr_clicks) (mstate=:{mulSpecialClick}, state)
	| isJust mstate.mulSpecialClick		= (mstate, fst (fromJust mstate.mulSpecialClick) state)
	= (mstate, state)
MouseFunction other (mstate, state)
	= (mstate, state)

// -----------------------------------------------------------------------------------------------------------------------
sliderHorizontal :: !SliderMove (.MarkUpLocalState a *(PSt .b),*PSt .b) -> *(MarkUpLocalState a *(PSt .b),*PSt .b)
// -----------------------------------------------------------------------------------------------------------------------
sliderHorizontal slidermove (mstate, state)
	# (mb_wstate, state)			= accPIO (getParentWindow mstate.mulId) state
	| isNothing mb_wstate			= (mstate, state)
	# wstate						= fromJust mb_wstate
	# (ok, mb_viewframe)			= getControlViewFrame mstate.mulId wstate
	| not ok						= (mstate, state)
	| isNothing mb_viewframe		= (mstate, state)
	# viewframe						= fromJust mb_viewframe
	# (ok, mb_viewdomain)			= getControlViewDomain mstate.mulId wstate
	| not ok						= (mstate, state)
	| isNothing mb_viewdomain		= (mstate, state)
	# viewdomain					= fromJust mb_viewdomain
	# (ok, viewsize)				= getControlViewSize mstate.mulId wstate
	| not ok						= (mstate, state)
	# (ok, mb_sliderstate)			= getSliderState (fst mstate.mulScrollIds) wstate
	| not ok						= (mstate, state)
	| isNothing mb_sliderstate		= (mstate, state)
	# sliderstate					= fromJust mb_sliderstate
	# new_thumb						= compute_thumb slidermove sliderstate.sliderThumb 10 viewframe
	# state							= appPIO (setSliderThumb (fst mstate.mulScrollIds) new_thumb) state
	# state							= appPIO (moveControlViewFrame mstate.mulId {vx=new_thumb-viewframe.corner1.x,vy=0}) state
	= (mstate, state)
	where
		compute_thumb :: !SliderMove !Int !Int !ViewFrame -> Int
		compute_thumb SliderIncSmall x d view_frame
			= x + d
		compute_thumb SliderDecSmall x d view_frame
			= x - d
		compute_thumb SliderIncLarge x d view_frame
			# viewFrameSize			= rectangleSize view_frame
			# edge					= viewFrameSize.w
			= x + (edge / d) * d
		compute_thumb SliderDecLarge x d view_frame
			# viewFrameSize			= rectangleSize view_frame
			# edge					= viewFrameSize.w
			= x - (edge / d) * d
		compute_thumb (SliderThumb x) _ d view_frame
			= x

// -----------------------------------------------------------------------------------------------------------------------
sliderVertical :: !SliderMove (.MarkUpLocalState a *(PSt .b),*PSt .b) -> *(MarkUpLocalState a *(PSt .b),*PSt .b)
// -----------------------------------------------------------------------------------------------------------------------
sliderVertical slidermove (mstate, state)
	# (mb_wstate, state)			= accPIO (getParentWindow mstate.mulId) state
	| isNothing mb_wstate			= (mstate, state)
	# wstate						= fromJust mb_wstate
	# (ok, mb_viewframe)			= getControlViewFrame mstate.mulId wstate
	| not ok						= (mstate, state)
	| isNothing mb_viewframe		= (mstate, state)
	# viewframe						= fromJust mb_viewframe
	# (ok, mb_viewdomain)			= getControlViewDomain mstate.mulId wstate
	| not ok						= (mstate, state)
	| isNothing mb_viewdomain		= (mstate, state)
	# viewdomain					= fromJust mb_viewdomain
	# (ok, viewsize)				= getControlViewSize mstate.mulId wstate
	| not ok						= (mstate, state)
	# (ok, mb_sliderstate)			= getSliderState (snd mstate.mulScrollIds) wstate
	| not ok						= (mstate, state)
	| isNothing mb_sliderstate		= (mstate, state)
	# sliderstate					= fromJust mb_sliderstate
	# line_height					= if ((isEmpty mstate.mulBaselines) || (isEmpty mstate.mulSkips)) 10 (hd mstate.mulBaselines + hd mstate.mulSkips)
	# new_thumb						= compute_thumb slidermove sliderstate.sliderThumb line_height viewframe
	# state							= appPIO (setSliderThumb (snd mstate.mulScrollIds) new_thumb) state
	# state							= appPIO (moveControlViewFrame mstate.mulId {vx=0,vy=new_thumb-viewframe.corner1.y}) state
	= (mstate, state)
	where
		compute_thumb :: !SliderMove !Int !Int !ViewFrame -> Int
		compute_thumb SliderIncSmall x d view_frame
			= x + d
		compute_thumb SliderDecSmall x d view_frame
			= x - d
		compute_thumb SliderIncLarge x d view_frame
			# viewFrameSize			= rectangleSize view_frame
			# edge					= viewFrameSize.h
			= x + (edge / d) * d
		compute_thumb SliderDecLarge x d view_frame
			# viewFrameSize			= rectangleSize view_frame
			# edge					= viewFrameSize.h
			= x - (edge / d) * d
		compute_thumb (SliderThumb x) _ d view_frame
			= x

// -----------------------------------------------------------------------------------------------------------------------
computeViewSizeDomain :: (!MarkUpLocalState a .ps) -> (!Size, !ViewDomain, !Int, Int->Int)
// -----------------------------------------------------------------------------------------------------------------------
computeViewSizeDomain mstate
	// compute viewdomain
	# maxx				= if (isEmpty mstate.mulDrawFunctions) 0 (ownMax 0 [area.smartRectangle.corner2.x \\ area <- mstate.mulDrawFunctions])
	# maxy				= if (isEmpty mstate.mulDrawFunctions) 0 (ownMax 0 [area.smartRectangle.corner2.y \\ area <- mstate.mulDrawFunctions])
	# viewdomain		= {corner1 = zero, corner2 = {x = maxx, y = maxy}}
	// compute viewsize
	# width				= if (mstate.mulWidth <> 0) mstate.mulWidth 
							(if (mstate.mulMaxWidth == 0) (maxx+1) (min mstate.mulMaxWidth (maxx+1)))
	# height			= if (mstate.mulHeight <> 0) mstate.mulHeight
							(if (mstate.mulMaxHeight == 0) (maxy+1) (min mstate.mulMaxHeight (maxy+1)))
	// compute auxiliary (possibly reset heigth)
	# lineheight		= if (isEmpty mstate.mulBaselines || isEmpty mstate.mulSkips) 0 (hd mstate.mulBaselines + hd mstate.mulSkips)
	# lineheight		= if (fst mstate.mulNrLines < 0) 10 lineheight
	# height			= if (fst mstate.mulNrLines < 0) height (lineheight * (fst mstate.mulNrLines) + 2 + (snd mstate.mulNrLines)) // +2 to compensate for bug?
	# round				= if (fst mstate.mulNrLines < 0) id (roundfun lineheight)
	// actual viewsize
	# viewsize			= {w = width, h = height}
	= (viewsize, viewdomain, lineheight, round)
	where
		roundfun :: !Int !Int -> !Int
		roundfun lineheight thumb_value
			# difference						= thumb_value - (thumb_value / lineheight) * lineheight
			| difference <= lineheight / 2		= thumb_value - difference
			| otherwise							= thumb_value + lineheight - difference
		
		ownMax :: !Int ![Int] -> !Int
		ownMax current [x:xs]
			| x == 10000						= ownMax current xs
			= ownMax (max x current) xs
		ownMax current []
			= current

// -----------------------------------------------------------------------------------------------------------------------
MarkUpControl :: ![MarkUpCommand a] ![MarkUpAttribute a .ps] ![ControlAttribute *(MarkUpLocalState a .ps, .ps)] 
			  -> MarkUpState a .ls .ps
// -----------------------------------------------------------------------------------------------------------------------
MarkUpControl commands custom_attributes control_attributes
	=	{ musCommands			= commands
		, musCustomAttributes	= custom_attributes
		, musControlAttributes	= control_attributes
		, musWindowAttributes	= []
		, musIsControl			= True
		}

// -----------------------------------------------------------------------------------------------------------------------
MarkUpWindow :: !String ![MarkUpCommand a] ![MarkUpAttribute a (*PSt .ps)] ![WindowAttribute *(MarkUpLocalState a (*PSt .ps), *PSt .ps)] !*(PSt .ps) -> *PSt .ps
// -----------------------------------------------------------------------------------------------------------------------
MarkUpWindow title commands custom_attributes window_attributes state
	# initial_mstate				=	{ musCommands			= commands
										, musCustomAttributes	= custom_attributes
										, musControlAttributes	= []
										, musWindowAttributes	= window_attributes
										, musIsControl			= False
										}
	# (mstate, state)				= initialMarkUpLocalState initial_mstate state
	# (mstate, state)				= makeCm_s mstate state
	# mstate						= {mstate & mulScroll = (False, False)}
	# mstate						= computeMetrics mstate
	# mstate						= getAlignConstraints mstate
	# mstate						= solveAlignConstraints mstate
	# mstate						= removeCmCenterRight mstate
	# (dummy_font, state)			= accPIO (accScreenPicture openDefaultFont) state
	# mstate						= makeDrawFunctions dummy_font mstate
	# (vsize, vdomain, line, round)	= computeViewSizeDomain mstate
	# mstate						= {mstate & mulViewDomain = vdomain}
	# mstate						= replaceInvalidDrawFunctions vsize.w mstate
	# mstate						= setDefaultLabels vdomain vsize mstate
	# the_window					= Window title (Receiver mstate.mulReceiverId receiver [])
										([ WindowId				mstate.mulOuterId
										 , WindowViewSize		vsize
										 , WindowViewDomain		vdomain
										 , WindowHScroll		(ScrollFunction 10 85 Horizontal id)
										 , WindowVScroll		(ScrollFunction line 85 Vertical round)
										 , WindowLook   		True (DrawSmartAreas mstate.mulDrawFunctions (toRGBColour mstate.mulInitialBackgroundColour))
										 , WindowMouse			(\x -> True) Able MouseFunction
										 , WindowKeyboard		(\x -> True) Able (KeyboardFunction mstate.mulKeyboard)
										 ] ++ window_attributes ++
										 [ WindowClose			(noLS (closeWindow mstate.mulId)) ])
	# (msg, state)					= openWindow mstate the_window state
	= state
	where
		receiver :: (!MarkUpMessage a) (!MarkUpLocalState a (*PSt .ps), *PSt .ps) -> (!MarkUpLocalState a (*PSt .ps), *PSt .ps)
		receiver (MarkUpChangeText new_text) (mstate, state)
			# mstate				= {mstate	& mulCommands				= new_text
												, mulViewDomain				= zero
												, mulViewSize				= zero
												, mulDrawFunctions			= []
												, mulHighlightDrawFunctions	= []
												, mulActiveLink				= -1
												, mulBaselines				= []
												, mulSkips					= []
												, mulScopes					= [[{aliName = "_START_", aliRelativeX = [RX_Solved 0], aliAbsoluteX = (-1)}]]
									  }
			# (mstate, state)				= makeCm_s mstate state
			# mstate						= computeMetrics mstate
			# mstate						= getAlignConstraints mstate
			# mstate						= solveAlignConstraints mstate
			# mstate						= removeCmCenterRight mstate
			# (dummy_font, state)			= accPIO (accScreenPicture openDefaultFont) state
			# mstate						= makeDrawFunctions dummy_font mstate
			# (vsize, vdomain, line, round)	= computeViewSizeDomain mstate
			# mstate						= {mstate & mulViewDomain = vdomain}
			# mstate						= replaceInvalidDrawFunctions vsize.w mstate
			# newlook						= DrawSmartAreas mstate.mulDrawFunctions (toRGBColour mstate.mulInitialBackgroundColour)
			# re_look						= appPIO (setWindowLook mstate.mulId True (True, newlook))
			# re_domain						= appPIO (setWindowViewDomain mstate.mulId vdomain)
			# state							= re_domain state
			# state							= re_look state
			= (mstate, state)
		receiver (MarkUpJumpTo label) (mstate, state)
			# labels						= mstate.mulLabels
			# correct_labels				= filter (\(a,b,c) -> a == label) labels
			| isEmpty correct_labels		= (mstate, state)
			# (_, x, y)						= hd correct_labels
			# (viewframe, state)			= accPIO (getWindowViewFrame mstate.mulId) state
			# vector						= {vx = x - viewframe.corner1.x, vy = y - viewframe.corner1.y}
			# state							= appPIO (moveWindowViewFrame mstate.mulId vector) state
			= (mstate, state)
		receiver (MarkUpDrawAtLabel label draw) (mstate, state)
			# labels						= mstate.mulLabels
			# correct_labels				= filter (\(a,b,c) -> a == label) labels
			| isEmpty correct_labels		= (mstate, state)
			# (_, x, y)						= hd correct_labels
			# draw							= draw o setPenPos {x=x,y=y}
			# state							= appPIO (appWindowPicture mstate.mulOuterId draw) state
			= (mstate, state)
		receiver (MarkUpTrigger link) (mstate, state)
			# event							=	{ meSelectEvent		= False
												, meClickEvent		= True
												, meNrClicks		= 1
												, meLink			= link
												, meLinkIndex		= Nothing
												, meOwnRId			= mstate.mulReceiverId
												, meModifiers		= Nothing
												}
			# state							= mstate.mulEventHandler event state
			= (mstate, state)
		receiver MarkUpDeactivate (mstate=:{mulActiveLink,mulIsControl,mulId,mulInitialBackgroundColour,mulDrawFunctions}, pstate)
			| mulActiveLink < 0				= (mstate, pstate)
			# old_normdrawfun				= findDrawFun mulActiveLink mulDrawFunctions
			# pstate						= updateLookFun mulIsControl mulId [old_normdrawfun] mulInitialBackgroundColour mulDrawFunctions pstate
			# mstate						= {mstate & mulActiveLink = (-1)}
			= (mstate, pstate)

// -----------------------------------------------------------------------------------------------------------------------
instance Controls (MarkUpState a)
// -----------------------------------------------------------------------------------------------------------------------
where
	getControlType _					= "MarkUpControl v2.0"
	controlToHandles mstate=:{musControlAttributes} state
		# (mstate, state)				= initialMarkUpLocalState mstate state
		# (mstate, state)				= makeCm_s mstate state
		# mstate						= computeMetrics mstate
		# mstate						= getAlignConstraints mstate
		# mstate						= solveAlignConstraints mstate
		# mstate						= removeCmCenterRight mstate
		# (dummy_font, state)			= accPIO (accScreenPicture openDefaultFont) state
		# mstate						= makeDrawFunctions dummy_font mstate
		# (vsize, vdomain, line, round)	= computeViewSizeDomain mstate
		# mstate						= replaceInvalidDrawFunctions vsize.w mstate
		# mstate						= setDefaultLabels vdomain vsize mstate
		// horizontal slider
		# need_hor_slider				= vdomain.corner2.x >= vsize.w
		# slider_selectstate			= if need_hor_slider (ControlSelectState Able) (ControlSelectState Unable)
		# slider_state					= {sliderMin = 0, sliderMax = vdomain.corner2.x + 1, sliderThumb = 0 /*, sliderSize = vsize.w - 1*/}
		# hor_resize					= \current old new -> {w = (mstate.mulResize current old new).w, h = current.h}
		# hor_slider					= case fst mstate.mulScroll of
											True	-> ControlJust (SliderControl Horizontal (PixelWidth vsize.w) slider_state sliderHorizontal [ControlPos (Below mstate.mulId, zero), slider_selectstate, ControlId (fst mstate.mulScrollIds), ControlResize hor_resize])
											False	-> ControlNothing
		// vertical slider
		# need_ver_slider				= vdomain.corner2.y >= vsize.h
		# slider_selectstate			= if need_ver_slider (ControlSelectState Able) (ControlSelectState Unable)
		# slider_state					= {sliderMin = 0, sliderMax = vdomain.corner2.y + 1, sliderThumb = 0/*, sliderSize = vsize.h - 1*/}
		# ver_resize					= \current old new -> {w = current.w, h = (mstate.mulResize current old new).h}
		# ver_slider					= case snd mstate.mulScroll of
											True	-> ControlJust (SliderControl Vertical (PixelWidth vsize.h) slider_state sliderVertical [ControlPos (RightTo mstate.mulId, zero), slider_selectstate, ControlId (snd mstate.mulScrollIds), ControlResize ver_resize])
											False	-> ControlNothing
		// fill-up space
		# (metrics, _)					= osDefaultWindowMetrics 42
		# fill_up_size					= {w=metrics.osmVSliderWidth, h=metrics.osmHSliderHeight}
		# fill_up_look					= \_ {newFrame} -> seq [setPenColour getDialogBackgroundColour, fill newFrame]
		# fill_up_control				= case (fst mstate.mulScroll && snd mstate.mulScroll) of
											True	-> ControlJust (CustomControl fill_up_size fill_up_look
																		[ ControlPos		(Below (snd mstate.mulScrollIds), zero)
																		]
																	)
											False	-> ControlNothing
		// receiver
		# receiver_control				= Receiver mstate.mulReceiverId receiver []
		// central control
		# the_control					= CompoundControl (NilLS)
													([ ControlId			mstate.mulId
													 , ControlViewSize 		vsize
													 , ControlViewDomain	vdomain
													 , ControlLook     		False (DrawSmartAreas mstate.mulDrawFunctions (toRGBColour mstate.mulInitialBackgroundColour))
													 , ControlMouse			(\x -> True) Able MouseFunction
													 , ControlKeyboard		(\x -> True) Able (KeyboardFunction mstate.mulKeyboard)
													 , ControlHMargin		0 0
													 , ControlVMargin		0 0
													 , ControlItemSpace		0 0
						  							 , ControlResize		mstate.mulResize
									 				 ])
		# compound_control				=	{ newLS		= mstate
											, newDef	= LayoutControl (receiver_control :+: the_control :+: hor_slider :+: ver_slider :+: fill_up_control)
															([ ControlId			mstate.mulOuterId
															 , ControlHMargin		0 0
															 , ControlVMargin		0 0
															 , ControlItemSpace		0 0
								  							 , ControlResize		mstate.mulResize
															] ++ musControlAttributes)
											}
		= controlToHandles compound_control state
		where
			receiver :: (!MarkUpMessage a) (!MarkUpLocalState a (*PSt .ps), *PSt .ps) -> (!MarkUpLocalState a (*PSt .ps), *PSt .ps)
			receiver (MarkUpChangeText new_text) (mstate, state)
				# old_drawfuns					= mstate.mulDrawFunctions
				# mstate						= {mstate	& mulCommands				= new_text
															, mulViewDomain				= zero
															, mulViewSize				= zero
															, mulDrawFunctions			= []
															, mulHighlightDrawFunctions	= []
															, mulActiveLink				= -1
															, mulBaselines				= []
															, mulSkips					= []
															, mulScopes					= [[{aliName = "_START_", aliRelativeX = [RX_Solved 0], aliAbsoluteX = (-1)}]]
												  }
				# (mstate, state)				= makeCm_s mstate state
				# mstate						= computeMetrics mstate
				# mstate						= getAlignConstraints mstate
				# mstate						= solveAlignConstraints mstate
				# mstate						= removeCmCenterRight mstate
				# (dummy_font, state)			= accPIO (accScreenPicture openDefaultFont) state
				# mstate						= makeDrawFunctions dummy_font mstate
				# (vsize, vdomain, line, round)	= computeViewSizeDomain mstate
				# mstate						= {mstate & mulViewDomain = vdomain}
				# mstate						= replaceInvalidDrawFunctions vsize.w mstate
				# mstate						= setDefaultLabels vdomain vsize mstate
				# newlook						= DrawSmartAreas mstate.mulDrawFunctions (toRGBColour mstate.mulInitialBackgroundColour)
				# re_look						= appPIO (setControlLook mstate.mulId False (False, newlook))
				# re_domain						= appPIO (setControlViewDomain mstate.mulId vdomain)
				# state							= re_domain state
				# state							= re_look state
				// sliders -- general
				# (mb_wstate, state)			= accPIO (getParentWindow mstate.mulId) state
				| isNothing mb_wstate			= (mstate, state)
				# wstate						= fromJust mb_wstate
				# (ok, mb_viewframe)			= getControlViewFrame mstate.mulId wstate
				| not ok						= (mstate, state)
				| isNothing mb_viewframe		= (mstate, state)
				# viewframe						= fromJust mb_viewframe
				# (ok, real_size)				= getControlViewSize mstate.mulId wstate
				| not ok						= (mstate, state)
				// horizontal slider
				# need_hor_slider				= vdomain.corner2.x >= real_size.w
				# slider_state					= {sliderMin = 0, sliderMax = vdomain.corner2.x, sliderThumb = viewframe.corner1.x/*, sliderSize = real_size.w - 1*/}
				# state							= case need_hor_slider of
													True	-> appPIO (setSliderState (fst mstate.mulScrollIds) (\_ -> slider_state)) state
													False	-> state
				# state							= case need_hor_slider of
													True	-> appPIO (enableControl (fst mstate.mulScrollIds)) state
													False	-> appPIO (disableControl (fst mstate.mulScrollIds)) state
				// vertical slider
				# need_ver_slider				= vdomain.corner2.y >= real_size.h
				# slider_state					= {sliderMin = 0, sliderMax = vdomain.corner2.y, sliderThumb = viewframe.corner1.y/*, sliderSize = real_size.h - 1*/}
				# state							= case need_ver_slider of
													True	-> appPIO (setSliderState (snd mstate.mulScrollIds) (\_ -> slider_state)) state
													False	-> state
				# state							= case need_ver_slider of
													True	-> appPIO (enableControl (snd mstate.mulScrollIds)) state
													False	-> appPIO (disableControl (snd mstate.mulScrollIds)) state
				// redraw
				# new_draws						= ChangeDrawAreas (toRGBColour mstate.mulInitialBackgroundColour) mstate.mulDrawFunctions old_drawfuns
				# state							= appPIO (appControlPicture mstate.mulId (ImmediateDraw new_draws)) state
				# mstate						= {mstate & mulPreviousMouseMove = {x=(-1),y=(-1)}}
				= (mstate, state)
			receiver (MarkUpChangeDraw center change_fun) (mstate, state)
				# old_draws						= mstate.mulDrawFunctions
				# (new_draws, update, y1, y2)	= change old_draws
				# mstate						= {mstate & mulDrawFunctions = new_draws}
				# newlook						= DrawSmartAreas mstate.mulDrawFunctions (toRGBColour mstate.mulInitialBackgroundColour)
				# state							= appPIO (setControlLook mstate.mulId False (False, newlook)) state
				# state							= appPIO (appControlPicture mstate.mulId (ImmediateDraw update)) state
				| not center					= (mstate, state)
				// viewframe + size
				# (mb_wstate, state)			= accPIO (getParentWindow mstate.mulId) state
				| isNothing mb_wstate			= (mstate, state)
				# wstate						= fromJust mb_wstate
				# (ok, mb_viewframe)			= getControlViewFrame mstate.mulId wstate
				| not ok						= (mstate, state)
				| isNothing mb_viewframe		= (mstate, state)
				# viewframe						= fromJust mb_viewframe
				# (ok, real_size)				= getControlViewSize mstate.mulId wstate
				| not ok						= (mstate, state)
				// center
				# vdomain						= mstate.mulViewDomain
				# y_diff						= y2 - y1
				# leave_free					= (real_size.h - y_diff) / 2
				# new_y							= y1 - leave_free
				# new_y							= if (new_y < 0) 0 new_y
				# move_y						= new_y - viewframe.corner1.y
				| move_y == 0					= (mstate, state)
				# state							= appPIO (moveControlViewFrame mstate.mulId {vx=0,vy=move_y}) state
				= (mstate, state)
				where
//					change :: ![SmartDrawArea a] -> (![SmartDrawArea a], ![SmartDrawArea a])
					change [area:areas]
						# (changed, area)				= change_fun area.smartId area
						# (new_draws, update, y1, y2)	= change areas
						= case changed of
							True	-> ([area:new_draws], [area:update], area.smartRectangle.corner1.y, area.smartRectangle.corner2.y)
							False	-> ([area:new_draws], update, y1, y2)
					change []
						= ([], [], -1, -1)
			receiver MarkUpResetSliders (mstate, state)
				# (vsize, vdomain, line, round)	= computeViewSizeDomain mstate
				// sliders -- general
				# (mb_wstate, state)			= accPIO (getParentWindow mstate.mulId) state
				| isNothing mb_wstate			= (mstate, state)
				# wstate						= fromJust mb_wstate
				# (ok, mb_viewframe)			= getControlViewFrame mstate.mulId wstate
				| not ok						= (mstate, state)
				| isNothing mb_viewframe		= (mstate, state)
				# viewframe						= fromJust mb_viewframe
				# (ok, real_size)				= getControlViewSize mstate.mulId wstate
				| not ok						= (mstate, state)
				// horizontal slider
				# need_hor_slider				= vdomain.corner2.x >= real_size.w
				# slider_state					= {sliderMin = 0, sliderMax = vdomain.corner2.x, sliderThumb = viewframe.corner1.x/*, sliderSize = real_size.w - 1*/}
				# state							= case need_hor_slider of
													True	-> appPIO (setSliderState (fst mstate.mulScrollIds) (\_ -> slider_state)) state
													False	-> state
				# state							= case need_hor_slider of
													True	-> appPIO (enableControl (fst mstate.mulScrollIds)) state
													False	-> appPIO (disableControl (fst mstate.mulScrollIds)) state
				// vertical slider
				# need_ver_slider				= vdomain.corner2.y >= real_size.h
				# slider_state					= {sliderMin = 0, sliderMax = vdomain.corner2.y, sliderThumb = viewframe.corner1.y/*, sliderSize = real_size.h - 1*/}
				# state							= case need_ver_slider of
													True	-> appPIO (setSliderState (snd mstate.mulScrollIds) (\_ -> slider_state)) state
													False	-> state
				# state							= case need_ver_slider of
													True	-> appPIO (enableControl (snd mstate.mulScrollIds)) state
													False	-> appPIO (disableControl (snd mstate.mulScrollIds)) state
				= (mstate, state)
			receiver (MarkUpJumpTo label) (mstate, state)
				# labels						= mstate.mulLabels
				# correct_labels				= filter (\(a,b,c) -> a == label) labels
				| isEmpty labels				= (mstate, state)
				# (_, x, y)						= hd correct_labels
				# (maybe_wstate, state)			= accPIO (getParentWindow mstate.mulId) state
				| isNothing maybe_wstate		= (mstate, state) ->> "WState?"
				# wstate						= fromJust maybe_wstate
				# (ok, maybe_viewframe)			= getControlViewFrame  mstate.mulId wstate
				| isNothing maybe_viewframe		= (mstate, state) ->> "ViewFrame?"
				# viewframe						= fromJust maybe_viewframe
				# (ok, mb_viewdomain)			= getControlViewDomain mstate.mulId wstate
				| isNothing mb_viewdomain		= (mstate, state) ->> "ViewDomain?"
				# viewdomain					= fromJust mb_viewdomain
				# (ok, viewsize)				= getControlViewSize mstate.mulId wstate
				| not ok						= (mstate, state) ->> "Viewsize?"
				
				# domain_height					= abs (viewdomain.corner1.y - viewdomain.corner2.y)
				# domain_width					= abs (viewdomain.corner1.x - viewdomain.corner2.x)
				# view_height					= abs (viewframe.corner1.y - viewframe.corner2.y)
				# view_width					= abs (viewframe.corner1.x - viewframe.corner2.x)
				# vector						= {vx = x - viewframe.corner1.x, vy = y - viewframe.corner1.y}
				# height_ok						= (vector.vy == 0) || (domain_height <= view_height)
				# width_ok						= (vector.vx == 0) || (domain_width <= view_width)
				| height_ok && width_ok			= (mstate, state)
				
				# state							= appPIO (moveControlViewFrame mstate.mulId vector) state
				# update_hor_slider				= fst mstate.mulScroll && viewdomain.corner2.x >= viewsize.w
				# update_ver_slider				= snd mstate.mulScroll && viewdomain.corner2.y >= viewsize.h
				# state							= case update_hor_slider of
													True	-> appPIO (setSliderThumb (fst mstate.mulScrollIds) x) state
													False	-> state
				# state							= case update_ver_slider of
													True	-> appPIO (setSliderThumb (snd mstate.mulScrollIds) y) state
													False	-> state
				= (mstate, state)
			receiver MarkUpDeactivate (mstate=:{mulActiveLink,mulIsControl,mulId,mulInitialBackgroundColour,mulDrawFunctions}, pstate)
				| mulActiveLink < 0				= (mstate, pstate)
				# old_normdrawfun				= findDrawFun mulActiveLink mulDrawFunctions
				# pstate						= updateLookFun mulIsControl mulId [old_normdrawfun] mulInitialBackgroundColour mulDrawFunctions pstate
				# mstate						= {mstate & mulActiveLink = (-1)}
				= (mstate, pstate)
			receiver (MarkUpDrawAtLabel label draw) (mstate, state)
				= (mstate, state) //--->> "Warning: MarkUpDrawAtLabel only implemented for windows"
			receiver (MarkUpTrigger link) (mstate, state)
				# event							=	{ meSelectEvent		= False
													, meClickEvent		= True
													, meNrClicks		= 1
													, meLink			= link
													, meLinkIndex		= Nothing
													, meOwnRId			= mstate.mulReceiverId
													, meModifiers		= Nothing
													}
				# state							= mstate.mulEventHandler event state
				= (mstate, state)
			receiver MarkUpScrollLeftBottom (mstate, state)
				# (maybe_wstate, state)			= accPIO (getParentWindow mstate.mulId) state
				| isNothing maybe_wstate		= (mstate, state) ->> "WState?"
				# wstate						= fromJust maybe_wstate
				# (ok, maybe_viewframe)			= getControlViewFrame  mstate.mulId wstate
				| isNothing maybe_viewframe		= (mstate, state) ->> "ViewFrame?"
				# viewframe						= fromJust maybe_viewframe
				# (ok, mb_viewdomain)			= getControlViewDomain mstate.mulId wstate
				| isNothing mb_viewdomain		= (mstate, state) ->> "ViewDomain?"
				# viewdomain					= fromJust mb_viewdomain
				# (ok, viewsize)				= getControlViewSize mstate.mulId wstate
				| not ok						= (mstate, state) ->> "Viewsize?"
				# new_left_top					= viewdomain.corner2.y - viewsize.h
				
				| new_left_top < 0				= (mstate, state)
				# move							= {vx = 0 - viewframe.corner1.x, vy = new_left_top - viewframe.corner1.y}
				# state							= appPIO (moveControlViewFrame mstate.mulId move) state
				= (mstate, state)

// -----------------------------------------------------------------------------------------------------------------------
changeMarkUpText :: !(RId !(MarkUpMessage a)) !(MarkUpText a) !(*PSt .ps) -> !*PSt .ps
// -----------------------------------------------------------------------------------------------------------------------
changeMarkUpText rid text state
	= snd (syncSend rid (MarkUpChangeText text) state) 

// -----------------------------------------------------------------------------------------------------------------------
changeMarkUpDraw :: !(RId !(MarkUpMessage a)) !Bool !((SmartId a) -> (SmartDrawArea a) -> (Bool, SmartDrawArea a)) !(*PSt .ps) -> !*PSt .ps
// -----------------------------------------------------------------------------------------------------------------------
changeMarkUpDraw rid center fun state
	= snd (syncSend rid (MarkUpChangeDraw center fun) state) 

// -----------------------------------------------------------------------------------------------------------------------
deactiveMarkUp :: !(RId (MarkUpMessage a)) !*(PSt .ps) -> *PSt .ps
// -----------------------------------------------------------------------------------------------------------------------
deactiveMarkUp rid pstate
	= snd (syncSend rid MarkUpDeactivate pstate)

// -----------------------------------------------------------------------------------------------------------------------
jumpToMarkUpLabel :: !(RId !(MarkUpMessage a)) !String !(*PSt .ps) -> !*PSt .ps
// -----------------------------------------------------------------------------------------------------------------------
jumpToMarkUpLabel rid label state
	= snd (syncSend rid (MarkUpJumpTo label) state) 

// -----------------------------------------------------------------------------------------------------------------------
redrawMarkUpSliders :: !(RId !(MarkUpMessage a)) !(*PSt .ps) -> !*PSt .ps
// -----------------------------------------------------------------------------------------------------------------------
redrawMarkUpSliders rid state
	= snd (syncSend rid MarkUpResetSliders state)

// -----------------------------------------------------------------------------------------------------------------------
triggerMarkUpLink :: !(RId !(MarkUpMessage a)) !a !(*PSt .ps) -> !*PSt .ps
// -----------------------------------------------------------------------------------------------------------------------
triggerMarkUpLink rid link state
	= snd (syncSend rid (MarkUpTrigger link) state)

// -----------------------------------------------------------------------------------------------------------------------
scrollMarkUpToBottom :: !(RId !(MarkUpMessage a)) !*(PSt .ps) -> !*PSt .ps
// -----------------------------------------------------------------------------------------------------------------------
scrollMarkUpToBottom rid state
	= snd (syncSend rid MarkUpScrollLeftBottom state)

// -----------------------------------------------------------------------------------------------------------------------
changeCmLink :: (a -> b) !(MarkUpText a) -> !MarkUpText b
// -----------------------------------------------------------------------------------------------------------------------
changeCmLink fun [CmText text:				commands] = [CmText text:					changeCmLink fun commands]
changeCmLink fun [CmBText text:				commands] = [CmBText text:					changeCmLink fun commands]
changeCmLink fun [CmIText text:				commands] = [CmIText text:					changeCmLink fun commands]
changeCmLink fun [CmUText text:				commands] = [CmUText text:					changeCmLink fun commands]
changeCmLink fun [CmNewlineI ignore e clr:	commands] = [CmNewlineI ignore e clr:		changeCmLink fun commands]
changeCmLink fun [CmFillLine:				commands] = [CmFillLine:					changeCmLink fun commands]
changeCmLink fun [CmStartOfLine:			commands] = [CmStartOfLine:					changeCmLink fun commands]
changeCmLink fun [CmScope:					commands] = [CmScope:						changeCmLink fun commands]
changeCmLink fun [CmEndScope:				commands] = [CmEndScope:					changeCmLink fun commands]
changeCmLink fun [CmAlignI text clr:		commands] = [CmAlignI text clr:				changeCmLink fun commands]
changeCmLink fun [CmCenter:					commands] = [CmCenter:						changeCmLink fun commands]
changeCmLink fun [CmBGCenter colour:		commands] = [CmBGCenter colour:				changeCmLink fun commands]
changeCmLink fun [CmRight:					commands] = [CmRight:						changeCmLink fun commands]
changeCmLink fun [CmBGRight colour:			commands] = [CmBGRight colour:				changeCmLink fun commands]
changeCmLink fun [CmHorSpace space:			commands] = [CmHorSpace space:				changeCmLink fun commands]
changeCmLink fun [CmSpaces nr:				commands] = [CmSpaces nr:					changeCmLink fun commands]
changeCmLink fun [CmBold:					commands] = [CmBold:						changeCmLink fun commands]
changeCmLink fun [CmEndBold:				commands] = [CmEndBold:						changeCmLink fun commands]
changeCmLink fun [CmItalic:					commands] = [CmItalic:						changeCmLink fun commands]
changeCmLink fun [CmEndItalic:				commands] = [CmEndItalic:					changeCmLink fun commands]
changeCmLink fun [CmUnderline:				commands] = [CmUnderline:					changeCmLink fun commands]
changeCmLink fun [CmEndUnderline:			commands] = [CmEndUnderline:				changeCmLink fun commands]
changeCmLink fun [CmSize num:				commands] = [CmSize num:					changeCmLink fun commands]
changeCmLink fun [CmChangeSize num:			commands] = [CmChangeSize num:				changeCmLink fun commands]
changeCmLink fun [CmEndSize:				commands] = [CmEndSize:						changeCmLink fun commands]
changeCmLink fun [CmColour colour:			commands] = [CmColour colour:				changeCmLink fun commands]
changeCmLink fun [CmEndColour:				commands] = [CmEndColour:					changeCmLink fun commands]
changeCmLink fun [CmBackgroundColour colour:commands] = [CmBackgroundColour colour:		changeCmLink fun commands]
changeCmLink fun [CmEndBackgroundColour:	commands] = [CmEndBackgroundColour:			changeCmLink fun commands]
changeCmLink fun [CmFont font:				commands] = [CmFont font:					changeCmLink fun commands]
changeCmLink fun [CmEndFont:				commands] = [CmEndFont:						changeCmLink fun commands]
changeCmLink fun [CmFontFace name:			commands] = [CmFontFace name:				changeCmLink fun commands]
changeCmLink fun [CmEndFontFace:			commands] = [CmEndFontFace:					changeCmLink fun commands]
changeCmLink fun [CmLink text link:			commands] = [CmLink text (fun link):		changeCmLink fun commands]
changeCmLink fun [CmLabel text base:		commands] = [CmLabel text base:				changeCmLink fun commands]
changeCmLink fun [Cm_Word text font metrics num colour bgcolour: commands]
	= [Cm_Word text font metrics num colour bgcolour: changeCmLink fun commands]
changeCmLink fun [Cm_Link text link metrics num (font1, colour1, bgcolour1) (font2, colour2, bgcolour2): commands]
	= [Cm_Link text (fun link) metrics num (font1, colour1, bgcolour1) (font2, colour2, bgcolour2): changeCmLink fun commands]
changeCmLink fun [Cm_HorSpace num colour:commands]
	= [Cm_HorSpace num colour: changeCmLink fun commands]
changeCmLink fun []
	= []

// -----------------------------------------------------------------------------------------------------------------------
removeCmLink :: !(MarkUpText a) -> !MarkUpText b
// -----------------------------------------------------------------------------------------------------------------------
removeCmLink [CmText text:				commands] = [CmText text:					removeCmLink commands]
removeCmLink [CmBText text:				commands] = [CmBText text:					removeCmLink commands]
removeCmLink [CmIText text:				commands] = [CmIText text:					removeCmLink commands]
removeCmLink [CmUText text:				commands] = [CmUText text:					removeCmLink commands]
removeCmLink [CmNewline:				commands] = [CmNewline:						removeCmLink commands]
removeCmLink [CmFillLine:				commands] = [CmFillLine:					removeCmLink commands]
removeCmLink [CmStartOfLine:			commands] = [CmStartOfLine:					removeCmLink commands]
removeCmLink [CmScope:					commands] = [CmScope:						removeCmLink commands]
removeCmLink [CmEndScope:				commands] = [CmEndScope:					removeCmLink commands]
removeCmLink [CmAlignI text clr:		commands] = [CmAlignI text clr:				removeCmLink commands]
removeCmLink [CmCenter:					commands] = [CmCenter:						removeCmLink commands]
removeCmLink [CmBGCenter colour:		commands] = [CmBGCenter colour:				removeCmLink commands]
removeCmLink [CmRight:					commands] = [CmRight:						removeCmLink commands]
removeCmLink [CmBGRight colour:			commands] = [CmBGRight colour:				removeCmLink commands]
removeCmLink [CmHorSpace space:			commands] = [CmHorSpace space:				removeCmLink commands]
removeCmLink [CmSpaces nr:				commands] = [CmSpaces nr:					removeCmLink commands]
removeCmLink [CmBold:					commands] = [CmBold:						removeCmLink commands]
removeCmLink [CmEndBold:				commands] = [CmEndBold:						removeCmLink commands]
removeCmLink [CmItalic:					commands] = [CmItalic:						removeCmLink commands]
removeCmLink [CmEndItalic:				commands] = [CmEndItalic:					removeCmLink commands]
removeCmLink [CmUnderline:				commands] = [CmUnderline:					removeCmLink commands]
removeCmLink [CmEndUnderline:			commands] = [CmEndUnderline:				removeCmLink commands]
removeCmLink [CmSize num:				commands] = [CmSize num:					removeCmLink commands]
removeCmLink [CmChangeSize num:			commands] = [CmChangeSize num:				removeCmLink commands]
removeCmLink [CmEndSize:				commands] = [CmEndSize:						removeCmLink commands]
removeCmLink [CmColour colour:			commands] = [CmColour colour:				removeCmLink commands]
removeCmLink [CmEndColour:				commands] = [CmEndColour:					removeCmLink commands]
removeCmLink [CmBackgroundColour colour:commands] = [CmBackgroundColour colour:		removeCmLink commands]
removeCmLink [CmEndBackgroundColour:	commands] = [CmEndBackgroundColour:			removeCmLink commands]
removeCmLink [CmFont font:				commands] = [CmFont font:					removeCmLink commands]
removeCmLink [CmEndFont:				commands] = [CmEndFont:						removeCmLink commands]
removeCmLink [CmFontFace name:			commands] = [CmFontFace name:				removeCmLink commands]
removeCmLink [CmEndFontFace:			commands] = [CmEndFontFace:					removeCmLink commands]
removeCmLink [CmLink text link:			commands] = [CmText text:					removeCmLink commands]
removeCmLink [CmLabel text base:		commands] = [CmLabel text base:				removeCmLink commands]
removeCmLink [Cm_Word text font metrics num colour bgcolour: commands]
	= [Cm_Word text font metrics num colour bgcolour: removeCmLink commands]
removeCmLink [Cm_Link text link metrics num (font1, colour1, bgcolour1) (font2, colour2, bgcolour2): commands]
	= [Cm_Word text font1 metrics num colour1 bgcolour1: removeCmLink commands]
removeCmLink [Cm_HorSpace num colour:commands]
	= [Cm_HorSpace num colour: removeCmLink commands]
removeCmLink []
	= []

// -----------------------------------------------------------------------------------------------------------------------
clickHandler :: (.command -> .state -> .state) (MarkUpEvent .command) .state -> .state
// -----------------------------------------------------------------------------------------------------------------------
clickHandler execute event pstate
	| event.meSelectEvent						= pstate
	= execute event.meLink pstate

// -----------------------------------------------------------------------------------------------------------------------
sendHandler :: !(RId command) (MarkUpEvent command) !*(PSt .state) -> *PSt .state
// -----------------------------------------------------------------------------------------------------------------------
sendHandler rid event pstate
	| event.meSelectEvent						= pstate
	= snd (asyncSend rid event.meLink pstate)


// -----------------------------------------------------------------------------------------------------------------------
toText :: !(MarkUpText a) -> !String
// -----------------------------------------------------------------------------------------------------------------------
toText [CmText text: rest]			= text +++ toText rest
toText [CmBText text: rest]			= text +++ toText rest
toText [CmIText text: rest]			= text +++ toText rest
toText [CmSpaces nr: rest]			= {c \\ c <- repeatn nr ' '} +++ toText rest
toText [CmNewline: rest]			= "\n" +++ toText rest
toText [CmLink text link: rest]		= text +++ toText rest
toText [CmLink2 _ text link: rest]	= text +++ toText rest
toText [other: rest]				= toText rest
toText []							= ""








// -----------------------------------------------------------------------------------------------------------------------
openButtonId :: !*env -> (!ButtonId, !*env) | Ids env
// -----------------------------------------------------------------------------------------------------------------------
openButtonId env
	# (id, env)							= openId env
	# (markup_rid, env)					= openRId env
	# (control_rid, env)				= openRId env
	= ((id, markup_rid, control_rid), env)

// -----------------------------------------------------------------------------------------------------------------------
openButtonIds :: !Int !*env -> (![ButtonId], !*env) | Ids env
// -----------------------------------------------------------------------------------------------------------------------
openButtonIds 0 env
	= ([], env)
openButtonIds n env
	# (bid, env)						= openButtonId env
	# (bids, env)						= openButtonIds (n-1) env
	= ([bid:bids], env)

// -----------------------------------------------------------------------------------------------------------------------
MarkUpButton :: !String !Colour !((*PSt .pstate) -> *PSt .pstate) !ButtonId ![ControlAttribute *(.lstate,*PSt .pstate)] -> CompoundControl (:+: (Receiver Bool) (MarkUpState Bool)) .lstate *(PSt .pstate)
// -----------------------------------------------------------------------------------------------------------------------
MarkUpButton title colour event_handler (control_id, markup_rid, control_rid) attrs
	# able_text							= [CmBold, CmHorSpace 3, CmText title, CmHorSpace 3, CmEndBold]
	# disable_text						= [CmBold, CmHorSpace 3, CmColour Grey, CmText title, CmEndColour, CmHorSpace 3, CmEndBold]
	# able								= check attrs
	= CompoundControl 
		(		Receiver				control_rid (receive able_text disable_text)
											[]
			:+:	MarkUpControl			(if able able_text disable_text)
											[ MarkUpFontFace				"Arial Narrow"
											, MarkUpTextSize				8
											, MarkUpBackgroundColour		colour
											, MarkUpSpecialClick			button_down button_up
											, MarkUpEventHandler			(clickHandler handler)
											, MarkUpReceiver				markup_rid
											]
											[]
		)
		[ ControlItemSpace				1 1
		, ControlHMargin				1 1
		, ControlVMargin				1 1
		, ControlLook					True (\_ {newFrame} -> drawFun False newFrame)
		, ControlId						control_id
		: attrs
		]
	where
		handler cmd pstate
			= event_handler pstate
		
		receive able_text disable_text False (lstate,pstate)
			# pstate					= appPIO (disableControl control_id) pstate
			# pstate					= changeMarkUpText markup_rid disable_text pstate
			= (lstate, pstate)
		receive able_text disable_text True (lstate, pstate)
			# pstate					= appPIO (enableControl control_id) pstate
			# pstate					= changeMarkUpText markup_rid able_text pstate
			= (lstate, pstate)
		
		drawFun :: !Bool !Rectangle !*Picture -> *Picture
		drawFun active rect pict
			# x1						= rect.corner1.x
			# x2						= rect.corner2.x-1
			# y1						= rect.corner1.y
			# y2						= rect.corner2.y-1
			# pict						= setPenColour (if active Black White) pict
			# pict						= drawLine {x=x1,y=y1} {x=x2,y=y1} pict
			# pict						= drawLine {x=x1,y=y1} {x=x1,y=y2} pict
			# pict						= setPenColour (if active White Black) pict
			# pict						= drawLine {x=x2,y=y1} {x=x2,y=y2} pict
			# pict						= drawLine {x=x2,y=y2} {x=x1,y=y2} pict
			= pict
		
		button_down :: !*(PSt .pstate) -> *PSt .pstate
		button_down pstate
			# new_look					= \_ {newFrame} -> drawFun True newFrame
			# pstate					= appPIO (setControlLook control_id True (True, new_look)) pstate
			= pstate
		
//		button_up :: !*(PSt .pstate) -> *PSt .pstate
		button_up pstate
			# new_look					= \_ {newFrame} -> drawFun False newFrame
			# pstate					= appPIO (setControlLook control_id True (True, new_look)) pstate
			= event_handler pstate
		
		check []								= True
		check [ControlSelectState Unable:_]		= False
		check [ControlSelectState Able:_]		= True
		check [attr: attrs]						= check attrs

// -----------------------------------------------------------------------------------------------------------------------
enableButton :: !ButtonId !*(PSt .ls) -> *PSt .ls
// -----------------------------------------------------------------------------------------------------------------------
enableButton (control_id, markup_rid, control_rid) pstate
	= snd (asyncSend control_rid True pstate)

// -----------------------------------------------------------------------------------------------------------------------
enableButtons :: ![ButtonId] !*(PSt .ls) -> *PSt .ls
// -----------------------------------------------------------------------------------------------------------------------
enableButtons [id:ids] pstate
	# pstate									= enableButton id pstate
	# pstate									= enableButtons ids pstate
	= pstate
enableButtons [] pstate
	= pstate

// -----------------------------------------------------------------------------------------------------------------------
disableButton :: !ButtonId !*(PSt .ls) -> *PSt .ls
// -----------------------------------------------------------------------------------------------------------------------
disableButton (control_id, markup_rid, control_rid) pstate
	= snd (asyncSend control_rid False pstate)

// -----------------------------------------------------------------------------------------------------------------------
disableButtons :: ![ButtonId] !*(PSt .ls) -> *PSt .ls
// -----------------------------------------------------------------------------------------------------------------------
disableButtons [id:ids] pstate
	# pstate									= disableButton id pstate
	# pstate									= disableButtons ids pstate
	= pstate
disableButtons [] pstate
	= pstate


// -----------------------------------------------------------------------------------------------------------------------
changeButtonText :: !ButtonId !String !*(PSt .ls) -> *PSt .ls
// -----------------------------------------------------------------------------------------------------------------------
changeButtonText id text pstate
	# button_text						= [CmBold, CmHorSpace 3, CmText text, CmHorSpace 3, CmEndBold]
	= changeMarkUpText (snd3 id) button_text pstate















// -----------------------------------------------------------------------------------------------------------------------
:: ResizeType =
// -----------------------------------------------------------------------------------------------------------------------
	  DoNotResize
	| ResizeHor
	| ResizeVer
	| ResizeHorVer

// -----------------------------------------------------------------------------------------------------------------------
resize :: !ResizeType !Size !Size !Size -> Size
// -----------------------------------------------------------------------------------------------------------------------
resize DoNotResize current_control_size old_window_size new_window_size
	= current_control_size
resize ResizeHor current_control_size old_window_size new_window_size
	=	{ w		= current_control_size.w + new_window_size.w - old_window_size.w
		, h		= current_control_size.h
		}
resize ResizeVer current_control_size old_window_size new_window_size
	=	{ w		= current_control_size.w
		, h		= current_control_size.h + new_window_size.h - old_window_size.h
		}
resize ResizeHorVer current_control_size old_window_size new_window_size
	=	{ w		= current_control_size.w + new_window_size.w - old_window_size.w
		, h		= current_control_size.h + new_window_size.h - old_window_size.h
		}

// -----------------------------------------------------------------------------------------------------------------------
boxedMarkUp :: .Colour .ResizeType [.(MarkUpCommand a)] [.(MarkUpAttribute a *(PSt .b))] [.(ControlAttribute *(.c,*(PSt .b)))] -> .(CompoundControl (MarkUpState a) .c *(PSt .b))
// -----------------------------------------------------------------------------------------------------------------------
boxedMarkUp colour resize_type text markup_attrs attrs
	#! mb_receiver_id					= find_receiver_id markup_attrs
	= CompoundControl markup1
			[ ControlHMargin			1 1
			, ControlVMargin			1 1
			, ControlItemSpace			1 1
			, ControlLook				True (\_ {newFrame} -> seq [setPenColour colour, draw newFrame])
			, ControlResize				(resize resize_type)
			, ControlMouse				(\x -> True) Able (myMouseFunction mb_receiver_id)
			: attrs
			]
	where
		markup1
			= MarkUpControl text markup_attrs
				[ ControlResize			(resize resize_type)
				]
		
		myMouseFunction (Just rid) _ (lstate, pstate)
			#! pstate					= deactiveMarkUp rid pstate
			= (lstate, pstate)
		myMouseFunction Nothing _ (lstate, pstate)
			= (lstate, pstate)
		
		find_receiver_id [MarkUpReceiver id: _]
			= Just id
		find_receiver_id [_: attrs]
			= find_receiver_id attrs
		find_receiver_id []
			= Nothing

// -----------------------------------------------------------------------------------------------------------------------
titledMarkUp :: !Colour !Colour !ResizeType !(MarkUpText a) !(MarkUpText b) ![MarkUpAttribute b .c] ![ControlAttribute *(.d,.c)] -> CompoundControl (:+: (MarkUpState a) (:+: CustomControl (MarkUpState b))) .d .c
// -----------------------------------------------------------------------------------------------------------------------
titledMarkUp border_colour title_bg_colour resize_type title text markup_attrs attrs
	# (vscroll, first_width)			= check markup_attrs
	= CompoundControl (markup1 vscroll :+: space vscroll first_width :+: markup2)
			[ ControlHMargin			1 1
			, ControlVMargin			1 1
			, ControlItemSpace			0 0
			, ControlLook				True (\_ {newFrame} -> seq [setPenColour border_colour, draw newFrame])
			, ControlResize				(resize resize_type)
			: attrs
			]
	where
		markup1 vscroll
			= MarkUpControl title
				[ MarkUpBackgroundColour	title_bg_colour
				: for_title vscroll markup_attrs
				]
				[ ControlResize			(resize (strip_ver_resize resize_type))
				]
		space vscroll first_width
			# (metrics, _)				= osDefaultWindowMetrics 42
			# width						= case vscroll of
											True	-> first_width + metrics.osmVSliderWidth
											False	-> first_width
			= CustomControl {w=width,h=1} (\_ {newFrame} -> seq [setPenColour border_colour, draw newFrame])
				[ ControlPos			(Left, zero)
				, ControlResize			(resize (strip_ver_resize resize_type))
				]
		markup2
			= MarkUpControl text markup_attrs
				[ ControlResize			(resize resize_type)
				, ControlPos			(Left, zero)
				]
		
		strip_ver_resize ResizeVer					= DoNotResize
		strip_ver_resize ResizeHorVer				= ResizeHor
		strip_ver_resize other						= other
		
		for_title vscroll [MarkUpFontFace face: attrs]
			= [MarkUpFontFace face: for_title vscroll attrs]
		for_title vscroll [MarkUpTextSize size: attrs]
			= [MarkUpTextSize size: for_title vscroll attrs]
		for_title vscroll [MarkUpWidth width: attrs]
			# (metrics, _)				= osDefaultWindowMetrics 42
			# width						= case vscroll of
											True	-> width + metrics.osmVSliderWidth
											False	-> width
			= [MarkUpWidth width: for_title vscroll attrs]
//		for_title vscroll [MarkUpBackgroundColour colour: attrs]
//			= [MarkUpBackgroundColour colour: for_title vscroll attrs]
		for_title vscroll [_:attrs]
			= for_title vscroll attrs
		for_title vscroll []
			= []
		
		check []
			= (False, 0)
		check [MarkUpVScroll:attrs]
			# (_, width)							= check attrs
			= (True, width)
		check [MarkUpWidth width:attrs]
			# (vscroll, _)							= check attrs
			= (vscroll, width)
		check [_:attrs]
			= check attrs
			







// ------------------------------------------------------------------------------------------------------------------------
rectifyDialog :: !(MarkUpText Bool) !*(PSt .a) -> (!Bool, !*PSt .a)
// ------------------------------------------------------------------------------------------------------------------------
rectifyDialog ftext pstate
	# (dialog_id, pstate)					= accPIO openId pstate
	# (yes_id, pstate)						= accPIO openId pstate
	# (no_id, pstate)						= accPIO openId pstate
	# ((_, mb_ok), pstate)					= openModalDialog True (rectify dialog_id yes_id no_id) pstate
	| isNothing mb_ok						= (False, pstate)
	= (fromJust mb_ok, pstate)
	where
		rectify dialog_id yes_id no_id
			= Dialog "Rectify"
				(		MarkUpControl		([ CmSpaces	2
											: ftext
											] ++ 
											[ CmSpaces	2
											])
												[ MarkUpFontFace				"Times New Roman"
												, MarkUpTextSize				10
												, MarkUpBackgroundColour		getDialogBackgroundColour
												]
												[]
					:+:	ButtonControl		"No"
												[ ControlId						no_id
												, ControlFunction				(cancel dialog_id)
												, ControlPos					(Right, OffsetVector {vx=0, vy=10})
												]
					:+:	ButtonControl		"Yes"
												[ ControlId						yes_id
												, ControlFunction				(ok dialog_id)
												, ControlPos					(LeftOf no_id, zero)
												]
				)
				[ WindowId							dialog_id
				, WindowClose						(cancel dialog_id)
				, WindowOk							yes_id
				, WindowCancel						no_id
				]
		
		cancel :: !Id !(!Bool, !*PSt .a) -> (!Bool, !*PSt .a)
		cancel dialog_id (_, pstate)
			= (False, closeWindow dialog_id pstate)
		
		ok :: !Id !(!Bool, !*PSt .a) -> (!Bool, !*PSt .a)
		ok dialog_id (_, pstate)
			= (True, closeWindow dialog_id pstate)