define('ivy/Programme', [
	'ivy/Interpreter',
	'ivy/AsyncResult',
	'ivy/Consts'
], function(Interpreter, AsyncResult, Consts) {
var AsyncResultState = Consts.AsyncResultState;
return FirClass(
	function Programme(moduleObjCache, directiveFactory, mainModuleName) {
		this._moduleObjCache = moduleObjCache;
		this._directiveFactory = directiveFactory;
		this._mainModuleName = mainModuleName;
	}, {
		/// Run programme main module with arguments passed as mainModuleScope parameter
		run: function(mainModuleScope, extraGlobals) {
			return this.runSaveState(mainModuleScope, extraGlobals).asyncResult;
		},

		runSync: function() {
			var ivyRes = this.runSaveStateSync(mainModuleScope, extraGlobals)._stack.back();
			if( ivyRes.type == IvyDataType.AsyncResult ) {
				ivyRes.asyncResult.then(function(methodRes) {
					ivyRes = methodRes;
				}, function(error) {
					throw error;
				});
			}
			return ivyRes;
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
		},

		runSaveStateSync: function(mainModuleScope, extraGlobals) {
			var moduleExecRes = this.runSaveState(mainModuleScope, extraGlobals);
			if( moduleExecRes.state !== AsyncResultState.resolved ) {
				'Expected module execution async result resolved state'
			}
			return moduleExecRes.interp;
		},

		runMethod: function(methodName, methodParams, extraGlobals, mainModuleScope) {
			var
				fResult = new AsyncResult(),
				moduleExecRes = this.runSaveState(mainModuleScope, extraGlobals);
			
			moduleExecRes.asyncResult.then(
				function(modRes) {
					// Module executed successfuly, then call method
					moduleExecRes.interp.runModuleDirective(methodName, methodParams).then(
						function(methodRes) {
							fResult.resolve(methodRes); // Successfully called method
						},
						function(error) {
							fResult.reject(error); // Error in calling method
						});
				},
				function(error) {
					fResult.reject(error); // Error in running module
				});
			return fResult;
		},

		runMethodSync: function(methodName, methodParams, extraGlobals, mainModuleScope) {
			var
				ivyRes,
				asyncRes = this.runSaveStateSync(mainModuleScope, extraGlobals)
					.runModuleDirective(methodName, methodParams);
			if( asyncRes.state !== AsyncResultState.resolved ) {
				throw new Error('Expected method execution async result resolved state');
			}
			asyncRes.then(function(methodRes) {
				ivyRes = methodRes;
			}, function(error) {
				throw error;
			});
			return ivyRes;
		}
	});
});