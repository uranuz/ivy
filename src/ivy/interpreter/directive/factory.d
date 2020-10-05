module ivy.interpreter.directive.factory;

class InterpreterDirectiveFactory
{
	import ivy.interpreter.directive.iface: IDirectiveInterpreter;
	import ivy.types.symbol.iface: ICallableSymbol;

	import std.exception: enforce;
private:
	IDirectiveInterpreter[] _dirInterps;
	size_t[string] _indexes;

public:
	this() {}

	IDirectiveInterpreter get(string name)
	{
		auto intPtr = name in this._indexes;
		if( intPtr is null ) {
			return null;
		}
		return this._dirInterps[*intPtr];
	}

	void add(IDirectiveInterpreter dirInterp)
	{
		string name = dirInterp.symbol.name;
		enforce(name !in this._indexes, "Directive interpreter with name: " ~ name ~ " already added");
		this._indexes[name] = this._dirInterps.length;
		this._dirInterps ~= dirInterp;
	}

	IDirectiveInterpreter[] interps() @property {
		return _dirInterps;
	}

	ICallableSymbol[] symbols() @property
	{
		import std.algorithm: map;
		import std.array: array;
		return _dirInterps.map!(it => it.symbol).array;
	}
}
