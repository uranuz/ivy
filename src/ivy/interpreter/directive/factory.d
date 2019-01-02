module ivy.interpreter.directive.factory;

class InterpreterDirectiveFactory
{
	import ivy.interpreter.iface: INativeDirectiveInterpreter;
	import ivy.compiler.symbol_table: Symbol;
private:
	INativeDirectiveInterpreter[string] _dirInterps;

public:
	this() {}

	INativeDirectiveInterpreter get(string name) {
		return _dirInterps.get(name, null);
	}

	void add(INativeDirectiveInterpreter dirInterp) {
		_dirInterps[dirInterp.symbol.name] = dirInterp;
	}

	INativeDirectiveInterpreter[string] interps() @property {
		return _dirInterps;
	}

	Symbol[] symbols() @property
	{
		import std.algorithm: map;
		import std.array: array;
		return _dirInterps.values.map!(it => it.symbol).array;
	}
}
