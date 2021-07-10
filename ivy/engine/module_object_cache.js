define('ivy/engine/config', [
], function() {
return FirClass(
	function ModuleObjectCache() {
		this._moduleObjects = {};
	}, {
		get: function(moduleName) {
			return this._moduleObjects[moduleName];
		},

		add: function(moduleObject) {
			this._moduleObjects[moduleObject.symbol.name] = moduleObject;
		},

		clearCache: function() {
			Object.keys(this._moduleObjects).forEach(function(key) {
				delete this._moduleObjects[key];
			});
		},

		moduleObjects: firProperty(function() {
			return this._moduleObjects
		})
	});
});