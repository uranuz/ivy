module ivy.interpreter.directive.factory;

class InterpreterDirectiveFactory
{
	import ivy.interpreter.directive.iface: IDirectiveInterpreter;
	import ivy.types.symbol.iface: ICallableSymbol;

	import std.exception: enforce;
private:
	IDirectiveInterpreter[string] _dirInterps;

public:
	this() {}

	IDirectiveInterpreter get(string name) {
		return _dirInterps.get(name, null);
	}

	void add(IDirectiveInterpreter dirInterp)
	{
		string name = dirInterp.symbol.name;
		enforce(name !in _dirInterps, `Directive interpreter with name "` ~ name ~ `" already added`);
		_dirInterps[name] = dirInterp;
	}

	IDirectiveInterpreter[string] interps() @property {
		return _dirInterps;
	}

	ICallableSymbol[] symbols() @property
	{
		import std.algorithm: map;
		import std.array: array;
		return _dirInterps.values.map!(it => it.symbol).array;
	}
}
