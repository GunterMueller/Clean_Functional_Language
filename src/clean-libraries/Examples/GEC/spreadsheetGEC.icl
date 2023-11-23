module spreadsheetGEC

import StdEnv
import StdIO
import genericgecs
import StdGEC

goGui :: (*(PSt u:Void) -> *(PSt u:Void)) *World -> .World
goGui gui world = startIO MDI Void gui [ProcessClose closeProcess] world

derive ggen Mode

Start :: *World -> *World
Start world 
= 	goGui 
 	spreadsheet1
 	world  

spreadsheet1	=	startCircuit (feedback (edit "spreadsheet" >>> arr updsheet)) (mksheet inittable) 
where
		updsheet (table <-> _ <|>
		          _ <-> _ )			= mksheet (^^ table)
		mksheet table				= table_hv_AGEC table <-> Display (vertlistAGEC rowsum) <|>
									  Display (horlistAGEC colsum) <-> Display (sum rowsum)
		where
			rowsum					= map sum table
			colsum 					= map sum transpose
			transpose				= [[table!!i!!j \\ i <- [0..(length table)    - 1]]
												    \\ j <- [0..length (table!!0) - 1]
									  ]
		inittable	  				= [map ((+) i) [1..5] \\ i <- [0,5..25]]	

spreadsheet2	=	startCircuit (feedback (edit "spreadsheet" >>> arr updsheet))	    (mksheet inittable) 
where
		updsheet (table <-> _ <|>
		          _ <-> _ )			= mksheet (^^ table)
		mksheet table				= table_hv_AGEC table <-> vertlistAGEC rowsum <|>
									  horlistAGEC colsum <-> sum rowsum
		where
			rowsum					= map sum table
			colsum 					= map sum transpose
			transpose				= [[table!!i!!j \\ i <- [0..(length table)    - 1]]
												    \\ j <- [0..length (table!!0) - 1]
									  ]
		inittable	  				= [map ((+) i) [1..5] \\ i <- [0,5..25]]	

spreadsheet3	=	startCircuit (feedback (edit "spreadsheet" >>> arr updsheet)) (mksheet initcosts initvat) 
where
		updsheet (_ <-> _ <-> _ <-> _ <|>
				  costs <-> _ <-> _ <-> vat <|>
		          _ <-> _ <-> _ )	= mksheet (^^ costs) vat
		mksheet costs vat			= Display "Result " <-> Display "Tax " <-> Display "Result + Tax " <-> Display "VAT " <|>
									  vertlistAGEC costs <-> Display (vertlistAGEC tax) <-> Display (vertlistAGEC rowsum) <-> vat <|>
									  Display sumcosts  <-> Display sumtax <-> Display (sumcosts + sumtax)
		where
			sumcosts				= sum costs
			sumtax					= sum tax
			rowsum					= [x + y \\ x <- costs & y <- tax]
			tax 					= [x * vat\\ x <- costs]
			
		initcosts	  				= [10.00 .. 16.00]
		initvat						= 0.19	

