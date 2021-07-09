module ivy.engine.engine;

/// Dump-simple in-memory cache for compiled programmes
class IvyEngine
{
	import ivy.engine.config: IvyEngineConfig;
	import ivy.engine.context_async_result: ContextAsyncResult;
	import ivy.engine.module_object_loader: ModuleObjectLoader;
	import ivy.engine.module_object_cache: ModuleObjectCache;

	import ivy.types.data: IvyData;
	import ivy.types.data.async_result: AsyncResult;

	import ivy.interpreter._global_callable_init; // Used to ensure that this module is compiled. Don't delete
	import ivy.interpreter.interpreter: Interpreter;

	import ivy.log.consts: LogInfoType;
	import ivy.log.info: LogInfo;

private:
	IvyEngineConfig _config;

	ModuleObjectLoader _loader;

public:
	this(IvyEngineConfig config)
	{
		this._config = config;

		import ivy.interpreter.directive.standard_factory: ivyDirFactory;

		if( this._config.directiveFactory is null ) {
			this._config.directiveFactory = ivyDirFactory;
		}

		this._loader = new ModuleObjectLoader(this._config);
	}

	/// Load module by name into engine
	AsyncResult loadModule(string moduleName)
	{
		if( this._config.clearCache ) {
			this.clearCache();
		}

		return this._loader.load(moduleName);
	}

	ContextAsyncResult runModule(string moduleName, IvyData[string] extraGlobals = null) {
		return this.runModule(moduleName, this.makeInterp(extraGlobals));
	}

	Interpreter makeInterp(IvyData[string] extraGlobals = null)
	{
		auto interp = new Interpreter(
			this._loader.cache,
			this._config.directiveFactory,
			this._config.interpreterLoger);
		interp.addExtraGlobals(extraGlobals);
		return interp;
	}

	ContextAsyncResult runModule(string moduleName, Interpreter interp)
	{
		auto asyncResult = new AsyncResult();
		auto res = ContextAsyncResult(interp, asyncResult);

		this.loadModule(moduleName).then((it) {
			interp.importModule(moduleName).then(asyncResult);
		}, &asyncResult.reject);
		return res;
	}

	AsyncResult runMethod(
		string moduleName,
		string methodName,
		IvyData[string] methodParams = null,
		IvyData[string] extraGlobals = null
	) {
		AsyncResult fResult = new AsyncResult();
		ContextAsyncResult moduleExecRes = this.runModule(moduleName, extraGlobals);
		
		moduleExecRes.asyncResult.then(
			(IvyData modRes) {
				// Module executed successfuly, then call method
				auto interp = moduleExecRes.interp;
				auto methodCallable = interp.asCallable(modRes.execFrame.getValue(methodName));
				interp.execCallable(methodCallable, methodParams).then(fResult);
			},
			&fResult.reject);
		return fResult;
	}

	import std.json: JSONValue;
	JSONValue serializeModule(string moduleName)
	{
		import std.algorithm: map;
		import std.array: array;

		// At first assure that module is loaded...
		this.loadModule(moduleName);

		return JSONValue([
			"mainModuleName": JSONValue(moduleName),
			"moduleObjects": JSONValue(map!((modObj) => modObj.toStdJSON())(this._moduleObjCache.moduleObjects.byValue).array)
		]);
	}

	private ModuleObjectCache _moduleObjCache() @property {
		return this._loader.cache;
	}

	void clearCache() {
		this._loader.clearCache();
	}
}