definition module StrictnessList

:: StrictnessList
	=	NotStrict
	|	Strict !Int
	|	StrictList !Int StrictnessList
