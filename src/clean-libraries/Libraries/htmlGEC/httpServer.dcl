definition module httpServer

// (c) 2005 Paul de Mast
// HIO - Breda - The Netherlands

// This is an Http 1.0 Server written in Clean
// The Server has to be used with (a) Clean function(s) which generates Html Code
// Together they are linked into one application !
// So this Server can only communicate with the linked in Clean functions.
// It is not a general purpose server which can communicate with other applications.
// As such this is great for testing Html / iData / iTasks Clean applications.

// StartServer takes a port number + list of virtual pages

StartServer		:: Int [(String,(String String Arguments *World -> ([String],String,*World)))] *World -> *World

getArgValue		:: String Arguments -> String
getContentType	:: String -> String

:: Arguments	:== [(String, String)]
printArguments	:: Arguments -> String

makeArguments :: String -> Arguments