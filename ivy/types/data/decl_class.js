define('ivy/types/data/decl_class', [
	'ivy/types/data/base_class_node',
	'ivy/types/binded_callable',
	'ivy/types/data/data'
], function(
	BaseClassNode,
	BindedCallable,
	idat
) {
return FirClass(
	function DeclClass(name, dataDict) {
		this._name = name;
		this._dataDict = dataDict;

		// Bind all callables to this class
		for( var key in this._dataDict )
		{
			if( idat.type(val) === IvyDataType.Callable ) {
				this._dataDict[key] = new BindedCallable(idat.type(val), this);
			}
		}
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

		_getMethods: function()
		{
			// Return all class callables except for "__new__"
			return Object.entries(this._dataDict).filter(function(it) {
				return it[1].type == IvyDataType.Callable && it[0] != "__new__"
			});
		},

		name: firProperty(function() {
			return this._name;
		})
	});
});
