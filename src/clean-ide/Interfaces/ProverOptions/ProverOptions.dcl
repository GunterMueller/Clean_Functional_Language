/*
** Program: Clean Prover System / CleanIDE
** Module:  ProverOptions (.dcl)
** 
** Author:  Maarten de Mol
** Created: 6 July 1999
*/

definition module 
   ProverOptions

import StdString, StdFile
import 
//   StdEnv,
   StdMaybe
   
// Modulenames should be stored WITHOUT extension; Pathnames should be stored fully and not end with a (back)slash   
:: ProjectStructure =
   { project_name         :: !String
   , project_paths        :: ![String]                     
   , main_module_name     :: !String                       
   , main_module_path     :: !String                       
   , icl_modules          :: ![(!String, !String)]        // (name, path)
   , dcl_modules          :: ![(!String, !String)]        // (name, path)
   }
DummyProjectStructure :: ProjectStructure   

WriteProverOptions :: !String !ProjectStructure !*Files -> (!Bool, *Files)
ReadProverOptions  :: !String                   *Files -> ((!Int, !Maybe ProjectStructure), *Files)