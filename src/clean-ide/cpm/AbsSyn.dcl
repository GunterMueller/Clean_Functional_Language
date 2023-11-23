definition module AbsSyn

:: FilePath:==Pathname
from PmTypes import ::Pathname,::Output
from StdMaybe import :: Maybe

/**
 * Datatypes
 */
:: CpmAction
  =  Project FilePath ProjectAction
  |  Module String ModuleAction
  |  Environment EnvironmentAction
  |  CpmMake
  |  CpmHelp

:: ProjectAction
  =  CreateProject (Maybe FilePath)
  |  ShowProject
  |  BuildProject Bool FilePath
  |  Compile [String]
  |  ProjectPath PathAction
  |  SetRelativeRoot String
  |  SetTarget String
  |  SetExec String
  |  SetBytecode (Maybe String)
  |  SetProjectOptions [ProjectOption]
  |  ExportTemplate FilePath
  |  ProjectHelp

:: PathAction
  =  AddPathAction [String]
  |  RemovePathAction Int
  |  ListPathsAction
  |  MovePathAction Int PathDirection
  |  PathHelp

:: PathDirection
  =  MovePathUp
  |  MovePathDown
  |  MovePathTop
  |  MovePathBottom

:: ProjectOption
	= DynamicsOn
	| DynamicsOff
	| GenericFusionOn
	| GenericFusionOff
	| RTSFlagsOn
	| RTSFlagsOff
	| StackTraceOn
	| StackTraceOff
	| TimeProfileOn
	| TimeProfileOff
	| CallgraphProfileOn
	| CallgraphProfileOff
	| MemoryProfileOn
	| MemoryProfileOff
	| DescExLOn
	| DescExLOff
	| HeapSize !Int
	| StackSize !Int
	| Output !Output
	| LinkerGenerateSymbolsOn
	| LinkerGenerateSymbolsOff
	| PO_OptimiseABC !Bool
	| PO_GenerateByteCode !Bool
	| PO_StripByteCode !Bool
	| PO_KeepByteCodeSymbols !Bool
	| PO_PreLinkByteCode !Bool

:: ModuleAction
  =  CreateModule ModuleType
  |  ModuleHelp

:: ModuleType
  =  ApplicationModule
  |  LibraryModule

:: EnvironmentAction
  =  ListEnvironments
  |  ImportEnvironment FilePath
  |  RemoveEnvironment String
  |  ShowEnvironment String
  |  ExportEnvironment String FilePath
  |  CreateEnvironment String (Maybe String)
  |  RenameEnvironment String String
  |  SetEnvironmentCompiler String String
  |  SetEnvironmentCodeGen String String
  |  EnvironmentHelp
  // TODO: EnvironmentPaths, EnvironmentVersion, EnvironmentProcessor, Environment64BitProcessor
