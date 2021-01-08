define('ivy/types/data/decl_class_node', [
	'ivy/types/data/base_class_node',
	'ivy/types/binded_callable',
	'ivy/types/data/data'
], function(
	BaseClassNode,
	BindedCallable,
	idat
) {
return FirClass(
	function DeclClassNode(type) {
		this._type = type;

		// Bind all class callables to class instance
		this._type._getMethods().forEach(function(it) {
			this._dataDict[it[0]] = new BindedCallable(idat.callable(it[1]), this);
		});
	}, BaseClassNode, {
		__getAttr__: function(field) {
			if( this._dataDict.hasOwnProperty(field) ) {
				return this._dataDict[field];
			}
			// Find field in a class if there is no such field in the class instance
			return this._type.__getAttr__(field);
		},
	
		__setAttr__: function(val, field) {
			this._dataDict[field] = val;
		},
	
		__serialize__: function() {
			return "<" + this._type.name + ">";
		}
	});
});
