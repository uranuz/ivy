module ivy.engine;

/// Dump-simple in-memory cache for compiled programmes
class IvyEngine
{
	import ivy.compiler.directive.standard_factory: makeStandardDirCompilerFactory;
	import ivy.interpreter.directive.standard_factory: makeStandardInterpreterDirFactory;
	import ivy.engine_config: IvyConfig;
	import ivy.compiler.module_repository: CompilerModuleRepository;
	import ivy.compiler.symbol_collector: CompilerSymbolsCollector;
	import ivy.compiler.compiler: ByteCodeCompiler;
	import ivy.interpreter.module_objects_cache: ModuleObjectsCache;
	import ivy.programme: ExecutableProgramme;
	import ivy.loger: LogInfo, LogInfoType;

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
		import std.exception: enforce;

		enforce(!!config.importPaths.length, `List of compiler import paths must not be empty!`);

		_mutex = new Mutex();
		_config = config;
		_initObjects();
	}

	/// Generate programme object or get existing from cache (if cache enabled)
	ExecutableProgramme getByModuleName(string moduleName)
	{
		synchronized(_mutex)
		{
			if( _config.clearCache ) {
				clearCache();
			}

			if( !_moduleObjCache.get(moduleName) )
			{
				_compiler.run(moduleName); // Run compilation itself

				if( _config.compilerLoger ) {
					debug _config.compilerLoger(LogInfo(
						"compileModule:\r\n" ~ _moduleObjCache.toPrettyStr(),
						LogInfoType.info,
						__FUNCTION__, __FILE__, __LINE__
					));
				}
			}
		}

		return new ExecutableProgramme(
			this._moduleObjCache,
			this._config.directiveFactory,
			moduleName,
			_config.interpreterLoger
		);
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
		if( _config.compilerFactory is null ) {
			_config.compilerFactory = makeStandardDirCompilerFactory();
		}
		if( _config.directiveFactory is null ) {
			_config.directiveFactory = makeStandardInterpreterDirFactory();
		}
		
		_moduleRepo = new CompilerModuleRepository(_config.importPaths, _config.fileExtension, _config.parserLoger);
		_symbolsCollector = new CompilerSymbolsCollector(_moduleRepo, _config.compilerFactory, _config.compilerLoger);
		_moduleObjCache = new ModuleObjectsCache();
		_compiler = new ByteCodeCompiler(
			_moduleRepo,
			_symbolsCollector,
			_config.compilerFactory,
			_config.directiveFactory.symbols,
			_moduleObjCache,
			_config.compilerLoger
		);
	}

	
}