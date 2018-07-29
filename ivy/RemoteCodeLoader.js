define('ivy/RemoteCodeLoader', [
	'ivy/ModuleObject',
	'ivy/CodeObject',
	'ivy/Consts'
], function(
	ModuleObject,
	CodeObject,
	Consts
) {
function RemoteCodeLoader(endpoint) {
	if( !endpoint ) {
		throw Error('Endpoint URL required to load compiled templates!');
	}
	this._endpoint = endpoint;
	this._moduleObjects = {};
	this._mainModuleName = null;
};
var DataNodeType = Consts.DataNodeType;
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
		this._mainModuleName = json.mainModuleName;

		for(var modName in moduleObjects) {
			if( !moduleObjects.hasOwnProperty(modName) ) continue;
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
					return new CodeObject(con.instrs, moduleObj, con.attrBlocks);
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