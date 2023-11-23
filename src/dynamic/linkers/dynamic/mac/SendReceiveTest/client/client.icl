module client;

import StdEnv;
import mac_types;
import ExtLibrary;

/*
	console application		


*/



/*
	It is assumed that the server with the boff-signature is already up
	and running.
	
	Set in size resource:
		can background to 1
		high level event aware to 1
		accept suspend events to 1
		does activate on FG switch to 1
		
	Furthermore a client application is assumed to support the Quit apple
	event. If not, the client application cannot be killed by the dynamic
	linker.
*/ 
import ExtInt;

Start
//	= hex_int (fourCharsToInt "APPL");
	// console application; fake toolbox
	#! toolbox
		= 0;

	// send an Init-request; a lazy linked application
	#! (oserr,toolbox)
		= ASyncSend InitID /*"Hallo, dynamische linker"*/ "" "boff" receiverIDisSignature toolbox;
		
	// wait for reply
	#! (data,toolbox)
		= wait_for_high_level_event toolbox;
	= ("client linked <" +++ data +++ ">",oserr,toolbox);


/*
	// no console application; with apple event handler
from deltaEventIO import StartIO,InitialIO,QuitIO,IOSystem;

Start world
	# (s,world)
		= StartIO iosystem start_state initial_io world;
	= world;
where {		
	iosystem 
		= [
			MenuSystem	[file_menu,dynamic_linker_menu]
//		,	HighLevelEventSystem [boff_highlevelevent]

		// Clean applications supporting 
//		,	system_dependent_device
		];

	// MenuSystem	
	file_menu 
		=	PullDownMenu 1 "File" Able [
				MenuItem 13 "Quit"	(Key 'Q') Able (\s io -> (s,QuitIO io))
			];
			
	dynamic_linker_menu
		= 	PullDownMenu 2 "Client; required apple events" Able [];
		
	// HighLevelEventSystem
	boff_highlevelevent
		= HighLevelEvent "boff" 
			[
			// test
				(InitID,			\s io -> HandleRequestResult (PreprocessRequest Init s io))

		/*
				(AddClientID,		\s io -> HandleRequestResult (PreprocessRequest AddClient s io))
			,	(AddLabelID,		\s io -> HandleRequestResult (PreprocessRequest AddLabel s io))
			,	(InitID,			\s io -> HandleRequestResult (PreprocessRequest Init s io))
			,	(QuitID,			\s io -> HandleRequestResult (PreprocessRequest Quit s io))
//
//			,	(QuitID				\s io -> HandleRequestResult (PreprocessRequest Close s io))
			,	(CloseID,			\s io -> HandleRequestResult (PreprocessRequest Close s io))
			,	(AddAndInitID,		\s io -> HandleRequestResult (PreprocessRequest AddAndInit s io))
			,	(AddDescriptorsID,	\s io -> HandleRequestResult (PreprocessRequest AddDescriptors s io))
		*/
			];

	system_dependent_device
		=	AppleEventSystem {openHandler =openHandler, quitHandler = quitHandler, clipboardChangedHandler =clipboardChangedHandler, scriptHandler = scriptHandler};
	where {
	 	openHandler project_name s io
			= (s,io);

		quitHandler s io
			= (s,QuitIO io); //QuitIO io);
			
		scriptHandler _ s io
			= (s,io);
			
		clipboardChangedHandler s io
			= (s,io);
	} // system_dependent_device	
		
	start_state 
		= 0;
		
	initial_io
		= [];

} // Start
*/
