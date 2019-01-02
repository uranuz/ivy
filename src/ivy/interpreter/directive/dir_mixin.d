module ivy.interpreter.directive.dir_mixin;

mixin template BaseNativeDirInterpreterImpl(string symbolName)
{
	import ivy.compiler.symbol_table: DirectiveDefinitionSymbol, Symbol;

	private __gshared DirectiveDefinitionSymbol _symbol;

	shared static this()
	{
		// Create symbol for compiler
		_symbol = new DirectiveDefinitionSymbol(symbolName, _attrBlocks);
	}

	override DirAttrsBlock[] attrBlocks() @property {
		return _attrBlocks;
	}

	override Symbol symbol() @property {
		return _symbol;
	}
}