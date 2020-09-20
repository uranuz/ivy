module ivy.interpreter.directive.iface;

interface IDirectiveInterpreter
{
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.types.symbol.iface: ICallableSymbol;

	void interpret(Interpreter interp);

	ICallableSymbol symbol() @property;
	ICallableSymbol moduleSymbol() @property;
}