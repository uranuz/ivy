define('ivy/interpreter/directive/factory', [
	'ivy/utils',
	'ivy/exception'
], function(
	iutil,
	IvyException
) {
var assure = iutil.ensure.bind(iutil, IvyException);
return FirClass(
	function DirectiveFactory(baseFactory) {
		this._baseFactory = baseFactory;
		this._dirInterps = [];
		this._indexes = {};
	}, {
		get: function(name) {
			var intPtr = this._indexes[name];
			if( intPtr != null )
				return this._dirInterps[intPtr];
			if( this._baseFactory )
				return this._baseFactory.get(name);
			return null;
		},

		add: function(dirInterp) {
			var name = dirInterp.symbol.name;
			assure(!this._indexes.hasOwnProperty(name), "Directive interpreter with name: " + name + " already added");
			this._indexes[name] = this._dirInterps.length;
			this._dirInterps.push(dirInterp);
		},

		interps: firProperty(function() {
			return this._dirInterps.concat(this._getBaseInterps());
		}),

		symbols: firProperty(function() {
			return this._dirInterps.map(function(it) { return it.symbol }).concat(this._getBaseSymbols());
		}),

		_getBaseInterps: function() {
			return this._baseFactory? this._baseFactory.interps: [];
		},
	
		_getBaseSymbols: function() {
			return this._baseFactory? this._baseFactory.symbols: [];
		}
	});
});