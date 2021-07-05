module ivy.engine.module_object_loader;

class ModuleObjectLoader
{
	import ivy.compiler.compiler: ByteCodeCompiler;
	import ivy.compiler.directive.standard_factory: makeStandardDirCompilerFactory;
	import ivy.compiler.module_repository: CompilerModuleRepository;
	import ivy.compiler.symbol_collector: CompilerSymbolsCollector;

	import ivy.engine.config: IvyConfig;

	import ivy.engine.module_object_cache: ModuleObjectCache;

	import ivy.types.data.async_result: AsyncResult;
	import ivy.types.data.data: IvyData;
	import ivy.types.symbol.iface: IIvySymbol;

	CompilerModuleRepository _moduleRepo;
	CompilerSymbolsCollector _symbolsCollector;
	ByteCodeCompiler _compiler;
	ModuleObjectCache _cache;

	this(IvyConfig config)
	{
		if( config.compilerFactory is null ) {
			config.compilerFactory = makeStandardDirCompilerFactory();
		}

		this._moduleRepo = new CompilerModuleRepository(
			config.importPaths,
			config.fileExtension,
			config.parserLoger
		);
		this._symbolsCollector = new CompilerSymbolsCollector(
			this._moduleRepo,
			config.compilerFactory,
			cast(IIvySymbol[]) config.directiveFactory.symbols,
			config.compilerLoger
		);

		this._cache = new ModuleObjectCache();
		this._compiler = new ByteCodeCompiler(
			this._moduleRepo,
			this._symbolsCollector,
			config.compilerFactory,
			this._cache,
			config.compilerLoger
		);
	}

	AsyncResult load(string moduleName)
	{
		AsyncResult fResult = new AsyncResult();

		if( !this.cache.get(moduleName) )
		{
			try {
				// Run compilation itself
				this._compiler.run(moduleName); 
			} catch(Exception ex) {
				fResult.reject(ex);
			}
		}

		fResult.resolve(IvyData(this.cache.get(moduleName)));
		return fResult;
	}

	ModuleObjectCache cache() @property {
		return this._cache;
	}

	void clearCache()
	{
		this._compiler.clearCache();
		this._symbolsCollector.clearCache();
		this._moduleRepo.clearCache();
		this._cache.clearCache();
	}
}