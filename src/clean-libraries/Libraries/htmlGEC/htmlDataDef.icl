implementation module htmlDataDef

import StdStrictLists, StdString
import htmlStyleDef, htmlStylelib

gHpr{|Html|}    prev (Html head rest)			= prev <+ htmlbegin <+ head <+ rest <+ htmlend 
where
	htmlbegin									= "<html>"
	htmlend 									= "</html>"

gHpr{|Head|}    prev (Head attr tags)			= prev <+> htmlAttrCmnd "head"			attr tags

gHpr{|HeadTag|} prev (Hd_Base attr)				= prev <+> openCmnd 	"base"			attr
gHpr{|HeadTag|} prev (Hd_Basefont attr)			= prev <+> openCmnd 	"basefont"		attr
gHpr{|HeadTag|} prev (Hd_Link attr)				= prev <+> openCmnd 	"link"			attr
gHpr{|HeadTag|} prev (Hd_Meta attr)				= prev <+> openCmnd 	"meta"			attr
gHpr{|HeadTag|} prev (Hd_Object attr param)		= prev <+> htmlAttrCmnd "object" 		attr param
gHpr{|HeadTag|} prev (Hd_Script attr text)		= prev <+> htmlAttrCmnd "script"		attr text
gHpr{|HeadTag|} prev (Hd_Style attr text)		= prev <+> htmlAttrCmnd "style"			attr text
gHpr{|HeadTag|} prev (Hd_Title text)			= prev <+> htmlAttrCmnd "title" 		None text

gHpr{|Rest|}    prev (Body attr body) 			= prev <+> htmlAttrCmnd "body"			attr body
gHpr{|Rest|}    prev (Frameset attr frames)		= prev <+> htmlAttrCmnd "frameset"		attr frames

gHpr{|Frame|}   prev (Frame attr)				= prev <+> openCmnd 	"frame"			attr
gHpr{|Frame|}   prev (NoFrames attr body)		= prev <+> htmlAttrCmnd "noframes"		attr body

gHpr{|BodyTag|} prev (A attr body)  			= prev <+> htmlAttrCmnd "a" 			attr body
gHpr{|BodyTag|} prev (Abbr attr text)  			= prev <+> htmlAttrCmnd "abbr" 			attr text
gHpr{|BodyTag|} prev (Acronym attr text)		= prev <+> htmlAttrCmnd "acronym"		attr text
gHpr{|BodyTag|} prev (Address attr text)		= prev <+> htmlAttrCmnd "address"		attr text
gHpr{|BodyTag|} prev (Applet attr text)			= prev <+> htmlAttrCmnd "applet"		attr text
gHpr{|BodyTag|} prev (Area attr)				= prev <+> openCmnd 	"area"			attr
gHpr{|BodyTag|} prev (B attr text)  			= prev <+> htmlAttrCmnd "b" 			attr text
gHpr{|BodyTag|} prev (Bdo attr text)			= prev <+> htmlAttrCmnd "bdo" 			attr text
gHpr{|BodyTag|} prev (Big attr text)			= prev <+> htmlAttrCmnd "big" 			attr text
gHpr{|BodyTag|} prev (Blink attr text)	 		= prev <+> htmlAttrCmnd "blink" 		attr text
gHpr{|BodyTag|} prev (Blockquote attr text)		= prev <+> htmlAttrCmnd "blockquote"	attr text
gHpr{|BodyTag|} prev Br							= prev <+ "<br>"
gHpr{|BodyTag|} prev (Button attr text)			= prev <+> htmlAttrCmnd "button" 		attr text
gHpr{|BodyTag|} prev (Caption attr text)		= prev <+> htmlAttrCmnd "caption" 		attr text
gHpr{|BodyTag|} prev (Center attr text)			= prev <+> htmlAttrCmnd "center" 		attr text
gHpr{|BodyTag|} prev (Cite attr text)  			= prev <+> htmlAttrCmnd "cite" 			attr text
gHpr{|BodyTag|} prev (Code attr text) 			= prev <+> htmlAttrCmnd "code" 			attr text
gHpr{|BodyTag|} prev (Col attr)	 				= prev <+> htmlAttrCmnd "col" 			attr None
gHpr{|BodyTag|} prev (Colgroup attr) 			= prev <+> htmlAttrCmnd "colgroup"		attr None
gHpr{|BodyTag|} prev (Comment text) 			= prev <+ "<!-- "  <+ text <+ " -->"
gHpr{|BodyTag|} prev (Dd attr body)				= prev <+> htmlAttrCmnd "dd" 			attr body
gHpr{|BodyTag|} prev (Del attr text) 			= prev <+> htmlAttrCmnd "del" 			attr text
gHpr{|BodyTag|} prev (Dfn attr text) 			= prev <+> htmlAttrCmnd "dfn" 			attr text
gHpr{|BodyTag|} prev (Dir attr body)	 		= prev <+> htmlAttrCmnd "dir" 			attr body
gHpr{|BodyTag|} prev (Div attr body)	 		= prev <+> htmlAttrCmnd "div" 			attr body
gHpr{|BodyTag|} prev (Dl attr body)	 			= prev <+> htmlAttrCmnd "dl" 			attr body
gHpr{|BodyTag|} prev (Dt attr body)	 			= prev <+> htmlAttrCmnd "dt" 			attr body
gHpr{|BodyTag|} prev (Em attr text) 			= prev <+> htmlAttrCmnd "em" 			attr text
gHpr{|BodyTag|} prev (Fieldset attr body)		= prev <+> htmlAttrCmnd "fieldset"		attr body
gHpr{|BodyTag|} prev (Font attr body)			= prev <+> htmlAttrCmnd "font"			attr body
gHpr{|BodyTag|} prev (Form attr body)			= prev <+> htmlAttrCmnd "form" 			attr body
gHpr{|BodyTag|} prev (H1 attr text) 			= prev <+> htmlAttrCmnd "h1" 			attr text
gHpr{|BodyTag|} prev (H2 attr text) 			= prev <+> htmlAttrCmnd "h2" 			attr text
gHpr{|BodyTag|} prev (H3 attr text)		 		= prev <+> htmlAttrCmnd "h3" 			attr text
gHpr{|BodyTag|} prev (H4 attr text) 			= prev <+> htmlAttrCmnd "h4"	 		attr text
gHpr{|BodyTag|} prev (H5 attr text) 			= prev <+> htmlAttrCmnd "h5" 			attr text
gHpr{|BodyTag|} prev (H6 attr text) 			= prev <+> htmlAttrCmnd "h6" 			attr text
gHpr{|BodyTag|} prev (Hr attr)					= prev <+> openCmnd 	"hr"			attr
gHpr{|BodyTag|} prev (I attr text)				= prev <+> htmlAttrCmnd "i" 			attr text
gHpr{|BodyTag|} prev (Iframe attr)				= prev <+> htmlAttrCmnd "iframe"		attr None
gHpr{|BodyTag|} prev (Img attr)					= prev <+> openCmnd 	"img"			attr
gHpr{|BodyTag|} prev (Input attr text)			= prev <+> htmlAttrCmnd "input"			attr text
gHpr{|BodyTag|} prev (Ins attr text) 			= prev <+> htmlAttrCmnd "ins" 			attr text
gHpr{|BodyTag|} prev (Kbd attr text)			= prev <+> htmlAttrCmnd "kbd" 			attr text
gHpr{|BodyTag|} prev (Label attr text)			= prev <+> htmlAttrCmnd "label"			attr text
gHpr{|BodyTag|} prev (Legend attr text)			= prev <+> htmlAttrCmnd "legend"		attr text
gHpr{|BodyTag|} prev (Li attr body)				= prev <+> htmlAttrCmnd "li" 			attr body
gHpr{|BodyTag|} prev (Map attr body)			= prev <+> htmlAttrCmnd "map" 			attr body
gHpr{|BodyTag|} prev (Menu attr body)			= prev <+> htmlAttrCmnd "menu" 			attr body
gHpr{|BodyTag|} prev (Noscript attr text)		= prev <+> htmlAttrCmnd "noscript"		attr text
gHpr{|BodyTag|} prev (Body_Object attr param)	= prev <+> htmlAttrCmnd "object" 		attr param
gHpr{|BodyTag|} prev (Ol attr body)		 		= prev <+> htmlAttrCmnd "ol" 			attr body
gHpr{|BodyTag|} prev (P attr body)  			= prev <+> htmlAttrCmnd "p"  			attr body
gHpr{|BodyTag|} prev (Pre attr body) 			= prev <+> htmlAttrCmnd "pre" 			attr body
gHpr{|BodyTag|} prev (Q attr text)		  		= prev <+> htmlAttrCmnd "q" 			attr text
gHpr{|BodyTag|} prev (S attr text)  			= prev <+> htmlAttrCmnd "s" 			attr text
gHpr{|BodyTag|} prev (Samp attr text)  			= prev <+> htmlAttrCmnd "samp" 			attr text
gHpr{|BodyTag|} prev (Small attr text)			= prev <+> htmlAttrCmnd "small"			attr text
gHpr{|BodyTag|} prev (Script attr text)			= prev <+> htmlAttrCmnd "script"		attr text
gHpr{|BodyTag|} prev (Select attr opts)			= prev <+> htmlAttrCmnd "select"		attr opts
gHpr{|BodyTag|} prev (Span attr body)			= prev <+> htmlAttrCmnd "span"			attr body
gHpr{|BodyTag|} prev (Strike attr text)			= prev <+> htmlAttrCmnd "strike"		attr text
gHpr{|BodyTag|} prev (Strong attr text)			= prev <+> htmlAttrCmnd "strong"		attr text
gHpr{|BodyTag|} prev (Sub attr text)			= prev <+> htmlAttrCmnd "sub"			attr text
gHpr{|BodyTag|} prev (Sup attr text)			= prev <+> htmlAttrCmnd "sup"			attr text
gHpr{|BodyTag|} prev (Table attr body)			= prev <+> htmlAttrCmnd "table"			attr body
gHpr{|BodyTag|} prev (TBody attr body)			= prev <+> htmlAttrCmnd "tbody"			attr body
gHpr{|BodyTag|} prev (Td attr body)				= prev <+> htmlAttrCmnd "td"			attr body
gHpr{|BodyTag|} prev (TFoot attr body)			= prev <+> htmlAttrCmnd "tfoot"			attr body
gHpr{|BodyTag|} prev (Th attr body)				= prev <+> htmlAttrCmnd "th"			attr body
gHpr{|BodyTag|} prev (THead attr body)			= prev <+> htmlAttrCmnd "thead"			attr body
gHpr{|BodyTag|} prev (Textarea attr text)	 	= prev <+> htmlAttrCmnd "textarea"		attr text
gHpr{|BodyTag|} prev (Tr attr body)				= prev <+> htmlAttrCmnd "tr"			attr body
gHpr{|BodyTag|} prev (Tt attr text)				= prev <+> htmlAttrCmnd "tt" 			attr text
gHpr{|BodyTag|} prev (Txt text)  				= prev <+ text

gHpr{|BodyTag|} prev (InlineCode text)	 		= [|text:prev]

gHpr{|BodyTag|} prev (U attr text)	 			= prev <+> htmlAttrCmnd "u" 			attr text
gHpr{|BodyTag|} prev (Ul attr body)	 			= prev <+> htmlAttrCmnd "ul" 			attr body
gHpr{|BodyTag|} prev (Var attr text) 			= prev <+> htmlAttrCmnd "var" 			attr text

// special BodyTags

gHpr{|BodyTag|} prev (STable atts table)		= prev <+> htmlAttrCmnd "table" 		atts (BodyTag (mktable table))
where
	mktable table							 	= [Tr [] (mkrow rows)           \\ rows <- table]
	mkrow   rows						 		= [Td [Td_VAlign Alo_Top] [row] \\ row  <- rows ]

gHpr{|BodyTag|} prev EmptyBody					= prev
gHpr{|BodyTag|} prev (BodyTag listofbodies)		= prev <+ listofbodies

gHpr{|Script|}  prev (SScript string)			= prev <+ string
gHpr{|Script|}  prev (FScript fof)				= prev <+> fof

gHpr{|Option|}  prev (Option attr text)			= prev <+> htmlAttrCmnd  "option"		attr text
gHpr{|Option|}  prev (Optgroup attr)			= prev <+> openCmnd "optgroup"			attr

gHpr{|Value|}   prev (SV string)				= prev <+ "\"" <+ string <+ "\""			
gHpr{|Value|}   prev (IV int)  					= prev <+ toString int  		
gHpr{|Value|}   prev (RV real) 					= prev <+ toString real		
gHpr{|Value|}   prev (BV bool) 					= prev <+ toString bool		
gHpr{|Value|}   prev (NQV string)				= prev <+ string 			

gHpr{|ScriptType|} prev (TypeEcmascript) 		= prev <+ "\"text/Emacscript\""		
gHpr{|ScriptType|} prev (TypeJavascript) 		= prev <+ "\"text/Javascript\""		
gHpr{|ScriptType|} prev (Typejscript)			= prev <+ "\"text/jscript\""		
gHpr{|ScriptType|} prev (TypeVbscript)			= prev <+ "\"text/Vbscript\""		
gHpr{|ScriptType|} prev (TypeVbs)				= prev <+ "\"text/Vbs\""		
gHpr{|ScriptType|} prev (TypeXml)				= prev <+ "\"text/Xml\""		

gHpr{|SizeOption|} prev (Pixels num)			= prev  <+ "\"" <+ num <+ "\"" 
gHpr{|SizeOption|} prev (Percent num)			= prev  <+ "\"" <+ num <+ "%\"" 
gHpr{|SizeOption|} prev (RelLength num)			= prev  <+ "\"" <+ num <+ "*\"" 

//gHpr{|Ins_Attr|} prev (Ins_Datetime y m d)	= prev  <+ " datetime=\"" <+ y <+ m <+ d <+ "\"" 

gHpr{|RGBColor|}   prev (RGBColor r g b)		= prev  <+ "\"RGB(" <+ r <+ "," <+ g <+ "," <+ b <+ ")\"" 

gHpr{|Hexnum|} prev (Hexnum h0 h1 h2 h3 h4 h5)	= prev  <+ "#" <+ h0 <+ h1 <+ h2 <+ h3 <+ h4 <+ h5 

gHpr{|HN|}     prev H_0							= prev  <+ "0"
gHpr{|HN|}     prev H_1 						= prev  <+ "1"
gHpr{|HN|}     prev H_2 						= prev  <+ "2"
gHpr{|HN|}     prev H_3 						= prev  <+ "3"
gHpr{|HN|}     prev H_4 						= prev  <+ "4"
gHpr{|HN|}     prev H_5 						= prev  <+ "5"
gHpr{|HN|}     prev H_6 						= prev  <+ "6"
gHpr{|HN|}     prev H_7 						= prev  <+ "7"
gHpr{|HN|}     prev H_8 						= prev  <+ "8"
gHpr{|HN|}     prev H_9 						= prev  <+ "9"
gHpr{|HN|}     prev H_A 						= prev  <+ "A"
gHpr{|HN|}     prev H_B 						= prev  <+ "B"
gHpr{|HN|}     prev H_C 						= prev  <+ "C"
gHpr{|HN|}     prev H_D 						= prev  <+ "D"
gHpr{|HN|}     prev H_E 						= prev  <+ "E"
gHpr{|HN|}     prev H_F 						= prev  <+ "F"

gHpr{|NoAttr|} prev _							= prev 

gHpr{|Param|}  prev (Param attr)				= prev <+> openCmnd "param" attr

derive gHpr AlignTxt
derive gHpr AlignObj
derive gHpr A_Attr
derive gHpr Applet_Attr
derive gHpr Area_Attr
derive gHpr BaseAttr
derive gHpr BasefontAttr
derive gHpr BdoTxtDir
derive gHpr Block_Attr
derive gHpr BoolValue
derive gHpr Button_Attr
derive gHpr Button_Type
derive gHpr Caption_Attr
derive gHpr Checked
derive gHpr Col_Attr
derive gHpr Colorname
derive gHpr ColorOption
derive gHpr Del_Attr
derive gHpr Div_Attr
derive gHpr Disabled
derive gHpr DocRelation
derive gHpr ElementEvents
derive gHpr Font_Attr
derive gHpr Form_Attr
derive gHpr FramesetAttr
derive gHpr FrameAttr
derive gHpr FrameOption
derive gHpr GetOrPost
derive gHpr Hnum_Attr
derive gHpr HeadAttr
derive gHpr Hr_Attr
derive gHpr Iframe_Attr
derive gHpr Image_Attr
derive gHpr Input_Attr
derive gHpr InputType
derive gHpr Ins_Attr
derive gHpr Label_Attr
derive gHpr Legend_Attr
derive gHpr Li_Attr
derive gHpr LinkAttr
derive gHpr List_Type
derive gHpr Map_Attr
derive gHpr MediaOption
derive gHpr MetaOption
derive gHpr MetaName
derive gHpr MetaHttpEquiv
derive gHpr Object_Attr
derive gHpr Ol_Attr
derive gHpr Opt_Attr
derive gHpr Optgroup_Attr
derive gHpr P_Attr
derive gHpr Param_Attr
derive gHpr ParamValType
derive gHpr Pre_Attr
derive gHpr Q_Attr
derive gHpr ReadOnly
derive gHpr RuleOption
derive gHpr Script_Attr
derive gHpr ScriptLanguage
derive gHpr ScopeOption
derive gHpr Select_Attr
derive gHpr Selected
derive gHpr ShapeOption
derive gHpr ScrollingOption
derive gHpr Standard_Attr
derive gHpr Std_Attr
derive gHpr StyleAttr
derive gHpr T_Attr
derive gHpr Table_Attr
derive gHpr TargetOption
derive gHpr Td_Attr
derive gHpr Tr_Attr
derive gHpr TxtA_Attr
derive gHpr TxtDir
derive gHpr Ul_Attr

derive gHpr BodyAttr
