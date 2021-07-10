define('ivy/types/symbol/decl_class', [
	'ivy/types/symbol/iface/callable',
	'ivy/location',
	'ivy/types/symbol/consts'
], function(
	ICallableSymbol,
	Location,
	SymbolConsts
) {
var SymbolKind = SymbolConsts.SymbolKind;
return FirClass(
	function DeclClassSymbol(name, loc) {
		this._name = name;
		this._loc = loc;
		this._initSymbol = null;

		if( !this._name.length ) {
			throw new Error('Expected directive symbol name');
		}
		if( !(this._loc instanceof Location) ) {
			throw new Error('Expected instance of Location');
		}
	}, ICallableSymbol, {
		name: firProperty(function() {
			return this._name;
		}),

		location: firProperty(function() {
			return this._loc;
		}),

		kind: firProperty(function() {
			return SymbolKind.declClass;
		}),

		attrs: firProperty(function() {
			return this.initSymbol.attrs;
		}),

		getAttr: function(attrName) {
			return this.initSymbol.getAttr(attrName);
		},

		initSymbol: firProperty(function() {
			return this._initSymbol;
		}, function(symb) {
			this._initSymbol = symb;
		})
	}
);
});