module arrow

import StdEnv
import StdHtml

derive gUpd   []
derive gForm  []

import tree

Start world  = doHtmlServer MyPage world

MyPage hst
# (mycircuitf,hst) = startCircuit mycircuit [1] hst
# [list,tree:_] = mycircuitf.form
= mkHtml "List to Balance Tree"
	[ H1 [] "List to Balance Tree"
	, Txt "This is the list :", Br
	, list
	, Txt "This is the resulting balanced tree :", Br
	, tree
	] hst
where
	mycircuit :: GecCircuit [Int] (Tree Int)
	mycircuit = edit (nFormId "list" []) >>> arr fromListToBalTree >>> display (nFormId "tree" Leaf)

