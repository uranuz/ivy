module ivy.types.data.decl_class;

import ivy.types.data.base_class_node: BaseClassNode;
import ivy.types.data.decl_class_node: DeclClassNode;

class DeclClass: BaseClassNode
{
	import ivy.types.data: IvyData, IvyDataType;
	import ivy.types.callable_object: CallableObject;
	import ivy.interpreter.directive.utils: makeDir;
	import ivy.interpreter.directive.iface: IDirectiveInterpreter;

	static struct CallableKV
	{
		string name;
		CallableObject callable;
	}

protected:
	string _name;
	IvyData[string] _dataDict;
	DeclClass _baseClass;

public:
	this(string name, IvyData[string] dataDict, DeclClass baseClass = null)
	{
		this._name = name;
		this._dataDict = dataDict;
		this._baseClass = baseClass;

		CallableObject initCallable;
		try {
			initCallable = this.__getAttr__("__init__").callable;
		} catch(Exception) {
			// Maybe there is no __init__ for class, so create it...
			this.__setAttr__(IvyData(new CallableObject(this.i__emptyInit__)), "__init__");
			initCallable = this.__getAttr__("__init__").callable;
		}

		try {
			// Put default values from __init__ to __new__
			CallableObject newCallable = this.__call__();
			newCallable.defaults = initCallable.defaults;
			// We need to bind __new__ callable to class object to be able to make instances
			this.__setAttr__(IvyData(new CallableObject(newCallable, IvyData(this))), "__new__");
		} catch(Exception) {
			// Seems that it is build in class that cannot be created by user
		}
	}

override {
	IvyData __getAttr__(string field)
	{
		auto valPtr = field in this._dataDict;
		if( valPtr !is null ) {
			return *valPtr;
		}
		if( this._baseClass !is null ) {
			return this._baseClass.__getAttr__(field);
		}
		throw new Exception("No attribute with name: " ~ field ~ " for class: " ~ this.name);
	}

	void __setAttr__(IvyData val, string field) {
		this._dataDict[field] = val;
	}

	CallableObject __call__() {
		return this.__getAttr__("__new__").callable;
	}
}
	final CallableKV[] _getThisMethods()
	{
		import std.algorithm: filter, map;
		import std.array: array;

		// Return all class callables
		return this._dataDict.byKeyValue.filter!(
			(it) => it.value.type == IvyDataType.Callable
		).map!(
			(it) => CallableKV(it.key, it.value.callable)
		).array;
	}

	final CallableKV[] _getBaseMethods() {
		return (this._baseClass is null)? []: this._baseClass._getMethods();
	}

	final CallableKV[] _getMethods()
	{
		import std.algorithm: filter, map;
		import std.array: array;
		import std.range: chain;

		return chain(this._getBaseMethods(), this._getThisMethods()).array;
	}

	string name() @property {
		return this._name;
	}

	private final void __emptyInit__() {
		// Default __init__ that does nothing
	}

	private __gshared IDirectiveInterpreter i__emptyInit__;

	shared static this()
	{
		i__emptyInit__ = makeDir!__emptyInit__("__init__");
	}
}

