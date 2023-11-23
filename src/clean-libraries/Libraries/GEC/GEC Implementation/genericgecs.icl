implementation module genericgecs

import infragecs, StdMisc

derive gGEC []

generic gGEC t :: !(GECArgs t (PSt .ps)) !(PSt .ps) -> (!GECVALUE t (PSt .ps),!PSt .ps)
gGEC{|Bool|}                                                                                           gecArgs pSt
	= let (tGEC,pSt1) = openGECId pSt
	      typeName    = "Bool"   in basicGEC typeName tGEC (basicGECGUI typeName (setGECvalue tGEC))   gecArgs pSt1
gGEC{|Int|}                                                                                            gecArgs pSt
	= let (tGEC,pSt1) = openGECId pSt
	      typeName    = "Int"    in basicGEC typeName tGEC (basicGECGUI typeName (setGECvalue tGEC))   gecArgs pSt1
gGEC{|Real|}                                                                                           gecArgs pSt
	= let (tGEC,pSt1) = openGECId pSt
	      typeName    = "Real"   in basicGEC typeName tGEC (basicGECGUI typeName (setGECvalue tGEC))   gecArgs pSt1
gGEC{|Char|}                                                                                           gecArgs pSt
	= let (tGEC,pSt1) = openGECId pSt
	      typeName    = "Char"   in basicGEC typeName tGEC (basicGECGUI typeName (setGECvalue tGEC))   gecArgs pSt1
gGEC{|String|}                                                                                         gecArgs pSt
	= let (tGEC,pSt1) = openGECId pSt
	      typeName    = "String" in basicGEC typeName tGEC (basicGECGUI typeName (setGECvalue tGEC))   gecArgs pSt1

gGEC{|OBJECT of t|}                                                                        gGECa       gecArgs pSt
	= let (tGEC,pSt1) = openGECId pSt
	  in  objectGEC t tGEC (objectGECGUI t (switchGEC tGEC YesUpdate) (arrangeGEC tGEC) gecArgs.hasOBJECT)
	                                                                                       gGECa       gecArgs pSt1
gGEC{|OBJECT |}                                                                        gGECa       gecArgs pSt
	= abort "zou niet mogen"
gGEC{|UNIT|}                                                                                           gecArgs pSt
	= unitGEC unitGECGUI                                                                               gecArgs pSt
gGEC{|PAIR|}                                                                               gGECa gGECb gecArgs pSt
	= pairGEC pairGECGUI                                                                   gGECa gGECb gecArgs pSt
gGEC{|CONS of d|}                                                                          gGECa       gecArgs pSt
	= consGEC d (consGECGUI d)                                                             gGECa       gecArgs pSt
gGEC{|FIELD of t|}                                                                         gGECa       gecArgs pSt
	= fieldGEC t (fieldGECGUI t)                                                           gGECa       gecArgs pSt
gGEC{|EITHER|}                                                                             gGECa gGECb gecArgs pSt
	= eitherGEC eitherGECGUI                                                               gGECa gGECb gecArgs pSt
