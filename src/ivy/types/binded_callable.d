module ivy.types.binded_callable;

import ivy.types.iface.callable_object: ICallableObject;

class BindedCallable: ICallableObject
{
	import ivy.types.code_object: CodeObject;
	import ivy.interpreter.directive.iface: IDirectiveInterpreter;
	import ivy.types.symbol.iface: ICallableSymbol;
	import ivy.types.data: IvyData;

private:
	ICallableObject _callable;
	IvyData _context;

public:
	this(ICallableObject callable, IvyData context)
	{
		this._callable = callable;
		this._context = context;
	}


override {
	bool isNative() @property {
		return this._callable.isNative;
	}

	IDirectiveInterpreter dirInterp() @property {
		return this._callable.dirInterp;
	}

	CodeObject codeObject() @property {
		return this._callable.codeObject;
	}

	ICallableSymbol symbol() @property {
		return this._callable.symbol;
	}

	ICallableSymbol moduleSymbol() @property {
		return this._callable.moduleSymbol;
	}

	ref IvyData[string] defaults() {
		return this._callable.defaults;
	}

	IvyData context() @property {
		return this._context;
	}
}

}

