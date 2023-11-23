module 
	Example

import
	StdEnv,
	StdIO,
	MarkUpText
	
import ddState, write_dynamic, dynamics, ExtInt;

/*
FunctionExample1 	=	[ CmBackgroundColour Green, CmBText "map :: (a -> b) [a] -> [b]", CmFillLine, CmEndBackgroundColour, CmNewline
						, CmText "map f [] ",     CmAlign "1", CmText "= []", CmNewline
						, CmText "map f [x:xs] ", CmAlign "1", CmText "= [f x: map f xs]"
						]
FunctionExample2 	=	[ CmBackgroundColour Green, CmBText "map :: (a -> b) [a] -> [b]", CmFillLine, CmEndBackgroundColour, CmNewline
						, CmText "map f _x", CmNewline
						, CmTabSpace, CmText "= "
						] ++ Case1
					where
						Case1 =	[ CmScope 
								, CmBText "case ", CmText "_x ", CmBText "of", CmNewline, CmTabSpace
								, CmAlign "c_pat", CmText "[] ",     CmAlign "c_end_pat", CmText "-> []", CmNewline
								, CmAlign "c_pat", CmText "[x:xs] ", CmAlign "c_end_pat", CmText "-> [f x: map f xs]"
								, CmEndScope
								]
FunctionExample3	=	[ CmLink "scroll down to [end]" "end", CmNewline
						, CmText "eqList :: [a] [a] -> Bool | == a", CmNewline
						, CmText "eqList _x _y", CmNewline
						, CmTabSpace, CmText "= "
						] ++ Case1 ++ [CmLabel "end"]
					where
						Case1 =	[ CmScope
								, CmBText "case ", CmText "_x ", CmBText "of", CmNewline, CmTabSpace
								, CmAlign "c_pat", CmText "[] ",     CmAlign "c_end_pat", CmText "-> "] ++ Case2 ++ [CmNewline
								, CmAlign "c_pat", CmText "[x:xs] ", CmAlign "c_end_pat", CmText "-> "] ++ Case3
						Case2 = [ CmScope
								, CmBText "case ", CmText "_y ", CmBText "of", CmNewline, CmTabSpace
								, CmAlign "c_pat", CmText "[] ",       CmAlign "c_end_pat", CmText "-> True", CmNewline
								, CmAlign "c_pat", CmBText "default ", CmAlign "c_end_pat", CmText "-> False"
								, CmEndScope
								]
						Case3 = [ CmScope
								, CmBText "case ", CmText "_y ", CmBText "of", CmNewline, CmTabSpace
								, CmAlign "c_pat", CmText "[] ",     CmAlign "c_end_pat", CmText "-> False", CmNewline
								, CmAlign "c_pat", CmText "[y:ys] ", CmAlign "c_end_pat", CmText "-> x == y && eqList xs ys"
								, CmEndScope
								]
RatingExample1 		= 	[ CmBold, CmUText "Indeling ronde 1:", CmEndBold, CmNewline
						, CmLink "Maarten de Mol" "Maarten de Mol", CmChangeSize (-4), CmColour Red, CmText "[1909]", CmEndColour, CmEndSize
						, CmAlign "1", CmText " - ", CmAlign "2"
						, CmText "M. Beekhuis", CmChangeSize (-4), CmColour Red, CmText "[2011]", CmEndColour, CmEndSize
						, CmAlign "3", CmText " 0 - 1", CmNewline
						, CmText "C. van Dijk", CmChangeSize (-4), CmColour Red, CmText "[1692]", CmEndColour, CmEndSize
						, CmAlign "1", CmText " - ", CmAlign "2" 
						, CmLink "Jan-Willem Hoentjen" "Jan-Willem Hoentjen", CmChangeSize (-4), CmColour Red, CmText "[1848]", CmEndColour, CmEndSize
						, CmAlign "3", CmText " 0 - 1"
						]
*/
ListExample1		=	[ 
							CmLink "zomaar" "label", CmNewline,
							CmText "1", CmNewline,
							CmText "2", CmNewline,
							CmText "1", CmNewline,
							CmText "2", CmNewline,
							CmText "1", CmNewline,
							CmText "2", CmNewline,
							CmText "1", CmNewline,
							CmText "2", CmNewline,
							CmText "1", CmNewline,
							CmText "2", CmNewline,
							CmText "1", CmNewline,
							CmText "2", CmNewline,
							CmText "1", CmNewline,
							CmText "2", CmNewline,
							CmText "1", CmNewline,
							CmText "2", CmNewline,
							CmText "1", CmNewline,
							CmText "2", CmNewline,
							CmText "1", CmNewline,
							CmText "2", CmNewline,
							CmText "1", CmNewline,
							CmText "2", CmNewline,

							CmLabel "label",
							CmText "HIER STAAT HET LABEL", CmNewline
						]							

/*
CmRight,  CmIText  "1. ", CmAlign "voor", CmCenter, CmLink "Assembly (Intel)"       0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "2. ", CmAlign "voor", CmCenter, CmLink "Assembly (Mac)"         0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "3. ", CmAlign "voor", CmCenter, CmLink "Assembly (Sparc)"       0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "4. ", CmAlign "voor", CmCenter, CmLink "C"                      0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "5. ", CmAlign "voor", CmCenter, CmLink "C++"                    0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "6. ", CmAlign "voor", CmCenter, CmLink "Clean"                  1,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "7. ", CmAlign "voor", CmCenter, CmLink "Java"                   0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "8. ", CmAlign "voor", CmCenter, CmLink "Haskell"                0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "9. ", CmAlign "voor", CmCenter, CmLink "ML"                     0,  CmAlign "na", CmNewline
						, CmRight,  CmIText "10. ", CmAlign "voor", CmCenter, CmLink "Pascal"                 0,  CmAlign "na", CmNewline
						, CmRight,  CmIText "11. ", CmAlign "voor", CmCenter, CmLink "Scheme"                 0,  CmAlign "na"

						]

*/
   /*  
ExampleDialog status_id rid
	= Dialog "Example dialog" 
		(     MarkUpControl		FunctionExample1 [] []
		  :+: MarkUpControl		FunctionExample2 
		  							[ MarkUpFontFace			"Comic Sans MS"
		  							, MarkUpTextSize			10
		  							, MarkUpBackgroundColour	Blue
		  							, MarkUpTextColour			White
		  							] 
		  							[ ControlPos				(Left, zero)
		  							]
		  :+: MarkUpControl		FunctionExample3 
		  							[ MarkUpFontFace			"MS Serif"
		  							, MarkUpTextSize			10
		  							, MarkUpBackgroundColour	Black
		  							, MarkUpTextColour			Red
		  							, MarkUpNrLines				3
		  							, MarkUpEventHandler		event_handler1
		  							, MarkUpLinkStyle			False White Black True White Black
		  							] 
		  							[ ControlPos				(Left, zero)
		  							]
		  :+: MarkUpControl		RatingExample1   
		  							[ MarkUpTextSize			12
		  							, MarkUpBackgroundColour	LightGrey
		  							, MarkUpEventHandler		event_handler2
		  							] 
		  							[ ControlPos (Left, zero)
		  							]
		  :+: TextControl		"" [ControlPos (Left, zero)]
		  :+: TextControl       "----------------------------------------------------------"
		  							[ ControlId					status_id
		  							, ControlPos				(Center, zero)
		  							]
		  :+: MarkUpControl		[CmBText "Time elapsed: ", CmText "0 clock ticks", CmTabSpace, CmTabSpace]
		  							[ MarkUpReceiver			rid
		  							]
		  							[ ControlPos				(Left, zero)
		  							]
		)
		[ WindowClose (noLS closeProcess)
		]
	where
		event_handler1 :: (!MarkUpEvent !String) !Id _ (*PSt .ps) -> (*PSt .ps)
		event_handler1 (MarkUpLinkClicked nr name) id rid state
			= jumpToMarkUpLabel rid name state
		event_handler1 other id rid state
			= state
		
		event_handler2 :: (!MarkUpEvent !String) !Id _ (*PSt .ps) -> (*PSt .ps)
		event_handler2 (MarkUpLinkSelected name)   id rid state
			= appPIO (setControlText status_id ("selected " +++ name)) state
		event_handler2 (MarkUpLinkClicked nr name) id rid state
			= appPIO (setControlText status_id ("clicked[" +++ toString nr +++ "] " +++ name) ) state
 */
           
//Start :: *World -> *World
Start world
	// MV ...
	#! (mem,world)
		= getMemory world;
		
	// init
// temp ...
	#! ddState
		= { DefaultDDState mem &
			file_name	= "C:\\WINDOWS\\DESKTOP\\Clean\\Dynamics\\Examples\\WriteDynamic\\test"
		,	project_name = "C:\\WINDOWS\\DESKTOP\\Clean\\Dynamics\\Examples\\WriteDynamic\\WriteDynamic.prj"
		};
// ... temp
		
	// do dynamic
//	#! (ddState,file,world)
//		= do_dynamic ddState file world;
	#! (file_name,ddState)
		= ddState!DDState.file_name;
		
	// read dynamic
	#! ((ok,dynamic_info),world)
		= accFiles (read_dynamic file_name) world;
	| not ok
		= abort "error"

	#! look
		= Value;
		
	#! (max_desc_name,max_mod_name,desc_table)
		= BuildDescriptorAddressTable look dynamic_info;
	#! (nodes,desc_table,ddState)
		= compute_nodes look desc_table dynamic_info ddState;	


	#! (nodes,file,desc_table)
		= WriteGraph2 look desc_table dynamic_info nodes [];
//	#! file
//		= reverse file
		
	// .. MV
	= (file,startIO MDI 1 (initialize file) [ProcessClose closeProcess] world)  
	where
//		initialize :: (*PSt .ps) -> *PSt .ps
		initialize l state
			# (status_id, state)		= accPIO openId state
			# (rid, state)				= accPIO openRId state
			# (timerid, state)			= accPIO openId state
			# (_, state)				= openTimer 0 (Timer 1 NilLS [TimerFunction (timer rid)]) state
//			# (_, state)				= openDialog 0 (ExampleDialog status_id rid) state
			# state						= MarkUpWindow "MarkUpWindow" l //ListExample1
											[ MarkUpBackgroundColour		Blue
											, MarkUpTextColour				White
											, MarkUpTextSize				11
											, MarkUpWidth					600
											, MarkUpHeight					400
											, MarkUpLinkStyle				False Yellow Blue False White Black
				  							, MarkUpEventHandler			event_handler1		// MV

											] [WindowClose (noLS closeProcess), WindowPos (Fix, OffsetVector {vx=500,vy=100})] state
			= state
			where
				timer :: (!RId (!MarkUpMessage a)) !Int (!Int, *PSt .ps) -> (!Int, *PSt .ps)
				timer rid new_ticks (ticks, state)
					# ticks				= ticks + new_ticks
					# state				= changeMarkUpText rid [CmBText "Time elapsed: ", CmText (toString ticks +++ " clock ticks")] state
					= (ticks, state)
					
			// MV ...
event_handler1 :: (!MarkUpEvent !String) !Id _ (*PSt .ps) -> (*PSt .ps)
event_handler1 (MarkUpLinkClicked nr name) id rid state
	= jumpToMarkUpLabel rid name state
event_handler1 other id rid state
	= state
			// ... MV


/*

			
	= (ddState,file,world);
*/

//WriteGraph2 :: !BinaryDynamicSelector !DescriptorAddressTable !DynamicInfo (Nodes NodeKind) !*File -> ((Nodes NodeKind),!*File,!DescriptorAddressTable);
WriteGraph2 binary_dynamic_selector desc_table dynamic_info nodes file
/*
	#! file
		= fwrites ("ENCODED GRAPH\n") file;

	#! file
		= write_entry2 graph_s "total size" file;
	#! file
		= write_entry2 graph_i "relative file pointer" file;
	#! file
		= write_entry2 (start_fp + graph_i) "absolute file pointer" file;
		
	#! file
		= fwritec '\n' file;
*/
	#! (desc_table,nodes,file)
		= write_graph desc_table nodes file;

	= (nodes,file,desc_table);
where // {	 

	write_graph desc_table nodes file
		#! (nodes,desc_table,file)
			= write_node 0 1 nodes desc_table file;
		= (desc_table,nodes,file);
	where // {
		write_node stringP node_i nodes desc_table file
			| /*F ("node_i: " +++ toString node_i)*/ stringP == graph_s
				= (nodes,desc_table,file);
	
			| node_i == (inc n_nodes)
			
			/* CALLBACK
				// an indirection; last node has been read but is followed by at least one indirection
				#! (_,file)
					= write_one_line True stringP file;
				#! file
					= fwrites "indirection\n" file;
			*/
				= write_node (stringP + 4) node_i nodes desc_table file	
		
			#! (graph_i,nodes)
				= nodes!nodes.[node_i].graph_index
			#! is_indirection_line
				= graph_i <> stringP;	
			#! (expanded_desc_table_o,file)
				= write_one_line is_indirection_line stringP file				
			
			| is_indirection_line
			/*
				// an indirection
				#! file
					= fwrites "indirection\n" file;
			*/
				= write_node (stringP + 4) node_i nodes desc_table file

			// Main comment				
			#! (s,nodes,desc_table,file)
				= make_string node_i expanded_desc_table_o nodes desc_table file

/*
			#! file
				= fwrites s file
			#! file
				= fwritec '\n' file
*/
				
			// Sub comments
			#! (stringP,nodes,file)
				= write_node_info (stringP + 4) node_i 0 nodes file
	//		#! file
	//			= file ++ [CmText " test "]
	//		#! file
	//			= file ++ [CmEndScope]
			= write_node stringP (inc node_i) nodes desc_table file
			
		write_node_info stringP node_i j nodes file
			#! (info,nodes)
				= nodes!nodes.[node_i].Node.info
			| more_info j info
				#! (_,file)
					= write_one_line True stringP file
				
				#! file
					= file ++ [CmAlign "1", CmText (get_more_info j info graph),CmNewline]
				/*
				#! file
					= fwrites (get_more_info j info graph) file
				#! file
					= fwritec '\n' file;
				*/
				= write_node_info (stringP + 4) node_i (inc j) nodes file
				= (stringP,nodes,file)
						
		make_string node_i expanded_desc_table_o nodes desc_table file
			#! (info,nodes)
				= nodes!nodes.[node_i].Node.info
			#! is_definition
				= is_definition_node info
			| is_definition
				#! (children,nodes)
					= nodes!nodes.[node_i].children
					
				#! (desc_addr_table_i,desc_table)
					= desc_table!expanded_desc_table.[expanded_desc_table_o]
				#! (descriptor_name,desc_table)
					= desc_table!desc_addr_table.[desc_addr_table_i].descriptor_name
					
//				#! s
//					= "@" +++ toString node_i +++ ": Node" +++ (convert_args children);
//					= "@" +++ toString node_i +++ ": " +++ (descriptor_name) +++ x

				#! (info,nodes)
					= nodes!nodes.[node_i].Node.info
//			| more_info j info


				#! file
					=  file ++ [CmLabel (toString node_i),CmText ("@" +++ toString node_i +++ ":  "), CmAlign "1",/*CmScope,*/ /* +++ "  "+++ descriptor_name),*/ CmText descriptor_name]
			// CmScope
				#! l1
					= (convert_args children [])

				#! file
					= file ++ l1
				#! s
					= "";
				= (s,nodes,desc_table,file)
				= ("ref",nodes,desc_table,file)

		where // {

			convert_args [] f
				= f ++ [CmNewline]
			convert_args [x:xs] f
				#! link
					= CmLink (" @" +++ (toString x)) (toString x)
				= convert_args xs [link:f]
		/*
				#! f
					= convert_args xs f 
				= [:file]
			*/	
				
			//	= [CmLink (" @" +++ (toString x)) (toString x): convert_args xs]
			
			
		/*
			convert_args []
				= ""
			convert_args [x:xs]
				#! new_s
					= convert_args xs
				=  new_s +++ (" @" +++ toString x)	
		*/
//		} 
			
		write_one_line is_indirection_line i file
		/*
			// offset
			#! file
				= fwrites SepSpaces file;
			#! file
				= fwrites (hex_int i) file;
			
			// Raw data
			#! file
				= fwrites SepSpaces file;
			#! file
				= fwrites (hex (toInt graph.[i + 0])) file;
		
			#! file
				= fwritec ' ' file;
			#! file
				= fwrites (hex (toInt graph.[i + 1])) file;
				
			#! file
				= fwritec ' ' file;
			#! file
				= fwrites (hex (toInt graph.[i + 2])) file;
				
			#! file
				= fwritec ' ' file;
			#! file
				= fwrites (hex (toInt graph.[i  + 3])) file;			
			*/
			
			// Prefix
			#! (prefix,partial_arity,expanded_desc_table_o)
				= decode_descriptor_offset i graph

			/*
			#! file
				= fwrites SepSpaces file;
			#! file
				= case is_indirection_line of {
					True
						#! file
							= ljustify_f 6 "" file;
						-> file;				

					False		
						#! prefix_string
							= case prefix of {
								DPREFIX
									#! prefix
										= (toString (bit_n_to_char prefix)) +++ " (" +++ toString partial_arity +++ ")";
									-> prefix;
								_
									-> toString (bit_n_to_char prefix);
								};
			//			#! file
			//				= fwrites SepSpaces file;
						#! file
							= ljustify_f 6 prefix_string file;
						-> file;
					};
				
			// Descriptor
			#! file
				= fwrites SepSpaces file;
			#! file
				= case is_indirection_line of {
					True
						#! file
							= ljustify_f 10 "" file;
						-> file;
					False
						#! file
							= ljustify_f 10 "dummy" file;
						-> file;
				};
				
			#! file
				= fwrites SepSpaces file;
			*/
			= (expanded_desc_table_o,file)

//	}
				
	(binary_dynamic=:{header={n_nodes,size1,start_fp,graph_s,graph_i,stringtable_i,stringtable_s,descriptortable_i,descriptortable_s},stringtable,descriptortable,value_graph=graph})
		= getBinaryDynamic binary_dynamic_selector dynamic_info

/*
	write_title file
		#! title
			= "  Offset    Raw data     Prefix  Descriptor  Comment\n";
		#! title_underlined
			= "  --------  -----------  ------  ----------  -------\n";
		
		#! file
			= fwrites title file;
		#! file
			= fwrites title_underlined file;
		= file;
*/

//} // WriteGraph