definition module webServerTest

/*
	Special library to test Webservers.
	Pieter Koopman 2005, 2006
*/

//import StdEnv, gast, StdHtml, htmlPrintUtil
import StdEnv, gast, StdHtml, PrintUtil

derive bimap []

:: HtmlInput
	= HtmlButton String
	| HtmlIntTextBox String Int
	| HtmlStringTextBox String String


// --------- Utilities --------- //

htmlPageTitle :: Html -> [String]
htmlEditBoxValues :: Html String -> [Int]
htmlTextValues :: Html -> [String]

// --------- The main function --------- //

testHtml :: [TestSMOption s i Html] (Spec s i Html) s (i->HtmlInput) (*HSt -> (Html,*HSt)) *World -> *World
			| ggen{|*|} i & gEq{|*|} s & genShow{|*|} s & genShow{|*|} i
