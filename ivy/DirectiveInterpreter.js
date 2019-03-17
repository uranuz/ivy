define('ivy/DirectiveInterpreter', [], function() {
return FirClass(
	function DirectiveInterpreter() {
		this._name = null;
		this._attrBlocks = [];
	}, {
		interpret: function(interp) {
			throw new Error('Not implemented method');
		},
		attrBlocks: function() {
			return this._attrBlocks;
		}
	});
});