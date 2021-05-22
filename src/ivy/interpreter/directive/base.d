module ivy.interpreter.directive.base;

import ivy.interpreter.directive.iface: IDirectiveInterpreter;

class DirectiveInterpreter: IDirectiveInterpreter
{
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.types.symbol.iface: ICallableSymbol;

	import std.exception: enforce;

	alias MethodType = void function(Interpreter);

	this(MethodType method, ICallableSymbol symb)
	{
		enforce(method !is null, "Expected directive method");
		enforce(symb !is null, "Expected directive symbol");
		this._method = method;
		this._symbol = symb;
	}

	protected MethodType _method;
	protected ICallableSymbol _symbol;

	override void interpret(Interpreter interp) {
		this._method(interp);
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
