/*
** Program: Clean Prover System
** Module:  FileMonad (.icl)
** 
** Author:  Maarten de Mol
** Created: 03 April 2001
*/

implementation module
	FileMonad

import
	StdEnv,
	StdIO,
	Errors,
	States

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
	= Dummy
instance DummyValue Dummy
	where DummyValue = Dummy

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: FileM state a :== (*FileState -> *(state -> *(*PState -> *(Error, a, *FileState, state, *PState))))
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: *FileState =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ fsName					:: !String				// without path
	, fsFile					:: !*File
	, fsMode					:: !Int
	, fsLineNumber				:: !Int
	, fsCharNumber				:: !Int
	, fsCurrentLine				:: !String
	}














// -------------------------------------------------------------------------------------------------------------------------------------------------
applyFileM :: !String !String !String !Int !state !(FileM state a) !*PState -> (!Error, !a, !*PState) | DummyValue a
// -------------------------------------------------------------------------------------------------------------------------------------------------
applyFileM path name extension mode state filem pstate
	# full_name									= path +++ "\\" +++ name +++ "." +++ extension
	# ((ok, file), pstate)						= accFiles (open_file full_name) pstate
	| not ok									= ([X_OpenFile full_name], DummyValue, pstate)
	# fstate									=	{ fsName				= name +++ "." +++ extension
													, fsFile				= file
													, fsMode				= mode
													, fsLineNumber			= (if (mode == FReadText) 0 1)
													, fsCharNumber			= (if (mode == FReadText) 0 1)
													, fsCurrentLine			= "\n"
													}
	# (error, a, fstate, state, pstate)			= filem fstate state pstate
	# (_, pstate)								= accFiles (fclose fstate.fsFile) pstate
	= (error, a, pstate)
	where
		open_file :: !CName !*Files -> (!(!Bool, !*File), !*Files)
		open_file name files
			# (ok, file, files)					= fopen name mode files
			= ((ok, file), files)

// -------------------------------------------------------------------------------------------------------------------------------------------------
accFileState :: !(*FileState -> (Error, a, *FileState)) -> FileM state a
// -------------------------------------------------------------------------------------------------------------------------------------------------
accFileState f
	= action f
	where
		action :: !(*FileState -> (Error, a, *FileState)) !*FileState !state !*PState -> (!Error, !a, !*FileState, !state, !*PState)
		action f fstate state pstate
			# (error, a, fstate)				= f fstate
			= (error, a, fstate, state, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
accStates :: !(String Int Int state *PState -> (Error, a, state, *PState)) -> FileM state a
// -------------------------------------------------------------------------------------------------------------------------------------------------
accStates f
	= action f
	where
		action :: !(String Int Int state *PState -> (Error, a, state, *PState)) !*FileState !state !*PState -> (!Error, !a, !*FileState, !state, !*PState)
		action f fstate state pstate
			# (name, line_nr, char_nr, fstate)	= getFileInfo fstate
			# (error, a, state, pstate)			= f name line_nr char_nr state pstate
			= (error, a, fstate, state, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getFileInfo :: !*FileState -> (!String, !Int, !Int, !*FileState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getFileInfo fstate=:{fsName, fsLineNumber, fsCharNumber}
	= (fsName, fsLineNumber, fsCharNumber, fstate)





















// -------------------------------------------------------------------------------------------------------------------------------------------------
parseErrorM :: !String -> FileM state a | DummyValue a
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseErrorM msg
	= accFileState mk_error
	where
		mk_error :: !*FileState -> (!Error, !a, !*FileState) | DummyValue a
		mk_error fstate=:{fsName, fsLineNumber, fsCharNumber}
			# error								= [X_ParseFile fsName fsLineNumber fsCharNumber msg]
			= (error, DummyValue, fstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
returnM :: !a -> FileM state a
// -------------------------------------------------------------------------------------------------------------------------------------------------
returnM value
	= ret value
	where
		ret :: !a !*FileState !state !*PState -> (!Error, !a, !*FileState, !state, !*PState)
		ret value fstate state pstate
			= (OK, value, fstate, state, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
(>>=) infixl 6 :: !(FileM state a) !(a -> FileM state b) -> FileM state b | DummyValue b
// -------------------------------------------------------------------------------------------------------------------------------------------------
(>>=) monad mk_monad
	= action monad mk_monad
	where
		action :: !(FileM state a) !(a -> FileM state b) !*FileState !state !*PState -> (!Error, !b, !*FileState, !state, !*PState) | DummyValue b
		action monad mk_monad fstate state pstate
			# (_, _, fstate, state, pstate)		= eatSpaces fstate state pstate
			# (error, a, fstate, state, pstate)	= monad fstate state pstate
			| isError error						= (error, DummyValue, fstate, state, pstate)
			# (_, _, fstate, state, pstate)		= eatSpaces fstate state pstate
			= mk_monad a fstate state pstate

// Doesn't do an initial eatSpaces.
// -------------------------------------------------------------------------------------------------------------------------------------------------
(>>>=) infixl 6 :: !(FileM state a) !(a -> FileM state b) -> FileM state b | DummyValue b
// -------------------------------------------------------------------------------------------------------------------------------------------------
(>>>=) monad mk_monad
	= action monad mk_monad
	where
		action :: !(FileM state a) !(a -> FileM state b) !*FileState !state !*PState -> (!Error, !b, !*FileState, !state, !*PState) | DummyValue b
		action monad mk_monad fstate state pstate
//			# (_, _, fstate, state, pstate)		= eatSpaces fstate state pstate
			# (error, a, fstate, state, pstate)	= monad fstate state pstate
			| isError error						= (error, DummyValue, fstate, state, pstate)
			# (_, _, fstate, state, pstate)		= eatSpaces fstate state pstate
			= mk_monad a fstate state pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
(>>>) infixr 5 :: !(FileM state a) !(FileM state b) -> FileM state b | DummyValue b
// -------------------------------------------------------------------------------------------------------------------------------------------------
(>>>) monad1 monad2
	= action monad1 monad2
	where
		action :: !(FileM state a) !(FileM state b) !*FileState !state !*PState -> (!Error, !b, !*FileState, !state, !*PState) | DummyValue b
		action monad1 monad2 fstate state pstate
			# (_, _, fstate, state, pstate)		= eatSpaces fstate state pstate
			# (error, a, fstate, state, pstate)	= monad1 fstate state pstate
			| isError error						= (error, DummyValue, fstate, state, pstate)
			# (_, _, fstate, state, pstate)		= eatSpaces fstate state pstate
			= monad2 fstate state pstate

// Doesn't do a eatSpaces in between.
// -------------------------------------------------------------------------------------------------------------------------------------------------
(>>>>) infixr 5 :: !(FileM state a) !(FileM state b) -> FileM state b | DummyValue b
// -------------------------------------------------------------------------------------------------------------------------------------------------
(>>>>) monad1 monad2
	= action monad1 monad2
	where
		action :: !(FileM state a) !(FileM state b) !*FileState !state !*PState -> (!Error, !b, !*FileState, !state, !*PState) | DummyValue b
		action monad1 monad2 fstate state pstate
			# (_, _, fstate, state, pstate)		= eatSpaces fstate state pstate
			# (error, a, fstate, state, pstate)	= monad1 fstate state pstate
			| isError error						= (error, DummyValue, fstate, state, pstate)
//			# (_, _, fstate, state, pstate)		= eatSpaces fstate state pstate
			= monad2 fstate state pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
mapM :: !(a -> FileM state b) ![a] -> FileM state [b]
// -------------------------------------------------------------------------------------------------------------------------------------------------
mapM mk_filem []
	=	returnM []
mapM mk_filem [a:as]
	=	mk_filem a								>>= \b ->
		mapM mk_filem as						>>= \bs ->
		returnM [b:bs]

// -------------------------------------------------------------------------------------------------------------------------------------------------
repeatM :: !Int !(FileM state a) -> FileM state [a]
// -------------------------------------------------------------------------------------------------------------------------------------------------
repeatM 0 filem
	=	returnM []
repeatM n filem
	=	filem									>>= \x ->
		repeatM (n-1) filem						>>= \xs ->
		returnM [x:xs]

// -------------------------------------------------------------------------------------------------------------------------------------------------
repeatUntilM :: !String !(FileM state a) -> FileM state [a]
// -------------------------------------------------------------------------------------------------------------------------------------------------
repeatUntilM text filem
	=	lookAhead
			[ (text, False, returnM [])
			] once
	where
		once
			=	filem							>>= \x ->
				repeatUntilM text filem			>>= \xs ->
				returnM [x:xs]

















// -------------------------------------------------------------------------------------------------------------------------------------------------
isValidIdChar :: !Char -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isValidIdChar c
	| isAlphanum c								= True
	| isMember c special_chars					= True
	= False
	where
		special_chars
			= ['~@#$%^?!+-*<>\/|&=:_`.!']

// -------------------------------------------------------------------------------------------------------------------------------------------------
isValidNameChar :: !Char -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isValidNameChar c
	| isAlphanum c								= True
	| isMember c special_chars					= True
	= False
	where
		special_chars
			= ['~@#$%^?!+-*<>\/|&=_`']

// -------------------------------------------------------------------------------------------------------------------------------------------------
ReadWhile :: !(Char -> Bool) !*FileState -> (!Error, !String, !*FileState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
ReadWhile pred fstate=:{fsCharNumber, fsCurrentLine}
	# line_size									= size fsCurrentLine
	# first_fail								= read 0 line_size pred fsCurrentLine
	# fstate									= {fstate	& fsCharNumber		= fsCharNumber + first_fail
															, fsCurrentLine		= fsCurrentLine % (first_fail, line_size-1)
												  }
	= (OK, fsCurrentLine % (0, first_fail-1), fstate)
	where
		read :: !Int !Int !(Char -> Bool) !String -> Int 
		read index max pred text
			| index >= max						= index
			| pred text.[index]					= read (index+1) max pred text
			= index























// -------------------------------------------------------------------------------------------------------------------------------------------------
advanceLine :: FileM state Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
advanceLine
	= accFileState advance__line
	where
		advance__line :: !*FileState -> (!Error, !Dummy, !*FileState)
		advance__line fstate=:{fsMode, fsLineNumber}
			| fsMode == FReadText				= advance_line fstate
			# file								= fwrites "\n" fstate.fsFile
			# fstate							= {fstate	& fsFile			= file
															, fsLineNumber		= fsLineNumber + 1
															, fsCharNumber		= 1
												  }
			= (OK, Dummy, fstate)
	
		advance_line :: !*FileState -> (!Error, !Dummy, !*FileState)
		advance_line fstate=:{fsName, fsLineNumber, fsCharNumber, fsCurrentLine}
			| fsCurrentLine <> "\n"
				# error							= [X_ParseFile fsName fsLineNumber fsCharNumber "End of line expected."]
				= (error, Dummy, fstate)
			# (ended, file)						= fend fstate.fsFile
			| ended
				# error							= [X_ParseFile fsName fsLineNumber fsCharNumber "Unexpected end of file."]
				# fstate						= {fstate & fsFile = file}
				= (error, Dummy, fstate)
			# (line, file)						= freadline file
			# fstate							= {fstate	& fsFile			= file
															, fsLineNumber		= fsLineNumber + 1
															, fsCharNumber		= 1
															, fsCurrentLine		= line
											  	  }
			= (OK, Dummy, fstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
checkAhead :: !(Char -> Bool) !(FileM state a) !(FileM state a) -> FileM state a
// -------------------------------------------------------------------------------------------------------------------------------------------------
checkAhead pred monad1 monad2
	= action pred monad1 monad2
	where
		action :: !(Char -> Bool) !(FileM state a) !(FileM state a) !*FileState !state !*PState -> (!Error, !a, !*FileState, !state, !*PState)
		action pred monad1 monad2 fstate=:{fsCurrentLine} state pstate
			= case fsCurrentLine of
				""		-> monad2 fstate state pstate
				_		-> case pred fsCurrentLine.[0] of
								True	-> monad1 fstate state pstate
								False	-> monad2 fstate state pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
ifEOF :: !(FileM state a) !(FileM state a) -> FileM state a
// -------------------------------------------------------------------------------------------------------------------------------------------------
ifEOF then_monad else_monad
	= action then_monad else_monad
	where
		action :: !(FileM state a) !(FileM state a) !*FileState !state !*PState -> (!Error, !a, !*FileState, !state, !*PState)
		action then_monad else_monad fstate state pstate
			| fstate.fsCurrentLine <> "\n"		= else_monad fstate state pstate
			# (ended, file)						= fend fstate.fsFile
			# fstate							= {fstate & fsFile = file}
			= case ended of
				True	-> then_monad fstate state pstate
				False	-> else_monad fstate state pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
eatSpaces :: FileM state Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
eatSpaces
	= accFileState eat_spaces
	where
		eat_spaces :: !*FileState -> (!Error, !Dummy, !*FileState)
		eat_spaces fstate
			# (_, _, fstate)					= ReadWhile (\c -> isMember c [' ', '\t']) fstate
			= (OK, Dummy, fstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
lookAhead :: ![(String, Bool, FileM state a)] !(FileM state a) -> FileM state a
// -------------------------------------------------------------------------------------------------------------------------------------------------
lookAhead alts def
	= look_ahead alts def
	where
		look_ahead :: ![(String, Bool, FileM state a)] !(FileM state a) !*FileState !state !*PState -> (!Error, !a, !*FileState, !state, !*PState)
		look_ahead [] def fstate state pstate
			= def fstate state pstate
		look_ahead [(text,skip,alt):alts] def fstate=:{fsCurrentLine} state pstate
			# size_text							= size text
			# size_line							= size fsCurrentLine
			| size_text > size_line				= look_ahead alts def fstate state pstate
			# line_text							= fsCurrentLine % (0, size_text-1)
			| line_text <> text					= look_ahead alts def fstate state pstate
			# (line, fstate)					= fstate!fsCurrentLine
			# (_, _, fstate, state, pstate)		= case skip of
													True	-> readCharacters size_text fstate state pstate
													False	-> (OK, "", fstate, state, pstate)
			# (line, fstate)					= fstate!fsCurrentLine
			= alt fstate state pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
lookAheadF :: ![(String, FileM state a)] !(FileM state a) -> FileM state a
// -------------------------------------------------------------------------------------------------------------------------------------------------
lookAheadF alts def
	# alts										= [(text, False, monad) \\ (text, monad) <- alts]
	= lookAhead alts def

// -------------------------------------------------------------------------------------------------------------------------------------------------
readBool :: FileM state Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
readBool
	=	readWhile isValidNameChar				>>= \text ->
		case text of
			"True"								-> returnM True
			"False"								-> returnM False
			_									-> parseErrorM ("boolean value expected.")

// -------------------------------------------------------------------------------------------------------------------------------------------------
readCharacters :: !Int -> FileM state String
// -------------------------------------------------------------------------------------------------------------------------------------------------
readCharacters n
	= accFileState (read_chars n)
	where
		read_chars :: !Int !*FileState -> (!Error, !String, !*FileState)
		read_chars n fstate=:{fsName, fsLineNumber, fsCharNumber, fsCurrentLine}
			# line_size							= size fsCurrentLine
			| line_size < n
				# error							= [X_ParseFile fsName fsLineNumber (fsCharNumber + line_size) "Unexpected end of line."]
				= (error, "", fstate)
			# fstate							= {fstate	& fsCharNumber		= fsCharNumber + n
															, fsCurrentLine		= fsCurrentLine % (n, line_size-1)
												  }
			= (OK, fsCurrentLine % (0, n-1), fstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
readIdentifier :: FileM state String
// -------------------------------------------------------------------------------------------------------------------------------------------------
readIdentifier
	=	readWhile isValidIdChar					>>= \text ->
		if (text == "")
			(parseErrorM "Identifier expected.")
			(returnM text)

// -------------------------------------------------------------------------------------------------------------------------------------------------
readName :: !String -> FileM state String
// -------------------------------------------------------------------------------------------------------------------------------------------------
readName what
	=	readWhile isValidNameChar				>>= \text ->
		if (text == "")
			(parseErrorM (what +++ " expected."))
			(returnM text)

// -------------------------------------------------------------------------------------------------------------------------------------------------
readNumber :: FileM state Int
// -------------------------------------------------------------------------------------------------------------------------------------------------
readNumber
	=	lookAhead
			[ ("+",		True, parse_number)
			, ("-",		True, parse_number >>= \n -> returnM (~n))
			] parse_number
	where
		parse_number
			=	readWhile isDigit				>>= \text ->
				if (text == "")
					(parseErrorM "Number expected.")
					(returnM (toInt text))

// -------------------------------------------------------------------------------------------------------------------------------------------------
readString :: FileM state String
// -------------------------------------------------------------------------------------------------------------------------------------------------
readString
	=	readToken "\""							>>>>
		readWhile (\c -> c <> '"')				>>>= \text ->
		readToken "\""							>>>
		returnM text

// -------------------------------------------------------------------------------------------------------------------------------------------------
readToken :: !String -> FileM state Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readToken token
	= accFileState (read_token token)
	where
		read_token :: !String !*FileState -> (!Error, !Dummy, !*FileState)
		read_token token fstate=:{fsName, fsLineNumber, fsCharNumber, fsCurrentLine}
			# size_token						= size token
			# size_line							= size fsCurrentLine
			| token <> fsCurrentLine % (0, size_token-1)
				# error							= [X_ParseFile fsName fsLineNumber fsCharNumber ("Expected token '" +++ token +++ "'.")]
				= (error, Dummy, fstate)
			# fstate							= {fstate	& fsCharNumber		= fsCharNumber + size_token
															, fsCurrentLine		= fsCurrentLine % (size_token, size_line-1)
												  }
			= (OK, Dummy, fstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
readUntil :: !String !Char -> FileM state String
// -------------------------------------------------------------------------------------------------------------------------------------------------
readUntil what char
	=	readWhile (\c -> c <> char)				>>= \text ->
		if (text == "")
			(parseErrorM (what +++ " expected."))
			(returnM text)

// -------------------------------------------------------------------------------------------------------------------------------------------------
readWhile :: !(Char -> Bool) -> FileM state String
// -------------------------------------------------------------------------------------------------------------------------------------------------
readWhile pred
	= accFileState (ReadWhile pred)

// -------------------------------------------------------------------------------------------------------------------------------------------------
returnState :: FileM state state
// -------------------------------------------------------------------------------------------------------------------------------------------------
returnState
	= accStates ret
	where
		ret :: !String !Int !Int !state !*PState -> (!Error, !state, !state, !*PState)
		ret _ _ _ state pstate
			= (OK, state, state, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
skipLine :: FileM state Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
skipLine
	= accFileState skip
	where
		skip :: !*FileState -> (!Error, !Dummy, !*FileState)
		skip fstate=:{fsFile, fsName, fsLineNumber, fsCharNumber}
			# (ended, file)						= fend fstate.fsFile
			| ended
				# error							= [X_ParseFile fsName fsLineNumber fsCharNumber "Unexpected end of file."]
				# fstate						= {fstate & fsFile = file}
				= (error, Dummy, fstate)
			# (line, file)						= freadline file
			# fstate							= {fstate	& fsFile			= file
															, fsLineNumber		= fsLineNumber + 1
															, fsCharNumber		= 1
															, fsCurrentLine		= line
											  	  }
			= (OK, Dummy, fstate)

















// -------------------------------------------------------------------------------------------------------------------------------------------------
alignTo :: !Int -> FileM state Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
alignTo n
	= accFileState (align n)
	where
		align :: !Int !*FileState -> (!Error, !Dummy, !*FileState)
		align n fstate=:{fsFile, fsCharNumber}
			| fsCharNumber > n					= (OK, Dummy, fstate)
			# need								= n - fsCharNumber
			# file								= fwrites (createArray need ' ') fsFile
			# fstate							= {fstate	& fsFile			= file
															, fsCharNumber		= n
												  }
			= (OK, Dummy, fstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
writeIdentifier :: !String -> FileM state Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
writeIdentifier id
	= writeToken id

// -------------------------------------------------------------------------------------------------------------------------------------------------
writeName :: !CName -> FileM state Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
writeName name
	= writeToken name

// -------------------------------------------------------------------------------------------------------------------------------------------------
writeNumber :: !Int -> FileM state Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
writeNumber n
	= writeToken (toString n)

// -------------------------------------------------------------------------------------------------------------------------------------------------
writeString :: !String -> FileM state Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
writeString text
	= writeToken ("\"" +++ text +++ "\"")

// -------------------------------------------------------------------------------------------------------------------------------------------------
writeToken :: !String -> FileM state Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
writeToken token
	= accFileState (write token)
	where
		write :: !String !*FileState -> (!Error, !Dummy, !*FileState)
		write text fstate=:{fsCharNumber, fsFile}
			# file								= fwrites text fsFile
			# fstate							= {fstate	& fsCharNumber		= fsCharNumber + size text
															, fsFile			= file
												  }
			= (OK, Dummy, fstate)