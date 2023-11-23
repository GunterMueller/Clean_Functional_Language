definition module EncodeDecode

// provides the encoding and decoding of information between browser and the executable
// (c) 2005 - MJP

import StdMaybe
import GenParse, GenPrint
import htmlFormData

:: HtmlState  		:== (!Formid,!Lifespan,!StorageFormat,!SerializedState)
:: Formid			:== String		// uniquely named !
:: SerializedState 	:== String 		// not encoded !

:: ServerKind
	= External						// An external Server has call to this executable (currently via a PhP script)
	| JustTesting					// No Server attached at all, intended for testing (in collaboration with Gast)
	| Internal						// No external server needed: a Clean Server is atached to this executable

// Triplet handling

:: Triplet			:== (String,Int,UpdValue)
:: TripletUpdate	:== (Triplet,String)
:: Triplets			:== [TripletUpdate]

:: UpdValue 													// the updates that can take place	
	= UpdI Int													// new integer value
	| UpdR Real													// new real value
	| UpdB Bool													// new boolean value
	| UpdC String												// choose indicated constructor 
	| UpdS String												// new piece of text

encodeTriplet		:: !Triplet -> String						// encoding of triplets
encodeString 		:: !String  -> String						// encoding of string 
urlEncode 			:: !String ->  String
urlDecode 			:: !String -> *String

// Form submission handling

callClean 					:: !(Script -> ElementEvents) !Mode !String -> [ElementEvents]
submitscript 				::  BodyTag
globalstateform 			:: !Value -> BodyTag

// serializing, de-serializing of iData states to strings stored in the html page

EncodeHtmlStates 			:: ![HtmlState] -> String
DecodeHtmlStatesAndUpdate 	:: !ServerKind (Maybe [(String, String)]) -> (![HtmlState],!Triplets) // hidden state stored in Client + triplets

// serializing, de-serializing of iData state stored in files

writeState		 			:: !String !String !String !*NWorld -> *NWorld 
readState				 	:: !String !String !*NWorld -> (!String,!*NWorld) 
deleteState 				:: !String !String !*NWorld -> *NWorld

// constants that maybe useful

ThisExe						:: !ServerKind -> String			// name of this executable
MyPhP 						:: !ServerKind -> String			// name of php script interface between server and this executable
MyDir 						:: !ServerKind -> String			// name of directory in which persistent form info is stored

traceHtmlInput				:: !ServerKind !(Maybe [(String, String)]) -> BodyTag					// for debugging showing the information received from browser


globalFormName	:== "CleanForm"		// name of hidden Html form in which iData state information is stored
updateInpName	:== "UD"			// marks update information
globalInpName	:== "GS"			// marks global state information
selectorInpName	:== "CS_"			// marks constructor update
