define('ivy/types/data/decl_class', [
	'ivy/types/data/base_class_node',
	'ivy/types/binded_callable',
	'ivy/types/data/data'
], function(
	BaseClassNode,
	BindedCallable,
	idat
) {
var CallableKV = FirClass(
	function CallableKV(name, callable) {
		var inst = firPODCtor(this, arguments);
		if( inst ) return inst;

		this.name = name;
		this.callable = callable;
	});

return FirClass(
	function DeclClass(name, dataDict, baseClass) {
		this._name = name;
		this._dataDict = dataDict;
		this._baseClass = baseClass || null;

		// Bind all callables to this class
		for( var it in this._getThisMethods() )
			this._dataDict[it.name] = new BindedCallable(it.callable, this);
	}, BaseClassNode, {
		__getAttr__: function(field) {
			if( this._dataDict.hasOwnproperty(field) ) {
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

		_getThisMethods: function() {
			// Return all class callables except for "__new__"
			return Object.entries(this._dataDict).filter(function(it) {
				return it[1].type == IvyDataType.Callable //&& it[0] != "__new__"
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

		name: firProperty(function() {
			return this._name;
		})
	});
});
