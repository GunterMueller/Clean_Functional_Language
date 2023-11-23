definition module htmlSettings

// iData & iTask Library
// Concept & Programming (c) 2005 - 2007 Rinus Plasmeijer

import htmlHandler

// Global settings of iData applications

class iData a							// The collection of generic functions needed to make iData:	
		| gForm {|*|}					// Creates an Html Form
		, iCreateAndPrint				
		, iParse
		, iSpecialStore a

class iCreateAndPrint a					// Used for tracing iTasks
		| iCreate
		, iPrint a	

class iCreate a
		| gUpd  {|*|} a					// Makes it possible to update and create any value, given a change somewhere in the data structure

class iPrint a
		| gPrint{|*|} a					// To serialize a value to a String

class iParse a
		| gParse{|*|} a					// To de-serialize a string back to a value
		
class iSpecialStore a
										// OPTION: Comment out the next two lines if you do not have access to an ODCB database on your machine !!!!
										// and enable the third line 
		| gerda {|*|} 	 				// To store and retrieve a value in a database
		, TC a							// To be able to store values in a dynamic
//		| TC a							// To be able to store values in a dynamic


// Debug switches								

TraceInput			:== False			// show what kind of information is received from Client
TraceOutput			:== False			// show what kind of information is stored

DEBUGSERVER			:== True			// show what kind of information is transmitted by the Clean HtmlServer

MyDataBase			:== "iDataDatabase"	// name of database being used by iData applications

iDataIdSeparator 	 :== "."			// used as separator when combining iData form id's
radioButtonSeparator :== '.'			// used as extension for family of radiobuttons

// OPTION: Comment out the next line if you do not have access to an ODCB database on your machine !!!!
IF_GERDA gerda no_gerda :== gerda		// If database option is used

// OPTION: Remove the comment from the next line if you do not have access to an ODCB database on your machine !!!!
//IF_GERDA gerda no_gerda :== no_gerda	// otherwise, BUT manually flag of ", gerda{|*|}" in the class definition above
