define('ivy/types/data/decl_class', [
	'ivy/types/data/base_class_node',
	'ivy/types/callable_object',
	'ivy/types/data/data',
	'ivy/types/data/consts',
	'ivy/interpreter/directive/utils'
], function(
	BaseClassNode,
	CallableObject,
	idat,
	IvyConsts,
	dutil
) {
var
	makeDir = dutil.makeDir,
	IvyDataType = IvyConsts.IvyDataType,
	CallableKV = FirClass(function CallableKV(name, callable) {
		var inst = firPODCtor(this, arguments);
		if( inst ) return inst;

		this.name = name;
		this.callable = callable;
	});

function __emptyInit__() {
	// Default __init__ that does nothing
}

return FirClass(
	function DeclClass(name, dataDict, baseClass) {
		this._name = name;
		this._dataDict = dataDict;
		this._baseClass = baseClass || null;

		var initCallable;
		try {
			initCallable = idat.callable(this.__getAttr__("__init__"));
		} catch(Exception) {
			// Maybe there is no __init__ for class, so create it...
			this.__setAttr__(new CallableObject(this.i__emptyInit__), "__init__");
			initCallable = idat.callable(this.__getAttr__("__init__"));
		}

		try {
			// Put default values from __init__ to __new__
			var newCallable = this.__call__();
			newCallable.defaults = initCallable.defaults;
			// We need to bind __new__ callable to class object to be able to make instances
			this.__setAttr__(new CallableObject(newCallable, this), "__new__");
		} catch(Exception) {
			// Seems that it is build in class that cannot be created by user
		}
	}, BaseClassNode, {
		__getAttr__: function(field) {
			if( !this._dataDict.hasOwnProperty(field) ) {
				throw new Error("No attribute with name: " + field + " for class: " + this.name);
			}
			return this._dataDict[field];
		},
	
		__setAttr__: function(val, field) {
			this._dataDict[field] = val;
		},
	
		__call__: function() {
			return idat.callable(this.__getAttr__("__new__"));
		},
	
		__serialize__: function() {
			return "<class " + this._name + ">";
		},

		name: firProperty(function() {
			return this._name;
		}),

		_getThisMethods: function() {
			// Return all class callables
			return Object.entries(this._dataDict).filter(function(it) {
				return idat.type(it[1]) === IvyDataType.Callable
			}).map(function(it) {
				return CallableKV(it[0], idat.callable(it[1]));
			});
		},
	
		_getBaseMethods: function() {
			return (this._baseClass == null)? []: this._baseClass._getMethods();
		},
	
		_getMethods: function() {
			return Array.prototype.concat(this._getBaseMethods(), this._getThisMethods());
		},

		i__emptyInit__: makeDir(__emptyInit__, "__init__")
	});
});
