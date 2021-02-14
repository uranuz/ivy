module ivy.types.data.decl_class;

import ivy.types.data.base_class_node: BaseClassNode;

class DeclClass: BaseClassNode
{
	import ivy.types.data: IvyData, IvyDataType;
	import ivy.types.binded_callable: BindedCallable;
	import ivy.types.iface.callable_object: ICallableObject;

	static struct CallableKV
	{
		string name;
		ICallableObject callable;
	}

protected:
	string _name;
	IvyData[string] _dataDict;
	DeclClass _baseClass;

public:
	this(string name, IvyData[string] dataDict, DeclClass baseClass)
	{
		this._name = name;
		this._dataDict = dataDict;
		this._baseClass = baseClass;

		// Bind all callables to this class
		foreach( it; this._getThisMethods() )
			this._dataDict[it.name] = new BindedCallable(it.callable, IvyData(this));

		// Workaround. Put default values from __init__ to __new__
		ICallableObject initCallable = this.__getAttr__("__init__").callable;
		ICallableObject newCallable = this.__call__();
		newCallable.defaults = initCallable.defaults;
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

	ICallableObject __call__() {
		return this.__getAttr__("__new__").callable;
	}

	IvyData __serialize__() {
		return IvyData("<class " ~ this._name ~ ">");
	}
}
	CallableKV[] _getThisMethods()
	{
		import std.algorithm: filter, map;
		import std.array: array;

		// Return all class callables except for "__new__"
		return this._dataDict.byKeyValue.filter!(
			(it) => it.value.type == IvyDataType.Callable //&& it.key != "__new__"
		).map!(
			(it) => CallableKV(it.key, it.value.callable)
		).array;
	}

	CallableKV[] _getBaseMethods() {
		return (this._baseClass is null)? []: this._baseClass._getMethods();
	}

	CallableKV[] _getMethods()
	{
		import std.algorithm: filter, map;
		import std.array: array;
		import std.range: chain;

		return chain(this._getBaseMethods(), this._getThisMethods()).array;
	}

	string name() @property {
		return this._name;
	}
}

