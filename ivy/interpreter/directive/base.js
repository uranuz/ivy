define('ivy/interpreter/directive/base', [
	'ivy/interpreter/directive/iface',
	'ivy/types/symbol/global'
], function(
	IDirectiveInterpreter,
	globalSymbol
) {
return FirClass(
	function BaseDirectiveInterpreter() {
		this._symbol = null;
	}, IDirectiveInterpreter, {
		interpret: function(interp) {
			throw new Error("Implement this!");
		},

		symbol: firProperty(function() {
			if( this._symbol == null ) {
				throw new Error("Directive symbol is not set for: " + this.constructor.name);
			}
			return this._symbol;
		}),

		moduleSymbol: firProperty(function() {
			return globalSymbol;
		})
	});
});