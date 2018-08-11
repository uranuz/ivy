define('ivy/CodeObject', [], function() {
	function CodeObject(name, instrs, moduleObj, attrBlocks) {
		this._name = name;
		this._instrs = instrs;
		this._moduleObj = moduleObj;
		this._attrBlocks = attrBlocks;
	};
	return __mixinProto(CodeObject, {
		
	});
});