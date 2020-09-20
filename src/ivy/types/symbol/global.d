module ivy.types.symbol.global;

import ivy.types.symbol.iface.callable: ICallableSymbol;

public import ivy.types.symbol.consts: GLOBAL_SYMBOL_NAME;

/// Contains declaration of global symbol
__gshared ICallableSymbol globalSymbol;

shared static this()
{
	import ivy.types.symbol.module_: ModuleSymbol;
	
	import trifle.location: Location;
	globalSymbol = new ModuleSymbol(GLOBAL_SYMBOL_NAME, Location(GLOBAL_SYMBOL_NAME));
}