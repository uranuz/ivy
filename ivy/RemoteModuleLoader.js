define('ivy/RemoteModuleLoader', [
	'ivy/ModuleObject',
	'ivy/CodeObject',
	'ivy/Consts'
], function(
	ModuleObject,
	CodeObject,
	Consts
) {
var IvyDataType = Consts.IvyDataType;
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
			var
				jMod = moduleObjects[modName],
				consts = jMod.consts,
				moduleObj = new ModuleObject(modName, consts, jMod.entryPointIndex);

			this._moduleObjects[modName] = moduleObj;
			for( var i = 0; i < consts.length; ++i ) {
				consts[i] = this._deserializeValue(consts[i], moduleObj);
			}
		}
		return this._moduleObjects;
	},
	_deserializeValue: function(con, moduleObj) {
		if( con === 'undef' ) {
			return undefined;
		} else if(
			con === null
			|| con === true || con === false || con instanceof Boolean
			|| typeof(con) === 'number' || con instanceof Number
			|| typeof(con) === 'string' || con instanceof String
			|| con instanceof Array
		) {
			return con;
		} else if( con instanceof Object ) {
			switch( con._t ) {
				case IvyDataType.CodeObject:
					return new CodeObject(con.name, con.instrs, moduleObj, con.attrBlocks);
				case IvyDataType.DateTime:
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