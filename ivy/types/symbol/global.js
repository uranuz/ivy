define('ivy/types/symbol/global', [
	'ivy/types/symbol/module_',
	'ivy/types/symbol/consts'
], function(
	ModuleSymbol,
	SymbolConsts
) {
var globalSymbol = new ModuleSymbol(SymbolConsts.GLOBAL_SYMBOL_NAME, Location(SymbolConsts.GLOBAL_SYMBOL_NAME));
return globalSymbol;
});