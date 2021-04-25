module ivy.types.symbol.consts;

enum IvyAttrType: string
{
	Any = "any",
	Str = "str",
	Int = "int",
	Bool = "bool",
	Float = "float"
}

static immutable GLOBAL_SYMBOL_NAME = "__global__";

enum SymbolKind: ubyte {
	directive,
	module_,
	declClass
}

enum IvyProtocolAttr: string
{
	serialize = "__serialize__"
}