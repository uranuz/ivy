module ivy.interpreter._global_callable_init;

shared static this()
{
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.types.callable_object: CallableObject;
	import ivy.interpreter.directive.base: makeDir;
	import ivy.types.symbol.global: GLOBAL_SYMBOL_NAME;

	Interpreter._globalCallable = new CallableObject(makeDir!_globalStub(GLOBAL_SYMBOL_NAME));
}

private void _globalStub() {
	// Does nothing...
}