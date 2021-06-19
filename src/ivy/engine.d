module ivy.engine;

struct SaveStateResult
{
	import ivy.types.data.async_result: AsyncResult;
	import ivy.interpreter.interpreter: Interpreter;

	Interpreter interp;
	AsyncResult asyncResult;
}

/// Dump-simple in-memory cache for compiled programmes
class IvyEngine
{
	import ivy.types.data: IvyData;
	import ivy.types.data.async_result: AsyncResult;
	import ivy.interpreter._global_callable_init; // Used to ensure that this module is compiled. Don't delete
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.compiler.directive.standard_factory: makeStandardDirCompilerFactory;
	import ivy.engine_config: IvyConfig;
	import ivy.compiler.module_repository: CompilerModuleRepository;
	import ivy.compiler.symbol_collector: CompilerSymbolsCollector;
	import ivy.compiler.compiler: ByteCodeCompiler;
	import ivy.interpreter.module_objects_cache: ModuleObjectsCache;
	import ivy.log.info: LogInfo;
	import ivy.log.consts: LogInfoType;

private:
	IvyConfig _config;
	CompilerModuleRepository _moduleRepo;
	CompilerSymbolsCollector _symbolsCollector;
	ByteCodeCompiler _compiler;
	ModuleObjectsCache _moduleObjCache;

	import core.sync.mutex: Mutex;
	Mutex _mutex;

public:
	this(IvyConfig config)
	{
		this._mutex = new Mutex();
		this._config = config;
		this._initObjects();
	}

	/// Load module by name into engine
	AsyncResult loadModule(string moduleName)
	{
		AsyncResult fResult = new AsyncResult();
		synchronized(_mutex)
		{
			if( this._config.clearCache ) {
				this.clearCache();
			}

			if( !this._moduleObjCache.get(moduleName) )
				this._compiler.run(moduleName); // Run compilation itself
			fResult.resolve(IvyData(this._moduleObjCache.get(moduleName)));
		}
		return fResult;
	}

	Interpreter makeInterp(IvyData[string] extraGlobals = null)
	{
		auto interp = new Interpreter(
			this._moduleObjCache,
			this._config.directiveFactory,
			this._config.interpreterLoger);
		interp.addExtraGlobals(extraGlobals);
		return interp;
	}

	SaveStateResult runModule(string moduleName, IvyData[string] extraGlobals = null) {
		return this.runModule(moduleName, this.makeInterp(extraGlobals));
	}

	SaveStateResult runModule(string moduleName, Interpreter interp)
	{
		import std.exception: enforce;
		enforce(interp, "Interpreter is null");

		auto asyncResult = new AsyncResult();
		auto res = SaveStateResult(interp, asyncResult);

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
		SaveStateResult moduleExecRes = this.runModule(moduleName, extraGlobals);
		
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

	void clearCache()
	{
		_moduleRepo.clearCache();
		_symbolsCollector.clearCache();
		_moduleObjCache.clearCache();
		_compiler.clearCache();
	}

private:
	void _initObjects()
	{
		import ivy.types.symbol.iface: IIvySymbol;
		import ivy.interpreter.directive.standard_factory: ivyDirFactory;

		if( _config.compilerFactory is null ) {
			_config.compilerFactory = makeStandardDirCompilerFactory();
		}
		if( _config.directiveFactory is null ) {
			_config.directiveFactory = ivyDirFactory;
		}
		
		_moduleRepo = new CompilerModuleRepository(
			_config.importPaths,
			_config.fileExtension,
			_config.parserLoger
		);
		_symbolsCollector = new CompilerSymbolsCollector(
			_moduleRepo,
			_config.compilerFactory,
			cast(IIvySymbol[]) _config.directiveFactory.symbols,
			_config.compilerLoger
		);
		_moduleObjCache = new ModuleObjectsCache();
		_compiler = new ByteCodeCompiler(
			_moduleRepo,
			_symbolsCollector,
			_config.compilerFactory,
			_moduleObjCache,
			_config.compilerLoger
		);
	}

	
}