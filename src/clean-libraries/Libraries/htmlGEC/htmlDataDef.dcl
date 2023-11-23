definition module htmlDataDef

// Clean Algebraic Data Types that are isomorphic with HTML intructions
// (c) 2005 MJP

import htmlStyleDef

:: Url				:== String
:: UniqueName		:== String

None				:== [NoAttr]
:: NoAttr			= NoAttr

// a Clean data structure representing a subset of html

:: Html 			= Html Head Rest

:: Head				= Head [HeadAttr] [HeadTag]

:: HeadAttr			= Hd_Profile		Url							// space separated list of URL's that contains meta data information about the page
					| `Hd_Std			[Standard_Attr]
			
:: HeadTag			= Hd_Base 			[BaseAttr]					// base <base>
					| Hd_Basefont 		[BasefontAttr]				// basefont <basefont>
					| Hd_Link 			[LinkAttr]					// link <link>
					| Hd_Meta 			[MetaOption]				// meta <meta>
					| Hd_Object 		[Object_Attr] [Param]		// object <object></object> 
					| Hd_Script	 		[Script_Attr] Script		// script <script></script>
					| Hd_Style 			[StyleAttr] [Style]			// <style></style>
		//			| Hd_Style 			[StyleAttr] String			// <style></style>
					| Hd_Title			String						// title <title></title>
			
:: BaseAttr			= Bsa_Href			Url							// URL to use as the base URL for links in the page
					| Bsa_Target	 	TargetOption				// where to open all the links on the page

:: BasefontAttr	 = Bsf_Color			ColorOption					// text color
					| Bsf_Face 			String						// font to use
					| Bsf_Size			Int							// size for font elements
					| `Bsf_Std			[Standard_Attr]

:: LinkAttr			= Lka_Charset		String						// character encoding of the target URL
					| Lka_Href			Url							// target URL of the resource
					| Lka_HrefLang		String						// base language of the target URL
					| Lka_Media			MediaOption					// on what device the document will be displayed
					| Lka_Rel			DocRelation					// relationship between the current document and the target URL
					| Lka_Rev			DocRelation					// relationship between the target URL and the current document
					| Lka_Target		TargetOption				// Where to open the target URL
					| Lka_Type			String						// MIME type of the target URL
					| `Lka_Std			[Standard_Attr]
					| `Lka_Events		[ElementEvents]
			
:: MediaOption		= All
					| Aural
					| Braille
					| Handheld
					| Print
					| Projection
					| Screen
					| Speech
					| Tty
					| Tv
				
:: MetaOption		= Mto_Content		String						// meta information to be associated with http-equiv or name
					| Mto_HttpEquiv 	MetaHttpEquiv				// connects the content attribute to an HTTP header
					| Mto_Name 			MetaName					// connects the content attribute to a name
					| Mto_Scheme 		String						// format to be used to interpret the value of the content attribute
						
:: MetaHttpEquiv	= ContentType
					| Expires
					| Refresh
					| SetCookie

:: MetaName			= Author
					| Description
					| Keywords
					| Generator
					| Revised
					| Others			String

:: StyleAttr		= Sty_Type			String
					| Sty_Media 		MediaOption

:: Rest				= Body				[BodyAttr] [BodyTag]
					| Frameset			[FramesetAttr] [Frame]
		
:: FramesetAttr		= Fsa_Cols			String						// number and size of columns
					| Fsa_Rows			String						// number and size of rows
					| `Fsa_Std			[Standard_Attr]
				
:: Frame			= Frame				[FrameAttr]
					| NoFrames			[Std_Attr] [BodyTag]

:: FrameAttr		= Fra_Frameborder	Int							// display (1) or not (0) border around the frame
					| Fra_Longdesc		Url							// URL to a long description of the frame 
					| Fra_Marginheight	Int							// top and bottom margins in the frame
					| Fra_Marginwidth	Int							// left and right margins in the frame
					| Fra_Name			String						// unique name for the frame 
					| Fra_Noresize									// set to noresize the user cannot resize the frame
					| Fra_Scrolling		ScrollingOption				// scrollbar action
					| Fra_Src			Url							// URL of the file to show in the frame
					| `Fra_Std			[Standard_Attr]

:: ScrollingOption	= DoScroll
					| NoScroll
					| Auto	
	
:: BodyAttr			= Batt_alink		ColorOption					// Color of the active links in the document
					| Batt_background	String						// An image to use as the background
					| Batt_bgcolor		ColorOption					// Background color of the document
					| Batt_link			ColorOption					// Color of all the links in the document
					| Batt_text			ColorOption					// Color of the text in the document
					| Batt_vlink		ColorOption					// Color of the visited links in the document
					| `Batt_Std			[Standard_Attr]
					| `Batt_Events		[ElementEvents]	

:: BodyTag			= A 				[A_Attr] [BodyTag]			// link ancor <a></a>
					| Abbr 				[Std_Attr] String			// abbreviation <abbr></abbr>
					| Acronym			[Std_Attr] String			// acronym <acronym></acronym>
					| Address			[Std_Attr] String			// address <address></address>
					| Applet			[Applet_Attr] String		// applet <applet></applet>
					| Area				[Area_Attr]					// link area in an image <area> ALWAYS NESTED INSIDE A <map> TAG
					| B  				[Std_Attr] String			// bold <b></b>
					| Bdo	  			[Std_Attr] String			// direction of text <bdo></bdo>
					| Big  				[Std_Attr] String			// big text <big></big>
					| Blink				[Std_Attr] String			// blinked text <blink></blink>
					| Blockquote	  	[Block_Attr] String			// start of a long quotation <blockquote></blockquote>
					| Br  											// single line break <br>
					| Button 			[Button_Attr] String		// push button <button></button>		
					| Caption			[Caption_Attr] String		// Table caption <caption></caption>			
					| Center			[Std_Attr] String			// centered text <center></center>			
					| Cite				[Std_Attr] String 			// citation <cite></cite>			
					| Code				[Std_Attr] String 			// computer code text <code></code>			
					| Comment			String 						// comment text <!-- text -->
					| Col				[Col_Attr]					// attribute values for one or more columns in a table <col></col>
					| Colgroup			[Col_Attr]					// group of table columns <colgroup></colgroup>
					| Dd				[Std_Attr] [BodyTag]		// description of a term in a definition list <dd></dd>			
					| Del				[Del_Attr] String 			// deleted text <del></del>			
					| Dfn		 		[Std_Attr] String			// definition <dfn></dfn>	
					| Dir				[Std_Attr] [BodyTag]		// directory list <dir></dir>			
					| Div				[Div_Attr] [BodyTag]		// section in a document <div></div>			
					| Dl				[Std_Attr] [BodyTag]		// definition list <dl></dl>			
					| Dt				[Std_Attr] [BodyTag]		// definition term <dt></dt>			
					| Em				[Std_Attr] String 			// emphasized text <em></em>			
					| Fieldset			[Std_Attr] [BodyTag]		// fieldset element <fieldset></fieldset>
					| Font				[Font_Attr] [BodyTag]		// font <font></font>
					| Form 				[Form_Attr] [BodyTag] 		// form <form></form>
					| H1		 		[Hnum_Attr] String			// header 1 <h1></h1>
					| H2 				[Hnum_Attr] String			// header 2 <h2></h2>
					| H3 				[Hnum_Attr] String			// header 3 <h3></h3>
					| H4		 		[Hnum_Attr] String			// header 4 <h4></h4>
					| H5	 			[Hnum_Attr] String			// header 5 <h5></h5>
					| H6	 			[Hnum_Attr] String			// header 6 <h6></h6>			
					| Hr	 			[Hr_Attr]					// horizontal rule <hr>
					| I 				[Std_Attr] String			// italic text <i></i>
					| Iframe			[Iframe_Attr]				// iframe <iframe></iframe>
					| Img		 		[Image_Attr]				// image <img>
					| Input	 			[Input_Attr] String			// inputs <input>
					| Ins 				[Ins_Attr] String			// inserted text <ins></ins>
					| Kbd  				[Std_Attr] String			// keyboard text <kbd></kbd>
					| Label				[Label_Attr] String			// label for a control <label></label>
					| Legend			[Legend_Attr] String		// legend for a fieldset <legend></legend>
					| Li				[Li_Attr] [BodyTag]			// options in lists <li></li>
					| Map 				[Map_Attr] [BodyTag]		// map <map></map>
					| Menu	 			[Std_Attr] [BodyTag]		// menu list <menu></menu>
					| Noscript			[Standard_Attr]	String		// you can't see scripts <noscript></noscript>
					| Body_Object	 	[Object_Attr] [Param]		// insert an object <object></object>
					| Ol		 		[Ol_Attr] [BodyTag]			// ordered list <ol></ol>
					| P  				[P_Attr] [BodyTag]			// paragraph <p></p>
					| Pre 				[Pre_Attr] [BodyTag]		// preformatted text <pre></pre>
					| Q					[Q_Attr] String				// short quotation <q></q>
					| S	 				[Std_Attr] String			// strikethrough text <s></s>
					| Samp	 			[Std_Attr] String			// Sample computer code <samp></samp>
					| Script			[Script_Attr] Script		// script <script></script>
					| Select	 		[Select_Attr] [Option]		// select <select></select>
					| Small 			[Std_Attr] String 			// smaller <small></small>
					| Span				[Std_Attr] [BodyTag]		// section in a document <span></span>
					| Strike			[Std_Attr] String			// strikethrough text <strike></strike>
					| Strong			[Std_Attr] String			// strong emphasized text <strong></strong>
					| Sub	 			[Std_Attr] String			// subscript text <sub></sub>
					| Sup				[Std_Attr] String			// superscript text <sup></sup>
					| Table				[Table_Attr] [BodyTag]  	// table <table></table>
					| TBody 			[T_Attr] [BodyTag]			// body of a table <tbody></tbody>
					| Td				[Td_Attr] [BodyTag]			// table cell <td></td>
					| Textarea			[TxtA_Attr] String			// textarea <textarea></textarea>
					| TFoot				[T_Attr] [BodyTag]			// foot of a table <tfoot></tfoot>
					| Th	 			[Td_Attr] String			// table header cell in a table <th></th>
					| THead				[T_Attr] [BodyTag]			// header of a table <thead></thead>
					| Tr				[Tr_Attr] [BodyTag]			// table row <tr></tr>
					| Tt			 	[Std_Attr] String 			// teletyped text <tt></tt>
					| Txt		 		String 						// plain text
					| U					[Std_Attr] String			// underlined text <u></u>
					| Ul		 		[Ul_Attr] [BodyTag]			// unordered list <ul></ul>
					| Var				[Std_Attr] String			// variable text <var></var>
		
					| InlineCode		String						// to give the ability to plug in code directly
					| STable			[Table_Attr] [[BodyTag]]	// simple table used for Clean forms
					| BodyTag			[BodyTag]					// improves flexibility for code generation
					| EmptyBody										// same 
									
// Order by type name
:: A_Attr			= Lnk_Href 			Url							// target URL of the link
					| Lnk_Target 		TargetOption				// where to open the target URL
					| Lnk_Charset		String						// character encoding of the target URL
					| Lnk_Coords		String  					// coordinates appropriate to the shape attribute to define a region of an image for image maps
					| Lnk_Hreflang		String						// base language of the target URL
					| Lnk_Name			String						// names an anchor. Use this attribute to create a bookmark in a document
					| Lnk_Rel			DocRelation					// relationship between the current document and the target URL
					| Lnk_Rev			DocRelation					// relationship between the target URL and the current document
					| Lnk_Shape			ShapeOption					// type of region to be defined for mapping in the current area tag
					| Lnk_Type			String						// MIME type of the target URL
					| `Lnk_Std			[Standard_Attr]
					| `Lnk_Events		[ElementEvents]

:: AlignTxt			= Aln_Left 
					| Aln_Right 
					| Aln_Center
					| Aln_Justify
					| Aln_Char

:: AlignObj			= Alo_Left 
					| Alo_Right 
					| Alo_Top
					| Alo_Bottom
					| Alo_Middle
					| Alo_Baseline
					| Alo_Texttop
					| Alo_Absmiddle
					| Alo_Absbottom

:: Applet_Attr		= Apl_Height 		Int							// Height of the applet
					| Apl_Width 		Int							// Width of the applet
					| Apl_Align			AlignObj					// Text Aligment around the applet
					| Apl_Alt			String  					// Alternate text
					| Apl_Archive		Url							// A URL to the applet
					| Apl_Code			Url							// A URL that points to the class of the applet
					| Apl_Codebase		Url							// Indicates the base URL of the applet 
					| Apl_Hspace		Int							// Horizontal spacing around the applet
					| Apl_Name			UniqueName					// Unique name of the applet(to use in scripts)
					| Apl_Object		String						// Name of the resource that contains a serialized representation of the applet
					| Apl_Title			String						// Additional information to be displayed in tool tip
					| Apl_Vspace		Int							// Vertical spacing around the applet
					| `Apl_Std			[Standard_Attr]
					| `Apl_Events		[ElementEvents]

:: Area_Attr		= Are_Alt	 		String						// Alternate text
					| Are_Coords 		String						// Coordinates of the clickable area
					| Are_Href			Url							// Target URL of the area
					| Are_Nohref		BoolValue					// Excludes an area from the image map
					| Are_Shape			ShapeOption					// Shape of the area
					| Are_Target		TargetOption				// Where to open the target URL
					| `Are_Std			[Standard_Attr]
					| `Are_Events		[ElementEvents]

:: BdoTxtDir		= Bdir_Dir TxtDir

:: Block_Attr		= Blk_Cite			Url							// URL of the quote
					| `Blk_Std			[Standard_Attr]
					| `Blk_Events		[ElementEvents]

:: BoolValue		= True
					| False

:: Button_Attr		= Btn_Disabled									// Disables the button
					| Btn_Name			String						// Unique name for the button
					| Btn_Type			Button_Type					// The type of button
					| Btn_Value			String						// Initial value for the button.
					| `Btn_Std			[Standard_Attr]
					| `Btn_Events		[ElementEvents]

:: Button_Type		= Btn_Button
					| Btn_Submit
					| Btn_Reset

:: Caption_Attr		= Cap_Aling			AlignObj					// how to align the caption
					| `Cap_Std			[Standard_Attr]
					| `Cap_Events		[ElementEvents]

:: Checked			= Checked

:: Col_Attr			= Col_Aling			AlignTxt 					// horizontal alignment of the content in the table cell
					| Col_Char			Char						// character to use to align text on
					| Col_Charoff		Int							// alignment offset to the first character to align on
					| Col_Span			Int							// number of columns the <col> should span
					| Col_VAlign		AlignObj					// vertical alignment of the content in the table cell
					| Col_Width			Int							// width of the column
					| `Col_Std			[Standard_Attr]
					| `Col_Events		[ElementEvents]

:: ColorOption		= `Colorname		Colorname
					| `HexColor 		Hexnum						// "#FFFFFF"
					| `RGBColor 		RGBColor					// "RGB(255,255,255)"
			
:: Colorname		= Black											// "#000000"
					| Silver										// "#C0C0C0"
					| Gray 											// "#808080"
					| White											// "#FFFFFF"
					| Maroon										// "#800000"
					| Red											// "#FF0000"
					| Purple										// "#800080"
					| Fuchsia										// "#FF00FF"
					| Green											// "#008000" 
					| Lime											// "#00FF00"
					| Olive											// "#808000" 
					| Yellow										// "#FFFF00"
					| Navy 											// "#000080" 
					| Blue											// "#0000FF"
					| Teal											// "#008080" 
					| Aqua											// "#00FFFF"

:: Del_Attr			= Del_Cite			Url							// URL to another document which explains why the text was deleted or inserted
					| Del_Datetime		String						// date and time the text was deleted
					| `Del_Std			[Standard_Attr]
					| `Del_Events		[ElementEvents]

:: Div_Attr			= Div_Align			AlignObj					// how to align the text in the div element
					| `Div_Std			[Standard_Attr]
					| `Div_Events		[ElementEvents]

:: Disabled			= Disabled

:: DocRelation		= Docr_Alternate
					| Docr_Designates
					| Docr_Stylesheet
					| Docr_Start
					| Docr_Next
					| Docr_Prev
					| Docr_Contents
					| Docr_Index
					| Docr_Glossary
					| Docr_Copyright
					| Docr_Chapter
					| Docr_Section
					| Docr_Subsection
					| Docr_Appendix
					| Docr_Help
					| Docr_Bookmark
		
:: ElementEvents	= OnChange			Script						// FormElementEvents - run when element changes
					| OnSubmit			Script						// FormElementEvents - run when form submitted
					| OnReset			Script						// FormElementEvents - run when form is reset
					| OnSelect			Script						// FormElementEvents - run when selected
					| OnBlur			Script						// FormElementEvents - run when element loses focus
					| OnFocus			Script						// FormElementEvents - run when element gets focus
					| OnKeyDown			Script						// KeyboardEvents - run when key pressed
					| OnKeyPress		Script						// KeyboardEvents - run when key pressed and released
					| OnKeyUp			Script						// KeyboardEvents - run when key released
					| OnClick			Script						// MouseEvents - run when mouse clicked
					| OnDClick			Script						// MouseEvents - run when mouse doubleclicked
					| OnMouseDown		Script						// MouseEvents - run when mouse button pressed
					| OnMouseMove		Script						// MouseEvents - run when mouse pointer moves
					| OnMouseOver		Script						// MouseEvents - run when mouse pointer moves over an element
					| OnMouseOut		Script						// MouseEvents - run when mouse pointer moves out of an element
					| OnMouseUp			Script						// MouseEvents - run when mouse button is released
					| OnLoad			Script						// WindowEvents - run when the window is loaded
					| OnUnload			Script						// WindowEvents - run when the window is unloaded

:: Font_Attr		= Fnt_Size			Int							// size of the text 
					| Fnt_Face			String						// font of the text 
					| Fnt_Color			ColorOption					// color of the text
					| `Fnt_Std			[Standard_Attr]
			
:: Form_Attr		= Frm_Action 		Url							// URL that defines where to send the data when the submit button is pushed
					| Frm_Accept		String						// comma separated list of content types that the server that processes this form will handle correctly
					| Frm_AcceptCharset	String						// comma separated list of possible character sets for the form data
					| Frm_Enctype	 	String						// mime type used to encode the content of the form
					| Frm_Method 		GetOrPost					// HTTP method for sending data to the action URL. Default is get
					| Frm_Name 			UniqueName					// unique name for the form
					| Frm_Target 		TargetOption				// where to open the target URL	
					| `Frm_Std			[Standard_Attr]
					| `Frm_Events		[ElementEvents]

:: FrameOption		= Frm_Void
					| Frm_Above
					| Frm_Below
					| Frm_Hsides
					| Frm_Lhs
					| Frm_Rhs
					| Frm_Vsides
					| Frm_Box
					| Frm_Border

:: GetOrPost		= Get 
					| Post
			
:: Hexnum			= Hexnum HN HN HN HN HN HN

:: HN				= H_0 | H_1 | H_2 | H_3 
					| H_4 | H_5 | H_6 | H_7 
					| H_8 | H_9 | H_A | H_B 
					| H_C | H_D | H_E | H_F

:: Hnum_Attr		= Hnum_Align 		AlignTxt					// alignment of the text in the header
					| `Hnum_Std			[Standard_Attr]
					| `Hnum_Events		[ElementEvents]

:: Hr_Attr			= Hr_Align 			AlignTxt					// alignment of the horizontal rule
					| Hr_Noshade									// set to true the rule should render in a solid color, when set to false the rule should render in a two-color "groove"
					| Hr_Size			SizeOption					// Specifies the thickness (height) of the horizontal rule
					| Hr_Width			SizeOption					// width of the horizontal rule
					| `Hr_Std			[Standard_Attr]
					| `Hr_Events		[ElementEvents]

:: Iframe_Attr		= Ifa_Align			AlignObj					// align the iframe according to the surrounding text
					| Ifa_Frameborder	Int							// display (1) or not (0) border around the iframe
					| Ifa_Height		Int							// height of the iframe
					| Ifa_Longdesc		Url							// URL to a long description of the contents 
					| Ifa_Marginheight	Int							// top and bottom margins in the iframe
					| Ifa_Marginwidth	Int							// left and right margins in the iframe
					| Ifa_Name			UniqueName					// unique name for the frame 
					| Ifa_Scrolling		ScrollingOption				// scrollbar
					| Ifa_Src			Url							// URL of the file to show in the iframe
					| Ifa_Width			Int							// width of the iframe
					| `Ifa_Std			[Standard_Attr]

:: Image_Attr		= Img_Align			AlignObj					// align the image according to the surrounding text
					| Img_Alt			String						// short description of the image
					| Img_Border		Int							// border around an image 
					| Img_Height		SizeOption					// height of the iframe
					| Img_Hspace		Int							// white space on the left and right side of the image
					| Img_Ismap			Url							// defines the image as a server-side image map
					| Img_Longdesc		Url							// URL to a long description of the image
					| Img_Src			Url							// URL of the file to show in the iframe
					| Img_Usemap		Url							// Defines the image as a client-side image map
					| Img_Vspace		Int							// white space on the top and bottom of the image
					| Img_Width			SizeOption					// width of the iframe
					| `Img_Std			[Standard_Attr]
					| `Img_Events		[ElementEvents]

:: Input_Attr		= Inp_Accept		String						// comma-separated list of MIME types that indicates the MIME type of the file transfer (Only type="file")
					| Inp_Align 		AlignObj					// alignment of text following the image (only type="image")
					| Inp_Alt			String						// alternate text for the image (only type="image")
					| Inp_Checked		Checked						// checked when it first loads (only type="radio" or type="checkbox")
					| Inp_Disabled		Disabled					// disables the input element when it first loads (not used for type="hidden")
					| Inp_Maxlength 	Int							// maximum number of characters allowed (only for type="text")
					| Inp_Name 			UniqueName					// unique name for the input element
					| Inp_ReadOnly		ReadOnly					// the value of this field cannot be modified (only for type="text")
					| Inp_Size 			Int							// size of the input element (not used for type="hidden")
					| Inp_Src 			Url							// URL of the image to display (only type="image")
					| Inp_Type 			InputType					// type of the input element
					| Inp_Value 		Value						// default value of the input (not used for type="file")
					| `Inp_Std			[Standard_Attr]
					| `Inp_Events		[ElementEvents]

:: InputType		= Inp_Button
					| Inp_Checkbox
					| Inp_File
					| Inp_Hidden
					| Inp_Image
					| Inp_Password
					| Inp_Radio
					| Inp_Reset
					| Inp_Submit
					| Inp_Text

:: Ins_Attr 		= Ins_Cite			Url							// URL to another document which explains why the text was inserted
					| Ins_Datetime 		String						// date and time when the text was inserted
					| `Ins_Std			[Standard_Attr]
					| `Ins_Events		[ElementEvents]

:: Label_Attr 		= Lbl_For			String						// which form element the label is for. Set to an ID of a form element
					| `Lbl_Std			[Standard_Attr]
					| `Lbl_Events		[ElementEvents]

:: Legend_Attr		= Leg_Align			AlignTxt					// alignment for contents in the fieldset
					| `Leg_Std			[Standard_Attr]
					| `Leg_Events		[ElementEvents]

:: Li_Attr			= Lia_Type			List_Type					// specifies the type of the list
					| Lia_Value			Int							// number of list item
					| `Lia_Std			[Standard_Attr]
					| `Lia_Events		[ElementEvents]

:: List_Type		= Lit_A
					| Lit_a
					| Lit_I
					| Lit_i
					| Lit_1
					| Lit_disc
					| Lit_square
					| Lit_circle

:: Map_Attr			= Map_Name			String						// unique name for the map tag (for backwards compability) 
					| `Map_Std			[Standard_Attr]				// (Id required - unique name for the map tag) 
					| `Map_Events		[ElementEvents]

:: Object_Attr		= Oba_Align 		AlignObj					// text alignment around the object
					| Oba_Archive 		Url							// a space separated list of URL's to archives. The archives contains resources relevant to the object
					| Oba_Border 		Int							// border around the object
					| Oba_ClassId 		String						// class ID value as set in the Windows Registry or a URL
					| Oba_Codebase	 	Url							// where to find the code for the object
					| Oba_Codetype 		String						// internet media type of the code referred to by the classid attribute
					| Oba_Data 			Url							// URL that refers to the object's data
					| Oba_Declare									// the object should only be declared, not created or instantiated until needed
					| Oba_Height 		Int							// height of the object
					| Oba_HSpace	 	Int							// horizontal spacing around the object
					| Oba_Name 			UniqueName					// unique name for the object 
					| Oba_Standby	 	String						// text to display while the object is loading
					| Oba_ObjectType	String						// MIME type of data specified in the data attribute
					| Oba_Usemap 		Url							// URL of a client-side image map to be used with the object
					| Oba_VSpace 		Int							// vertical spacing around the object
					| Oba_Width 		Int							// width of the object
					| `Oba_Std			[Standard_Attr]
					| `Oba_Events		[ElementEvents]

:: Ol_Attr			= Ola_Compact									// compact rendering
					| Ola_Start			Int							// number to start on
					| Ola_Type			List_Type					// type of the list
					| `Ola_Std			[Standard_Attr]
					| `Ola_Events		[ElementEvents]

:: Option			= Option [Opt_Attr] String
					| Optgroup [Optgroup_Attr]
			
:: Opt_Attr			= Opt_Disabled		Disabled					// ??? // option should be disabled when it first loads
					| Opt_Label			String						// label to use when using <optgroup>
					| Opt_Selected		Selected					// ??? // the option should appear selected 
					| Opt_Value			String						// value of the option to be sent to the server
					| `Opt_Std			[Standard_Attr]
					| `Opt_Events		[ElementEvents]

:: Optgroup_Attr	= Opg_Label			String						// label for the option group
					| Opg_Disabled									// option-group disabled when it first loads
					| `Opg_Std			[Standard_Attr]
					| `Opg_Events		[ElementEvents]

:: P_Attr			= Pat_Align			AlignTxt					// alignment of the text
					| `Pat_Std			[Standard_Attr]
					| `Pat_Events		[ElementEvents]

:: Param			= Param 			[Param_Attr]

:: Param_Attr		= Pam_Id			String						// id for the parameter
					| Pam_Name 			UniqueName					// unique name for the parameter
					| Pam_Type 			String						// internet media type for the parameter
					| Pam_Value			Value						// value of the parameter
					| Pam_ValueType		ParamValType				// MIME type of the value

:: ParamValType		= Data
					| Ref
					| Object

:: Pre_Attr			= Pre_Width			Int							// maximum number of characters per line
					| `Pre_Std			[Standard_Attr]
					| `Pre_Events		[ElementEvents]

:: Q_Attr			= Qat_Cite			String						// citation for the quotation
					| `Qat_Std			[Standard_Attr]
					| `Qat_Events		[ElementEvents]

:: ReadOnly			= ReadOnly

:: RGBColor			= RGBColor			Int Int Int 

:: RuleOption		= Rul_None
					| Rul_Groups
					| Rul_Rows
					| Rul_Cols
					| Rul_All

:: ScopeOption		= Scp_Col
					| Scp_ColGroup
					| Scp_Row
					| Scp_RowGroup

:: Script 			= SScript String
					| FScript .FoF

:: Script_Attr		= Scr_Type			ScriptType					// MIME type of the script
					| Scr_CharSet		String						// character encoding used in script
					| Scr_Defer										// the script is not going to generate any document content
					| Scr_Language		ScriptLanguage				// scripting language
					| Scr_Src			Url							// URL to a file that contains the script

:: ScriptType		= TypeEcmascript
					| TypeJavascript
					| Typejscript
					| TypeVbscript
					| TypeVbs
					| TypeXml
			
:: ScriptLanguage	= JavaScript
					| LiveScript
					| VbScript
					| `Other 			String

:: Select_Attr		= Sel_Disabled		Disabled					// disables the drop-down list
					| Sel_Multiple									// specifies that multiple items can be selected at a time
					| Sel_Name 			UniqueName					// unique name for the drop-down list
					| Sel_Size 			Int							// number of visible items in the drop-down list
					| `Sel_Std			[Standard_Attr]
					| `Sel_Events		[ElementEvents]

:: Selected			= Selected

:: ShapeOption		= Sopt_Rect
					| Sopt_Rectangle
					| Sopt_Circ
					| Sopt_Circle
					| Sopt_Poly
					| Sopt_Polygon

:: SizeOption		= Pixels			Int
					| Percent			Int
					| RelLength			Int

:: Standard_Attr	= Std_Class			String  					// Core_Attr - All except base,head,html,meta,param,script,style and title
					| Std_Id			String						// Core_Attr - All except base,head,html,meta,param,script,style and title
					| Std_Style			String						// Core_Attr - All except base,head,html,meta,param,script,style and title
					| Std_Title			String						// Core_Attr - All except base,head,html,meta,param,script,style and title
					| Std_Dir			TxtDir  					// Language_Attr - All except base,br,frame,frameset,hr,iframe,param and script
					| Std_Lang			String						// Language_Attr - All except base,br,frame,frameset,hr,iframe,param and script
					| Std_Accesskey		Char						// Keyboard_Attr
					| Std_Tabindex		Int							// Keyboard_Attr

:: Std_Attr			= `Std_Attr			[Standard_Attr]
					| `Std_Events		[ElementEvents]

:: T_Attr			= Tat_Align			AlignTxt					// text alignment in cells
					| Tat_Char 			Int							// which character to align text on
					| Tat_Charoff		SizeOption					// alignment offset to the first character to align on
					| Tat_Valign 		AlignObj					// vertical text alignment in cells
					| `Tat_Std			[Standard_Attr]
					| `Tat_Events		[ElementEvents]
			
:: Table_Attr		= Tbl_Align			AlignTxt					// aligns the table
					| Tbl_Bgcolor 		ColorOption					// background color of the table
					| Tbl_Border 		Int							// border width
					| Tbl_CellPadding 	SizeOption					// space between the cell walls and contents
					| Tbl_CellSpacing 	SizeOption					// space between cells
					| Tbl_Frame 		FrameOption					// how the outer borders should be displayed
					| Tbl_Rules 		RuleOption					// the horizontal/vertical divider lines
					| Tbl_Summary 		String						// summary of the table for speech-synthesizing/non-visual browsers
					| Tbl_Width 		SizeOption					// width of the table
					| `Tbl_Std			[Standard_Attr]
					| `Tbl_Events		[ElementEvents]

:: TargetOption		= Trg__Blank 
					| Trg__Parent 
					| Trg__Self 
					| Trg__Top

:: Td_Attr			= Td_Abbr			String						// abbreviated version of the content in a cell
					| Td_Align			AlignTxt					// horizontal alignment of cell content
					| Td_Axis			String						// name for a cell
					| Td_Bgcolor		ColorOption					// background color of the table cell
					| Td_Char			Char						// which character to align text on
					| Td_Charoff		SizeOption					// alignment offset to the first character to align on
					| Td_Colspan		Int							// number of columns this cell should span
					| Td_Headers		String						// space-separated list of cell IDs that supply header information for the cell
					| Td_Height			Int							// height of the table cell
					| Td_NoWrap										// disable or enable automatic text wrapping in this cell
					| Td_Rowspan		Int							// number of rows this cell should span
					| Td_Scope			ScopeOption					// specifies if this cell provides header information for the rest of the row that contains it (row), or for the rest of the column (col), or for the rest of the row group that contains it (rowgroup), or for the rest of the column group that contains it 
					| Td_VAlign			AlignObj					// vertical alignment of cell content
					| Td_Width			SizeOption					// width of the table cell
					| `Td_Std			[Standard_Attr]
					| `Td_Events		[ElementEvents]

:: Tr_Attr			= Tr_Align			AlignTxt					// text alignment in cells
					| Tr_Bgcolor		ColorOption					// background color of the table cell
					| Tr_Char			Char						// which character to align text on
					| Tr_Charoff		SizeOption					// alignment offset to the first character to align on
					| Tr_VAlign			AlignObj					// vertical text alignment in cells
					| `Tr_Std			[Standard_Attr]
					| `Tr_Events		[ElementEvents]

:: TxtA_Attr		= Txa_Cols			Int							// number of columns visible in the text-area
					| Txa_Disabled									// disables the text-area when it is first displayed
					| Txa_Name			String						// name for the text-area
					| Txa_Readonly									// the user cannot modify the content in the text-area
					| Txa_Rows			Int							// number of rows visible in the text-area
					| `Txa_Std			[Standard_Attr]
					| `Txa_Events		[ElementEvents]

:: TxtDir			= Tdir_Ltr 
					| Tdir_Rtl  

:: Ul_Attr			= Ula_Compact									// compact rendering
					| Ula_Type			List_Type					// type of the list
					| `Ula_Std			[Standard_Attr]
					| `Ula_Events		[ElementEvents]

:: Value			= SV String
					| NQV String
					| IV Int
					| RV Real
					| BV Bool


import PrintUtil

derive gHpr Html, BodyTag, ColorOption, TxtDir
