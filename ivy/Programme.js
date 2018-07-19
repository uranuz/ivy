define('ivy/Programme', [
	'ivy/Interpreter'
], function(Interpreter) {
	function Programme(moduleObjs, mainModuleName, dirInterps) {
		this._moduleObjs = moduleObjs;
		this._mainModuleName = mainModuleName;
		yhis._dirInterps = dirInterps || {};
	};
	return __mixinProto(Programme, {
		run: function() {
			var interp = new Interpreter();
		}
	});
});