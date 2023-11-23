implementation module gui;

// Linkers
import ProcessSerialNumber;
import DLState;

// 0.8.x
import deltaWindow;
import deltaTimer;
import deltaDialog;

// Non-standard libraries
import expand_8_3_names_in_path;

min_client_width	:== 250;
min_client_height	:== 250;

monaco_font
	# (ok,font)=SelectFont /*"Monaco"*/ "Courier" [] 9;
	| ok
		= font;
		
openClientWindow :: !String !ProcessSerialNumber !*DLServerState !(IOState !*DLServerState) -> !(!*DLServerState,!(IOState !*DLServerState));
openClientWindow client_name client_id s io
	/*
	** - multiple clients lazily linked from same project file probably need different names
	*/		
	// get dl_client_state for client_id
	#! (ok,dl_client_state,s)
		= RemoveFromDLServerState client_id s;
	| not ok
		= abort "openClientWindow (internal error)";
	#! (client_window,dl_client_state)
		= dl_client_state!client_window;
	#! ({visible_window_ids},s)
		= s!global_client_window;

	// generate unique id for client window
	#! (dl_client_states,s)
		= acc_dl_client_states (\dl_client_states -> (dl_client_states,[])) s;
	#! (dl_client_states,ids)
		= collect_ids dl_client_states [] visible_window_ids;
	#! window_id
		= find_out_unique_window_id (sort ids) free_id;
		
	#! dl_client_state
		= { dl_client_state &
			client_window	= { client_window & client_window_id = window_id }
		};
	#! s
		= { s &
			dl_client_states = [dl_client_state:dl_client_states]
		};
	#! io
		= DEBUG_MODE io (OpenWindows [window_def window_id] io);
	= (s,io);
where {
	collect_ids [] l ids
		= (l,ids);
	collect_ids [dl_client_state:dl_client_states] l ids
		#! ({visible_client_window,client_window_id},dl_client_state)
			= dl_client_state!client_window;
		| not visible_client_window
			= collect_ids dl_client_states [dl_client_state:l] ids;	
			= collect_ids dl_client_states [dl_client_state:l] [client_window_id:ids];
		
	find_out_unique_window_id :: [Int] !Int -> !Int;	
	find_out_unique_window_id [] cnt
		= cnt;
	find_out_unique_window_id [a:aa] cnt
		| a < free_id
			= find_out_unique_window_id aa cnt;
			
		| a == cnt	
			= find_out_unique_window_id aa (inc cnt);
			= cnt;
		
	// Client window specification
	window_def window_id
		= ScrollWindow window_id window_pos window_title
			(ScrollBar (Thumb 0) (Scroll 4)) 
			(ScrollBar (Thumb 0) (Scroll 4))
			picture_domain
			minimum_window_size
			initial_window_size
			update_function
			[GoAway (go_awayClientWindow window_id client_id)];
			
	where {
		go_awayClientWindow window_id client_id s=:{global_client_window={visible_window_ids}} io
			| isMember window_id visible_window_ids
				// client has already been killed
				#! (global_client_window=:{visible_window_ids},s)
					= s!global_client_window;
				#! visible_window_ids 
					= filter (\visible_window_id -> window_id <> window_id) visible_window_ids;
				#! io
					= CloseWindows [window_id] io;
				#! s
					= { s &
						global_client_window = {global_client_window & visible_window_ids = visible_window_ids}	
					};	
				= (s,io);
				
				#! io
					= KillClient2 client_id io;
				= (s,io);
					
		(ascent,descent,_,leading)
			= FontMetrics monaco_font;
		line_height 
			= ascent + descent + leading;
			
		window_pos
			= (100,100);
		window_title
			= expand_8_3_names_in_path client_name;
	
		window_width
			= 1000;
		window_height
			= 100;	
		picture_domain
			= ((0,0),(min_client_width,min_client_height));
		minimum_window_size
			= initial_window_size; 
		initial_window_size
			= (min_client_width,min_client_height);

		update_function _ s 
			= (s,[]);		
	}
}

updateClientWindow :: !*DLServerState !(IOState *DLServerState) -> (!*DLServerState,!(IOState *DLServerState));
updateClientWindow s io
	// collect messages
	#! (dl_client_states,s)
		= acc_dl_client_states (\dl_client_states -> (dl_client_states,[])) s;
	#! (dl_client_states,messages)
		= collect_messages dl_client_states [] [];
	#! io
		= case length messages of {
				0
					-> io;
				1
					#! io
						= foldl draw_client_window io messages;
					-> io;
				_
					-> abort "meedere messages";
		};
	#! (s,io)
		= foldl change_picture_domain (s,io) messages;	
	= ({s & dl_client_states = dl_client_states},io);
where {
	change_picture_domain (s,io) (id_client_window,messages)
		#! (ascent,descent,_,leading)
			= FontMetrics monaco_font;
		#! line_height
			= ascent + descent + leading;
			
		// compute new picture domain
		#! height_picture_domain
			= max (length messages * line_height) min_client_height;
		#! width_picture_domain
			= max (foldl (\max_width msg -> max max_width (FontStringWidth (toString msg) monaco_font) ) 0 messages) min_client_width;
		= ChangePictureDomain id_client_window ((0,0),(width_picture_domain,height_picture_domain)) s io;
	
	draw_client_window io (id_client_window,messages)
		#! draw_functions
			= [SetFont monaco_font,draw_linker_messages messages (leading + ascent) (ascent + descent + leading)];
		#! io
			= ChangeUpdateFunction id_client_window (\_ s -> (s,draw_functions)) io;
			
		// under macOS: enforce a redraw of the (entire) window
		#! io
			= sel_platform io (DrawInWindow id_client_window draw_functions io);
		= io;
	where {
		(ascent,descent,_,leading)
			= FontMetrics monaco_font;
			
		draw_linker_messages [] y line_height picture
			= picture;
		draw_linker_messages [msg:msgs] y line_height picture
			#! picture
				= MovePenTo (0,y) picture;
		
			#! picture
				= DrawString (toString msg) picture;
			= draw_linker_messages msgs (y + line_height) line_height picture;
	}
	
	// collect all messages for windows that need to be updated
	collect_messages :: !*[*DLClientState] !*[*DLClientState] [(!Int,!LinkerMessages)] -> *(*[*DLClientState],[(Int,[LinkerMessage])]);
	collect_messages [] dl_client_states messages
		= (dl_client_states,messages);
	collect_messages [dl_client_state:dl_client_states] new_dl_client_states messages
		#! (messages0,dl_client_state)
			= GetLinkerMessages dl_client_state;
			
		#! (client_window=:{n_messages,visible_client_window,client_window_id},dl_client_state)
			= dl_client_state!client_window;
		| n_messages == (length messages0) || not visible_client_window
			= collect_messages dl_client_states [dl_client_state:new_dl_client_states] messages;
		
			#! dl_client_state
				= { dl_client_state &
					client_window	= { client_window & n_messages = length messages0 }
				};				
			= collect_messages dl_client_states [dl_client_state:new_dl_client_states] [(client_window_id,messages0):messages];
}

/*
	removeClientWindow
	
	Task:
	It registers the window id as occupied of the client being closed. The window id *cannot* be released because
	it might contain error messages which the user may want to see first.
	
	If, however no errors have occured, the window is closed immediately	
*/
removeClientWindow :: !*DLClientState !*DLServerState !(IOState *DLServerState) -> (!*DLServerState,!(IOState !*DLServerState));
removeClientWindow dl_client_state=:{id,client_window={client_window_id,visible_client_window}} s io
	#! (ok,dl_client_state)
		= IsErrorOccured dl_client_state
	| ok
		// no errors; just close the window
		/*
			perhaps the user should be given the chance to close the window herself because she may want
			to read warnings. For debugging purposes its perhaps the way to go.
		*/
		= closeClientWindow dl_client_state s io;
		
		// errors; window remains visible
		#! s
			= case visible_client_window of {
				True
					#! (global_client_window,s)
						= s!global_client_window;
					#! s
						= { s &
							global_client_window = { global_client_window & visible_window_ids = [client_window_id:global_client_window.visible_window_ids]}
						};
					-> s;
				False
					-> s;
			}
		= (s,io);
where {
	closeClientWindow dl_client_state=:{client_window} s io
		#! (client_window_id,client_window)
			= client_window!client_window_id;
		#! io
			= CloseWindows [client_window_id] io;
		= (s,io);
} // removeClientWindow


HandleRequestResult :: (!Bool,!ProcessSerialNumber,!*DLServerState,(IOState !*DLServerState)) -> (!*DLServerState,IOState !*DLServerState);
HandleRequestResult (remove_state,client_id,s,io)
	// platform independent ...; check for errors
	#! ((messages,ok),s)
		= selacc_app_linker_state client_id get_error_and_messages s;
		
	// update client windows
	
	// als window nog niet geopened, dan openen
	#! (s,io)
		= updateClientWindow s io;

	// remove client if necessary
	#! (s,io)
		= case remove_state of {
			True
				#! (_,removed_dl_client_state,s)
					= RemoveFromDLServerState client_id s;
				#! (s,io)
					= removeClientWindow removed_dl_client_state s io;
				-> (s,io);
					
			False
				-> (s,io);
		};
		
	// check for error fatal for client application
	| not ok
		# io
			= abort ("!kk"  +++ (pr_linker_message messages "")) //KillClient2 client_id io;
		= (s,io);
		
		= (s,io);
where {	
	get_error_and_messages state 
		#! (messages,state)
			= GetLinkerMessages state;		
		#! (ok,state)
			= IsErrorOccured state;
		= ((messages,ok),state);

	pr_linker_message [] s
		= s;
	pr_linker_message [LinkerError x:xs] s
		# new_s = "LinkerError:\t " +++ x +++ "\n";
		= pr_linker_message xs (s +++ new_s);
	pr_linker_message [LinkerWarning x:xs] s
		# new_s = "LinkerWarning:\t " +++ x  +++ "\n";
		= pr_linker_message xs (s +++ new_s);
	pr_linker_message [Verbose x:xs] s
		# new_s = "Verbose:\t " +++ x  +++ "\n";
		= pr_linker_message xs (s +++ new_s);
} // HandleRequestResult

instance toString LinkerMessage
where {
	toString (LinkerError msg)
		= "Error: " +++ msg;
	toString (LinkerWarning msg)
		= "Warning: " +++ msg;
	toString (Verbose msg)
		= msg;
};

error :: [String] !*a !*(IOState *a) -> *(*a,*(IOState *a));
error l s io
	#! io
		= DisableTimer timer_id io;
	#! (i,s,io)
		= OpenNotice (Notice ["Fatal error:":l] (NoticeButton 0 "Ok") []) s io;
	#! io
		= EnableTimer timer_id io;
	= (s, io);