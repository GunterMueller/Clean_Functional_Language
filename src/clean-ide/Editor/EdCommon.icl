implementation module EdCommon

from EdState import class Editor, :: EditorState
import EdMonad

:: *PLocState :== MyEditorState
:: MyEditorState = MES EditorState

instance Editor MyEditorState
where
	getEditorState ps=:(MES es) = (es,ps)
	setEditorState es ps = MES es

mChangeSelectionTo :: Selection -> EditMonad (PSt *MyEditorState) nothing
mChangeSelectionTo newSelection = skip
/*	getText											>>>= \text ->
	getMenuSelection								>>>= \mselold ->
	accEnv (getMenuIds)								>>>= \mIds ->
	let (frag,_)	= getTextFragment (orderSelection newSelection) text
		mselnew		= dofrag frag
		fragaction
			| changed mselold mselnew = (handlefrag mselnew mIds	>>> setMenuSelection mselnew)
			= skip
	in
	fragaction
where
	changed Nothing Nothing = False
	changed (Just strl) (Just strr) = strl <> strr
	changed _ _ = True
	
	dofrag (SCons (str) SNil) 
		| CleanModId str
			= Just str
		= Nothing
	dofrag _ = Nothing

	handlefrag (Just str) mIds
		=	appEnv (appPIO (setMenuElementTitles
				[(mIds.mn_odm,"Open "+++(MakeDefPathname str))
				,(mIds.mn_oim,"Open "+++(MakeImpPathname str))
				]))
	handlefrag _ mIds =
		appEnv (appPIO (setMenuElementTitles
			[(mIds.mn_odm,"Open Definition...")
			,(mIds.mn_oim,"Open Implementation...")
			]))
*/
mRemoveSelection :: EditMonad (PSt *MyEditorState) nothing
mRemoveSelection = skip
/*	getMenuSelection								>>>= \mselold ->
	accEnv (getMenuIds)								>>>= \mIds ->
	let
		mselnew		= Nothing
		fragaction
			| changed mselold mselnew = (handlefrag mselnew mIds	>>> setMenuSelection mselnew)
			= skip
	in
	fragaction
where
	changed Nothing Nothing = False
	changed (Just strl) (Just strr) = strl <> strr
	changed _ _ = True
	
	handlefrag (Just str) mIds
		=	appEnv (appPIO (setMenuElementTitles
				[(mIds.mn_odm,"Open "+++(MakeDefPathname str))
				,(mIds.mn_oim,"Open "+++(MakeImpPathname str))
				]))
	handlefrag _ mIds =
		appEnv (appPIO (setMenuElementTitles
			[(mIds.mn_odm,"Open Definition...")
			,(mIds.mn_oim,"Open Implementation...")
			]))
*/

controlDoubleClick :: !.Bool !.Position -> .(!*(EditState,*PSt PLocState) -> *(a,*(EditState,*PSt PLocState)));
controlDoubleClick shiftDown position =
	skip