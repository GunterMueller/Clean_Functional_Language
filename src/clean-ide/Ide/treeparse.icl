/************************************************/
/* Module:	searchtree 							*/
/* 												*/
/* Auteurs:	Tim Nieuwenhuis, Coen Goedegebure 	*/
/*												*/
/* Datum:	14/07/00							*/
/*												*/
/************************************************/

implementation module treeparse

import StdEnv, StdIO, searchtree
//import StdDebug

definitionsFileName	:==	"Defs.def"

// Read the tree from disk into memory,
// Called externally
readFileInTree :: !*env -> (!Tree,!*env) | FileEnv env
readFileInTree filesEnv
	# (boom,filesEnv)			= accFiles (fillTreeWithDefs (applicationpath definitionsFileName)) filesEnv
	= (boom,filesEnv)
where
	fillTreeWithDefs :: !String !*Files -> (!Tree,!*Files)
	fillTreeWithDefs fileName filesEnv
		# (ok,f,filesEnv)		= fopen fileName FReadText filesEnv
		| not ok
			= //trace_n ("Warning: could not open file '"+++fileName+++"' for reading")
				(newTree,filesEnv)
		| otherwise
			# (boom,f)			= readlines f (newTree)
			# (_,filesEnv)		= fclose f filesEnv
			= (boom,filesEnv)
	where
		readlines :: !*File !Tree -> (!Tree,!*File)
		readlines f b
			# (line,f) 			= readline f
			| (line == "EOF")	= (b,f)
			# line 				= removeNl line False
			# (b,f)				= readDefinitions f line b False
			= (b,f)

// read line from a file, if EOF returns "EOF"
readline :: !*File -> (!String,!*File)
readline f
	| sfend f
				= ("EOF",f)
	# (line, f)	= freadline f
	= (line,f)
			
/* Removes \n character from a line,
   if True, check whether the \n is present, if not just remove last character */
removeNl :: !String !Bool -> String
removeNl s doCheck
	# length 	= size s
	| doCheck	= if (s%(length,length)=="\n") (s%(0,length-2)) s 	
	| otherwise	= if (length>1) (s%(0,length-2)) (s)				


// Reads the definition file and returns the binary searchtree
readDefinitions :: !*File !String !Tree !Bool-> (!Tree, !*File)
readDefinitions f s b inComment
	# d								= getDefName s
	# keepNl						= if ((d=="class") || (d=="where") || (d=="::")) True False
	# (s, nextLine, f, inComment)	= findNextLines f s inComment keepNl
	# (fName, fDef, _)				= case d of
										"class"	-> parseClassDef (s%(size d+1,size s)) False
										"::"	-> parseTypeDef (s%(size d+1,size s))
										_		-> (getDefName s,s,[])
	# b 							= (insertIntoTree {funName=fName,funDef=fDef} b)
	| (nextLine=="EOF")				= (b,f)
	| otherwise						= readDefinitions f nextLine b inComment

/* Collects a definition. Checks if the definition is continued in the next line, if so add next line to the definition
   if second boolean is True, keep the \n-characters */
findNextLines :: !*File !String !Bool !Bool-> (!String, !String, !*File, !Bool)
findNextLines f s inComment keepNlChar
	# (nextLine, f)									= readline f
	| (nextLine=="EOF")								= (s, nextLine, f, inComment)
	# nextLine										= if (not keepNlChar) (removeNl nextLine False) (nextLine)
	# (parsedNextLine, nextInComment)				= parseDef nextLine inComment
	| (((getDefName s)=="class") 
		&& ((getDefName parsedNextLine)=="where"))	= findNextLines f (s+++" "+++parsedNextLine) nextInComment keepNlChar
	| (((getDefName s)=="::") 
		&& (parsedNextLine%(0,1)==" |"))			= findNextLines f (s+++"\n"+++parsedNextLine) nextInComment keepNlChar
	| (parsedNextLine=="")							= findNextLines f s nextInComment keepNlChar
	| (not (isBlankChar 0 nextLine)	
		&& inComment 
		&& not (parsedNextLine==""))				= (s, nextLine, f, inComment)
	| ((isBlankChar 0 nextLine) 
		&& (parsedNextLine=="\n"))					= findNextLines f s nextInComment keepNlChar
	| ((isBlankChar 0 nextLine) 
		&& (parsedNextLine%(0,6)==" Member"))		= findNextLines f (s+++"\n"+++parsedNextLine) nextInComment keepNlChar
	| (isBlankChar 0 nextLine)						= findNextLines f (s+++" "+++parsedNextLine) nextInComment keepNlChar
	| (inComment)									= findNextLines f (s+++" "+++parsedNextLine) nextInComment keepNlChar
	| (keepNlChar)									= (s, removeNl nextLine False, f, inComment)
	| otherwise										= (s, nextLine, f, inComment)

// returns the definition name from string s
getDefName :: !String -> String
getDefName s
	# n = findFirstBlank 0 s 
	# s = if (n==(-1)) "" (s%(0,n-1))
	= removeBraces 0 s

// removes the ()-braces for infix operators
removeBraces :: !Int !String -> String
removeBraces i s
	# c = s%(i,i)
	| (i>size s)				= s
	| ((c=="(") || (c==")"))	= removeBraces (i+1) (s%(0,i-1)+++s%(i+1,size s))
	| otherwise					= removeBraces (i+1) s	

// find the first blank-character in string s starting from index i
findFirstBlank :: !Int !String -> Int
findFirstBlank i s
	# c = s%(i,i)
	# cc = s%(i,i+1)
	| (i>size s)												= -1 	
	| ((cc=="::") && (i==0))									= i+2
	| ((c==" ") || (c=="\t") || (c==":") || (c=="") ||(c=="\n"))= i
	| otherwise 												= findFirstBlank (i+1) s
	
/* parse the definition. Remove comment and blanks to optimise the layout in the tooltip
   Bool is True if line inComment */
parseDef :: !String !Bool-> (!String, !Bool)
parseDef s inComment
	# (s, inComment) 	= removeComment 0 s inComment 0 False (not inComment)
	# s 				= removeBlanks 0 s
	= (s, inComment)

/* 	removes the comment from a line and returns the clean string 
	AND True if the next line starts in comment as well
 	i		 	= counter 
	inComment	= current character is in comment
	cStart		= index where comment started
	inString	= current character is in a String
	isDblComment= type of comment, True if comment is doubleslash, False otherwise */
removeComment :: !Int !String !Bool !Int !Bool !Bool -> (!String, !Bool)
removeComment i s inComment cStart inString isDblComment
	# c															= s%(i,i)
	# cMin 														= select s (i-1)
	| ((i>size s) && inComment && (not isDblComment))			= (s%(0,cStart-1), True)
	| ((i>size s) && inComment && isDblComment)					= (s%(0,cStart-1), False)
	| ((i>size s) && (not inComment))							= (s, False)
	| ((c=="\"") && (not inString))								= removeComment (i+1) s inComment cStart True isDblComment
	| ((c=="\"") && (inString) && (cMin<>'\\'))					= removeComment (i+1) s inComment cStart False isDblComment
	# cc														= s%(i,i+1)
	# backN														= findInString (i+1) s "\n"
	| inString													= removeComment (i+1) s inComment cStart inString isDblComment
	| ((cc=="//") && (isAlphaSpace cMin) && (not inComment))	= (s%(0,i-1), False)
	| ((cc=="//") && (i==0) && (not inComment))					= ("", False)
	| ((cc=="//") && (isAlphaSpace cMin) && (not inComment))	= removeComment (i+1) (s%(0,i-1)+++s%(backN,size s)) inComment cStart inString isDblComment
	| ((cc=="//") && (isAlphaSpace cMin) && inComment)			= (s%(0,cStart-1), True)
	| ((cc=="/*") && (isAlphaSpace cMin) && (not inComment))	= removeComment (i+2) s True i inString False
	| ((cc=="/*") && (i==0) && (not inComment))					= removeComment (i+2) s True i inString False
	| ((cc=="*/") && inComment)									= removeComment (cStart+2) (s%(0,cStart-1)+++s%(i+2,size s)) False cStart inString False
	| ((cc=="*/") && (not inComment))							= removeComment 0 (s%(i+2,size s)) False 0 inString isDblComment
	| otherwise													= removeComment (i+1) s inComment cStart inString isDblComment

// Returns True if the character is an alphanumeric character or a space
isAlphaSpace :: !Char -> Bool 
isAlphaSpace c 
	= ((isAlphanum c) || (c==' ') || (c=='\t'))

// Remove the blanks from the string to optimise the layout in the tooltip
removeBlanks :: !Int !String -> String
removeBlanks i s
	# c = s%(i,i)
	| (i>size s)	 				 		= s
	| ((isBlankChar i s)==False)			= removeBlanks (i+1) s
	| (c=="\t") 					 		= removeBlanks i ((s%(0,i-1))+++" "+++(s%(i+1,size s)))
	| ((c==" ") && (isBlankChar (i+1) s))	= removeBlanks i ((s%(0,i-1))+++(s%(i+1,size s)))
	| (c==" ") 						 		= removeBlanks (i+1) s
	| otherwise								= removeBlanks (i+1) s 

// Returns True if the character is a blank
isBlankChar :: !Int !String -> Bool
isBlankChar i s
	# s = s%(i,i)
	| ((s==" ") || (s=="\t") || (s=="") || (s=="\n"))	= True
	| otherwise 										= False

// Returns True if the entire line is a blank line
isBlankLine :: !String -> Bool
isBlankLine s
	| ((s==" ") || (s=="\t") || (s=="") || (s=="\n"))	= True
	| otherwise 										= False

/* Run through the dcl-file to collect definitions 
   Called externally to create a defs.def file. 
   Currently sends the data to stderr. The generated file can be renamed to defs.def*/
spitDclDoor :: !String !*env -> *env | FileEnv env
spitDclDoor s filesEnv
	# (_,filesEnv)				= accFiles (openDcl (applicationpath s)) filesEnv
	= filesEnv
where
	openDcl :: !String !*Files -> (!Bool,!*Files)
	openDcl fileName filesEnv
		# (ok,f,filesEnv)		= fopen fileName FReadText filesEnv
		| not ok
			= //trace_n ("Warning: could not open file '"+++fileName+++"' for reading")
				(False,filesEnv)
		| otherwise
			# f	= initDcl f
			# (_,filesEnv)		= fclose f filesEnv
			= (True,filesEnv)
	where
		initDcl :: !*File -> *File
		initDcl f 
			# (line,f) 			= readline f
			| (line == "EOF")	= f
			# line 				= removeNl line False
			# f					= processDcl f line False
			= f

// Physically run through the dcl-file
processDcl :: !*File !String !Bool -> *File
processDcl f s inComment
	# (s, inComment)				= parseDef s inComment
	# d								= getDefName s
	# d								= removeNl d True
	# keepNl						= if ((d=="class") || (d=="where") || (d=="::")) True False
	# (s, nextLine, f, inComment)	= findNextLines f s inComment keepNl
	# s								= removeBlanks 0 s
	# f								= writeDefToFile f s
	| (nextLine=="EOF")				= f
	| otherwise						= processDcl f nextLine inComment
 
// Write the found definitions to a file
writeDefToFile :: !*File !String -> *File
writeDefToFile f s
	# (fn,fd,dl)	= validateDefinition s
	# fn			= if ((fn=="") && (fn=="")) fn fn	//(trace_n fd fn)
	# f				= if ((fn=="") && (fn=="")) f (writeListToFile f dl)
	= f

// Write the classfunctions in the list to file
writeListToFile :: !*File [String] -> *File
writeListToFile f [] 
	= f
writeListToFile f [h:t]
//	# t	= trace_n h t
	= writeListToFile f t

// Checks if the string is a valid definition
validateDefinition :: !String -> (!String, !String, [String])
validateDefinition s
	| (isBlankLine s)				= ("","",[])					// blank line
	# d								= getDefName s
	| (isSpecialType d)				= ("","",[])
	# (funName, funDef, defList)	= case d of
									"class"	-> parseClassDef (s%(size d+1,size s)) True
									"::"	-> parseTypeDef (s%(size d+1,size s))
									_		-> (getDefName s,s, [])
	= (funName, funDef, defList)

// Parse the classdefinition
parseClassDef :: !String !Bool-> (!String, !String, [String])
parseClassDef s spitWhereDoor
	# funName 		= getDefName s
	# locWhere		= findInString 0 s "where"
	# afterWhere	= if (not (locWhere==(-1)) && (not (s%(locWhere+6,locWhere+6)=="\n"))) ("\n"+++s%(locWhere+6,size s)) (s%(locWhere+6,size s))
	# beforeWhere	= if (not (locWhere==(-1))) (s%(0,locWhere-1)) s 
	# (s, defList)	= zoekFuncties locWhere s funName afterWhere
	# funDef		= if (locWhere==(-1)) s (beforeWhere+++"\nwhere"+++s)
	# funDef 		= removeNl (removeBlanks 0 funDef) True 
	# funDef		= if (isControl (select funDef (size funDef-1))) (funDef%(0,size funDef-2)) funDef
	= (funName , "class "+++funDef, defList)
	where
		zoekFuncties :: !Int !String !String !String -> (!String, [String])
		zoekFuncties i ss funName afterWhere 
			| (i==(-1)) 		= (ss,[])
			| (spitWhereDoor)	= findClassFunctions funName afterWhere
			| otherwise			= (afterWhere,[])

// Parse the typedefinition
parseTypeDef :: !String -> (!String, !String, [String])
parseTypeDef s
	# funName 		= getDefName s
	# locAcc		= findInString 0 s "{"
	# locEq			= findInString 0 s "="
	# isNotEqual	= if ((s%(locEq,locEq+2))==":==") True False
	# afterAcc		= if (not (locAcc==(-1))) ("\n "+++s%(locAcc+1,size s)) s
	# funDef		= if ((locAcc==(-1)) || (isNotEqual)) s (s%(0,locEq+1)+++afterAcc)
	# funDef 		= removeNl funDef True 
	# funDef		= if (isControl (select funDef (size funDef-1))) (funDef%(0,size funDef-2)) funDef
	= (funName , ":: "+++funDef, [])

// Checks if there are any classfunctions
findClassFunctions :: !String !String -> (!String, [String])
findClassFunctions className s
	# s				= parseClassFunctions 0 (decreaseLevel 0 s)
	# (s, defList)	= writeClassFunctions 1 [] className s
	# s				= increaseLevel 0 s
	= (s, defList)

// Write the classfunction to a list
writeClassFunctions :: !Int [String] !String !String -> (!String, [String])
writeClassFunctions i defList className s
	# n									= (findInString i s "\n")
	# ss								= if (n==(-1)) (s%(i,size s)) (s%(i,n))
	# isValidDef						= if ((findInString 0 ss "::")==(-1)) False True
	| ((not isValidDef) && (n==(-1))) 	= (s%(0,i-1), defList)
	| (not isValidDef) 					= writeClassFunctions i defList className (s%(0,i-2)+++s%(n+1,size s))
	# funDef							= ss+++"\n Member of class "+++className
	# defList							= defList ++ [funDef]
	| (n==(-1)) 						= (s, defList)
	| otherwise							= writeClassFunctions (n+2) defList className s

// parse the classfunctions
parseClassFunctions :: !Int !String -> String
parseClassFunctions i s
	# n												= (findInString i s "\n")+1
	# cc											= s%(n+1,n+2)
	| ((n==(-1)) || (i>size s))						= s
	| (n==1)										= parseClassFunctions (n+1) s
	| ((isBlankChar (n+1) s) || (isSeparator cc))	= parseClassFunctions (n+2) (s%(0,n-1)+++" "+++s%(n+1,size s))
	| otherwise										= parseClassFunctions (n+1) s
	
// Returns True if the string is a separator
isSeparator :: !String -> Bool
isSeparator s
	| ((s=="::") || (s=="->"))	= True
	| otherwise					= False

// Move the code-block one blank left
decreaseLevel :: !Int !String -> String
decreaseLevel i s
	# n				= findInString i s "\n"
	| (n==(-1))		= s
	| (n==0)		= decreaseLevel (n+2) (s%(0,n)+++s%(n+2,size s))
	| otherwise		= decreaseLevel (n+3) (s%(0,n+1)+++s%(n+3,size s))

// Move the code-block one blank right
increaseLevel :: !Int !String -> String
increaseLevel i s
	# n				= findInString i s "\n"
	| (n==(-1))		= s
	| (n==0)		= increaseLevel (n+2) (s%(0,n)+++" "+++s%(n+1,size s))
	| otherwise		= increaseLevel (n+3) (s%(0,n+1)+++" "+++s%(n+2,size s))

/* Returns the start-index of fs, if fs is a part of in ss, -1 if it is not */
findInString :: !Int !String !String -> Int
findInString i ss fs
	| (i+size fs>size ss)						= -1
	| ((ss%(i,i+size fs-1)==fs) && (i==0))		= 0
	| ((ss%(i,i+size fs-1)==fs) && not (i==0))	= i-1
	| otherwise									= findInString (i+1) ss fs

// is the line of a type that must not be searched for, or must be removed.
isSpecialType :: !String -> Bool
isSpecialType s
	| ((s=="definition") 			// no definition module name definition
		|| (s=="from") 				// no imports
		|| (s=="import") 			// no imports
		|| (s=="system")			// no system module name
		|| (s=="instance")			// no instance definitions of classes, only real classes
		|| (s=="export")			// no exports
		|| (s=="where"))			// no wheres from instance for example
		 					= True
	| otherwise				= False