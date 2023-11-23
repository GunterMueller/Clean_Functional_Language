module spreadsheet

// simple spreadsheet example
// (c) MJP 2005

import StdEnv
import StdHtml, htmlMonad

derive gUpd []
derive gForm []

// Different ways to define a simple spreadsheet
// Just pick out one of the following Start rules.

//Start world  = doHtmlServer spreadsheet world
//Start world  = doHtmlServer toHtmlFormspreadsheet world
//Start world  = doHtmlServer arrowsspreadsheet world
Start world  = doHtmlServer spreadsheetM world

myTableId :: (FormId [[Int]])
myTableId = nFormId "table" mytable

mytable	= inittable 8 10

myRowId :: (FormId [Int])
myRowId = ndFormId "rsum" [1]

myColId :: (FormId [Int])
myColId  = ndFormId "csum" [2]

myTotId ::  (FormId Int)
myTotId  = ndFormId "tsum" 0

// Classical way using Cleans # notation

spreadsheet hst
# (table, hst)  = table_hv_Form (initID myTableId) hst
# (rowsumf,hst) = vertlistForm  (setID  myRowId (rowsum table.value)) hst
# (colsumf,hst) = horlistForm   (setID  myColId (colsum table.value)) hst
# (totsumf,hst) = mkEditForm    (setID  myTotId (sum (rowsum table.value)))	hst
= mkHtml "Spreadsheet"
	[ H1 [] "Spreadsheet Example: "
	, table.form  <=> rowsumf.form
	, colsumf.form <=> totsumf.form
	] hst
	
// Variant using only editable forms in the # notation, displaying rest using toHtmlForm

toHtmlFormspreadsheet hst
# (table, hst) = table_hv_Form (initID myTableId) hst
= mkHtml "Spreadsheet"
	[ H1 [] "Simple Spreadsheet Example: "
	, table.form  <=> rowsumF table.value
	, colsumF table.value <=> totsumF table.value
	] hst
where
	rowsumF table = toHtmlForm (vertlistForm  (setID myRowId (rowsum table)))      
	colsumF table = toHtmlForm (horlistForm   (setID myColId (colsum table)))      
	totsumF table = toHtmlForm (mkEditForm    (setID myTotId (sum (rowsum table))))
 
// Variant using Arrow notation

arrowsspreadsheet hst
# (circuitf, hst) = startCircuit mycircuit mytable hst
# [tablefbody,rowsumfbody,colsumfbody,totsumfbody:_] = circuitf.form
= mkHtml "Spreadsheet"
	[ H1 [] "Spreadsheet Example: "
	, [tablefbody]  <=> [rowsumfbody]
	, [colsumfbody] <=> [totsumfbody]
	] hst
where
	mycircuit =	lift (Init,myTableId) table_hv_Form
				>>>	(	(arr rowsum >>> lift (Set,myRowId) vertlistForm)	&&&
			    		(arr colsum >>> lift (Set,myColId) horlistForm) 
			 		)
			 	>>> arr (sum o fst)
			 	>>> display myTotId 		

// Variant uding monads

spreadsheetM
  = table_hv_Form (initID myTableId)							>>= \tablef  ->
	vertlistForm  (setID  myRowId (rowsum tablef.value)) 		>>= \rowsumf -> 
	horlistForm   (setID  myColId (colsum tablef.value))  		>>= \colsumf ->
	mkEditForm    (setID  myTotId (sum (rowsum tablef.value)))	>>= \totsumf ->
	mkHtmlM "Spreadsheet"
	[ H1 [] "Spreadsheet Example: "
	, Br
	, tablef.form  <=> rowsumf.form
	, colsumf.form <=> totsumf.form
	]

// simple utility functions to calculate the sum of the rows, sum of columns, total sum

rowsum table	= map sum table
colsum table	= map sum (transpose table)
where
	transpose table	= [[table!!i!!j \\ i <- [0..(length table)    - 1]]
							    	\\ j <- [0..length (table!!0) - 1]
				  	  ]
inittable n m	= [ [i..i+n] \\ i <- [0,n+1 .. n*m+1]]	



