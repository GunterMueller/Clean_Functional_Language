module IFL2005Examples

import StdEnv
import StdHtml

//Start world  = doHtml example1 world
Start world  = doHtmlServer example5a world

myIntId :: (InIDataId Int)
myIntId		= initID (nFormId "nr" 1)


mySumId :: a -> (InIDataId a) | toString a
mySumId i	= initID (nFormId ("sum"<+++ i) i)


//  Example: display an integer editor:
example1 hst
    # (nrF,hst) = mkEditForm myIntId hst
    = mkHtml "Int editor"
        [ H1 [] "Int editor"
        , STable [] [nrF.form]
        ] hst

//  Example: display a list of numbers vertically, and the sum of its values:
example2 hst
    # (nrFs,hst) = seqList [mkEditForm (mySumId nr) \\ nr<-[1..5]] hst
    # sumNrs     = sum [nrF.value \\ nrF <- nrFs]
    = mkHtml "Sum of Numbers"
        [ H1 [] "Sum of Numbers"
        , STable [] ([nrF.form \\ nrF <- nrFs] ++ [[toHtml sumNrs]])
        ] hst

//  Example: display a list of numbers vertically, and the sum of its values.
//           Do this twice, to illustrate sharing.
example3 hst
    # (nrFs,hst) = seqList [mkEditForm (mySumId nr) \\ nr<-[1..5]] hst
    # sumNrs     = sum [nrF.value \\ nrF <- nrFs]
    = mkHtml "Sum of Numbers"
        [ H1 [] "Sum of Numbers"
        , STable [] ([nrF.form ++ nrF.form  \\ nrF <- nrFs] ++ [[toHtml sumNrs,toHtml sumNrs]])
        ] hst


//  Example: display a list of numbers vertically, but use counter-editors instead of number-editors:
example4 hst
    # (nrFs,hst) = seqList [counterForm (mySumId nr) \\ nr<-[1..5]] hst
    # sumNrs     = sum [nrF.value \\ nrF <- nrFs]
    = mkHtml "Sum of Numbers"
        [ H1 [] "Sum of Numbers"
        , STable [] ([nrF.form \\ nrF <- nrFs] ++ [[toHtml sumNrs]])
        ] hst

//  Example: display a list of numbers vertically, but use counter-editors instead of number-editors:
example5 hst
    # (nrFs,hst) = seqList [mkEditForm (mySumId (M nr)) \\ nr<-[1..5]] hst
    # sumNrs     = sum [toInt nrF.value \\ nrF <- nrFs]
    = mkHtml "Sum of Numbers"
        [ H1 [] "Sum of Numbers"
        , STable [] ([nrF.form \\ nrF <- nrFs] ++ [[toHtml sumNrs]])
        ] hst

<<<<<<< IFL2005Examples.icl
//  Example: display a list of numbers vertically, but use counter-editors instead of number-editors:
example5a hst
    # (nrFs,hst) = seqList [mkEditForm (sumId nr) (Init nr) \\ nr<-[1..5]] hst
    # sumNrs     = sum [toInt nrF.value \\ nrF <- nrFs]
    = mkHtml "Vertical Table"
        [ H1 [] "Vertical Table"
        , STable [] ([nrF.form \\ nrF <- nrFs] ++ [[toHtml sumNrs]])
        ] hst

sumId i = nFormId ("sum"<$i)
=======
>>>>>>> 1.5

//	Define new type to specialize 'Int':
::  MInt = M Int
derive gParse MInt
derive gPrint MInt
derive gUpd   MInt
derive gerda   MInt

gForm{|MInt|} (init,formid) hst = specialize asCounter (init,formid) hst
where
    asCounter (init,formId) hst
        # (counterF,hst) = counterForm (init,nformId) hst
        = ({changed=counterF.changed,value=M (toInt counterF.value),form=counterF.form},hst)
	where
		(M i) = formId.ival
  		nformId = reuseFormId formId i      

instance toInt MInt where toInt (M i) = i
instance toString MInt where toString (M i) = toString i
