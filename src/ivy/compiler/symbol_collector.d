module ivy.compiler.symbol_collector;


import ivy.directive_stuff;
import ivy.ast.iface;
import ivy.ast.iface.visitor: AbstractNodeVisitor;
import ivy.compiler.common: takeFrontAs;
import ivy.compiler.module_repository;
import ivy.compiler.symbol_table;
import ivy.compiler.def_analyze_mixin: DefAnalyzeMixin;
import ivy.compiler.errors: IvyCompilerException;
import ivy.compiler.node_visit_mixin: NodeVisitMixin;
import ivy.loger: LogInfo, LogerProxyImpl, LogInfoType;


class CompilerSymbolsCollector: AbstractNodeVisitor
{
	mixin DefAnalyzeMixin;
	alias LogerMethod = void delegate(LogInfo);
private:
	CompilerModuleRepository _moduleRepo;
	SymbolTableFrame[string] _moduleSymbols;
	SymbolTableFrame[] _frameStack;
	LogerMethod _logerMethod;

public:
	this(CompilerModuleRepository moduleRepo, LogerMethod logerMethod = null)
	{
		import std.range: back;
		_moduleRepo = moduleRepo;
		_logerMethod = logerMethod;
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
		import std.range: popBack, empty, back;
		import std.algorithm: canFind;

		switch( node.name )
		{
			case "def":
			{
				IAttributeRange defAttrsRange = node[];

				INameExpression dirNameExpr = defAttrsRange.takeFrontAs!INameExpression("Expected directive name");
				ICodeBlockStatement attrsDefBlockStmt = defAttrsRange.takeFrontAs!ICodeBlockStatement("Expected code block as directive attributes definition");
				IDirectiveStatementRange attrsDefStmtRange = attrsDefBlockStmt[];

				ICompoundStatement bodyStmt;

				DirAttrsBlock[] attrBlocks;

				while( !attrsDefStmtRange.empty )
				{
					IDirectiveStatement attrsDefStmt = attrsDefStmtRange.front; // Current attributes definition statement
					IAttributeRange attrsDefStmtAttrRange = attrsDefStmt[]; // Range on attributes of attributes definition statement

					switch( attrsDefStmt.name )
					{
						case "def.kv":
						{
							DirValueAttr[string] namedAttrs;
							while( !attrsDefStmtAttrRange.empty )
							{
								auto res = analyzeValueAttr(attrsDefStmtAttrRange);
								log.internalAssert(res.isSet, `Check 1`);

								if( res.attr.name in namedAttrs )
									log.error(`Named attribute "`, res.attr.name, `" already defined in directive definition`);

								namedAttrs[res.attr.name] = res.attr;
							}

							attrBlocks ~= DirAttrsBlock(DirAttrKind.NamedAttr, namedAttrs);
							break;
						}
						case "def.pos":
						{
							DirValueAttr[] exprAttrs;
							while( !attrsDefStmtAttrRange.empty )
							{
								auto res = analyzeValueAttr(attrsDefStmtAttrRange);
								log.internalAssert(res.isSet, `Check 2`);

								if( exprAttrs.canFind!( (it, needle) => it.name == needle )(res.attr.name) )
									log.error(`Named attribute "`, res.attr.name, `" already defined in directive definition`);

								exprAttrs ~= res.attr;
							}

							attrBlocks ~= DirAttrsBlock(DirAttrKind.ExprAttr, exprAttrs);
							break;
						}
						case "def.names", "def.kwd": log.internalAssert(false, `Not implemented yet!`);
						case "def.body":
						{
							if( bodyStmt )
								log.error(`Multiple body statements are not allowed!`);

							auto res = analyzeDirBody(attrsDefStmtAttrRange);
							bodyStmt = res.statement;

							attrBlocks ~= DirAttrsBlock(DirAttrKind.BodyAttr, res.attr);

							if( _frameStack.empty )
								log.error(`Cannot store symbol, because fu** you.. Oops.. because symbol table frame stack is empty`);
							if( !_frameStack.back )
								log.error(`Cannot store symbol, because symbol table frame is null`);
							// Add directive definition into existing frame
							_frameStack.back.add(new DirectiveDefinitionSymbol(dirNameExpr.name, attrBlocks));

							if( bodyStmt && !res.attr.isNoscope )
							{
								// Create new frame for body if not forbidden
								_frameStack ~= _frameStack.back.newChildFrame(bodyStmt.location.index);
							}

							scope(exit)
							{
								if( bodyStmt && !res.attr.isNoscope ) {
									_frameStack.popBack();
								}
							}

							if( bodyStmt )
							{
								// Analyse nested tree
								bodyStmt.accept(this);
							}
							break;
						}
						default:
							break;
					}

					attrsDefStmtRange.popFront();
				}

				if( !defAttrsRange.empty )
					log.error(`Expected end of directive definition statement. Maybe ; is missing`);
				break;
			}
			case "import":
			{
				IAttributeRange attrRange = node[];
				if( attrRange.empty )
					log.error(`Expected module name in import statement, but got end of directive`);

				INameExpression moduleNameExpr = attrRange.takeFrontAs!INameExpression("Expected module name in import directive");

				if( !attrRange.empty )
					log.error(`Expected end of import directive, maybe ; is missing`);

				// Add imported module symbol table as local symbol
				_frameStack.back.add(new ModuleSymbol(
					moduleNameExpr.name,
					getModuleSymbols(moduleNameExpr.name)
				));
				break;
			}
			case "from":
			{
				IAttributeRange attrRange = node[];
				if( attrRange.empty )
					log.error(`Expected module name in import statement, but got end of directive`);

				INameExpression moduleNameExpr = attrRange.takeFrontAs!INameExpression("Expected module name in import directive");
				INameExpression importKwdExpr = attrRange.takeFrontAs!INameExpression("Expected 'import' keyword!");
				if( importKwdExpr.name != "import" )
					log.error("Expected 'import' keyword!");

				string[] symbolNames;
				while( !attrRange.empty )
				{
					INameExpression symbolNameExpr = attrRange.takeFrontAs!INameExpression("Expected imported symbol name");
					symbolNames ~= symbolNameExpr.name;
				}

				SymbolTableFrame moduleTable = getModuleSymbols(moduleNameExpr.name);

				foreach( symbolName; symbolNames )
				{
					// As long as variables currently shall be imported in runtime only and there is no compile-time
					// symbols for it, so import symbol that currently exists
					if( Symbol importedSymbol = moduleTable.localLookup(symbolName) ) {
						_frameStack.back.add(importedSymbol);
					}
				}
				break;
			}
			default:
				foreach( childNode; node[] )
				{
					log.write(`Symbols collector. Analyse child of kind: `, childNode.kind, ` for IDirectiveStatement node: `, node.name);
					log.internalAssert(childNode, `Child node is null`);
					childNode.accept(this);
				}
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

	private SymbolTableFrame _analyzeModuleSymbols(string moduleName)
	{
		import std.range: popBack, empty, back;
		if( auto modFramePtr = moduleName in _moduleSymbols ) {
			log.internalAssert(*modFramePtr, "Cannot store imported symbols, because symbol table stack is null!");
			return *modFramePtr;
		} else {
			// Try to open, parse and load symbols info from another module
			IvyNode moduleTree = _moduleRepo.getModuleTree(moduleName);

			if( !moduleTree )
				log.error(`Couldn't load module: `, moduleName);

			SymbolTableFrame moduleTable = new SymbolTableFrame(null, _logerMethod);
			_moduleSymbols[moduleName] = moduleTable;
			_frameStack ~= moduleTable;
			scope(exit) {
				log.internalAssert(!_frameStack.empty, `Compiler directive collector frame stack is empty!`);
				_frameStack.popBack();
			}

			// Go to find directive definitions in this imported module
			moduleTree.accept(this);
			return moduleTable;
		}
	}

	SymbolTableFrame getModuleSymbols(string moduleName)
	{
		if( auto modPtr = moduleName in _moduleSymbols ) {
			return *modPtr;
		} else {
			return _analyzeModuleSymbols(moduleName);
		}
	}

	void enterModuleScope(string moduleName)
	{
		log.write(`Enter method`);
		if( SymbolTableFrame table = getModuleSymbols(moduleName) ) {
			_frameStack ~= table;
		} else {
			log.error(`Cannot enter module symbol table, because module "` ~ moduleName ~ `" not found!`);
		}
		log.write(`Exit method`);
	}

	void enterScope(size_t sourceIndex)
	{
		import std.range: empty, back;
		log.internalAssert(!_frameStack.empty, `Cannot enter nested symbol table, because symbol table stack is empty`);

		SymbolTableFrame childFrame = _frameStack.back.getChildFrame(sourceIndex);
		log.internalAssert(childFrame, `Cannot enter child symbol table frame, because it's null`);

		_frameStack ~= childFrame;
	}

	void exitScope()
	{
		import std.range: empty, popBack;
		log.internalAssert(!_frameStack.empty, "Cannot exit frame, because compiler symbol table stack is empty!");

		_frameStack.popBack();
	}

	Symbol symbolLookup(string name)
	{
		import std.range: empty, back;
		log.internalAssert(!_frameStack.empty, `Cannot look for symbol, because symbol table stack is empty`);
		log.internalAssert(_frameStack.back, `Cannot look for symbol, current symbol table frame is null`);

		Symbol symb = _frameStack.back.lookup(name);
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

		return symb;
	}

	void clearCache()
	{
		_moduleSymbols.clear();
		_frameStack.length = 0;
	}
}