/*
** Program: Clean Prover System
** Module:  Compilation (.icl)
** 
** Author:  Maarten de Mol
** Created: 5 July 1999
*/

implementation module 
   Compilation

import 
   StdEnv,
   StdMaarten,
   StdDebug,
   frontend,
   Types,
   Errors,
   ProverOptions

// -------------------------------------------------------------------------------------------------------------------------------------------------
CompileICLModule :: !TModuleName !TPath !ProjectStructure *file_env -> ((Maybe !(TModule TCompilerSymbol), !TErrorInfo), *file_env) | FileEnv file_env
// -------------------------------------------------------------------------------------------------------------------------------------------------
CompileICLModule module_name module_path project file_env
   # ((maybe_syntax_tree, error_info), file_env) = accFiles use_frontend file_env
   | ErrorPresent error_info                     = ((Nothing, error_info), file_env)
   # (pclmodule, error_info)                     = TransformSyntaxTree module_name module_path project (fromJust maybe_syntax_tree)
   = ((Just pclmodule, error_info), file_env)
   where
      // -----------------------------------------------------------------------------------------
      use_frontend :: *Files -> ((Maybe *FrontEndSyntaxTree, TErrorInfo), *Files)
      // -----------------------------------------------------------------------------------------
      use_frontend files
         # (open_error_ok, error_file, files)       = fopen "Errors.___" FWriteText files 
         | not open_error_ok                        = ((Nothing, InsertError (TE_CouldNotOpenFile "Errors.___") Nothing), files)
         # known_locations                          = [(project.main_module_name +++ ".icl", project.main_module_path +++ "\\")] ++
                                                      (map (\(name, path) -> (name +++ ".dcl", path +++ "\\")) project.dcl_modules) ++
                                                      (map (\(name, path) -> (name +++ ".icl", path +++ "\\")) project.icl_modules)
         # (files, error_file, _, _, o_syntax_tree) = frontEndInterface module_name {sp_paths=[],sp_locations=known_locations} 
                                                                        files error_file dummy_file dummy_file
         # maybe_syntax_tree                        = optional_to_maybe o_syntax_tree
         | isNothing maybe_syntax_tree              = get_compile_errors (snd (fclose error_file files))
         # (close_error_ok, files)                  = fclose error_file files
         | not close_error_ok                       = ((Nothing, InsertError (TE_CouldNotCloseFile "Errors.___") Nothing), files)
         = ((maybe_syntax_tree, Nothing), files)
         
      // -------------------------------------------------------------------------------
      get_compile_errors :: *Files -> ((Maybe *FrontEndSyntaxTree, TErrorInfo), *Files) 
      // -------------------------------------------------------------------------------
      get_compile_errors files
         # (_, error_file, files)                   = fopen "Errors.___" FReadText files
         # (msgs, error_file)                       = freadlines error_file
         # (_, files)                               = fclose error_file files
         # error_info                               = Just (map TE_ExternalError msgs)
         = ((Nothing, InsertError (TE_CouldNotCompileICLModule module_name) error_info), files)
         
      // --------------------------------------------   
      optional_to_maybe :: (Optional .a) -> Maybe .a 
      // --------------------------------------------
      optional_to_maybe (Yes x)  
         = Just x
      optional_to_maybe No       
         = Nothing   
         
      // -----------------
      dummy_file :: *File
      // -----------------
      dummy_file = abort ("Internal error. Use of dummy_file as argument for the FrontEndSyntaxTree compilation failed.\n"
                          +++ "Please contact Maarten de Mol.")         

// -------------------------------------------------------------------------------------------------------------------------------------------------
TransformSyntaxTree :: !TModuleName !TPath !ProjectStructure *FrontEndSyntaxTree -> (!TModule TCompilerSymbol, !TErrorInfo)
// -------------------------------------------------------------------------------------------------------------------------------------------------
TransformSyntaxTree module_name module_path project syntax_tree=:{fe_dcls}
   = ({ modName                = module_name
      , modImportedDcls        = [dcl.dcl_name.id_name \\ dcl <-: fe_dcls]
      , modDefinitions         = {}
      }  
      , Nothing)