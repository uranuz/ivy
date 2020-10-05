define('ivy/types/code_object', [], function() {
return FirClass(
	function CodeObject(symbol, moduleObject) {
		this._symbol = symbol;
		this._instrs = [];
		this._moduleObject = moduleObject;
	}, {
		symbol: firProperty(function() {
			return this._symbol;
		}),

		moduleObject: firProperty(function() {
			return this._moduleObject;
		}),

		addInstr: function(instr) {
			var index = this._instrs.length;
			this._instrs.push(instr);
			return index;
		}
	});
});