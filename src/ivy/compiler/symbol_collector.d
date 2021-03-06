module ivy.compiler.symbol_collector;

import ivy.ast.iface.visitor: AbstractNodeVisitor;

version(IvyTotalDebug) version = IvyCompilerDebug;

class CompilerSymbolsCollector: AbstractNodeVisitor
{
	import trifle.utils: ensure;

	import ivy.ast.iface;
	import ivy.compiler.common: takeFrontAs;
	import ivy.compiler.module_repository: CompilerModuleRepository;
	import ivy.compiler.symbol_table: SymbolTableFrame, SymbolWithFrame;
	import ivy.compiler.errors: IvyCompilerException;
	import ivy.compiler.node_visit_mixin: NodeVisitMixin;
	import ivy.log: LogInfoType, LogInfo, IvyLogProxy, LogerMethod;
	import ivy.compiler.directive.factory: DirectiveCompilerFactory;
	import ivy.types.symbol.iface: IIvySymbol;
	import ivy.types.symbol.module_: ModuleSymbol;
	
	import trifle.location: Location;

	alias assure = ensure!IvyCompilerException;
protected:
	CompilerModuleRepository _moduleRepo;
	DirectiveCompilerFactory _compilerFactory;
	SymbolTableFrame _moduleSymbols;
	SymbolTableFrame _globalSymbolTable;

public SymbolTableFrame[] _frameStack;
public IvyLogProxy log;

public:
	this(
		CompilerModuleRepository moduleRepo,
		DirectiveCompilerFactory compilerFactory,
		IIvySymbol[] globalSymbols,
		LogerMethod logerMethod = null
	) {
		_moduleRepo = moduleRepo;
		_compilerFactory = compilerFactory;
		log = IvyLogProxy(logerMethod? (ref LogInfo logInfo) {
			logInfo.location = this._currentLocation;
			logerMethod(logInfo);
		}: null);

		assure(_moduleRepo, "Expected compiler module repository");
		assure(_compilerFactory, "Expected directive compiler factory");

		_globalSymbolTable = new SymbolTableFrame(null);
		_addGlobalSymbols(globalSymbols);

		_moduleSymbols = new SymbolTableFrame(null);
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


	mixin NodeVisitMixin;

	SymbolWithFrame getModuleSymbols(string moduleName)
	{
		import std.range: popBack, empty, back;

		SymbolWithFrame swf = _moduleSymbols.getChildFrame(moduleName);
		if( swf.symbol !is null && swf.frame !is null ) {
			return swf;
		}

		// Try to open, parse and load symbols info from another module
		IvyNode moduleTree = _moduleRepo.getModuleTree(moduleName);

		// Create module symbol
		swf.symbol = new ModuleSymbol(moduleName, moduleTree.location);

		// Add module symbol with frame in common table of module symbols
		swf.frame = _moduleSymbols.newChildFrame(swf.symbol, null);

		{
			// Add module frame into frame stack...
			_frameStack ~= swf.frame;
			// ... and set up exit from frame upon analysis finished
			scope(exit) {
				this.exitScope();
			}

			// Go to find directive definitions in this imported module
			moduleTree.accept(this);
		}

		return swf;
	}

	ModuleSymbol enterModuleScope(string moduleName)
	{
		SymbolWithFrame swf = getModuleSymbols(moduleName);

		ModuleSymbol res = cast(ModuleSymbol) swf.symbol;
		assure(res, "Expected module symbol");
		_frameStack ~= swf.frame;

		log.info("Enter module scope: ", moduleName);
		_printState();
		return res;
	}

	void enterScope(Location loc)
	{
		import std.range: empty, back;
		assure(!_frameStack.empty, "Cannot enter nested symbol table, because symbol table stack is empty");

		_frameStack ~= _frameStack.back.getChildFrame(loc);
		log.info("Enter scope for: ", loc.toString());
		_printState();
	}

	void exitScope()
	{
		import std.range: empty, popBack, back;
		assure(!_frameStack.empty, "Cannot exit frame, because compiler symbol table stack is empty!");

		log.info("Exit scope:");
		_printState();
		_frameStack.popBack();
	}

	private void _printState()
	{
		debug {
			log.info("Symbol tables:");
			foreach( lvl, table; _frameStack[] ) {
				log.info("	symbols lvl", lvl, ": ", table.toPrettyStr());
			}
			log.info("_moduleSymbols: ", _moduleSymbols.toPrettyStr());
		}
	}

	IIvySymbol symbolLookup(string name)
	{
		import std.range: empty, back;
		assure(!_frameStack.empty, "Cannot look for symbol, because symbol table stack is empty");
		log.info("Symbol lookup: ", name, ", in:");
		_printState();

		IIvySymbol symb = _frameStack.back.lookup(name);


		if( symb ) {
			return symb;
		}

		symb = _globalSymbolTable.lookup(name);

		assure(symb, "Cannot find symbol: ");

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
			log.info("Symbols collector. Analyse child of kind: ", childNode.kind, " for IDirectiveStatement node: ", node.name);
			assure(childNode, "Child node is null");
			childNode.accept(this);
		}
		// TODO: Check if needed to analyse other directive attributes scopes
	}
	void _visit(IDataFragmentStatement node) {  }
	void _visit(ICompoundStatement node)
	{
		foreach( childNode; node[] )
		{
			log.info(`Symbols collector. Analyse child of kind: `, childNode.kind, ` for ICompoundStatement of kind: `, node.kind);
			childNode.accept(this);
		}

	}

	void _visit(ICodeBlockStatement node) { _visit(cast(ICompoundStatement) node); }
	void _visit(IMixedBlockStatement node) { _visit(cast(ICompoundStatement) node); }


}