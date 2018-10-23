define('ivy/CallableObject', [
	'ivy/CodeObject',
	'ivy/utils',
	'ivy/Consts'
], function(CodeObject, iu, Consts) {
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
		},

		isNoscope: function() {
			var attrBlocks = this.attrBlocks();
			if( attrBlocks.length < 1 ) {
				throw new Error('Attr block count must be > 1');
			}
			if( iu.back(attrBlocks).kind !== Consts.DirAttrKind.BodyAttr ) {
				throw new Error('Last attr block definition expected to be BodyAttr');
			}
			return iu.back(attrBlocks).bodyAttr.isNoscope;
		}
	});
});