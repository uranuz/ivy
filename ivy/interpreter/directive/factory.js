define('ivy/interpreter/directive/factory', [
	'ivy/utils',
	'ivy/exception'
], function(
	iutil,
	IvyException
) {
var enforce = iutil.enforce.bind(iutil, IvyException);
return FirClass(
	function DirectiveFactory() {
		this._dirInterps = [];
		this._indexes = {};
	}, {
		get: function(name) {
			return this._dirInterps[this._indexes[name]];
		},

		add: function(dirInterp) {
			var name = dirInterp.symbol.name;
			enforce(!this._indexes.hasOwnProperty(name), "Directive interpreter with name: " + name + " already added");
			this._indexes[name] = this._dirInterps.length;
			this._dirInterps.push(dirInterp);
		},

		interps: firProperty(function() {
			return this._dirInterps;
		}),

		symbols: firProperty(function() {
			return this._dirInterps.map(function(it) { return it.symbol });
		})
	});
});