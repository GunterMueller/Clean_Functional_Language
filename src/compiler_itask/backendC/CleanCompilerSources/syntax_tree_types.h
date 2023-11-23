
typedef enum {
	int_type, bool_type, char_type, real_type,
	file_type, world_type, procid_type, redid_type,
	fun_type,
	array_type, strict_array_type, unboxed_array_type, packed_array_type,
	list_type, maybe_type, tuple_type,
	dynamic_type,
	apply_type_symb,
	NTypeSymbKinds,
	type_definition = 20
} TypeSymbKind;

#define Nr_Of_Predef_Types apply_type_symb

union type_symb_value {
	struct symbol_def *	tval_def;
	int					tval_arity;
};

STRUCT (type_symbol,TypeSymbol) {
	union type_symb_value	ts_tval;
	unsigned				ts_kind:8;				/* TypeSymbKind */
	unsigned				ts_head_strictness:4;	/* 0=lazy,1=overloaded,2=strict,3=unboxed overloaded,4=unboxed*/
	unsigned				ts_tail_strictness:2;	/* 0=lazy,1=strict */
};

#define ts_def ts_tval.tval_def
#define ts_arity ts_tval.tval_arity

typedef enum
{	NoUniAttr, NotUniqueAttr, UniqueAttr, ExistsAttr, UniqueVariable, FirstUniVarNumber
} UniquenessAttributeKind;

typedef unsigned AttributeKind;

typedef struct poly_list
{	struct symbol_def *	pl_elem;
	struct poly_list *	pl_next;
} * PolyList;

typedef struct type_arg * TypeArgs, TypeArg;
typedef struct type_node *	TypeNode;
typedef struct type_alt *	TypeAlts;

typedef struct type_var *TypeVar;

typedef struct field_list
{
	Symbol				fl_symbol;
	TypeNode			fl_type;
	StateS				fl_state;
	struct field_list *	fl_next;
} * FieldList;

typedef struct constructor_list
{
	Symbol						cl_constructor_symbol;
	struct type_arg *			cl_constructor_arguments;
	FieldList					cl_fields;
	StateP						cl_state_p; /* for constructors, union met cl_fields ? */
	struct constructor_list *	cl_next;
} * ConstructorList;

typedef struct type
{
	TypeSymbol			type_symbol;
	AttributeKind		type_attribute;
	ConstructorList		type_constructors;
	int					type_nr_of_constructors;	/* 0 for records */
} * Types;

#define type_fields 	type_constructors -> cl_fields

struct rule_type
{	TypeAlts			rule_type_rule;
	StateP              rule_type_state_p;
};

struct type_node
{
	union {
		int					contents_tv_argument_n;
		TypeSymbol			contents_symbol;
	} type_node_contents;

	struct type_arg *		type_node_arguments;
	AttributeKind			type_node_attribute;
	short					type_node_arity;
	Annotation				type_node_annotation;
	unsigned char			type_node_is_var:1;
};

#define type_node_symbol type_node_contents.contents_symbol
#define type_node_tv_argument_n type_node_contents.contents_tv_argument_n

struct type_arg
{	TypeNode	type_arg_node;
	TypeArgs	type_arg_next;
};

STRUCT (strict_positions, StrictPositions)
{
	int sp_size;		/* size in bits */
	int sp_bits [1];	/* variable size */
};

typedef struct type_alt
{
	Symbol					type_alt_lhs_symbol;
	struct type_arg *		type_alt_lhs_arguments;
	short					type_alt_lhs_arity;
	TypeNode				type_alt_rhs;
	StrictPositionsP		type_alt_strict_positions;
} TypeAlt;
