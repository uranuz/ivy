module ivy.compiler.symbol_collector;

import ivy.ast.iface.visitor: AbstractNodeVisitor;

class CompilerSymbolsCollector: AbstractNodeVisitor
{
	import ivy.ast.iface;
	import ivy.compiler.common: takeFrontAs;
	import ivy.compiler.module_repository;
	import ivy.compiler.symbol_table;
	import ivy.compiler.errors: IvyCompilerException;
	import ivy.compiler.node_visit_mixin: NodeVisitMixin;
	import ivy.loger: LogInfo, LogerProxyImpl, LogInfoType;
	import ivy.compiler.directive.factory: DirectiveCompilerFactory;
	import ivy.types.symbol.iface: IIvySymbol;
	
	
	alias LogerMethod = void delegate(LogInfo);
private:
	CompilerModuleRepository _moduleRepo;
	DirectiveCompilerFactory _compilerFactory;
	SymbolTableFrame[string] _moduleSymbols;
	SymbolTableFrame _globalSymbolTable;

public SymbolTableFrame[] _frameStack;
	LogerMethod _logerMethod;

public:
	this(
		CompilerModuleRepository moduleRepo,
		DirectiveCompilerFactory compilerFactory,
		IIvySymbol[] globalSymbols,
		LogerMethod logerMethod = null
	) {
		import std.exception: enforce;

		_moduleRepo = moduleRepo;
		_compilerFactory = compilerFactory;
		_logerMethod = logerMethod;

		enforce(_moduleRepo !is null, `Expected compiler module repository`);
		enforce(_compilerFactory !is null, `Expected directive compiler factory`);

		_globalSymbolTable = new SymbolTableFrame(null, _logerMethod);
		_addGlobalSymbols(globalSymbols);
	}

	private void _addGlobalSymbols(IIvySymbol[] globalSymbols)
	{
		foreach(symb; globalSymbols) {
			_globalSymbolTable.add(symb);
		}
	}

	version(IvyCompilerDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy {
		mixin LogerProxyImpl!(IvyCompilerException, isDebugMode);
		CompilerSymbolsCollector collector;

		string sendLogInfo(LogInfoType logInfoType, string msg)
		{
			import ivy.loger: getShortFuncName;

			if( collector._logerMethod !is null )
			{
				collector._logerMethod(LogInfo(
					msg,
					logInfoType,
					getShortFuncName(func),
					file,
					line,
					collector._currentLocation.fileName,
					collector._currentLocation.lineIndex
				));
			}
			return msg;
		}
	}

	LogerProxy log(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	mixin NodeVisitMixin!();

	SymbolTableFrame getModuleSymbols(string moduleName)
	{
		import std.range: popBack, empty, back;

		SymbolTableFrame modFrame = _moduleSymbols.get(moduleName, null);
		if( modFrame !is null ) {
			return modFrame;
		}

		// Try to open, parse and load symbols info from another module
		IvyNode moduleTree = _moduleRepo.getModuleTree(moduleName);

		modFrame = new SymbolTableFrame(null, _logerMethod);
		_moduleSymbols[moduleName] = modFrame;

		{
			_frameStack ~= modFrame;
			scope(exit) {
				log.internalAssert(!_frameStack.empty, `Compiler directive collector frame stack is empty!`);
				_frameStack.popBack();
			}

			// Go to find directive definitions in this imported module
			moduleTree.accept(this);
		}

		return modFrame;
	}

	void enterModuleScope(string moduleName)
	{
		log.write(`Enter method`);
		_frameStack ~= getModuleSymbols(moduleName);
		log.write(`Exit method`);
	}

	void enterScope(size_t sourceIndex)
	{
		import std.range: empty, back;
		log.internalAssert(!_frameStack.empty, `Cannot enter nested symbol table, because symbol table stack is empty`);

		_frameStack ~= _frameStack.back.getChildFrame(sourceIndex);
	}

	void exitScope()
	{
		import std.range: empty, popBack;
		log.internalAssert(!_frameStack.empty, "Cannot exit frame, because compiler symbol table stack is empty!");

		_frameStack.popBack();
	}

	IIvySymbol symbolLookup(string name)
	{
		import std.range: empty, back;
		log.internalAssert(!_frameStack.empty, `Cannot look for symbol, because symbol table stack is empty`);

		IIvySymbol symb = _frameStack.back.lookup(name);
		debug {
			log.write(`symbolLookup, _frameStack symbols:`);
			foreach( lvl, table; _frameStack[] ) {
				log.write(`	symbols lvl`, lvl, `: `, table._symbols);
				if( table._moduleFrame ) {
					log.write(`	module symbols lvl`, lvl, `: `, table._moduleFrame._symbols);
				} else {
					log.write(`	module frame lvl`, lvl, ` is null`);
				}
			}
		}

		if( symb ) {
			return symb;
		}

		symb = _globalSymbolTable.lookup(name);

		if( !symb ) {
			log.error( `Cannot find symbol "` ~ name ~ `"` );
		}

		return symb;
	}

	void clearCache()
	{
		_moduleSymbols.clear();
		_frameStack.length = 0;
	}

	// Most of these stuff is just empty implementation except directive statements parsing
	void _visit(IvyNode node) { assert(0); }

	//Expressions
	void _visit(IExpression node) {  }
	void _visit(ILiteralExpression node) {  }
	void _visit(INameExpression node) {  }
	void _visit(IOperatorExpression node) {  }
	void _visit(IUnaryExpression node) {  }
	void _visit(IBinaryExpression node) {  }
	void _visit(IAssocArrayPair node) {  }

	//Statements
	void _visit(IStatement node) {  }
	void _visit(IKeyValueAttribute node) {  }
	void _visit(IDirectiveStatement node)
	{
		if( auto comp = this._compilerFactory.get(node.name) ) {
			comp.collect(node, this);
			return;
		}
		foreach( childNode; node[] )
		{
			log.write(`Symbols collector. Analyse child of kind: `, childNode.kind, ` for IDirectiveStatement node: `, node.name);
			log.internalAssert(childNode, `Child node is null`);
			childNode.accept(this);
		}
		// TODO: Check if needed to analyse other directive attributes scopes
	}
	void _visit(IDataFragmentStatement node) {  }
	void _visit(ICompoundStatement node)
	{
		foreach( childNode; node[] )
		{
			log.write(`Symbols collector. Analyse child of kind: `, childNode.kind, ` for ICompoundStatement of kind: `, node.kind);
			childNode.accept(this);
		}

	}

	void _visit(ICodeBlockStatement node) { _visit(cast(ICompoundStatement) node); }
	void _visit(IMixedBlockStatement node) { _visit(cast(ICompoundStatement) node); }


}