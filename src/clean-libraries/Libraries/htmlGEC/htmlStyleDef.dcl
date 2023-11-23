definition module htmlStyleDef

import htmlDataDef

// a Clean data structure representing a subset of html Style


:: Style		= Style String [StyleOpt]

:: StyleOpt		=									
			//	Background Style
				Background			[BackgroundOpt]		// background : A shorthand property for setting all background properties in one declaration
				| BgAttach			AttachOpt			// background-attachment : sets whether a background image is fixed or scrolls with the rest of the page
				| BgColor			ColorOpt			// background-color : set the background color of an element
				| BgImage			ImageOpt			// background-image : sets the background image of an element
				| BgPosition		BgPosOpt			// background-position : initial position of the background image
				| BgRepeat			RepeatOpt			// background-repeat : Sets if/how a background image will be repeated
			//	Border Style
				| Border			[BorderOpt]			// border : shorthand property for setting all of the properties for the four borders in one declaration 
				| BdBottom			BorderOpt			// border-bottom : shorthand property for setting the width, style, and color of the bottom border of a box
				| BdBottomColor		ColorOption			// border-bottom-color : sets the color of the bottom border of a box
				| BdBottomStyle		BorderStyle			// border-bottom-style : sets the style of the bottom border of a box
				| BdBottomWidth		BorderWidth			// border-bottom-width : sets the width of the bottom border of a box
				| BdColor			ColorOpt			// border-color : color of the four borders
				| BdLeft			BorderOpt			// border-left : shorthand property for setting the width, style, and color of the left border of a box
				| BdLeftColor		ColorOption			// border-left-color : sets the color of the left border of a box
				| BdLeftStyle		BorderStyle			// border-left-style : sets the style of the left border of a box
				| BdLeftWidth		BorderWidth			// border-left-width : sets the width of the left border of a box
				| BdRight			BorderOpt			// border-right : shorthand property for setting the width, style, and color of the right border of a box
				| BdRightColor		ColorOption			// border-right-color : sets the color of the right border of a box
				| BdRightStyle		BorderStyle			// border-right-style : sets the style of the right border of a box
				| BdRightWidth		BorderWidth			// border-right-width : sets the width of the right border of a box
				| BdStyle			BorderStyle			// border-style : sets the style of the four borders. It can have from one to four values (top, right, bottom, left)
				| BdTop				BorderOpt			// border-top : shorthand property for setting the width, style, and color of the top border of a box
				| BdTopColor		ColorOption			// border-top-color : sets the color of the top border of a box
				| BdTopStyle		BorderStyle			// border-top-style : sets the style of the top border of a box
				| BdTopWidth		BorderWidth			// border-top-width : sets the width of the top border of a box
				| BdWidth			BorderWidth			// border-width : shorthand property for setting 'border-top-width', 'border-right-width', 'border-bottom-width', and 'border-left-width' at the same place in the style sheet
			//	Classification Style
				| ClassClear		ClearOpt			// clear : sets the sides of an element where other floating elements are not allowed
				| ClassCursor		CursorOpt			// cursor : specifies the type of cursor to be displayed
				| ClassDisplay		DisplayOpt			// display : sets how/if an element is displayed
				| ClassFloat		FloatOpt			// float : sets where an image or a text will appear in another element
				| ClassPos			PosOpt				// position : places an element in a static, relative, absolute or fixed position
				| ClassVisibility	VisibOpt			// visibility : sets if an element should be visible or invisible
			//	Dimension Style
				| DimHeight			SizeOpt				// height : sets the height of an element
				| DimLineHeight		LineSizeOpt			// line-height : sets the distance between lines
				| DimMaxHeight		MaxSizeOpt			// max-height : sets the maximum height of an element
				| DimMaxWidth		MaxSizeOpt			// max-width : sets the maximum width of an element
				| DimMinHeight		LengthOpt			// min-height : sets the minimum height of an element
				| DimMinWidth		LengthOpt			// min-width : sets the minimum width of an element
				| DimWidth			SizeOpt				// width : sets the width of an element
			// 	Font Style
				| FntFont			[FontOpt]			// font : shorthand property for setting all of the properties for a font in one declaration
				| FntFamily			String				// font-family : prioritized list of font family names and/or generic family names for an element
				| FntSize			FntSizeOpt			// font-size : sets the size of a font
				| FntSizeAdj		FntSizeAdjOpt		// font-size-adjust : specifies an aspect value for an element that will preserve the x-height of the first-choice font
				| FntStretch		StretchOpt			// font-stretch : condenses or expands the current font-family
				| FntStyle			FntStyleOpt			// font-style : sets the style of the font
				| FntVariant		VariantOpt			// font-variant : displays text in a small-caps font or a normal font
				| FntWeight			FntWeightOpt		// font-weight : sets the weight of a font
			// 	Generated Content Style
			// 	| GenContent		ContentOpt			// content : generates content in a document. Used with the :before and :after pseudo-elements
				| GenCounterIncr	CounterOpt			// counter-increment : sets how much the counter increments on each occurrence of a selector 
				| GenCounterReset	CounterOpt			// counter-reset : sets the value the counter is set to on each occurrence of a selector
				| GenQuotes			QuotesOpt			// quotes : sets the type of quotation marks
			// 	List and Marker Style
				| LstStyle			[LstStyleOpt]		// list-style : shorthand property for setting all of the properties for a list in one declaration
				| LstStyleImg		LstImgOpt			// list-style-image : sets an image as the list-item marker
				| LstStylePos		LstPosOpt			// list-style-position : sets where the list-item marker is placed in the list
				| LstStyleType		LstTypeOpt			// list-style-type : sets the type of the list-item marker
				| MarketOffset		MktOffsetOpt		// market-offset
			// 	Margin Style
				| MrgMargin			[MarginOpt]			// margin : shorthand property for setting the margin properties in one declaration
				| MrgBottom			SizeOpt				// margin-bottom : sets the bottom margin of an element
				| MrgLeft			SizeOpt				// margin-left : sets the left margin of an element
				| MrgRight			SizeOpt				// margin-right : sets the right margin of an element
				| MrgTop			SizeOpt				// margin-top : sets the top margin of an element
			// 	Outline Style
				| OlnOutline		[OutlineOpt]		// outline : shorthand property for setting all the outline properties in one declaration
				| OlnColor			OlnColorOpt			// outline-color : sets the color of the outline around an element
				| OlnStyle			OlnStyleOpt			// outline-style : sets the style of the outline around an element
				| OlnWidth			OlnWidthOpt			// outline-width : sets the width of the outline around an element
			// 	Padding Style
				| PadPadding		[LengthOpt]			// padding : shorthand property for setting all of  the padding properties in one declaration
				| PadBottom			LengthOpt			// padding-bottom : sets the bottom padding of an element
				| PadLeft			LengthOpt			// padding-left : sets the left padding of an element
				| PadRight			LengthOpt			// padding-right : sets the right padding of an element
				| PadTop			LengthOpt			// padding-top : sets the top padding of an element
			// 	Positioning Style
				| PosBottom			SizeOpt				// bottom : sets how far the bottom edge of an element is above/below the bottom edge of the parent element
				| PosClip			ClipOpt				// clip : sets the shape of an element. The element is clipped into this shape, and displayed
				| PosLeft			SizeOpt				// left : sets how far the left edge of an element is to the right/left of the left edge of the parent element
				| PosOverflow		OverflowOpt			// overflow : sets what happens if the content of an element overflow its area
				| PosRight			SizeOpt				// right : sets how far the right edge of an element is to the left/right of the right edge of the parent element
				| PosTop			SizeOpt				// top : sets how far the top edge of an element is above/below the top edge of the parent element
				| PosVertAlign		VertAlignOpt		// vertical-align : sets the vertical alignment of an element
				| PosZIndex			ZIndexOpt			// z-index : sets the stack order of an element
			// 	Table Style
				| TblBdCollapse		CollapseOpt			// border-collapse : sets the border model of a table
				| TblBdSpacing		[Int]				// border-spacing : sets the distance between the borders of adjacent cells (only for the "separated borders" model)
				| TblCaptSide		SideOpt				// caption-side : sets the position of the caption according to the table
				| TblEmptyCells		ShowHideOpt			// empty-cells : sets whether cells with no visible content should have borders or not (only for the "separated borders" model) 
				| TblLayout			LayoutOpt			// table-layout : sets the algorithm used to lay out the table
			// 	Text Style
				| TxtColor			ColorOption			// color : sets the color of a text
				| TxtDirection		TxtDir				// direction : sets the text direction
				| TxtLetterSpacing	SpacingOpt			// letter-spacing : increase or decrease the space between characters	
				| TxtAlign			AlignOpt			// text-align : aligns the text in an element
				| TxtDecoration		DecoraOpt			// text-decoration : adds decoration to text
				| TxtIndent			LengthOpt			// text-indent : indents the first line of text in an element
				| TxtShadow			ShadowOpt			// text-shadow
				| TxtTransform		TransformOpt		// text-transform : controls the letters in an element
				| TxtUnicodeBidi	UnicodeOpt			// unicode-bidi
				| TxtWhiteSpace		WhiteSpaceOpt		// white-space : sets how white space inside an element is handled
				| TxtWordSpacing	SpacingOpt			// word-spacing : increase or decrease the space between words


// Order by type name
:: AlignOpt		= Alt_Left 
				| Alt_Right 
				| Alt_Center
				| Alt_Justify

:: AttachOpt	= Ato_Fixed
				| Ato_Scroll

:: BackgroundOpt= `Bg_Attach	AttachOpt				// background-attachment
				| `Bg_Color		ColorOption				// background-color
				| `Bg_Image		ImageOpt				// background-image
				| `Bg_Position	BgPosOpt				// background-position
				| `Bg_Repeat	RepeatOpt				// background-repeat

:: BgPosOpt		= `Bgp_Position		BgVPosOpt BgHPosOpt
				| `Bgp_Percent		Int Int				// x-% y-% - first value is the horizontal position and the second value is the vertical
				| `Bgp_Pixel		Int Int				// x-pos y-pos - first value is the horizontal position and the second value is the vertical

:: BgHPosOpt	= Bgh_Left
				| Bgh_Center
				| Bgh_Right
				| Bgh_NoPos								// when it's not specified

:: BgVPosOpt	= Bgv_Top
				| Bgv_Center
				| Bgv_Bottom

:: BorderOpt	= `Bd_Color		ColorOption				// border-color
				| `Bd_Style		[BorderStyle]			// border-style
				| `Bd_Width		BorderWidth				// border-width
			
:: BorderStyle	= Bds_Dashed							// dashed border. Renders as solid in most browsers
				| Bds_Dotted							// dotted border. Renders as solid in most browsers
				| Bds_Double							// two borders. The width of the two borders are the same as the border-width value
				| Bds_Groove							// 3D grooved border. The effect depends on the border-color value
				| Bds_Hidden							// same as "none", except in border conflict resolution for table elements
				| Bds_Inset								// 3D inset border. The effect depends on the border-color value
				| Bds_None								// no border
				| Bds_Outset							// 3D outset border. The effect depends on the border-color value
				| Bds_Ridge								// 3D ridged border. The effect depends on the border-color value
				| Bds_Solid								// solid border
			
:: BorderWidth	= Bdw_Medium							// medium border
				| Bdw_Thick								// thick border
				| Bdw_Thin								// thin border
				| `Bdw_Length	Int						// define the thickness of the borders

:: ClearOpt		= Clo_Both								// no floating elements allowed on either the left or the right side
				| Clo_Left								// no floating elements allowed on the left side
				| Clo_None								// allows floating elements on both sides
				| Clo_Right								// no floating elements allowed on the right side
			
:: ClipOpt		= Cli_Auto								// browser sets the shape of the element
				| Cli_Shape	Int Int Int Int				// sets the shape of the element. The valid shape value is: rect (top, right, bottom, left)

:: CollapseOpt	= Coo_Collapse							// selects the collapsing borders model
				| Coo_Separate							// selects the separated borders model
			
:: ColorOpt		= `Color		ColorOption
				| Col_Transparent						// takes the background-color of the body element

:: CounterOpt	= Cto_Ident	String						// string defines a selector, id, or class that should reset the counter.
				| Cto_IdentInt	String Int				// string defines a selector, id, or class that should reset the counter. Int sets the value the counter is set to on each occurrence of the selector
				| Cto_None

:: CursorOpt	= Cuo_Auto								// auto : browser sets a cursor
				| Cuo_Crosshair							// crosshair : cursor render as a crosshair
				| Cuo_Default							// default : default cursor (often an arrow)
				| Cuo_Eresize							// e-resize : cursor indicates that an edge of a box is to be moved right (east)
				| Cuo_Help								// help : cursor indicates that help is available (often a question mark or a balloon)
				| Cuo_Move								// move : cursor indicates something that should be moved
				| Cuo_Ne_Resize							// ne-resize : cursor indicates that an edge of a box is to be moved up and right (north/east)
				| Cuo_N_Resize							// n-resize : cursor indicates that an edge of a box is to be moved up (north)
				| Cuo_Nw_Resize							// nw-resize : cursor indicates that an edge of a box is to be moved up and left (north/west)
				| Cuo_Pointer							// pointer : cursor render as a pointer (a hand) that indicates a link 
				| Cuo_Se_Resize							// se-resize : cursor indicates that an edge of a box is to be moved down and right (south/east)
				| Cuo_S_Resize							// s-resize : cursor indicates that an edge of a box is to be moved down (south)
				| Cuo_Sw_Resize							// sw-resize : cursor indicates that an edge of a box is to be moved down and left (south/west)
				| Cuo_Text								// text : cursor indicates text
				| `Cuo_Url		Url						// url of a custom cursor to be used
				| Cuo_Wait								// wait : cursor indicates that the program is busy (often a watch or an hourglass)
				| Cuo_W_Resize							// w-resize : cursor indicates that an edge of a box is to be moved left (west)

:: DecoraOpt	= Dec_Blink								// blinking text
				| Dec_Line_Through						// line through the text
				| Dec_None								// normal text
				| Dec_Overline							// line over the text
				| Dec_Underline							// line under the text

:: DisplayOpt	= Dio_Block								// displayed as a block-level element, with a line break before and after the element
				| Dio_Compact							// displayed as block-level or inline element depending on context
				| Dio_Inline							// displayed as an inline element, with no line break before or after the element
				| Dio_Inline_Table						// displayed as an inline table (like <table>), with no line break before or after the table
				| Dio_List_Item							// displayed as a list
				| Dio_Marker	
				| Dio_None								// not displayed
				| Dio_Run_In							// displayed as block-level or inline element depending on context
				| Dio_Table								// displayed as a block table (like <table>), with a line break before and after the table
				| Dio_Table_Row_Group					// displayed as a group of one or more rows (like <tbody>)
				| Dio_Table_Head_Group					// displayed as a group of one or more rows (like <thead>)
				| Dio_Table_Foot_Group					// displayed as a group of one or more rows (like <tfoot>)
				| Dio_Table_Row							// displayed as a table row (like <tr>)
				| Dio_Table_Column_Group				// displayed as a group of one or more columns (like <colgroup>)
				| Dio_Table_Column						// displayed as a column of cells (like <col>)
				| Dio_Table_Cell						// displayed as a table cell (like <td> and <th>)
				| Dio_Table_Caption						// displayed as a table caption (like <caption>)

:: FloatOpt		= Fto_Left								// image or text moves to the left in the parent element
				| Fto_None								// image or the text will be displayed just where it occurs in the text 
				| Fto_Right								// image or text moves to the right in the parent element

:: FntSizeOpt	= Fso_Large								// sets the size of the font to	large size			
				| Fso_Larger							// sets the font-size to a larger size than the parent element
				| Fso_Length	Int						// sets the font-size to a fixed size
				| Fso_Medium							// sets the size of the font to medium size
				| Fso_Percent	Int						// sets the font-size to a % of  the parent element
				| Fso_Small								// sets the size of the font to small size
				| Fso_Smaller							// sets the font-size to a smaller size than the parent element
				| Fso_X_Large							// sets the size of the font to x-large size
				| Fso_XX_Large							// sets the size of the font to xx-large size
				| Fso_X_Small							// sets the size of the font to x-small size
				| Fso_XX_Small							// sets the size of the font to xx-small size
			
:: FntSizeAdjOpt	= Fsa_None							// do not preserve the font's x-height if the font is unavailable
					| `Fsa_Number	Real				// defines the aspect value ratio for the font 

:: FntStyleOpt	= Fst_Italic
				| Fst_Normal
				| Fst_Oblique 

:: FntWeightOpt = Fwo_Bold								// thick characters
				| Fwo_Bolder							// thicker characters
				| Fwo_Lighter							// lighter characters
				| Fwo_Normal							// normal characters
				| Fwo_100								// thinest characters
				| Fwo_200		
				| Fwo_300		
				| Fwo_400								// same as normal
				| Fwo_500		
				| Fwo_600		
				| Fwo_700								// same as bold
				| Fwo_800		
				| Fwo_900								// thickest characters

:: FontOpt		= Fto_Caption							// font that are used by captioned controls (like buttons, drop-downs, etc.)
				| Fto_Icon								// fonts that are used by icon labels
				| Fto_Menu								// fonts that are used by dropdown menus
				| Fto_MsgBox							// fonts that are used by dialog boxes
				| Fto_SmallCap		
				| Fto_StatusBar							// fonts that are used by window status bars
				| `Fto_Family		String				// font-family
				| `Fto_LineHeight	LineHOpt			// font-line-height : line-height value sets the space between lines
				| `Fto_Size			FntSizeOpt			// font-size
				| `Fto_Style		FntStyleOpt			// font-style
				| `Fto_Variant		VariantOpt			// font-variant
				| `Fto_Weight 		FntWeightOpt		// font-weight

:: ImageOpt		= `Img_URL	Url							// path to an image
				| Img_None								// no background image

:: LayoutOpt	= Lyo_Auto
				| Lyo_Fixed
			
:: LengthOpt	= Lgt_Percent	Int						// length in % of the length of the closest element
				| Lgt_Pixel		Int						// length in pixels
			
:: LineHOpt		= Lho_Percent	Int						// space in percent %
				| Lho_Size		Int						// space in font size

:: LineSizeOpt	= Lso_Length	Int						// fixed distance between the lines
				| Lso_Normal							// reasonable distance between lines
				| Lso_Number	Int						// number that will be multiplied with the current font-size to set the distance between the lines
				| Lso_Percent	Int						// distance between the lines in % of the current font size

:: LstImgOpt	= Lio_None								// no image will be displayed
				| `Lio_Url		Url						// path to the image
			
:: LstPosOpt	= Lpo_Inside							// indents the marker and the text
				| Lpo_Outside							// keeps the marker to the left of the text

:: LstTypeOpt	= Lto_Armenian							// armenian : marker is traditional Armenian numbering
				| Lto_Circle							// circle : marker is a circle
				| Lto_Cjk_Ideographic					// cjk-ideographic : marker is plain ideographic numbers
				| Lto_Decimal							// decimal : marker is a number
				| Lto_Decimal_Leading_Zero				// decimal-leading-zero : marker is a number padded by initial zeros (01, 02, 03, etc.)
				| Lto_Disc								// disc : marker is a filled circle
				| Lto_Georgian							// georgian : marker is traditional Georgian numbering (an, ban, gan, etc.)
				| Lto_Hebrew							// hebrew : marker is traditional Hebrew numbering
				| Lto_Hiragana							// hiragana : marker is: a, i, u, e, o, ka, ki, etc.
				| Lto_Hiragana_Iroha					// hiragana-iroha : marker is: i, ro, ha, ni, ho, he, to, etc.
				| Lto_Katakana							// katakana : marker is: A, I, U, E, O, KA, KI, etc.
				| Lto_Katakana_Iroha 					// katakana-iroha : marker is: I, RO, HA, NI, HO, HE, TO, etc.
				| Lto_Lower_Alpha						// lower-alpha : marker is lower-alpha (a, b, c, d, e, etc.)
				| Lto_Lower_Greek						// lower-greek : marker is lower-greek (alpha, beta, gamma, etc.)
				| Lto_Lower_Latin						// lower-latin : marker is lower-latin (a, b, c, d, e, etc.)
				| Lto_Lower_Roman						// lower-roman : marker is lower-roman (i, ii, iii, iv, v, etc.)
				| Lto_None								// none : no marker
				| Lto_Square							// square : marker is a square
				| Lto_Upper_Alpha						// upper-alpha : marker is upper-alpha (A, B, C, D, E, etc.) 
				| Lto_Upper_Latin						// upper-latin : marker is upper-latin (A, B, C, D, E, etc.)
				| Lto_Upper_Roman						// upper-roman : marker is upper-roman (I, II, III, IV, V, etc.)

:: LstStyleOpt	= `Lst_StyleImg	LstImgOpt				// list-style-image
				| `Lst_StylePos		LstPosOpt			// list-style-position
				| `Lst_StyleType	LstTypeOpt			// list-style-type

:: MarginOpt	= `Mg_Bottom	SizeOpt					// margin-bottom
				| `Mg_Left		SizeOpt					// margin-left
				| `Mg_Right		SizeOpt					// margin-right
				| `Mg_Top		SizeOpt					// margin-top
			
:: MktOffsetOpt = Moo_Auto				
				| `Moo_Length	Int

:: MaxSizeOpt	= Mas_Length	Int						// maximum size for the element
				| Mas_None								// no limit on the maximum width allowed for the element
				| Mas_Percent	Int						// maximum size for the element in % of the containing block
			
:: OlnColorOpt	= `Oco_Color	ColorOption				// color by name, RGB or Hexadecimal
				| Oco_Invert							// performs a color inversion

:: OlnStyleOpt	= Oso_Dashed							// dashed outline
				| Oso_Dotted							// dotted outline
				| Oso_Double							// two lines around the element
				| Oso_Groove							// 3D grooved outline
				| Oso_Inset								// 3D inset outline
				| Oso_None								// no outlines
				| Oso_Outset							// 3D outset outline
				| Oso_Ridge								// 3D ridged outline
				| Oso_Solid								// solid outline

:: OlnWidthOpt	= `Owo_Length	Int						// you to define the thickness of the outlines
				| Owo_Medium							// medium outlines
				| Owo_Thick								// thick outlines
				| Owo_Thin								// thin outlines

:: OutlineOpt	= `Oln_Color	OlnColorOpt				// outline-color
				| `Oln_Style	OlnStyleOpt				// outline-style
				| `Oln_Width	OlnWidthOpt				// outline-width	

:: OverflowOpt	= Ofo_Auto								// if the content is clipped, the browser should display a scroll-bar to see the rest of the content
				| Ofo_Hidden							// content is clipped, but the browser does not display a scroll-bar to see the rest of the content 
				| Ofo_Scroll							// content is clipped, but the browser displays a scroll-bar to see the rest of the content
				| Ofo_Visible							// content is not clipped. It renders outside the element

:: PosOpt		= Poo_Absolute							// element can be placed anywhere on a page. The element's position is specified with the "left", "top", "right", and "bottom" properties
				| Poo_Fixed	
				| Poo_Relative							// moves an element relative to its normal position, so "left:20" adds 20 pixels to the element's LEFT position
				| Poo_Static							// placed in a normal position (according to the normal flow). we do not use the "left" and "top" properties

:: QuotesOpt	= Qto_None								// "open-quote" and "close-quote" values of the "content" property will not produce any quotation marks
				| Qto_Quotes String String String String// first two values specifies the first level of quotation, next two values specifies the next level of quote embedding

:: RepeatOpt	= Rop_Repeat
				| Rop_Repeat_X
				| Rop_Repeat_Y
				| Rop_No_Repeat

:: ShadowOpt	= `Swo_Color	ColorOption		
				| `Swo_Length	Int				
				| Swo_None								// no shadow

:: ShowHideOpt	= Sho_Hide	
				| Sho_Show
			
:: SideOpt		= Sdo_Bottom
				| Sdo_Left
				| Sdo_Right
				| Sdo_Top
			
:: SizeOpt		= Szo_Auto								// browser calculates the actual height
				| Szo_Length	Int						// the size in pixels
				| Szo_Percent	Int						// the size in % of the containing block
		
:: SpacingOpt	= Spo_Length	Int						// fixed space between characters or words 
				| Spo_Normal							// normal space between characters or words

:: StretchOpt	= Sto_Condensed							// condensed : normal scale of condensation of the font-family
				| Sto_Expanded							// expanded : normal scale of expansion of the font-family
				| Sto_Extra_Condensed					// extra-condensed : scale of condensation of the font-family
				| Sto_Extra_Expanded					// extra-expanded : scale of expansion of the font-family
				| Sto_Narrower							// sets the scale of condensation to the next condensed value 
				| Sto_Normal							// sets the scale of condensation or expansion  to normal	
				| Sto_Semi_Condensed					// semi-condensed : scale of condensation of the font-family
				| Sto_Semi_Expanded						// semi-expanded : scale of expansion of the font-family
				| Sto_Ultra_Condensed					// ultra-condensed : scale of condensation of the font-family (the most)
				| Sto_Ultra_Expanded					// ultra-expanded : scale of expansion of the font-family (the most)
				| Sto_Wider								// sets the scale of expansion to the next expanded value 

:: TransformOpt = Tfo_Capitalize						// each word in a text starts with a capital letter
				| Tfo_Lowercase							// no capital letters, only lower case letters
				| Tfo_None								// normal text, with lower case letters and capital letters
				| Tfo_Uppercase							// only capital letters
				 
:: UnicodeOpt	= Uno_Bidi_Override						// bidi-override
				| Uno_Embed			
				| Uno_Normal

:: VariantOpt	= Vro_Normal							// normal
				| Vro_Small_Caps						// small-caps

:: VertAlignOpt = Vao_Baseline							// element is placed on the baseline of the parent element
				| Vao_Bottom							// bottom of the element is aligned with the lowest element on the line
				| Vao_Length	Int		 
				| Vao_Middle							// element is placed in the middle of the parent element
				| Vao_Percent	Int						// aligns the element in a % value of the "line-height" property. Negative values are allowed
				| Vao_Sub								// aligns the element as it was subscript
				| Vao_Super								// aligns the element as it was superscript				
				| Vao_TextBottom						// bottom of the element is aligned with the bottom of the parent element's font
				| Vao_TextTop							// top of the element is aligned with the top of the parent element's font
				| Vao_Top								// top of the element is aligned with the top of the tallest element on the line

:: VisibOpt		= Vis_Collapse							// when used in table elements, this value removes a row or column, but it does not affect the table layout. Other elements as hidden
				| Vis_Hidden							// the element is invisible
				| Vis_Visible							// the element is visible
			
:: WhiteSpaceOpt= Wso_Normal							// white-space is ignored by the browser
				| Wso_NoWrap							// the text will never wrap, it continues on the same line until a <br> tag is encountered
				| Wso_Pre								// white-space is preserved by the browser. Acts like the <pre> tag in HTML

:: ZIndexOpt	= Zio_Auto								// stack order is equal to its parents 
				| `Zio_Number	Int						// sets the stack order of the element
			
derive gHpr Style								