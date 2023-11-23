definition module predef

import syntax, hashtable

::	PredefinedSymbols	:== {# PredefinedSymbol}

::	PredefinedSymbol = {
		pds_module	:: !Index,
		pds_def		:: !Index
	}

init_identifiers :: !*SymbolTable !*World -> (!*SymbolTable,!*World)

predefined_idents :: {!Ident}

buildPredefinedSymbols :: !*HashTable -> (!.PredefinedSymbols,!*HashTable)

buildPredefinedModule :: !Bool !*PredefinedSymbols -> (!ScannedModule, !.PredefinedSymbols)

PredefinedModuleIndex :== 1
cPredefinedModuleIndex :== 1

// index in com_type_defs

PD_StringTypeIndex :== 0

PD_ListTypeIndex :== 1
PD_StrictListTypeIndex :== 2
PD_UnboxedListTypeIndex :== 3
PD_TailStrictListTypeIndex :== 4
PD_StrictTailStrictListTypeIndex :== 5
PD_UnboxedTailStrictListTypeIndex :== 6
//PD_OverloadedListTypeIndex :== 7

PD_Arity2TupleTypeIndex :== 8
PD_Arity32TupleTypeIndex :== 38

PD_LazyArrayTypeIndex :== 39
PD_StrictArrayTypeIndex :== 40
PD_UnboxedArrayTypeIndex :== 41
PD_PackedArrayTypeIndex :== 42

PD_MaybeTypeIndex :== 43
PD_StrictMaybeTypeIndex :== 44
PD_UnboxedMaybeTypeIndex :== 45
//PD_OverloadedMaybeTypeIndex :== 46

PD_UnitTypeIndex :== 47

/* identifiers not present the hashtable */

PD_PredefinedModule			:== 0

FirstTypePredefinedSymbolIndex:==PD_StringType; // to compute index in com_type_defs

PD_StringType				:== 1

PD_ListType :== 2
PD_StrictListType :== 3
PD_UnboxedListType :== 4
PD_TailStrictListType :== 5
PD_StrictTailStrictListType :== 6
PD_UnboxedTailStrictListType :== 7
PD_OverloadedListType :== 8

PD_Arity2TupleType			:== 9
PD_Arity32TupleType			:== 39

PD_LazyArrayType			:== 40
PD_StrictArrayType			:== 41
PD_UnboxedArrayType			:== 42
PD_PackedArrayType			:== 43

// same order as in MaybeIdentToken
PD_MaybeType :== 44
PD_StrictMaybeType :== 45
PD_UnboxedMaybeType :== 46
PD_OverloadedMaybeType :== 47

PD_UnitType :== 48

// constructors:

FirstConstructorPredefinedSymbolIndex :== PD_ConsSymbol; // to compute index in com_cons_defs

PD_ConsSymbol :== 49
PD_StrictConsSymbol :== 50
PD_UnboxedConsSymbol :== 51
PD_TailStrictConsSymbol :== 52
PD_StrictTailStrictConsSymbol :== 53
PD_UnboxedTailStrictConsSymbol :== 54
PD_OverloadedConsSymbol :== 55

PD_NilSymbol :== 56
PD_StrictNilSymbol :== 57
PD_UnboxedNilSymbol :== 58
PD_TailStrictNilSymbol :== 59
PD_StrictTailStrictNilSymbol :== 60
PD_UnboxedTailStrictNilSymbol :== 61
PD_OverloadedNilSymbol :== 62

PD_Arity2TupleSymbol		:== 63
PD_Arity32TupleSymbol		:== 93

// same order as in MaybeIdentToken
PD_JustSymbol :== 94
PD_NoneSymbol :== 95
PD_StrictJustSymbol :== 96
PD_StrictNoneSymbol :== 97
PD_UnboxedJustSymbol :== 98
PD_UnboxedNoneSymbol :== 99
PD_OverloadedJustSymbol :== 100
PD_OverloadedNoneSymbol :== 101

PD_UnitConsSymbol :== 102

// end constructors

PD_TypeVar_a0				:== 103
PD_TypeVar_a31				:== 134

/* identifiers present in the hashtable */

PD_StdArray					:== 135
PD_StdEnum					:== 136
PD_StdBool					:== 137

PD_AndOp					:== 138
PD_OrOp						:== 139

/* Array functions */

PD_ArrayClass				:== 140

PD_CreateArrayFun			:== 141
PD__CreateArrayFun			:== 142
PD_ArraySelectFun			:== 143
PD_UnqArraySelectFun		:== 144
PD_ArrayUpdateFun			:== 145
PD_ArrayReplaceFun			:== 146
PD_ArraySizeFun				:== 147
PD_UnqArraySizeFun			:== 148

/* Enum/Comprehension functions */

PD_SmallerFun				:== 149
PD_LessOrEqualFun			:== 150
PD_IncFun					:== 151
PD_SubFun					:== 152
PD_From						:== 153
PD_FromThen					:== 154
PD_FromTo					:== 155
PD_FromThenTo				:== 156

/* StdMisc */
PD_StdMisc					:== 157
PD_abort					:== 158
PD_undef					:== 159

PD_Start					:== 160

PD_DummyForStrictAliasFun	:== 161

// StdStrictLists
PD_StdStrictLists:==162

PD_cons:==163
PD_decons:==164

PD_cons_u:==165
PD_decons_u:==166

PD_cons_uts:==167
PD_decons_uts:==168

PD_nil:==169
PD_nil_u:==170
PD_nil_uts:==171

PD_ListClass :== 172
PD_UListClass :== 173
PD_UTSListClass :== 174

// StdStrictMaybes
PD_StdStrictMaybes:==175

// same order as in MaybeIdentToken
PD_just_u:==176
PD_none_u:==177
PD_just:==178
PD_none:==179

PD_from_just_u:==180
PD_from_just:==181

PD_MaybeClass :== 182
PD_UMaybeClass :== 183

/* Dynamics */

// TC class
PD_TypeCodeMember			:== 184
PD_TypeCodeClass			:== 185
// dynamic module
PD_StdDynamic				:== 186
// dynamic type
PD_Dyn_DynamicTemp				:== 187
// type code (type)
PD_Dyn_TypeCode					:== 188
// unification (type)
PD_Dyn_UnificationEnvironment	:== 189
// type code (expressions)
PD_Dyn_TypeScheme			:== 190
PD_Dyn_TypeApp				:== 191
PD_Dyn_TypeVar				:== 192
PD_Dyn_TypeCons				:== 193
PD_Dyn_TypeUnique			:== 194
PD_Dyn__TypeFixedVar		:== 195
// unification (expressions)
PD_Dyn_initial_unification_environment	:== 196
PD_Dyn_bind_global_type_pattern_var_n	:== 197
PD_Dyn_unify							:== 198
PD_Dyn_unify_							:== 199
PD_Dyn_unify_tcs						:== 200
PD_Dyn_normalise						:== 201

/* Generics */
PD_StdGeneric				:== 202
// Generics types
PD_TypeUNIT					:== 203
PD_TypeEITHER				:== 204
PD_TypePAIR					:== 205
// for constructor info
PD_TypeCONS					:== 206
PD_TypeRECORD				:== 207
PD_TypeFIELD				:== 208
PD_TypeOBJECT				:== 209
PD_TGenericConsDescriptor	:== 210
PD_TGenericRecordDescriptor	:== 211
PD_TGenericFieldDescriptor 	:== 212
PD_TGenericTypeDefDescriptor :== 213
PD_TGenConsPrio				:== 214
PD_TGenConsAssoc			:== 215
PD_TGenType					:== 216

PD_TypeGenericDict 			:== 217
PD_TypeGenericDict0			:== 218
// Generics expression
PD_ConsUNIT					:== 219
PD_ConsLEFT					:== 220
PD_ConsRIGHT				:== 221
PD_ConsPAIR					:== 222
// for constructor info
PD_ConsCONS					:== 223
PD_ConsRECORD				:== 224
PD_ConsFIELD				:== 225
PD_ConsOBJECT				:== 226
PD_CGenericConsDescriptor 	:== 227
PD_CGenericRecordDescriptor	:== 228
PD_CGenericFieldDescriptor 	:== 229
PD_CGenericTypeDefDescriptor :== 230
PD_CGenConsNoPrio			:== 231
PD_CGenConsPrio				:== 232
PD_CGenConsAssocNone		:== 233
PD_CGenConsAssocLeft		:== 234
PD_CGenConsAssocRight		:== 235
PD_CGenTypeCons				:== 236
PD_CGenTypeVar				:== 237
PD_CGenTypeArrow			:== 238
PD_CGenTypeApp				:== 239

PD_GenericBimap				:== 240

PD__SystemEnumStrict:==241

PD_FromS					:== 242
PD_FromTS					:== 243
PD_FromSTS					:== 244
PD_FromU					:== 245
PD_FromUTS					:== 246
PD_FromO					:== 247

PD_FromThenS				:== 248
PD_FromThenTS				:== 249
PD_FromThenSTS				:== 250
PD_FromThenU				:== 251
PD_FromThenUTS				:== 252
PD_FromThenO				:== 253

PD_FromToS					:== 254
PD_FromToTS					:== 255
PD_FromToSTS				:== 256
PD_FromToU					:== 257
PD_FromToUTS				:== 258
PD_FromToO					:== 259

PD_FromThenToS				:== 260
PD_FromThenToTS				:== 261
PD_FromThenToSTS			:== 262
PD_FromThenToU				:== 263
PD_FromThenToUTS			:== 264
PD_FromThenToO				:== 265

PD_Dyn__to_TypeCodeConstructor	:== 266
PD_TypeCodeConstructor :== 267

PD_TC_Int			:== 268
PD_TC_Char			:== 269
PD_TC_Real			:== 270
PD_TC_Bool			:== 271
PD_TC_Dynamic		:== 272
PD_TC_File			:== 273
PD_TC_World			:== 274

PD_TC__Arrow		:== 275

PD_TC__List			:== 276
PD_TC__StrictList	:== 277
PD_TC__UnboxedList	:== 278
PD_TC__TailStrictList	:== 279
PD_TC__StrictTailStrictList	:== 280
PD_TC__UnboxedTailStrictList	:== 281

PD_TC__Tuple2		:== 282
PD_TC__Tuple32		:== 312

PD_TC__LazyArray	:== 313
PD_TC__StrictArray	:== 314
PD_TC__UnboxedArray	:== 315
PD_TC__PackedArray	:== 316

PD_TC__Maybe		:== 317
PD_TC__StrictMaybe	:== 318
PD_TC__UnboxedMaybe	:== 319

PD_TC__Unit			:== 320

PD_NrOfPredefSymbols		:== 321

GetTupleConsIndex tup_arity :== PD_Arity2TupleSymbol + tup_arity - 2
GetTupleTypeIndex tup_arity :== PD_Arity2TupleType + tup_arity - 2

// changes requires recompile of {static,dynamic}-linker plus all dynamics ever made
UnderscoreSystemDynamicModule_String	:== "_SystemDynamic"	

// List-type
PD_ListType_String				:== "_List"
PD_ConsSymbol_String			:== "_Cons"
PD_NilSymbol_String				:== "_Nil"

// Array-type
PD_UnboxedArray_String			:== "_#Array"

DynamicRepresentation_String			:== "DynamicTemp" // "_DynamicTemp"		
