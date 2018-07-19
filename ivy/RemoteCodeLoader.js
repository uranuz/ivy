define('ivy/RemoteCodeLoader', [
	'ivy/ModuleObject',
	'ivy/CodeObject',
], function(
	ModuleObject,
	CodeObject
) {
function RemoteCodeLoader(endpoint) {
	if( !endpoint ) {
		throw Error('Endpoint URL required to load compiled templates!');
	}
	this._endpoint = endpoint;
};
return __mixinProto(RemoteCodeLoader, {
	load: function(moduleName, callback) {
		var self = this;
		$.ajax(this._endpoint + '?moduleName=' + moduleName, {
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
		this._mainModuleObject = json.mainModuleObject;

		for(var modName in moduleObjects) {
			if( !moduleObjects.hasOwnProperty(modName) ) continue;
			var
				jMod = moduleObjects[modName],
				consts = jMod.consts;

			this._moduleObjects[modName] = new ModuleObject(modName, consts);
			for( var i = 0; i < consts.length; ++i ) {
				consts[i] = this._deserializeValue(consts[i]);
			}
		}
		return this._moduleObjects;
	},
	_deserializeValue: function(con) {
		if( con === 'undef' ) {
			return undefined;
		} else if(
			con === null
			|| con === true
			|| con === false
			|| typeof(con) === 'number'
			|| typeof(con) === 'string'
			|| con instanceof Array
		) {
			return con;
		} else if( con instanceof Object ) {
			switch( con._t ) {
				case DataNodeType.CodeObject:
					return new CodeObject(con.instrs, this._moduleObjects[modName]);
				case DataNodeType.DateTime:
					return new Date(con._v);
				default:
					return con;
			}
		} else {
			throw new Error('Unexpected value type!');
		}
	}
});
});