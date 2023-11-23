implementation module modeGEC

import genericgecs, guigecs, infragecs
import StdGECExt

// A hidden editor will show nothing but behaves as an editor

// Mode = Hide:    hidden editor will show nothing but behaves as an editor
// Mode = Display: non editable
// Mode = Edit:    identity

gGEC{|Mode|} gGECa args=:{gec_value = Just (Display a), update = modeupdate} pSt
= convert (gGECa {args & gec_value = Just a, update = aupdate,outputOnly = OutputOnly} pSt)
where
	convert (ahandle,pst) = ({ahandle & gecSetValue = modeSetValue ahandle
	                                  , gecGetValue = displayGetValue ahandle
	                          },pst)
	displayGetValue ahandle pst
	# (na,pst) = ahandle.gecGetValue pst
	= (Display na,pst)
	
	modeSetValue ahandle upd (Edit a) 		=  ahandle.gecSetValue upd a
	modeSetValue ahandle upd (Display a) 	=  ahandle.gecSetValue upd a
	modeSetValue ahandle upd (Hide a) 		=  ahandle.gecSetValue upd a
	modeSetValue ahandle upd (EmptyMode) 	=  \pst 	=  pst

	aupdate reason na pst = modeupdate reason (Display na) pst

gGEC{|Mode|} gGECa args=:{gec_value = Just (Edit a), update = modeupdate} pSt
= convert (gGECa {args & gec_value = Just a, update = aupdate} pSt)
where
	convert (ahandle,pst) = ({ahandle & gecSetValue = modeSetValue ahandle
	                                  , gecGetValue = modeGetValue ahandle
	                          },pst)
	modeGetValue ahandle pst
	# (na,pst) = ahandle.gecGetValue pst
	= (Edit na,pst)
	
	modeSetValue ahandle upd (Edit a) 		=  ahandle.gecSetValue upd a
	modeSetValue ahandle upd (Display a) 	=  ahandle.gecSetValue upd a
	modeSetValue ahandle upd (Hide a) 		=  ahandle.gecSetValue upd a
	modeSetValue ahandle upd (EmptyMode) 	=  \pst 	=  pst

	aupdate reason na pst = modeupdate reason (Edit na) pst

gGEC{|Mode|} gGECa args=:{gec_value = Just (Hide a), update = modeupdate} pSt
= createDummyGEC OutputOnly (Hide a) modeupdate pSt

gGEC{|Mode|} gGECa args=:{gec_value = Just (EmptyMode), update = modeupdate} pSt
= createDummyGEC OutputOnly (EmptyMode) modeupdate pSt
