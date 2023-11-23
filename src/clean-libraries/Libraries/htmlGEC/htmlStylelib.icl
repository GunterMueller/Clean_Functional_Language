implementation module htmlStylelib

import htmlStyleDef

TableHeaderStyle :: Standard_Attr
TableHeaderStyle	= Std_Class "TableHeader"

TableRowStyle :: Standard_Attr
TableRowStyle		= Std_Class "TableRow"

CleanStyle :: Standard_Attr
CleanStyle			= Std_Class "CleanStyle"

EditBoxStyle :: Standard_Attr
EditBoxStyle		= Std_Class "EditBox"

DisplayBoxStyle :: Standard_Attr
DisplayBoxStyle		= Std_Class "DisplayBox"

CleanStyles :: [Style]
CleanStyles 
	=:	[ Style "CleanStyle" 
			[ 	BgImage (`Img_URL "images/back35.jpg")
			,  	FntFamily "Arial, Helvetica, sans-serif"
			, 	FntStyle Fst_Normal
			,	FntWeight Fwo_Normal
			, 	FntSize (Fso_Length 14)
			, 	TxtColor (`Colorname White)
			, 	BdColor (`Color (`HexColor (Hexnum H_9 H_C H_A H_2 H_A H_D)))	
			, 	BdTopColor (`Colorname Red)
			]
		, Style "TableHeader"
			[	FntFamily "Arial, Helvetica, sans-serif"
			, 	TxtColor (`HexColor (Hexnum H_F H_E H_D H_B H_1 H_8))
//			,	BgColor (`Color (`HexColor (Hexnum H_3 H_2 H_7 H_2 H_9 H_D)))
			,	BgColor (`Color (`Colorname Black))
//			,	FntWeight Fwo_Bold
			,	FntWeight Fwo_Normal
			,	FntSize (Fso_Length	18)
			]
		, Style "TableRow"
			[	FntFamily "Arial, Helvetica, sans-serif"
			,	BgColor (`Color (`HexColor (Hexnum H_3 H_2 H_7 H_2 H_9 H_D)))
			,	FntWeight Fwo_Normal
			,	FntSize (Fso_Length	18)
			]
		, Style "EditBox"
			[	FntFamily "Arial, Helvetica, sans-serif"
			,	FntSize (Fso_Length	18)
			]
		, Style "DisplayBox"
			[	FntFamily "Arial, Helvetica, sans-serif"
			,	FntSize (Fso_Length	18)
			, 	TxtColor (`Colorname White)
			,	BgColor (`Color (`HexColor (Hexnum H_3 H_2 H_7 H_2 H_9 H_D)))
			]
		, Style "SectionTitle"
			[	FntFamily "Arial, Helvetica, sans-serif"
			, 	TxtColor (`HexColor (Hexnum H_F H_E H_D H_B H_1 H_8))
			,	FntWeight Fwo_Bold
			,	FntSize (Fso_Length	24)
			]
		, Style "BookTitle"
			[	FntFamily "Arial, Helvetica, sans-serif"
			,	FntStyle Fst_Italic
			,	FntSize (Fso_Length	18)
			, 	TxtColor (`HexColor (Hexnum H_F H_F H_F H_F H_F H_F))
			]
		, Style "AuthorName"
		  	[	FntSize (Fso_Length	16)
		  	]
		, Style "BookInfo" 
		  	[	FntFamily "Arial, Helvetica, sans-serif"
			, 	TxtColor (`HexColor (Hexnum H_F H_F H_F H_F H_F H_F))
			]
		, Style "TrackList" 
		  	[	TxtColor (`HexColor (Hexnum H_3 H_1 H_7 H_1 H_9 H_C))
			,	FntWeight Fwo_Bold
			]
		]
