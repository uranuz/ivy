define('ivy/CallableObject', [
	'ivy/CodeObject'
], function(CodeObject) {
	function CallableObject(name, codeObj) {
		this._name = name;
		if( codeObj instanceof CodeObject ) {
			this._codeObj = codeObj;
			this._dirInterp = null;
		} else {
			this._codeObj = null;
			this._dirInterp = codeObj;
		}
	};
	return __mixinProto(CallableObject, {
		attrBlocks: function() {
			return (this._codeObj? this._codeObj._attrBlocks: this._dirInterp._attrBlocks)
		}
	});
});