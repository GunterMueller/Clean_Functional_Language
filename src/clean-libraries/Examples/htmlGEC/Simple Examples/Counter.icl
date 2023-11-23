module Counter

import StdEnv
import StdHtml

//Start world  = doHtml MyPage world
Start world  = doHtmlServer MyPage world

counterId1 = initID (nFormId "counter1" 0)
counterId2 = initID (nFormId "counter2" 0)

MyPage hst
# (counter0,hst) = counterForm  counterId1 hst
# (counter1,hst) = counterForm  counterId2 hst
= mkHtml "Counter Example"
	[ H1 [] "Counter Example"
	, toBody counter0
	, toBody counter1
	, toHtml (counter0.value + counter1.value)
	] hst
