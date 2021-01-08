module ivy.types.data.decl_class;

import ivy.types.data.base_class_node: BaseClassNode;

/++
class DataSource {=

def this {=
	var
		uri
		method;
	do {=
		set this._uri: 
		set this._method;
	}
};

def list {=
	var
		data;
	do {=
		var res: {=await {=remoteCall this._uri this._method data} };
		return res.items;
	}
};

};

def MyComponent {=
	var
		dataSource: {=DataSource 'http://somewhere.com/api' 'test.do'}
}

{=call DataSource {}}

+/

class DeclClass: BaseClassNode
{
	import ivy.types.data: IvyData, IvyDataType;
	import ivy.types.binded_callable: BindedCallable;
	import ivy.types.iface.callable_object: ICallableObject;

protected:
	string _name;
	IvyData[string] _dataDict;

public:
	this(string name, IvyData[string] dataDict)
	{
		this._name = name;
		this._dataDict = dataDict;

		// Bind all callables to this class
		foreach( key, val; this._dataDict )
		{
			if( val.type == IvyDataType.Callable ) {
				this._dataDict[key] = new BindedCallable(val.callable, IvyData(this));
			}
		}
	}

override {
	IvyData __getAttr__(string field)
	{
		auto valPtr = field in this._dataDict;
		if( valPtr is null ) {
			throw new Exception("No attribute with name: " ~ field ~ " for class: " ~ this.name);
		}
		return *valPtr;
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
	auto _getMethods()
	{
		import std.algorithm: filter, canFind;

		// Return all class callables except for "__new__"
		return this._dataDict.byKeyValue.filter!(
			(it) => it.value.type == IvyDataType.Callable && it.key != "__new__"
		);
	}

	string name() @property {
		return this._name;
	}
}

