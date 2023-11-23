module 
   Example

import
   StdEnv,
   StdIO,
   ErrorHandler
   
:: ErrorCode = 
      X_Compile_Module      !String
    | X_Open_File           !String
    | X_Open_Project        !String
:: Error :== HandlerError ErrorCode
             
// ------------------------------------------------------------------------------------------------
ShortMessage :: ErrorCode -> !String
// ------------------------------------------------------------------------------------------------
ShortMessage (X_Compile_Module modulename)  = "Unable to compile the module '" +++ modulename +++ "'."
ShortMessage (X_Open_File filename)         = "Unable to open the file '" +++ filename +++ "'."
ShortMessage (X_Open_Project projectname)   = "Unable to open the project '" +++ projectname +++ "'."

// ------------------------------------------------------------------------------------------------
LongMessage :: ErrorCode -> String
// ------------------------------------------------------------------------------------------------
LongMessage (X_Open_Project projectname)    = "One of the modules in the project can probably not be compiled succesfully."
LongMessage _                               = ""
               
// ------------------------------------------------------------------------------------------------
Start :: *World -> *World
// ------------------------------------------------------------------------------------------------
Start world
   = startIO MDI 0 show_errors [ProcessClose closeProcess] world   
   where
      show_errors :: (*PSt .ps) -> *PSt .ps
      show_errors state
         # error   = pushError (X_Open_File "Main.icl") OK
         # state   = handleError ShortMessage LongMessage error id state
         # error   = pushError (X_Compile_Module "Main") error
         # state   = handleError ShortMessage LongMessage error id state
         # error   = pushError (X_Open_Project "MyProject") error
         # state   = handleError ShortMessage LongMessage error id state
         = closeProcess state