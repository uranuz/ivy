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
	// Code object related to this callable
	CodeObject _codeObject;

	// Native directive interpreter connected to this callable
	IDirectiveInterpreter _dirInterp;

	// Calculated default values
	IvyData[string] _defaults;

public:
	this(CodeObject codeObject, IvyData[string] defaults = null)
	{
		this._codeObject = codeObject;
		this._defaults = defaults;
		enforce(this._codeObject !is null, "Expected code object");
	}

	this(IDirectiveInterpreter dirInterp)
	{
		this._dirInterp = dirInterp;
		enforce(this._dirInterp !is null, "Expected native dir interpreter");
	}

	bool isNative() @property {
		return this._dirInterp !is null;
	}

	IDirectiveInterpreter dirInterp() @property
	{
		enforce(this._dirInterp !is null, "Callable is not a native dir interpreter");
		return this._dirInterp;
	}

	CodeObject codeObject() @property
	{
		enforce(this._codeObject !is null, "Callable is not an ivy code object");
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
}