define('ivy/ModuleObjectsCache', [
], function() {
	function ModuleObjectsCache() {
		this._moduleObjects = {};
	};
	return __mixinProto(ModuleObjectsCache, {
		get: function(moduleName) {
			return this._moduleObjects[moduleName];
		},

		add: function(moduleObj) {
			this._moduleObjects[moduleObj._name] = moduleObj;
		},

		clearCache: function() {
			for( var key in this._moduleObjects ) {
				if( this._moduleObjects.hasOwnProperty(key) ) {
					delete this._moduleObjects[key];
				}
			}
		},

		moduleObjects: function() {
			return this._moduleObjects;
		}
	});
});