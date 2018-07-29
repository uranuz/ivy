define('ivy/DirectiveInterpreter', [], function() {
	function DirectiveInterpreter() {
		this._name = null;
		this._attrBlocks = [];
	}
	return __mixinProto(DirectiveInterpreter, {
		interpret: function(interp) {
			throw new Error('Not implemented method');
		},
		attrBlocks: function() {
			return this._attrBlocks;
		}
	});
});