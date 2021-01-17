define('ivy/programme', [
	'ivy/interpreter/interpreter',
	'ivy/types/data/async_result',
	'ivy/types/data/consts'
], function(
	Interpreter,
	AsyncResult,
	DataConsts
) {
var AsyncResultState = DataConsts.AsyncResultState;
return FirClass(
	function ExecutableProgramme(mainModuleName, moduleObjCache, directiveFactory) {
		this._mainModuleName = mainModuleName;
		this._moduleObjCache = moduleObjCache;
		this._directiveFactory = directiveFactory;
	}, {
		/// Run programme main module with arguments passed as mainModuleScope parameter
		run: function(extraGlobals) {
			return this.runSaveState(extraGlobals).asyncResult;
		},

		runSync: function() {
			var ivyRes = this.runSaveStateSync(extraGlobals)._stack.back;
			if( ivyRes.type == IvyDataType.AsyncResult ) {
				ivyRes.asyncResult.then(function(methodRes) {
					ivyRes = methodRes;
				}, function(error) {
					throw error;
				});
			}
			return ivyRes;
		},

		runSaveState: function(extraGlobals) {
			var interp = new Interpreter(
				this._moduleObjCache,
				this._directiveFactory
			);
			interp.addExtraGlobals(extraGlobals);
			return {
				interp: interp,
				asyncResult: interp.importModule(this._mainModuleName)
			};
		},

		runSaveStateSync: function(extraGlobals) {
			var moduleExecRes = this.runSaveState(extraGlobals);
			if( moduleExecRes.state !== AsyncResultState.resolved ) {
				'Expected module execution async result resolved state'
			}
			return moduleExecRes.interp;
		},

		runMethod: function(methodName, methodParams, extraGlobals) {
			var
				fResult = new AsyncResult(),
				moduleExecRes = this.runSaveState(extraGlobals);
			
			moduleExecRes.asyncResult.then(
				function(modRes) {
					// Module executed successfuly, then call method
					moduleExecRes.interp.execModuleDirective(methodName, methodParams).then(
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

		runMethodSync: function(methodName, methodParams, extraGlobals) {
			var
				ivyRes,
				asyncRes = this.runSaveStateSync(extraGlobals)
					.execModuleDirective(methodName, methodParams);
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