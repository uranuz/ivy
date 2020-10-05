module ivy.interpreter.directive.base;

import ivy.interpreter.directive.iface: IDirectiveInterpreter;

class BaseDirectiveInterpreter: IDirectiveInterpreter
{
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.types.symbol.iface: ICallableSymbol;

	import std.exception: enforce;

	protected ICallableSymbol _symbol;

	override void interpret(Interpreter interp) {
		assert(false, "Implement this!");
	}

	override ICallableSymbol symbol() @property
	{
		import std.conv: text;
		enforce(this._symbol !is null, "Directive symbol is not set for: " ~ typeid(this).text);
		return this._symbol;
	}

	override ICallableSymbol moduleSymbol() @property
	{
		import ivy.types.symbol.global: globalSymbol;
		return globalSymbol;
	}
}