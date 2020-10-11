define('ivy/types/module_object', [
	'ivy/types/code_object',
	'ivy/types/data/consts'
], function(
	CodeObject,
	DataConsts
) {
var NodeEscapeState = DataConsts.NodeEscapeState;
return FirClass(
	function ModuleObject(symbol) {
		this._consts = [];
		this.addConst(new CodeObject(symbol, this));
	}, {
		// Append const to list and return it's index
		addConst: function(data)
		{
			// Get index of added constant
			var index = this._consts.length;
			// Consider all constants are Safe by default
			//data.escapeState = NodeEscapeState.Safe;
			this._consts.push(data);
			return index;
		},

		getConst: function(index) {
			if( index >= this._consts.length ) {
				throw Error('There is no module const with specified index!');
			}
			return this._consts[index];
		},

		mainCodeObject: firProperty(function() {
			return this.getConst(0);
		}),

		symbol: firProperty(function() {
			return this.mainCodeObject.symbol;
		}),
		
		name: firProperty(function() {
			return this.symbol.name
		}),

		fileName: firProperty(function() {
			return this.symbol.location.fileName;
		})
	});
});