define('ivy/interpreter/directive/factory', [], function(dirs) {
return FirClass(
	function DirectiveFactory() {
		this._dirInterps = {};
	}, {
		get: function(name) {
			return this._dirInterps[name];
		},

		add: function(dirInterp) {
			this._dirInterps[dirInterp._name] = dirInterp;
		},

		interps: function() {
			return this._dirInterps;
		},

		symbols: function() {
			var symbs = [];
			for( var key in this._dirInterps ) {
				if( this._dirInterps.hasOwnProperty(key) ) {
					symbs.push(this._dirInterps[key].symbol);
				}
			}
			return symbs;
		}
	});
	return DirectiveFactory;
});