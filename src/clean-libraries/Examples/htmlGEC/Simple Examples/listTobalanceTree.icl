module listTobalanceTree

import StdEnv, StdStrictLists
import StdHtml

derive gUpd   []
derive gForm  []

import tree


Start world  = doHtml MyPage world
//Start world  = doHtmlSubServer (1,1,1,"*.*") MyPage world

myListId = nFormId "list" []
myTreeId = nFormId "tree" Leaf


gForm {|GerdaObject|} ga (init,formidGO=:{ival}) hst
# (fa,hst) = ga (init,reuseFormId formidGO ival.gerdaObject) hst
= ({fa & value = {ival & gerdaObject = fa.value}},hst) 

gParse {|GerdaObject|} ga expr =
	case ga expr of
		(Just a) -> Just (gerdaObject a)
		_ -> Nothing

gPrint {|GerdaObject|} ga {gerdaObject} pst =
	ga gerdaObject pst 

gUpd{|GerdaObject|} ga (UpdCreate l) _ 
# (updmode,a)	= ga (UpdCreate l) (abort "gerdaobject cannot create new element")
= (updmode,gerdaObject a)
gUpd{|GerdaObject|} ga updmode go 
# (updmode,a)	= ga updmode go.gerdaObject
= (updmode,{go & gerdaObject = a})

MyPage hst
# (iList1,hst) = mkEditForm (Init, nFormId "mylist1" initVal ) hst
# (iList2,hst) = mkEditForm (Init, nFormId "mylist2" initVal <@ Display ) hst
= mkHtml "Balancing Tree From List"
		[ Txt "Converting a list:", Br, Br
          , BodyTag iList1.form
         , BodyTag iList2.form
           ] hst

//initVal :: [GerdaObject Int]
//initVal = [gerdaObject i \\ i <- [1..3]]
initVal = [1..3]

MyPageArr hst
# (mycircuitf,hst) = startCircuit mycircuit [1,5,2] hst
= mkHtml "Balancing Tree From List"
	[ Txt "List to Balanced Tree", Br
	, BodyTag mycircuitf.form
	] hst
where
	mycircuit :: GecCircuit [Int] (Tree Int)
	mycircuit = edit myListId >>> arr fromListToBalTree >>> display myTreeId

