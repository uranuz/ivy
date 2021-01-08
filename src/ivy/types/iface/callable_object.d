module ivy.types.iface.callable_object;

interface ICallableObject
{
	import ivy.types.code_object: CodeObject;
	import ivy.interpreter.directive.iface: IDirectiveInterpreter;
	import ivy.types.symbol.iface: ICallableSymbol;
	import ivy.types.data: IvyData;

	bool isNative() @property;

	IDirectiveInterpreter dirInterp() @property;

	CodeObject codeObject() @property;

	ICallableSymbol symbol() @property;

	ICallableSymbol moduleSymbol() @property;

	ref IvyData[string] defaults();

	IvyData context() @property;
}

