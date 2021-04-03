module ivy.interpreter.directive.global;

import ivy.interpreter.directive.utils;

private class GlobalDirInterpreter: BaseDirectiveInterpreter
{
	import ivy.types.symbol.global: globalSymbol;
	
	this() {
		this._symbol = globalSymbol;
	}
	
	override void interpret(Interpreter interp) {
		throw new Exception("This is not expected to be executed");
	}
}

import ivy.types.callable_object: CallableObject;

private __gshared IDirectiveInterpreter globalDirective;
__gshared CallableObject globalCallable;

shared static this()
{
	globalDirective = new GlobalDirInterpreter;
	globalCallable = new CallableObject(globalDirective);
}