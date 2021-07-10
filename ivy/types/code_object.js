define('ivy/types/code_object', [], function() {
return FirClass(
	function CodeObject(symbol, moduleObject) {
		this._symbol = symbol;
		this._moduleObject = moduleObject;
		this._instrs = [];
	}, {
		symbol: firProperty(function() {
			return this._symbol;
		}),

		moduleObject: firProperty(function() {
			return this._moduleObject;
		}),

		instrs: firProperty(function() {
			return this._instrs;
		}),

		addInstr: function(instr) {
			var index = this._instrs.length;
			this._instrs.push(instr);
			return index;
		},

		instrCount: firProperty(function() {
			return this._instrs.length;
		})
	});
});