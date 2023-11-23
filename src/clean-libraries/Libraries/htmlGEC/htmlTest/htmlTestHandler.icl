implementation module htmlTestHandler

import htmlEncodeDecode, htmlHandler, StdEnv

derive gParse UpdValue

instance toString (a,b,c) | toString a & toString b & toString c
where
	toString (a,b,c) = "(\"" +++ toString a +++ "\"," +++ toString b +++ "," +++ toString c +++ ")"

instance toString UpdValue
where
	toString (UpdI i)	= "UpdI " +++ toString i	
	toString (UpdR r)	= "UpdR " +++ toString r	
	toString (UpdB b)	= "UpdB " +++ toString b	
	toString (UpdC c)	= "UpdC " +++ c	
	toString (UpdS s)	= "UpdS \"" +++ s +++ "\""	

doHtmlTest :: (Maybe *TestEvent) (*HSt -> (Html,!*HSt)) *NWorld -> (Html,*FormStates,*NWorld)
doHtmlTest nextevent userpage nworld // execute user code given the chosen testevent to determine the new possible inputs
# (newstates,nworld) 	= case nextevent of 
							Nothing -> initTestFormStates nworld // initial empty states
							Just (triplet=:(id,pos,UpdI oldint),UpdI newint,oldstates) -> setTestFormStates (toString triplet) id (toString newint) oldstates nworld  
							Just (triplet=:(id,pos,UpdR oldreal),UpdR newreal,oldstates) -> setTestFormStates (/*encodeInfo*/ toString triplet) id (toString newreal) oldstates nworld  
							Just (triplet=:(id,pos,UpdB oldbool),UpdB newbool,oldstates) -> setTestFormStates (toString triplet) id (toString newbool) oldstates nworld  
							Just (triplet=:(id,pos,UpdC oldcons),UpdC newcons,oldstates) -> setTestFormStates (toString triplet) id (toString newcons) oldstates nworld  
							Just (triplet=:(id,pos,UpdS oldstring),UpdS newstring,oldstates) -> setTestFormStates (toString triplet) id (toString newstring) oldstates nworld  
= runUserApplication userpage newstates nworld
	
fetchInputOptions :: Html -> [(InputType,Value,Maybe (String,Int,UpdValue))] // determine from html code which inputs can be given next time
fetchInputOptions (Html (Head headattr headtags) (Body attr bodytags))
	= fetchInputOptions` bodytags
where
	fetchInputOptions` :: [BodyTag] -> [(InputType,Value,Maybe (String,Int,UpdValue))] // determine from html code which inputs can be given next time
	fetchInputOptions` [] 						= []
	fetchInputOptions` [Input info _  :inputs]	= fetchInputOption info   ++ fetchInputOptions` inputs
	fetchInputOptions` [BodyTag bdtag :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [A _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Dd _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Dir _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Div _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Dl _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Dt _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Fieldset _ bdtag :inputs]= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Font _ bdtag  :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Form _ bdtag  :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Li _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Map _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Menu _ bdtag  :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Ol _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [P _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Pre _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Span _ bdtag  :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Table _ bdtag :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [TBody _ bdtag :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Td _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [TFoot _ bdtag :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [THead _ bdtag :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Tr _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [Ul _ bdtag 	 :inputs] 	= fetchInputOptions` bdtag ++ fetchInputOptions` inputs
	fetchInputOptions` [STable _ bdtags :inputs] = flatten (map fetchInputOptions` bdtags) ++ fetchInputOptions` inputs
	fetchInputOptions` [_			 :inputs] 	= fetchInputOptions` inputs
	
	fetchInputOption [Inp_Type inptype, Inp_Value val,	Inp_Name triplet:_] = [(inptype,val,decodeTriplet triplet)]
	fetchInputOption [Inp_Type inptype, Inp_Value val:_] = [(inptype,val,Nothing)]
	fetchInputOption [x:xs] = fetchInputOption xs
	fetchInputOption _ = []
