define('ivy/DirectiveFactory', [
	'ivy/directives'
], function(dirs) {
	function DirectiveFactory() {
		this._dirInterps = {};
	};
	__mixinProto(DirectiveFactory, {
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
	DirectiveFactory.makeStandardInterpreterDirFactory = function() {
		var factory = new DirectiveFactory();
		factory.add(new dirs.IntCtorDirInterpreter);
		factory.add(new dirs.FloatCtorDirInterpreter);
		factory.add(new dirs.StrCtorDirInterpreter);
		factory.add(new dirs.HasDirInterpreter);
		factory.add(new dirs.TypeStrDirInterpreter);
		factory.add(new dirs.LenDirInterpreter);
		factory.add(new dirs.EmptyDirInterpreter);
		factory.add(new dirs.ScopeDirInterpreter);
		factory.add(new dirs.ToJSONBase64DirInterpreter);
		factory.add(new dirs.DateTimeGetDirInterpreter);
		factory.add(new dirs.RangeDirInterpreter);
		return factory;
	};
	return DirectiveFactory;
});