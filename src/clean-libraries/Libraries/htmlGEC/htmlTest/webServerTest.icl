implementation module webServerTest

/*
	Special library to test Webservers.
	Pieter Koopman 2005, 2006
*/

import StdEnv, gast, StdHtml, PrintUtil
import StdTime // for making the seed

:: *TestEvent	:== (Triplet,UpdValue,*FormStates) // chosen triplet, its new value 


gEq{|Html|} h1 h2 = abort "\nDo not use gEq for Html !!\n"
genShow{|Html|} sep b html c = genShow{|*|} sep b (fetchInputOptions1 html) ["\n\ttexts: ":htmlTextValues html ++ c]
derive genShow InputType, Value, Maybe, UpdValue

derive bimap []
derive gParse UpdValue

// --------- Utilities --------- //

htmlPageTitle :: Html -> [String]
htmlPageTitle (Html (Head headAttrs headTags) bodyTags) = [s \\ `Hd_Std stdAttrs <- headAttrs, Std_Title s <- stdAttrs ]

htmlEditBoxValues :: Html String -> [Int]
htmlEditBoxValues html s = [ i \\ (Inp_Text,IV i,Just (t,int,UpdI j)) <- fetchInputOptions1 html | s==t ]

htmlTextValues :: Html -> [String]
htmlTextValues html = findTexts html

// --------- The main function --------- //

:: *SUT = { ioOptions	:: [(InputType,Value,Maybe Triplet)]
		 , fStates		:: *FormStates
		 , nWorld 		:: *NWorld
		 }

calcNextHtml  :: (*HSt -> (Html,*HSt)) (i->HtmlInput) *SUT i -> ([Html],*SUT)
calcNextHtml userpage transinput {ioOptions,fStates,nWorld} input
= case calcnewevents ioOptions of
	Just (triplet,updvalue) = convert (doHtmlTest3 (Just (triplet,updvalue,fStates)) userpage nWorld)
	Nothing = convert (doHtmlTest3 Nothing userpage nWorld)
where
	convert (html,fStates,nWorld) = ([html],{ioOptions = fetchInputOptions1 html,fStates = fStates,nWorld = nWorld})

	calcnewevents :: [(InputType,Value,Maybe Triplet)] -> Maybe (Triplet,UpdValue)
//	calcnewevents []     = stderr <+ "\nInput not found.\n\n" //Nothing
	calcnewevents []     = Nothing
	calcnewevents [x:xs] = case calcnewevent x (transinput input) of
							Nothing -> calcnewevents xs
							else	-> else

	calcnewevent :: (InputType,Value,Maybe Triplet) HtmlInput -> Maybe (Triplet,UpdValue)
	calcnewevent (Inp_Button,SV buttonname,Just triplet=:(t,_,_)) (HtmlButton b) 
		| buttonname == b //t == b
			= Just (triplet,UpdS buttonname)		// button pressed
	calcnewevent (Inp_Text,IV oldint,Just triplet=:(t,_,_)) (HtmlIntTextBox b i)
		| t == b
			= Just (triplet,UpdI i)				// int input
	calcnewevent (Inp_Text,SV oldtext,Just triplet=:(t,_,_)) (HtmlStringTextBox b s)
		| t == b
			= Just (triplet,UpdS s)				// text input
	calcnewevent _ _ = Nothing

testHtml :: [TestSMOption s i Html] (Spec s i Html) s (i->HtmlInput) (*HSt -> (Html,*HSt)) *World -> *World 
			| ggen{|*|} i & gEq{|*|} s & genShow{|*|} s & genShow{|*|} i
testHtml opts spec initState transInput userpage world
	# ({hours, minutes, seconds}, world) = getCurrentTime world
	  seed = (hours * 60 + minutes) * 60 + seconds
	  (ok1,console,world)		= fopen "console.txt" FWriteText world
	  (ok2,file,world)			= fopen "testOut.txt" FWriteText world
	  (inout,world) 			= stdio world
	  (gerda,world)				= openGerda "iDataDatabase" world
	  nworld 					= {worldC = world, inout = inout, gerda = gerda}	
	  (initFormStates,nworld)	= initTestFormStates nworld 
	  inits 					= {ioOptions = [], fStates = initFormStates, nWorld = nworld}
	  (sut,console,file)		= testConfSM ([Seed seed]++opts) spec initState (calcNextHtml userpage transInput) inits (\sut={sut & ioOptions = []}) console file
	  nworld					= sut.nWorld
	  (_,world)					= fclose console nworld.worldC
	  (_,world)					= fclose file world
	  world						= closeGerda gerda world
	= world

doHtmlTest3 :: (Maybe *TestEvent) (*HSt -> (Html,!*HSt)) *NWorld -> (Html,*FormStates,*NWorld)
doHtmlTest3 nextevent userpage nworld // execute user code given the chosen testevent to determine the new possible inputs
# (newstates,nworld) 	= case nextevent of 
							Nothing -> initTestFormStates nworld // initial empty states
							Just (triplet=:(id,pos,UpdI oldint),UpdI newint,oldstates) -> setTestFormStates (Just triplet) id (toString newint) oldstates nworld  
							Just (triplet=:(id,pos,UpdR oldreal),UpdR newreal,oldstates) -> setTestFormStates (Just triplet) id (toString newreal) oldstates nworld  
							Just (triplet=:(id,pos,UpdB oldbool),UpdB newbool,oldstates) -> setTestFormStates (Just triplet) id (toString newbool) oldstates nworld  
							Just (triplet=:(id,pos,UpdC oldcons),UpdC newcons,oldstates) -> setTestFormStates (Just triplet) id (toString newcons) oldstates nworld  
							Just (triplet=:(id,pos,UpdS oldstring),UpdS newstring,oldstates) -> setTestFormStates (Just triplet) id (toString newstring) oldstates nworld  
= runUserApplication userpage newstates nworld
where
	runUserApplication userpage states nworld
	# (html,{states,world}) 
						= userpage {cntr = 0, states = states, world = nworld}
	= (html,states,world)

fetchInputOptions1 :: Html -> [(InputType,Value,Maybe (String,Int,UpdValue))] // determine from html code which inputs can be given next time
fetchInputOptions1 (Html (Head headattr headtags) (Body attr bodytags))
	= fetchInputOptions bodytags
where
	fetchInputOptions :: [BodyTag] -> [(InputType,Value,Maybe (String,Int,UpdValue))] // determine from html code which inputs can be given next time
	fetchInputOptions [] 						= []
	fetchInputOptions [Input info _  :inputs]	= fetchInputOption info   ++ fetchInputOptions inputs
	fetchInputOptions [BodyTag bdtag :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [A _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Dd _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Dir _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Div _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Dl _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Dt _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Fieldset _ bdtag :inputs]= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Font _ bdtag  :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Form _ bdtag  :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Li _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Map _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Menu _ bdtag  :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Ol _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [P _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Pre _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Span _ bdtag  :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Table _ bdtag :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [TBody _ bdtag :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Td _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [TFoot _ bdtag :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [THead _ bdtag :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Tr _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [Ul _ bdtag 	 :inputs] 	= fetchInputOptions bdtag ++ fetchInputOptions inputs
	fetchInputOptions [STable _ bdtags :inputs] = flatten (map fetchInputOptions bdtags) ++ fetchInputOptions inputs
	fetchInputOptions [_			 :inputs] 	= fetchInputOptions inputs
	
	fetchInputOption [Inp_Type inptype, Inp_Value val,	Inp_Name triplet:_] = [(inptype,val,decodeInfo triplet)]
	fetchInputOption [Inp_Type inptype, Inp_Value val:_] = [(inptype,val,Nothing)]
	fetchInputOption [x:xs] = fetchInputOption xs
	fetchInputOption _ = []
	
findTexts :: Html -> [String]
findTexts (Html (Head headattr headtags) (Body attr bodytags))
 = ft bodytags []
where
	ft :: [BodyTag] [String] -> [String]
	ft [BodyTag bdt:tl]    		c = ft bdt (ft tl c)
	ft [A		attrs btags:tl] c = ft btags (ft tl c)	// link ancor <a></a>
	ft [B  		attrs str  :tl] c = [str:ft tl c]		// bold <b></b>
	ft [Big  	attrs str  :tl] c = [str:ft tl c]		// big text <big></big>
	ft [Caption	attrs str  :tl] c = [str:ft tl c]		// Table caption <caption></caption>			
	ft [Center	attrs str  :tl] c = [str:ft tl c]		// centered text <center></center>			
	ft [Code	attrs str  :tl] c = [str:ft tl c] 		// computer code text <code></code>			
	ft [Em		attrs str  :tl] c = [str:ft tl c] 		// emphasized text <em></em>			
	ft [H1	 	attrs str  :tl] c = [str:ft tl c]		// header 1 <h1></h1>
	ft [H2 		attrs str  :tl] c = [str:ft tl c]		// header 2 <h2></h2>
	ft [H3 		attrs str  :tl] c = [str:ft tl c]		// header 3 <h3></h3>
	ft [H4	 	attrs str  :tl] c = [str:ft tl c]		// header 4 <h4></h4>
	ft [H5 		attrs str  :tl] c = [str:ft tl c]		// header 5 <h5></h5>
	ft [H6 		attrs str  :tl] c = [str:ft tl c]		// header 6 <h6></h6>			
	ft [I 		attrs str  :tl] c = [str:ft tl c]		// italic text <i></i>
	ft [Table	attrs btags:tl] c = ft btags (ft tl c)	// table <table></table>
	ft [TBody 	attrs btags:tl] c = ft btags (ft tl c)	// body of a table <tbody></tbody>
	ft [Td		attrs btags:tl] c = ft btags (ft tl c)	// table cell <td></td>
	ft [Tr		attrs btags:tl] c = ft btags (ft tl c)	// table row <tr></tr>
	ft [Tt		attrs str  :tl] c = [str:ft tl c] 		// teletyped text <tt></tt>
	ft [Txt		      str  :tl] c = [str:ft tl c] 		// plain text
	ft [U		attrs str  :tl] c = [str:ft tl c]		// underlined text <u></u>
	ft [_:tl]                   c = ft tl c
	ft []                       c = c	