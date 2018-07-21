define('ivy/Programme', [
	'ivy/Interpreter'
], function(Interpreter) {
	function Programme(moduleObjs, mainModuleName, dirInterps) {
		this._moduleObjs = moduleObjs;
		this._mainModuleName = mainModuleName;
		this._dirInterps = dirInterps || {};
	};
	return __mixinProto(Programme, {
		run: function(mainModuleScope) {
			mainModuleScope = mainModuleScope || {};
			var interp = new Interpreter(
				this._moduleObjs,
				this._mainModuleName,
				mainModuleScope
			);
			return interp.execLoop();
		}
	});
});