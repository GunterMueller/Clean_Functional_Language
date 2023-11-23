implementation module
	MarkUpText

import
	StdEnv,
	StdIO,
	MdM_IOlib
	, RWSDebug

// -----------------------------------------------------------------------------------------------------------------------
:: MarkUpCommand a =
// -----------------------------------------------------------------------------------------------------------------------
	  CmText				!String			
	| CmBText				!String				| CmIText				!String		| CmUText		!String
	| CmNewline									| CmFillLine						| CmStartOfLine
	| CmScope									| CmEndScope
	| CmAlign				!String
	| CmCenter									| CmBGCenter			!Colour
	| CmRight									| CmBGRight				!Colour
	| CmHorSpace			!Int				| CmTabSpace
	| CmBold									| CmEndBold
	| CmItalic									| CmEndItalic
	| CmUnderline								| CmEndUnderline
	| CmSize				!Int				| CmChangeSize			!Int		| CmEndSize
	| CmColour				!Colour				| CmEndColour
	| CmBackgroundColour	!Colour				| CmEndBackgroundColour
	| CmFont				!FontDef			| CmEndFont
	| CmFontFace			!String				| CmEndFontFace
	| CmLink				!String a
	| CmLabel				!String

	| Cm_Word				!String !Font !FontMetrics !Int !Colour !Colour								    // word, font, fontmetrics, width, colour, bgcolour
	| Cm_Link				!String a !FontMetrics !Int (!Font, !Colour, !Colour) (!Font, !Colour, !Colour) // as above, but 2 styles: one for normal link, one for selected link
	| Cm_HorSpace			!Int !Colour																    // width, bgcolour (if width = -1, fill to end of line)

// -----------------------------------------------------------------------------------------------------------------------
:: MarkUpText a :== [MarkUpCommand a]
// -----------------------------------------------------------------------------------------------------------------------

// -----------------------------------------------------------------------------------------------------------------------
:: MarkUpAttribute a ps =
// -----------------------------------------------------------------------------------------------------------------------
	  MarkUpWidth				!Int
	| MarkUpMaxWidth			!Int
	| MarkUpHeight				!Int
	| MarkUpMaxHeight			!Int
	| MarkUpTextColour			!Colour
	| MarkUpTextSize			!Int
	| MarkUpBackgroundColour	!Colour
	| MarkUpFont				!FontDef
	| MarkUpFontFace			!String
	| MarkUpLinkStyle			!Bool !Colour !Colour !Bool !Colour !Colour
	| MarkUpEventHandler		((!MarkUpEvent a) -> Id -> (RId (MarkUpMessage a)) -> ps -> ps)
	| MarkUpNrLines				!Int
	| MarkUpIgnoreMultipleSpaces
	| MarkUpReceiver			(!RId (MarkUpMessage a))
	| MarkUpInWindow			!Id

// -----------------------------------------------------------------------------------------------------------------------
:: MarkUpEvent a =
// -----------------------------------------------------------------------------------------------------------------------
	  MarkUpLinkSelected		a
	| MarkUpLinkClicked			!Int a

// -----------------------------------------------------------------------------------------------------------------------
:: MarkUpState a ls ps =
// -----------------------------------------------------------------------------------------------------------------------
	{ musCommands				:: [!MarkUpCommand a]
	, musCustomAttributes		:: [!MarkUpAttribute a ps]
	, musControlAttributes		:: [!ControlAttribute *(MarkUpLocalState a ps, ps)]
	, musWindowAttributes		:: [!WindowAttribute *(MarkUpLocalState a ps, ps)]
	, musIsControl				:: !Bool
	}

// -----------------------------------------------------------------------------------------------------------------------
:: MarkUpMessage a =
// -----------------------------------------------------------------------------------------------------------------------
	  MarkUpChangeText			!(MarkUpText a)
	| MarkUpJumpTo				!String

// -----------------------------------------------------------------------------------------------------------------------
:: MarkUpLocalState a ps =
// -----------------------------------------------------------------------------------------------------------------------
	{ mulIsControl					:: !Bool
	, mulId							:: !Id
//	, mulWindowId					:: Id					// lazy -- sometimes gets an abort 
	, mulReceiverId					:: (!RId (MarkUpMessage a))
	, mulCommands					:: [!MarkUpCommand a]
	, mulViewDomain					:: !ViewDomain
	, mulViewSize					:: !Size
	, mulDrawFunctions				:: [(!Rectangle, *Picture -> *Picture)]
	, mulHighlightDrawFunctions		:: [(!Rectangle, !Int, a, *Picture -> *Picture)]
	, mulActiveLink					:: !Int
	, mulWidth						:: !Int
	, mulMaxWidth					:: !Int
	, mulHeight						:: !Int
	, mulMaxHeight					:: !Int
	, mulIgnoreMultipleSpaces		:: !Bool
	, mulNrLines					:: !Int
	, mulNormalLink					:: (!Bool, !Colour, !Colour)
	, mulSelectedLink				:: (!Bool, !Colour, !Colour)
	, mulInitialColour				:: !Colour
	, mulInitialFontDef				:: !FontDef
	, mulInitialBackgroundColour	:: !Colour
	, mulEventHandler				:: ((!MarkUpEvent a) -> Id -> (RId (MarkUpMessage a)) -> ps -> ps)
	, mulBaselines					:: [!Int]				// for each line: fAscent + fDescent of largest font
	, mulSkips						:: [!Int]				// for each line: fLeading of largest font
	, mulScopes						:: [!Scope]
	, mulLabels						:: [(!String, !Int, !Int)]
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
:: AlignInfo =
// -----------------------------------------------------------------------------------------------------------------------
	{ aliName		:: !String
	, aliRelativeX	:: [!RelativeX]
	, aliAbsoluteX	:: !Int
	}

// -----------------------------------------------------------------------------------------------------------------------
:: Scope :== [!AlignInfo]
// -----------------------------------------------------------------------------------------------------------------------

// -----------------------------------------------------------------------------------------------------------------------
filterTab :: !String -> !String
// -----------------------------------------------------------------------------------------------------------------------
filterTab text
	= filter_tabs text 0
	where
		filter_tabs text index
			| index >= size text			= text
			| text.[index] == '	'			= filter_tabs (text := (index, ' ')) (index+1)
			= filter_tabs text (index+1)

// -----------------------------------------------------------------------------------------------------------------------
filterTabs :: [!MarkUpCommand a] -> [!MarkUpCommand a]
// -----------------------------------------------------------------------------------------------------------------------
filterTabs [CmText text: cmds]
	= [CmText (filterTab text): filterTabs cmds]
filterTabs [other: cmds]
	= [other: filterTabs cmds]
filterTabs []
	= []

// -----------------------------------------------------------------------------------------------------------------------
addConstraint :: !Int !String !RelativeX [!Scope] -> [!Scope]
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
replaceRelativeConstraint :: [!Scope] !Int !String !Int -> [!Scope]
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
getAbsoluteConstraint :: [!Scope] !Int !String -> !Int
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
	# (the_id, state)				= case mstate.musIsControl of
										True	-> get_cid mstate.musControlAttributes state
										False	-> get_wid mstate.musWindowAttributes state
//	# maybe_iid						= get_iid mstate.musCustomAttributes
//	# iid							= if (isJust maybe_iid) (fromJust maybe_iid) (abort "Error: did not give MarkUpInWindow attribute")
	# (the_rid, state)				= get_rid mstate.musCustomAttributes state
	# (font, state)					= accPIO (accScreenPicture openDialogFont) state
	# fontdef						= getFontDef font
	# initial_mstate				= 	{ mulIsControl					= mstate.musIsControl
										, mulId							= the_id
//										, mulWindowId					= iid
										, mulReceiverId					= the_rid
										, mulCommands					= filterTabs mstate.musCommands
										, mulViewDomain					= zero
										, mulViewSize					= zero
										, mulDrawFunctions				= []
										, mulHighlightDrawFunctions		= []
										, mulActiveLink					= -1						// index in mulDrawFunctions
										, mulWidth						= 0
										, mulMaxWidth					= 0
										, mulHeight						= 0
										, mulMaxHeight					= 0
										, mulIgnoreMultipleSpaces		= False
										, mulNrLines					= -1
										, mulNormalLink					= (True, Blue, White)
										, mulSelectedLink				= (True, Red, White)
										, mulInitialColour				= Black
										, mulInitialFontDef				= fontdef
										, mulInitialBackgroundColour	= White
										, mulEventHandler				= (\x y z -> id)
										, mulBaselines					= []
										, mulSkips						= []
										, mulScopes						= [[{aliName = "_START_", aliRelativeX = [RX_Solved 0], aliAbsoluteX = (-1)}]]
										, mulLabels						= []
										}
	# (override, initial_mstate)	= checkAttributes initial_mstate False mstate.musCustomAttributes
	# initial_mstate				= if (not override) {initial_mstate & mulNormalLink   = change3 initial_mstate.mulInitialBackgroundColour initial_mstate.mulNormalLink} initial_mstate
	# initial_mstate				= if (not override) {initial_mstate & mulSelectedLink = change3 initial_mstate.mulInitialBackgroundColour initial_mstate.mulSelectedLink} initial_mstate
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
			= checkAttributes {mstate & mulNormalLink   = (nunderline, ncolour, nbgcolour), 
								        mulSelectedLink = (sunderline, scolour, sbgcolour)} True attrs
		checkAttributes mstate override_link [MarkUpEventHandler eventhandler: attrs]
			= checkAttributes {mstate & mulEventHandler = eventhandler} override_link attrs
		checkAttributes mstate override_link [MarkUpNrLines nrlines: attrs]
			= checkAttributes {mstate & mulNrLines = nrlines} override_link attrs
		checkAttributes mstate override_link [MarkUpIgnoreMultipleSpaces: attrs]
			= checkAttributes {mstate & mulIgnoreMultipleSpaces = True} override_link attrs
		checkAttributes mstate override_link [MarkUpReceiver rid: attrs]
			= checkAttributes mstate override_link attrs
		checkAttributes mstate override_link []
			= (override_link, mstate)

// -----------------------------------------------------------------------------------------------------------------------
makeCm_s :: (!MarkUpLocalState a (*PSt .ps)) (*PSt .ps) -> (!MarkUpLocalState a (*PSt .ps), *PSt .ps)
// -----------------------------------------------------------------------------------------------------------------------
makeCm_s mstate=:{mulCommands, mulInitialFontDef, mulInitialColour, mulInitialBackgroundColour, mulIgnoreMultipleSpaces} state
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
			# ((_, font), state)	= openFont fontdef state
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
				
				make_commands wordsofar spacessofar [c: cs] font space_width state
					# spacessofar					= if (mulIgnoreMultipleSpaces && spacessofar > 1) 1 spacessofar
					| c == ' ' && wordsofar == ""	= make_commands wordsofar (spacessofar+1) cs font space_width state
					| c == ' ' && wordsofar <> ""	= let (commands, state1)	= make_commands "" 1 cs font space_width state
														  (wordcmd, state2)		= make_word_command wordsofar font state1
													   in ([wordcmd: commands], state2)
					| c <> ' ' && spacessofar == 0	= make_commands (wordsofar +++ toString c) spacessofar cs font space_width state
					| c <> ' ' && spacessofar <> 0	= let (commands, state1)	= make_commands (toString c) 0 cs font space_width state
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
					# (width, state)	= getFontStringWidth font word state
					# (metrics, state)	= getFontMetrics font state
					# cm_word			= Cm_Word word font metrics width colour bgcolour
					= (cm_word, state)
		check_commands [CmNewline: commands] fontdefs colours bgcolours no_leading_spaces state
			# (commands, state)		= check_commands commands fontdefs colours bgcolours False state
			= ([CmNewline: commands], state)
		check_commands [CmStartOfLine: commands] fontdefs colours bgcolours no_leading_spaces state
			# (commands, state)		= check_commands commands fontdefs colours bgcolours False state
			= ([CmStartOfLine: commands], state)
		check_commands [CmAlign name: commands] fontdefs colours bgcolours no_leading_spaces state
			# (commands, state)		= check_commands commands fontdefs colours bgcolours False state
			= ([CmAlign name: commands], state)
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
		check_commands [CmTabSpace: commands] [fontdef: fontdefs] colours [bgcolour: bgcolours] no_leading_spaces state
			# (commands, state)		= check_commands commands [fontdef: fontdefs] colours [bgcolour: bgcolours] False state
			# ((_, font), state)	= openFont fontdef state
			# (width, state)		= getFontStringWidth font "atab" state
			= ([Cm_HorSpace width bgcolour: commands], state)
		check_commands [CmBold: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands [{fontdef & fStyles = ["Bold": fontdef.fStyles]}: [fontdef: fontdefs]] colours bgcolours no_leading_spaces state
		check_commands [CmEndBold: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmItalic: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands [{fontdef & fStyles = ["Italic": fontdef.fStyles]}: [fontdef: fontdefs]] colours bgcolours no_leading_spaces state
		check_commands [CmEndItalic: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmUnderline: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands [{fontdef & fStyles = ["Underline": fontdef.fStyles]}: [fontdef: fontdefs]] colours bgcolours no_leading_spaces state
		check_commands [CmEndUnderline: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmSize size: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands [{fontdef & fSize = size}: [fontdef: fontdefs]] colours bgcolours no_leading_spaces state
		check_commands [CmChangeSize size: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands [{fontdef & fSize = fontdef.fSize + size}: [fontdef: fontdefs]] colours bgcolours no_leading_spaces state
		check_commands [CmEndSize: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
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
		check_commands [CmEndFont: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmFontFace face: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands [{fontdef & fName = face}: [fontdef: fontdefs]] colours bgcolours no_leading_spaces state
		check_commands [CmEndFontFace: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			= check_commands commands fontdefs colours bgcolours no_leading_spaces state
		check_commands [CmLink text value: commands] [fontdef: fontdefs] colours bgcolours no_leading_spaces state
			# (commands, state)		= check_commands commands [fontdef: fontdefs] colours bgcolours False state
			# normal_fontdef		= if (fst3 mstate.mulNormalLink)   {fontdef & fStyles = ["Underline": fontdef.fStyles]} fontdef
			# selected_fontdef		= if (fst3 mstate.mulSelectedLink) {fontdef & fStyles = ["Underline": fontdef.fStyles]} fontdef
			# ((_, n_font), state)	= openFont normal_fontdef state
			# ((_, s_font), state)	= openFont selected_fontdef state
			# (metrics, state)		= getFontMetrics n_font state
			# (width, state)		= getFontStringWidth n_font text state
			# cm_link				= Cm_Link text value metrics width (n_font, snd3 mstate.mulNormalLink,   thd3 mstate.mulNormalLink)
															 		   (s_font, snd3 mstate.mulSelectedLink, thd3 mstate.mulSelectedLink)
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
			# baseline					= max baseline /*(metrics.fAscent + metrics.fDescent)*/ (metrics.fAscent + metrics.fLeading)
			# skip						= max skip /*metrics.fLeading*/metrics.fDescent
			= compute_metrics (baseline, skip) commands
		compute_metrics (baseline, skip) [Cm_Link _ _ metrics width _ _: commands]
			# baseline					= max baseline /*(metrics.fAscent + metrics.fDescent)*/ (metrics.fAscent + metrics.fLeading)
			# skip						= max skip /*metrics.fLeading*/metrics.fDescent
			= compute_metrics (baseline, skip) commands
		compute_metrics (baseline, skip) [CmNewline: commands]
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
		check_aligns scope_stack next_scope scopes relx [CmNewline: commands]
			= check_aligns scope_stack next_scope scopes (RX_Align (hd scope_stack) "_START_" 0) commands
		check_aligns scope_stack next_scope scopes relx [CmStartOfLine: commands]
			= check_aligns scope_stack next_scope scopes (RX_Align (hd scope_stack) "_START_" 0) commands
		check_aligns scope_stack next_scope scopes relx [CmAlign align: commands]
			# scopes					= addConstraint (hd scope_stack) align relx scopes
			= check_aligns scope_stack next_scope scopes (RX_Align (hd scope_stack) align 0) commands
		check_aligns scope_stack next_scope scopes relx [CmBGRight bgcolour: commands]
			= check_aligns scope_stack next_scope scopes relx commands
		check_aligns scope_stack next_scope scopes relx [CmBGCenter bgcolour: commands]
			= check_aligns scope_stack next_scope scopes relx commands
		check_aligns scope_stack next_scope scopes relx [CmLabel label: commands]
			= check_aligns scope_stack next_scope scopes relx commands
		check_aligns _ _ scopes _ []
			= scopes
		check_aligns _ _ _ _ [other: rest]
			= abort "check_aligns in module MarkUpText: found a MarkUpCommand which should have been filtered"

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
		solveScopes :: [!Scope] -> (!Bool, [!Scope])
		// ------------------------------------------
		solveScopes scopes
			# (scopes, finished)	= collect_finished_aligns_in_scope 0 scopes
			| isEmpty finished		= (False, scopes)
			# scopes				= change_all finished scopes
			= (True, scopes)
		
		// --------------------------------------------------------
		change_all :: [(!Int, !String, !Int)] [!Scope] -> [!Scope]
		// --------------------------------------------------------
		change_all [(scope, align, absx): changes] scopes
			# scopes					= replaceRelativeConstraint scopes scope align absx
			= change_all changes scopes
		change_all [] scopes
			= scopes
		
		// --------------------------------------------------------------------------------------
		collect_finished_aligns_in_scope :: !Int [!Scope] -> ([!Scope], [(!Int, !String, !Int)])
		// --------------------------------------------------------------------------------------
		collect_finished_aligns_in_scope num [scope: scopes]
			# (scope, finished1)		= collect_finished_aligns num scope
			# (scopes, finished2)		= collect_finished_aligns_in_scope (num+1) scopes
			= ([scope: scopes], finished1 ++ finished2)
		collect_finished_aligns_in_scope num []
			= ([], [])
		
		// -------------------------------------------------------------------------------------
		collect_finished_aligns :: !Int [!AlignInfo] -> ([!AlignInfo], [(!Int, !String, !Int)])
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
		compute_abs_x :: !Int [!RelativeX] -> !Int
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
		remove_cms :: !Int [!Int] !Int [!MarkUpCommand a] -> [!MarkUpCommand a]
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
		remove_cms x scopes free_scope [command=:CmNewline: commands]
			# x											= getAbsoluteConstraint mstate.mulScopes (hd scopes) "_START_"
			= [command: remove_cms x scopes free_scope commands]
		remove_cms x scopes free_scope [command=:CmStartOfLine: commands]
			# x											= getAbsoluteConstraint mstate.mulScopes (hd scopes) "_START_"
			= [command: remove_cms x scopes free_scope commands]
		remove_cms x scopes free_scope [command=:CmAlign name: commands]
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
		remove_cms x scopes free_scope [CmLabel label: commands]
			= [CmLabel label: remove_cms x scopes free_scope commands]
		remove_cms x scopes free_scope []
			= []
		
		// --------------------------------------------------------------------------------------------------------
		get_width_to_align :: !Int !Int [!MarkUpCommand a] -> (!Int, !Int, [!MarkUpCommand a], [!MarkUpCommand a])
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
		get_width_to_align scope width [command=:(CmAlign name): commands]
			# finalx									= getAbsoluteConstraint mstate.mulScopes scope name
			= (width, finalx, [], [command: commands])
		get_width_to_align scope width [command=:CmNewline: commands]
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
makeDrawFunctions :: (!MarkUpLocalState a (*PSt .p)) -> !MarkUpLocalState a (*PSt .p)
// -----------------------------------------------------------------------------------------------------------------------
makeDrawFunctions mstate
	# (drawfuns, highlightdrawfuns, labels)	= walk_through mstate.mulBaselines mstate.mulSkips [0] 1 0 zero mstate.mulCommands 0
	# mstate								= {mstate & mulDrawFunctions = drawfuns, mulHighlightDrawFunctions = highlightdrawfuns, mulLabels = labels}
	= mstate
	where
		walk_through :: ![Int] ![Int] [!Int] !Int !Int !Point2 ![MarkUpCommand .c] !Int 
					 -> (![(!Rectangle, (!*Picture -> .Picture))],[!(Rectangle,!Int,.c,.(!*Picture -> .Picture))], [(!String, !Int, !Int)])
		walk_through [baseline: baselines] [skip: skips] scopestack nextscope line point=:{x, y} [CmNewline: rest] num
			# x								= getAbsoluteConstraint mstate.mulScopes (hd scopestack) "_START_"
			# y								= y + baseline + skip
			= walk_through baselines skips scopestack nextscope (line+1) {x=x, y=y} rest num
		walk_through baselines skips scopestack nextscope line point=:{x,y} [CmStartOfLine: rest] num
			# x								= getAbsoluteConstraint mstate.mulScopes (hd scopestack) "_START_"
			= walk_through baselines skips scopestack nextscope line {x=x, y=y} rest num
		walk_through baselines skips scopestack nextscope line point=:{x,y} [CmScope: rest] num
			# scopestack					= [nextscope: scopestack]
			= walk_through baselines skips scopestack (nextscope+1) line point rest num
		walk_through baselines skips scopestack nextscope line point=:{x,y} [CmEndScope: rest] num
			= walk_through baselines skips (tl scopestack) nextscope line point rest num
		walk_through baselines skips scopestack nextscope line point=:{x,y} [CmAlign name: rest] num
			# x								= getAbsoluteConstraint mstate.mulScopes (hd scopestack) name
			= walk_through baselines skips scopestack nextscope line {x=x,y=y} rest num
		walk_through [baseline: baselines] [skip: skips] scopestack nextscope line point=:{x,y} [Cm_Word word font metrics width colour bgcolour: rest] num
			# rectangle						= {corner1 = {x=x,y=y+1/*+skip-1*/}, corner2 = {x=x+width, y=y+baseline+skip+1}}
			# draw							= seq	[ setPenColour		bgcolour
													, fill				rectangle
													, setPenColour		colour
													, setPenFont		font
													, drawAt			{x=x, y=y+baseline} word
													]
			# (normals, highlights, labels)	= walk_through [baseline: baselines] [skip: skips] scopestack nextscope line {x=x+width,y=y} rest (num+1)
			= ([(rectangle, draw): normals], highlights, labels)
		walk_through [baseline: baselines] [skip: skips] scopestack nextscope line point=:{x,y} [Cm_Link word value _ width (font1, colour1, bgcolour1) (font2, colour2, bgcolour2): rest] num
			# rectangle						= {corner1 = {x=x, y=y+1/*+skip-1*/}, corner2 = {x=x+width, y=y+baseline+skip+1}}
			# drawnormal					= seq	[ setPenColour		bgcolour1
													, fill				rectangle
													, setPenColour		colour1
													, setPenFont		font1
													, drawAt			{x=x, y=y+baseline} word
													]
			# drawselected					= seq	[ setPenColour		bgcolour2
													, fill				rectangle
													, setPenColour		colour2
													, setPenFont		font2
													, drawAt			{x=x, y=y+baseline} word
													]
			# (normals, highlights, labels)	= walk_through [baseline: baselines] [skip: skips] scopestack nextscope line {x=x+width,y=y} rest (num+1)
			= ([(rectangle, drawnormal): normals], [(rectangle, num, value, drawselected): highlights], labels)
		walk_through [baseline: baselines] [skip: skips] scopestack nextscope line point=:{x,y} [Cm_HorSpace width colour: rest] num
			# rectangle						= {corner1 = {x=x, y=y+1/*skip-1*/}, corner2 = {x=x+width, y=y+baseline+skip+1}}
			# fill_rectangle				= if (width >= 0) rectangle {rectangle & corner2.x = 10000}
			# draw							= seq	[ setPenColour		colour
													, fill				fill_rectangle
													]
			# (normals, highlights, labels)	= walk_through [baseline: baselines] [skip: skips] scopestack nextscope line {x=x+width,y=y} rest (num+1)
			= ([(rectangle, draw): normals], highlights, labels)
		walk_through baselines skips scopestack nextscope line point=:{x,y} [CmLabel label: rest] num
			# (normals, highlights, labels)	= walk_through baselines skips scopestack nextscope line point rest num
			= (normals, highlights, [(label,x,y): labels])
		walk_through baselines skips scopestack nextscope line point=:{x,y} [other: rest] num
			= walk_through baselines skips scopestack nextscope line point rest num
		walk_through baselines skips scopestack nextscope line point=:{x,y} [] num
			= ([], [], [])

// =======================================================================================================================
// For each CmFillLine a Cm_HorSpace with a negative width is created. This leads to an invalid rectangle. 
// These are corrected here, using the computed width of the control.
// -----------------------------------------------------------------------------------------------------------------------
replaceInvalidDrawFunctions :: !Int (!MarkUpLocalState a .ps) -> !MarkUpLocalState a .ps
// -----------------------------------------------------------------------------------------------------------------------
replaceInvalidDrawFunctions goodwidth mstate
	= {mstate & mulDrawFunctions = replace_drawfunctions goodwidth mstate.mulDrawFunctions}
	where
		replace_drawfunctions goodwidth [(rect, drawfun): drawfuns]
			# rect			= if (rect.corner2.x >= rect.corner1.x) rect {rect & corner2.x = goodwidth}
			= [(rect, drawfun): replace_drawfunctions goodwidth drawfuns]
		replace_drawfunctions _ []
			= []

// -----------------------------------------------------------------------------------------------------------------------
getArea :: !Point2 (!MarkUpLocalState a .ps) -> (!Int, !Rectangle, [a], *Picture -> *Picture)
// -----------------------------------------------------------------------------------------------------------------------
getArea point {mulHighlightDrawFunctions}
	= get_area point mulHighlightDrawFunctions
	where
		get_area point [(rectangle, index, value, drawfun): rest]
			| inRectangle point rectangle		= (index, rectangle, [value], drawfun)
			= get_area point rest
		get_area point []
			= ((-1), zero, [], id)

// -----------------------------------------------------------------------------------------------------------------------
updateLookFun :: !Bool !Id (*Picture -> *Picture) !Colour !SmartDrawFunction (*PSt .ps) -> *PSt .ps
// -----------------------------------------------------------------------------------------------------------------------
updateLookFun True controlid draw colour newlook state
	# state						= appPIO (appControlPicture controlid draw) state
	# state						= appPIO (setControlLook controlid False (True, SmartLook newlook (Just colour))) state
	= state
updateLookFun False windowid draw colour newlook state
	# state						= appPIO (appWindowPicture windowid draw) state
	# state						= appPIO (setWindowLook windowid False (True, SmartLook newlook (Just colour))) state
	= state

// -----------------------------------------------------------------------------------------------------------------------
// KeyboardFunction
// -----------------------------------------------------------------------------------------------------------------------
KeyboardFunction (CharKey 'P' (KeyDown _)) (mstate, state)
	# lookFunction				= SmartLook mstate.mulDrawFunctions (Just mstate.mulInitialBackgroundColour) Able
	# (printsetup, state)		= defaultPrintSetup state
	# size						= mstate.mulViewDomain
	# (printsetup, state)		= printUpdateFunction True lookFunction [size] printsetup state
	= (mstate, state)
KeyboardFunction other (mstate, state)
	= (mstate, state)

// -----------------------------------------------------------------------------------------------------------------------
// MouseFunction
// -----------------------------------------------------------------------------------------------------------------------
MouseFunction (MouseMove point modifiers) (mstate=:{mulIsControl, mulId, mulReceiverId, mulActiveLink, mulDrawFunctions, mulInitialBackgroundColour}, state)
	# (area, rect, value, seldrawfun)	= getArea point mstate
	# old_normdrawfun					= snd (mulDrawFunctions !! mulActiveLink)
	| area == mulActiveLink				= (mstate, state)
	# mstate							= {mstate & mulActiveLink = area}
	| area == (-1)						= (mstate, updateLookFun mulIsControl mulId old_normdrawfun mulInitialBackgroundColour mulDrawFunctions state)
	# new_draws							= (take area mulDrawFunctions) ++ [(rect, seldrawfun): drop (area+1) mulDrawFunctions]
	# direct_update						= if (mulActiveLink == (-1)) seldrawfun (seldrawfun o old_normdrawfun)
	# state								= updateLookFun mulIsControl mulId direct_update mulInitialBackgroundColour new_draws state
	# state								= mstate.mulEventHandler (MarkUpLinkSelected (hd value)) mulId mulReceiverId state
	= (mstate, state)
MouseFunction (MouseDown point modifiers nr_clicks) (mstate=:{mulId, mulReceiverId}, state)
	| mstate.mulActiveLink == (-1)		= (mstate, state)
	# filtered_hdraws					= filter (\(rect, index, value, draw) -> index == mstate.mulActiveLink) mstate.mulHighlightDrawFunctions
	| isEmpty filtered_hdraws			= (mstate, state)
	# (_, _, value, _)					= hd filtered_hdraws
	# state								= mstate.mulEventHandler (MarkUpLinkClicked nr_clicks value) mulId mulReceiverId state
	= (mstate, state)
MouseFunction other (mstate, state)
	= (mstate, state)

// -----------------------------------------------------------------------------------------------------------------------
computeViewSizeDomain :: (!MarkUpLocalState a .ps) -> (!Size, !ViewDomain, !Int, Int->Int)
// -----------------------------------------------------------------------------------------------------------------------
computeViewSizeDomain mstate
	# maxx				= if (isEmpty mstate.mulDrawFunctions) 0 (maxList [rect.corner2.x \\ (rect, draw) <- mstate.mulDrawFunctions])
	# maxy				= if (isEmpty mstate.mulDrawFunctions) 0 (maxList [rect.corner2.y \\ (rect, draw) <- mstate.mulDrawFunctions])
	# maxx				= max 1 maxx
	# maxy				= max 1 maxy
	# viewdomain		= {corner1 = zero, corner2 = {x = maxx, y = maxy}}
	# width				= if (mstate.mulWidth <> 0) mstate.mulWidth 
							(if (mstate.mulMaxWidth == 0) maxx (min mstate.mulMaxWidth maxx))
	# height			= if (mstate.mulHeight <> 0) mstate.mulHeight
							(if (mstate.mulMaxHeight == 0) maxy (min mstate.mulMaxHeight maxy))
	# lineheight		= if (isEmpty mstate.mulBaselines || isEmpty mstate.mulSkips) 0 (hd mstate.mulBaselines + hd mstate.mulSkips)
	# lineheight		= if (mstate.mulNrLines < 0) 10 lineheight
	# height			= if (mstate.mulNrLines < 0) height (lineheight * mstate.mulNrLines)
	# round				= if (mstate.mulNrLines < 0) id (roundfun lineheight)
	# viewsize			= {w = width, h = height}
	= (viewsize, viewdomain, lineheight, round)
	where
		roundfun :: !Int !Int -> !Int
		roundfun lineheight thumb_value
			# difference						= thumb_value - (thumb_value / lineheight) * lineheight
			| difference <= lineheight / 2		= thumb_value - difference
			| otherwise							= thumb_value + lineheight - difference


// -----------------------------------------------------------------------------------------------------------------------
MarkUpControl :: [!MarkUpCommand a] [!MarkUpAttribute a .ps] [!ControlAttribute *(MarkUpLocalState a .ps, .ps)] 
			  -> !MarkUpState a .ls .ps
// -----------------------------------------------------------------------------------------------------------------------
MarkUpControl commands custom_attributes control_attributes
	=	{ musCommands			= commands
		, musCustomAttributes	= custom_attributes
		, musControlAttributes	= control_attributes
		, musWindowAttributes	= []
		, musIsControl			= True
		}

// -----------------------------------------------------------------------------------------------------------------------
MarkUpWindow :: !String [!MarkUpCommand a] [!MarkUpAttribute a (*PSt .ps)] [!WindowAttribute *(MarkUpLocalState a (*PSt .ps), *PSt .ps)] (*PSt .ps) -> *PSt .ps
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
	# mstate						= computeMetrics mstate
	# mstate						= getAlignConstraints mstate
	# mstate						= solveAlignConstraints mstate
	# mstate						= removeCmCenterRight mstate
	# mstate						= makeDrawFunctions mstate
	# (vsize, vdomain, line, round)	= computeViewSizeDomain mstate
	# mstate						= {mstate & mulViewDomain = vdomain}
	# mstate						= replaceInvalidDrawFunctions vsize.w mstate
	# the_window					= Window title (Receiver mstate.mulReceiverId receiver [])
										([ WindowId				mstate.mulId
										 , WindowViewSize		vsize
										 , WindowViewDomain		vdomain
										 , WindowHScroll		(ScrollFunction 10 85 Horizontal id)
										 , WindowVScroll		(ScrollFunction line 85 Vertical round)
										 , WindowLook   		True (SmartLook mstate.mulDrawFunctions (Just mstate.mulInitialBackgroundColour))
										 , WindowMouse			(\x -> True) Able MouseFunction
										 , WindowKeyboard		(\x -> True) Able KeyboardFunction
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
			# mstate						= makeDrawFunctions mstate
			# (vsize, vdomain, line, round)	= computeViewSizeDomain mstate
			# mstate						= {mstate & mulViewDomain = vdomain}
			# mstate						= replaceInvalidDrawFunctions vsize.w mstate
			# newlook						= SmartLook mstate.mulDrawFunctions (Just mstate.mulInitialBackgroundColour)
			# re_look						= appPIO (setWindowLook mstate.mulId True (False, newlook))
			# re_domain						= appPIO (setWindowViewDomain mstate.mulId vdomain)
			# state							= re_domain state
			# state							= re_look state
			= (mstate, state)
		receiver (MarkUpJumpTo label) (mstate, state)
			# labels						= mstate.mulLabels
			# correct_labels				= filter (\(a,b,c) -> a == label) labels
			| isEmpty labels				= (mstate, state)
			# (_, x, y)						= hd correct_labels
			# (viewframe, state)			= accPIO (getWindowViewFrame mstate.mulId) state
			# vector						= {vx = x - viewframe.corner1.x, vy = y - viewframe.corner1.y}
			# state							= appPIO (moveWindowViewFrame mstate.mulId vector) state
			= (mstate, state)

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
		# mstate						= makeDrawFunctions mstate
		# (vsize, vdomain, line, round)	= computeViewSizeDomain mstate
		# mstate						= replaceInvalidDrawFunctions vsize.w mstate
		# the_control					= 	{ newLS		= mstate
											, newDef	= CompoundControl (Receiver mstate.mulReceiverId receiver []) 
															([ ControlId			mstate.mulId
															 , ControlViewSize 		vsize
															 , ControlViewDomain	vdomain
															 , ControlHScroll		(ScrollFunction 10 85 Horizontal id)
															 , ControlVScroll		(ScrollFunction line 85 Vertical round)
															 , ControlLook     		True (SmartLook mstate.mulDrawFunctions (Just mstate.mulInitialBackgroundColour))
															 , ControlMouse			(\x -> True) Able MouseFunction
															 , ControlKeyboard		(\x -> True) Able KeyboardFunction
											 				 ] ++ musControlAttributes)
											 }
		= controlToHandles the_control state
		where
			receiver :: (!MarkUpMessage a) (!MarkUpLocalState a (*PSt .ps), *PSt .ps) -> (!MarkUpLocalState a (*PSt .ps), *PSt .ps)
			receiver (MarkUpChangeText new_text) (mstate, state)
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
				# mstate						= makeDrawFunctions mstate
				# (vsize, vdomain, line, round)	= computeViewSizeDomain mstate
				# mstate						= {mstate & mulViewDomain = vdomain}
				# mstate						= replaceInvalidDrawFunctions vsize.w mstate
				# newlook						= SmartLook mstate.mulDrawFunctions (Just mstate.mulInitialBackgroundColour)
				# re_look						= appPIO (setControlLook mstate.mulId True (False, newlook))
				# re_domain						= appPIO (setControlViewDomain mstate.mulId vdomain)
				# state							= re_domain state
				# state							= re_look state
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
				# vector						= {vx = x - viewframe.corner1.x, vy = y - viewframe.corner1.y}
				# state							= appPIO (moveControlViewFrame mstate.mulId vector) state
				= (mstate, state)

// -----------------------------------------------------------------------------------------------------------------------
changeMarkUpText :: !(RId !(MarkUpMessage a)) !(MarkUpText a) !(*PSt .ps) -> !*PSt .ps
// -----------------------------------------------------------------------------------------------------------------------
changeMarkUpText rid text state
	= snd (syncSend rid (MarkUpChangeText text) state) 

// -----------------------------------------------------------------------------------------------------------------------
jumpToMarkUpLabel :: !(RId !(MarkUpMessage a)) !String !(*PSt .ps) -> !*PSt .ps
// -----------------------------------------------------------------------------------------------------------------------
jumpToMarkUpLabel rid label state
	= snd (syncSend rid (MarkUpJumpTo label) state) 

// -----------------------------------------------------------------------------------------------------------------------
toText :: !(MarkUpText a) -> !String
// -----------------------------------------------------------------------------------------------------------------------
toText [CmText text: rest]			= text +++ toText rest
toText [CmTabSpace: rest]			= "    " +++ toText rest
toText [CmNewline: rest]			= "\n" +++ toText rest
toText [other: rest]				= toText rest
toText []							= ""