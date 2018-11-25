module ivy.interpreter.iface;

interface INativeDirectiveInterpreter
{
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.compiler.symbol_table: Symbol;
	import ivy.directive_stuff: DirAttrsBlock;

	void interpret(Interpreter interp);

	DirAttrsBlock[] attrBlocks() @property;

	Symbol symbol() @property;
}