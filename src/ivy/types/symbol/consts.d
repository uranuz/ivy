module ivy.types.symbol.consts;

enum IvyAttrType: string
{
	Any = "any"
}

static immutable GLOBAL_SYMBOL_NAME = "__global__";

enum SymbolKind: ubyte {
	directive,
	module_,
	declClass
}