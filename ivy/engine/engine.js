define('ivy/engine', [
	'ivy/engine/context_async_result',
	'ivy/engine/module_object_loader',
	'ivy/interpreter/directive/standard_factory',
	'ivy/interpreter/interpreter',
	'ivy/types/data/async_result',
], function(
	ContextAsyncResult,
	ModuleObjectLoader,
	ivyDirFactory,
	Interpreter,
	AsyncResult
) {
return FirClass(
	function IvyEngine(config) {
		this._config = config;

		if( this._config.directiveFactory == null ) {
			this._config.directiveFactory = ivyDirFactory;
		}

		this._loader = new ModuleObjectLoader(this._config);
	}, {
		/// Load module by name into engine
		loadModule: function(moduleName) {
			if (this._config.clearCache) {
				this.clearCache();
			}
			return this._loader.load(moduleName);
		},

		runModule: function(moduleName, globalsOrInterp) {
			if (globalsOrInterp instanceof Interpreter) {
				return this._runModuleImpl(globalsOrInterp);
			}
			return this._runModuleImpl(moduleName, this.makeInterp(globalsOrInterp));
		},

		makeInterp: function(extraGlobals) {
			var interp = new Interpreter(
				this._loader.cache,
				this._config.directiveFactory);
			interp.addExtraGlobals(extraGlobals);
			return interp;
		},

		_runModuleImpl: function(moduleName, interp) {
			var
				asyncResult = new AsyncResult(),
				res = ContextAsyncResult(interp, asyncResult);
	
			this.loadModule(moduleName).then(function(it) {
				interp.importModule(moduleName).then(asyncResult);
			}, asyncResult.reject);
			return res;
		},
	
		runMethod: function(
			moduleName,
			methodName,
			methodParams = null,
			extraGlobals = null
		) {
			var
				fResult = new AsyncResult(),
				moduleExecRes = this.runModule(moduleName, extraGlobals);
			
			moduleExecRes.asyncResult.then(
				function(modRes) {
					// Module executed successfuly, then call method
					var
						interp = moduleExecRes.interp,
						methodCallable = interp.asCallable(modRes.execFrame.getValue(methodName));
					interp.execCallable(methodCallable, methodParams).then(fResult);
				},
				fResult.reject);
			return fResult;
		},

		clearCache: function() {
			this._loader.clearCache();
		}
	});
});