import {ContextAsyncResult} from 'ivy/engine/context_async_result';
import {ModuleObjectLoader} from 'ivy/engine/module_object_loader';
import {ivyDirFactory} from 'ivy/interpreter/directive/standard_factory';
import {Interpreter} from 'ivy/interpreter/interpreter';
import {AsyncResult} from 'ivy/types/data/async_result';
import {IvyEngineConfig} from 'ivy/engine/config';
import {IvyDataDict} from 'ivy/types/data/data';
import {ModuleObjectCache} from 'ivy/engine/module_object_cache';

export class IvyEngine {
	private _config: IvyEngineConfig;
	private _loader: ModuleObjectLoader;

	constructor(config: IvyEngineConfig) {
		this._config = config;
	
		if( this._config.directiveFactory == null ) {
			this._config.directiveFactory = ivyDirFactory;
		}
	
		this._loader = new ModuleObjectLoader(this._config);
	}

	/// Load module by name into engine
	loadModule(moduleName: string): AsyncResult {
		if (this._config.clearCache) {
			this.clearCache();
		}
		return this._loader.load(moduleName);
	}

	runModule(moduleName: string, globalsOrInterp: IvyDataDict | Interpreter ): ContextAsyncResult {
		if (globalsOrInterp instanceof Interpreter) {
			return this._runModuleImpl(moduleName, globalsOrInterp);
		}
		return this._runModuleImpl(moduleName, this.makeInterp(globalsOrInterp));
	}

	makeInterp(extraGlobals: IvyDataDict): Interpreter {
		var interp = new Interpreter(
			this._loader.cache,
			this._config.directiveFactory);
		interp.addExtraGlobals(extraGlobals);
		return interp;
	}

	_runModuleImpl(moduleName: string, interp?: any) {
		var
			asyncResult = new AsyncResult(),
			res = new ContextAsyncResult(interp, asyncResult);

		this.loadModule(moduleName).then(function(it) {
			interp.importModule(moduleName).then(asyncResult);
		}, asyncResult.reject);
		return res;
	}

	runMethod(
		moduleName: string,
		methodName: string,
		methodParams?: IvyDataDict,
		extraGlobals?: IvyDataDict
	): AsyncResult {
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
	}

	get moduleObjCache(): ModuleObjectCache {
		return this._loader.cache;
	}

	clearCache() {
		this._loader.clearCache();
	}
}