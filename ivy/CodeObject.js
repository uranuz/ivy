define('ivy/CodeObject', [], function() {
	function CodeObject(instrs, moduleObj, attrBlocks) {
		this._instrs = instrs;
		this._moduleObj = moduleObj;
		this._attrBlocks = attrBlocks;
	};
	return __mixinProto(CodeObject, {
		
	});
});