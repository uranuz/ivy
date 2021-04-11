module ivy.interpreter.directive.factory;

class InterpreterDirectiveFactory
{
	import ivy.interpreter.directive.iface: IDirectiveInterpreter;
	import ivy.types.symbol.iface: ICallableSymbol;

	import std.exception: enforce;

private:
	InterpreterDirectiveFactory _baseFactory;
	IDirectiveInterpreter[] _dirInterps;
	size_t[string] _indexes;

public:
	this(InterpreterDirectiveFactory baseFactory = null) {
		this._baseFactory = baseFactory;
	}

	IDirectiveInterpreter get(string name)
	{
		auto intPtr = name in this._indexes;
		if( intPtr is null ) {
			return this._dirInterps[*intPtr];
		}
		if( this._baseFactory !is null ) {
			return this._baseFactory.get(name);
		}
		return null;
	}

	void add(IDirectiveInterpreter dirInterp)
	{
		string name = dirInterp.symbol.name;
		enforce(name !in this._indexes, "Directive interpreter with name: " ~ name ~ " already added");
		this._indexes[name] = this._dirInterps.length;
		this._dirInterps ~= dirInterp;
	}

	IDirectiveInterpreter[] interps() @property
	{
		import std.algorithm: map;
		import std.range: chain;
		import std.array: array;

		return chain(this._getBaseInterps(), this._dirInterps).array;
	}

	ICallableSymbol[] symbols() @property
	{
		import std.algorithm: map;
		import std.range: chain;
		import std.array: array;

		return chain(this._dirInterps.map!(it => it.symbol), this._getBaseSymbols()).array;
	}

	IDirectiveInterpreter[] _getBaseInterps() {
		return this._baseFactory is null? []: this._baseFactory.interps;
	}

	ICallableSymbol[] _getBaseSymbols() {
		return this._baseFactory is null? []: this._baseFactory.symbols;
	}
}
