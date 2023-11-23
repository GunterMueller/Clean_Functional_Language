/*
** Program: Clean Prover System / CleanIDE
** Module:  ProverOptions (.icl)
** 
** Author:  Maarten de Mol
** Created: 6 July 1999
*/

implementation module 
   ProverOptions
   
import 
   StdEnv,
   StdMaybe   
   
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ProjectStructure =
// -------------------------------------------------------------------------------------------------------------------------------------------------
   { project_name         :: !String
   , project_paths        :: ![String]
   , main_module_name     :: !String                       
   , main_module_path     :: !String                       
   , icl_modules          :: ![(String, String)]
   , dcl_modules          :: ![(String, String)]
   }  
   
// -------------------------------------------------------------------------------------------------------------------------------------------------
DummyProjectStructure :: ProjectStructure
// -------------------------------------------------------------------------------------------------------------------------------------------------
DummyProjectStructure =
   { project_name          = ""
   , project_paths         = []
   , main_module_name      = ""   
   , main_module_path      = ""
   , icl_modules           = []
   , dcl_modules           = []
   }
   
// -------------------------------------------------------------------------------------------------------------------------------------------------
StartLine :: String
// -------------------------------------------------------------------------------------------------------------------------------------------------
StartLine
   = "=============================== CLEAN PROVER SYSTEM: project file ==============================="
   
// -------------------------------------------------------------------------------------------------------------------------------------------------
FReadLines :: !*File -> (![String], !*File)
// -------------------------------------------------------------------------------------------------------------------------------------------------
FReadLines file
   # (ended, file) = fend file
   | ended         = ([], file)
   # (line, file)  = freadline file
   # (lines, file) = FReadLines file
   = (map remove_new_lines [line:lines], file)  
   where
      remove_new_lines :: !String -> String
      remove_new_lines string
         # last_index                             = size string
         | select string (last_index-1) <> '\n'   = string
         = string % (0, last_index-2)
      
// -------------------------------------------------------------------------------------------------------------------------------------------------
WriteProverOptions :: !String !ProjectStructure !*Files -> (!Bool, !*Files)
// -------------------------------------------------------------------------------------------------------------------------------------------------
WriteProverOptions project_name options files
   # ((open_ok, options_file), files)    = f_open project_name FWriteText files
   | not open_ok                         = (False, files)
   # options_file                        = fwrites (StartLine +++ "\n") options_file
   # options_file                        = fwrites ("MAIN_MODULE " +++ options.main_module_name +++ " IN " +++ options.main_module_path
                                                                   +++ "\n") options_file
   # options_file                        = WriteIclModules options.icl_modules options_file
   # options_file                        = WriteDclModules options.dcl_modules options_file
   # options_file                        = WriteProjectPaths options.project_paths options_file
   # (close_ok, files)                   = fclose options_file files
   | not close_ok                        = (False, files)                                                                   
   = (True, files)
   where
      f_open :: !String !Int !*Files -> (!(!Bool, !*File), !*Files)
      f_open name mode files
         # (ok, file, files) = fopen name mode files
         = ((ok, file), files)
         
// -------------------------------------------------------------------------------------------------------------------------------------------------
WriteIclModules :: ![(String, String)] !*File -> *File
// -------------------------------------------------------------------------------------------------------------------------------------------------
WriteIclModules [] file
   = file
WriteIclModules [(name, path): rest] file
   # file   = fwrites ("ICL_MODULE " +++ name +++ " IN " +++ path +++ "\n") file
   = WriteIclModules rest file            

// -------------------------------------------------------------------------------------------------------------------------------------------------
WriteDclModules :: ![(String, String)] !*File -> *File
// -------------------------------------------------------------------------------------------------------------------------------------------------
WriteDclModules [] file
   = file
WriteDclModules [(name, path): rest] file
   # file   = fwrites ("DCL_MODULE " +++ name +++ " IN " +++ path +++ "\n") file
   = WriteDclModules rest file            
   
// -------------------------------------------------------------------------------------------------------------------------------------------------
WriteProjectPaths :: ![String] !*File -> *File
// -------------------------------------------------------------------------------------------------------------------------------------------------
WriteProjectPaths [] file
   = file
WriteProjectPaths [path:rest] file
   # file   = fwrites ("PROJECT_PATH " +++ path +++ "\n") file
   = WriteProjectPaths rest file
                  
// =================================================================================================================================================
// The first result indicates success:
//   0 = OK
//   1 = Failure to open
//   2 = Failure to close
//   3 = Failure to convert
//   4 = Wrong extension (must be .pr_)
// These codes will be translated to the format used for error-messages in CleanProverSystem.                   
// -------------------------------------------------------------------------------------------------------------------------------------------------
ReadProverOptions  :: !String !*Files -> (!(!Int, !Maybe ProjectStructure), !*Files)
// -------------------------------------------------------------------------------------------------------------------------------------------------
ReadProverOptions project_name files
   # without_extension                                = remove_last_extension project_name
   | without_extension +++ ".pr_" <> project_name     = ((4, Nothing), files)
   # ((open_ok, options_file), files)                 = f_open project_name FReadText files
   | not open_ok                                      = ((1, Nothing), files)
   # (lines, options_file)                            = FReadLines options_file
   # (close_ok, files)                                = fclose options_file files
   | not close_ok                                     = ((2, Nothing), files)
   | isEmpty lines                                    = ((3, Nothing), files)
   | hd lines <> StartLine                            = ((3, Nothing), files)
   # lines                                            = tl lines
   # (convert_ok, main_module_name, main_module_path) = ReadMainModule (hd lines)
   | not convert_ok                                   = ((3, Nothing), files)
   # lines                                            = tl lines
   # (icl_modules, lines)                             = ReadIclModules lines
   # (dcl_modules, lines)                             = ReadDclModules lines
// # project_paths                                    = ReadProjectPaths lines
   = ((0, Just { main_module_name   = main_module_name
               , main_module_path   = main_module_path
               , icl_modules        = icl_modules
               , dcl_modules        = dcl_modules
               , project_paths      = [] /* project_paths */
               , project_name       = remove_last_extension (remove_path project_name)
               }), files)
   where
      f_open :: !String !Int !*Files -> (!(!Bool, !*File), !*Files)
      f_open name mode files
         # (ok, file, files) = fopen name mode files
         = ((ok, file), files)
      
      remove_path :: !String -> String
      remove_path text
         = {c \\ c <- remove__path [c \\ c <-: text]}
         
      remove__path :: ![Char] -> [Char]
      remove__path text
         | isMember sep1 text        = remove__path (tl (dropWhile (\c -> c <> sep1) text))
         | isMember sep2 text        = remove__path (tl (dropWhile (\c -> c <> sep2) text))
         = text
         where
            sep1 = '\\'
            sep2 = '/'
            
      remove_last_extension :: !String -> String
      remove_last_extension text
         = {c \\ c <- remove__last__extension [c \\ c <-: text]}
      remove__last__extension []
         = []
      remove__last__extension [c:cs]
         | c == '.' && not (isMember '.' cs) = []
         = [c: remove__last__extension cs]

// -------------------------------------------------------------------------------------------------------------------------------------------------
ReadMainModule :: !String -> (!Bool, !String, !String)
// -------------------------------------------------------------------------------------------------------------------------------------------------
ReadMainModule line
   # (start_ok, left)  = Eat line "MAIN_MODULE "
   | not start_ok      = (False, "", "")
   # (name, left)      = EatUntilSpace left
   # (mid_ok, path)    = Eat left "IN "
   | not mid_ok        = (False, "", "")
   = (True, name, path)

// -------------------------------------------------------------------------------------------------------------------------------------------------
ReadIclModules :: ![String] -> (![(String, String)], ![String])
// -------------------------------------------------------------------------------------------------------------------------------------------------
ReadIclModules []
   = ([], [])
ReadIclModules [line:lines]
   # (start_ok, left)     = Eat line "ICL_MODULE "
   | not start_ok         = ([], [line:lines])
   # (name, left)         = EatUntilSpace left
   # (mid_ok, path)       = Eat left "IN "
   | not mid_ok           = ([], [])
   # (other_icls, rest)   = ReadIclModules lines
   = ([(name,path):other_icls], rest)
   
// -------------------------------------------------------------------------------------------------------------------------------------------------
ReadDclModules :: ![String] -> (![(String, String)], ![String])
// -------------------------------------------------------------------------------------------------------------------------------------------------
ReadDclModules []
   = ([], [])
ReadDclModules [line:lines]
   # (start_ok, left)     = Eat line "DCL_MODULE "
   | not start_ok         = ([], [line:lines])
   # (name, left)         = EatUntilSpace left
   # (mid_ok, path)       = Eat left "IN "
   | not mid_ok           = ([], [])
   # (other_dcls, rest)   = ReadDclModules lines
   = ([(name,path):other_dcls], rest)
   
/*   
// -------------------------------------------------------------------------------------------------------------------------------------------------
ReadProjectPaths :: [String] -> [String]
// -------------------------------------------------------------------------------------------------------------------------------------------------
ReadProjectPaths []
   = []
ReadProjectPaths [line:lines]
   # other_paths          = ReadProjectPaths lines
   # (start_ok, left)     = Eat [c \\ c <-: line] ['PROJECT_PATH']
   | not start_ok         = other_paths
   # path                 = {c \\ c <- left}
//   # (path, left)         = GetIdentifier left
   = [path:other_paths] 
*/

// -------------------------------------------------------------------------------------------------------------------------------------------------
Eat :: !String !String -> (!Bool, !String)
// -------------------------------------------------------------------------------------------------------------------------------------------------
Eat text subtext
   | text % (0, size subtext - 1) == subtext       = (True, text % (size subtext, size text - 1))
   | otherwise                                     = (False, text)
   
// -------------------------------------------------------------------------------------------------------------------------------------------------
EatUntilSpace :: !String -> (!String, !String)   
// -------------------------------------------------------------------------------------------------------------------------------------------------
EatUntilSpace text
   = find_space 0 (size text - 1)
   where
      find_space :: !Int !Int -> (!String, !String)
      find_space index last_index
         | index > last_index         = ("", text)
         | select text index == ' '   = (text % (0, index-1), text % (index+1, last_index))
         | otherwise                  = find_space (index+1) last_index         