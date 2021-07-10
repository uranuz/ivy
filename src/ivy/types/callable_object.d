module ivy.types.callable_object;

/**
	Callable object is representation of directive or module prepared for execution.
	Consists of it's code object (that will be executed) and some context (module for example)
*/
class CallableObject
{
	import ivy.types.code_object: CodeObject;
	import ivy.interpreter.directive.iface: IDirectiveInterpreter;
	import ivy.types.symbol.iface: ICallableSymbol;
	import ivy.types.data: IvyData;
	
	import std.exception: enforce;

private:
	union
	{
		// Native directive interpreter connected to this callable
		IDirectiveInterpreter _dirInterp;
		// Code object related to this callable
		CodeObject _codeObject;
	}

	// Kind of callable: native IDirectiveInterpreter or ivy CodeObject
	bool _isNative;

	// Context is a "this" variable used with this callable
	IvyData _context;

	// Calculated default values
	IvyData[string] _defaults;

public:
	this(CodeObject codeObject, IvyData[string] defaults = null)
	{
		this._codeObject = codeObject;
		this._isNative = false;
		this._defaults = defaults;
		enforce(this._codeObject !is null, "Expected code object");
	}

	this(IDirectiveInterpreter dirInterp)
	{
		this._dirInterp = dirInterp;
		this._isNative = true;
		enforce(this._dirInterp !is null, "Expected native dir interpreter");
	}

	this(CallableObject other, IvyData context)
	{
		this._isNative = other.isNative;
		if( other.isNative ) {
			this._dirInterp = other.dirInterp;
		} else {
			this._codeObject = other.codeObject;
		}
		this._defaults = other.defaults;
		this._context = context;
	}

	bool isNative() @property {
		return this._isNative;
	}

	IDirectiveInterpreter dirInterp() @property
	{
		enforce(this._dirInterp, "Callable is not a native dir interpreter");
		return this._dirInterp;
	}

	CodeObject codeObject() @property
	{
		enforce(this._codeObject , "Callable is not an ivy code object");
		return this._codeObject;
	}

	ICallableSymbol symbol() @property
	{
		if( this.isNative ) {
			return this._dirInterp.symbol;
		}
		return this.codeObject.symbol;
	}

	ICallableSymbol moduleSymbol() @property
	{
		if( this.isNative ) {
			return this._dirInterp.moduleSymbol;
		}
		return this.codeObject.moduleObject.symbol;
	}

	ref IvyData[string] defaults() @property {
		return this._defaults;
	}

	IvyData context() @property {
		return this._context;
	}

}