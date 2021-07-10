define('ivy/engine/module_object_loader', [
	'ivy/types/data/consts',
	'ivy/types/data/async_result',
	'ivy/engine/module_object_cache'
], function(
	DataConsts,
	AsyncResult,
	ModuleObjectCache
) {
var IvyDataType = DataConsts.IvyDataType;
return FirClass(
	function ModuleObjectLoader(config) {
		if( !config.endpoint ) {
			throw new Error('Endpoint URL required to load compiled templates!');
		}
		if( !config.deserializer ) {
			throw new Error('Required link to "fir/datctrl/ivy/Deserializer" in ivy config');
		}
		this._endpoint = config.endpoint;
		this._cache = new ModuleObjectCache();
		this._deserializer = config.deserializer;
	}, {
		load: function(moduleName) {
			var fResult = new AsyncResult();
			if (this.cache.get(moduleName)) {
				fResult.resolve(this.cache.get(moduleName));
				return fResult;
			}

			$.ajax(this._endpoint + '?moduleName=' + moduleName + '&appTemplate=no', {
				success: function(json) {
					this._parseModules(json.result);
					fResult.resolve(this.cache.get(moduleName));
				}.bind(this),
				error: fResult.reject.bind(fResult)
			});
			return fResult;
		},

		cache: firProperty(function() {
			return this._cache;
		}),
	
		clearCache: function() {
			this.cache.clearCache();
		},

		_parseModules: function(json) {
			json.moduleObjects.forEach(this._parseModule.bind(this));
		},

		_parseModule: function(rawModule) {
			var moduleName = this._deserializer.getRawModuleName(rawModule);
			if( this.cache.get(moduleName) ) {
				// Module is loaded already. No need to spend more time for deserialization
				return;
			}
			this.cache.add(this._deserializer.deserialize(rawModule));
		}
	});
});