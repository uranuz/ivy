define('ivy/RemoteModuleLoader', [
	'fir/datctrl/ivy/Deserializer',
	'ivy/Consts'
], function(
	IvyDeserializer
) {
return FirClass(
function RemoteModuleLoader(endpoint) {
	if( !endpoint ) {
		throw Error('Endpoint URL required to load compiled templates!');
	}
	this._endpoint = endpoint;
	this._moduleObjects = {};
}, {
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
	},

	load: function(moduleName, callback) {
		var self = this;
		$.ajax(this._endpoint + '?moduleName=' + moduleName + '&generalTemplate=no', {
			success: function(jsonText) {
				var json = JSON.parse(jsonText);
				callback(self.parseModules(json), moduleName);
			},
			error: function(error) {
				console.error(error);
			}
		});
	},
	parseModules: function(json) {
		var moduleObjects = json.moduleObjects;
		for( var modName in moduleObjects ) {
			if( !moduleObjects.hasOwnProperty(modName) || this._moduleObjects.hasOwnProperty(modName) ) {
				// Skip build-in properties. Do not recreate the same modules again
				continue;
			}
			this._moduleObjects[modName] = IvyDeserializer.deserialize(moduleObjects[modName]);
		}
		return this._moduleObjects;
	}
});
});