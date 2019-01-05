define('ivy/Programme', [
	'ivy/Interpreter',
	'ivy/AsyncResult',
], function(Interpreter, AsyncResult) {
	function Programme(moduleObjCache, directiveFactory, mainModuleName) {
		this._moduleObjCache = moduleObjCache;
		this._directiveFactory = directiveFactory;
		this._mainModuleName = mainModuleName;
	};
	return __mixinProto(Programme, {
		/// Run programme main module with arguments passed as mainModuleScope parameter
		run: function(mainModuleScope, extraGlobals) {
			return this.runSaveState(mainModuleScope, extraGlobals).asyncResult;
		},

		runSaveState: function(mainModuleScope, extraGlobals) {
			var
				fResult = new AsyncResult(),
				interp = new Interpreter(
					this._moduleObjCache,
					this._directiveFactory,
					this._mainModuleName,
					mainModuleScope
				);
			interp.addExtraGlobals(extraGlobals);
			return {
				interp: interp,
				asyncResult: interp.execLoop()
			};
		}
	});
});