module ivy.compiler.symbol_collector;

import ivy.common;
import ivy.directive_stuff;
import ivy.parser.node;
import ivy.parser.node_visitor: AbstractNodeVisitor;
import ivy.compiler.common;
import ivy.compiler.compiler: takeFrontAs;
import ivy.compiler.module_repository;
import ivy.compiler.symbol_table;
import ivy.compiler.def_analyze_mixin: DefAnalyzeMixin;


class CompilerSymbolsCollector: AbstractNodeVisitor
{
	mixin DefAnalyzeMixin;
	alias LogerMethod = void delegate(LogInfo);
private:
	CompilerModuleRepository _moduleRepo;
	SymbolTableFrame[string] _moduleSymbols;
	string _mainModuleName;
	SymbolTableFrame[] _frameStack;
	LogerMethod _logerMethod;

public:
	this(CompilerModuleRepository moduleRepo, string mainModuleName, LogerMethod logerMethod = null)
	{
		import std.range: back;
		_moduleRepo = moduleRepo;
		_logerMethod = logerMethod;
		_mainModuleName = mainModuleName;
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

	LogerProxy loger(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	mixin NodeVisitWrapperImpl!();

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
								loger.internalAssert(res.isSet, `Check 1`);

								if( res.attr.name in namedAttrs )
									loger.error(`Named attribute "`, res.attr.name, `" already defined in directive definition`);

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
								loger.internalAssert(res.isSet, `Check 2`);

								if( exprAttrs.canFind!( (it, needle) => it.name == needle )(res.attr.name) )
									loger.error(`Named attribute "`, res.attr.name, `" already defined in directive definition`);

								exprAttrs ~= res.attr;
							}

							attrBlocks ~= DirAttrsBlock(DirAttrKind.ExprAttr, exprAttrs);
							break;
						}
						case "def.names", "def.kwd": loger.internalAssert(false, `Not implemented yet!`);
						case "def.body":
						{
							if( bodyStmt )
								loger.error(`Multiple body statements are not allowed!`);

							auto res = analyzeDirBody(attrsDefStmtAttrRange);
							bodyStmt = res.statement;

							attrBlocks ~= DirAttrsBlock(DirAttrKind.BodyAttr, res.attr);

							if( _frameStack.empty )
								loger.error(`Cannot store symbol, because fu** you.. Oops.. because symbol table frame stack is empty`);
							if( !_frameStack.back )
								loger.error(`Cannot store symbol, because symbol table frame is null`);
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
					loger.error(`Expected end of directive definition statement. Maybe ; is missing`);
				break;
			}
			case "import":
			{
				IAttributeRange attrRange = node[];
				if( attrRange.empty )
					loger.error(`Expected module name in import statement, but got end of directive`);

				INameExpression moduleNameExpr = attrRange.takeFrontAs!INameExpression("Expected module name in import directive");

				if( !attrRange.empty )
					loger.error(`Expected end of import directive, maybe ; is missing`);

				// Add imported module symbol table as local symbol
				_frameStack.back.add(new ModuleSymbol(
					moduleNameExpr.name,
					analyzeModuleSymbols(moduleNameExpr.name)
				));
				break;
			}
			case "from":
			{
				IAttributeRange attrRange = node[];
				if( attrRange.empty )
					loger.error(`Expected module name in import statement, but got end of directive`);

				INameExpression moduleNameExpr = attrRange.takeFrontAs!INameExpression("Expected module name in import directive");
				INameExpression importKwdExpr = attrRange.takeFrontAs!INameExpression("Expected 'import' keyword!");
				if( importKwdExpr.name != "import" )
					loger.error("Expected 'import' keyword!");

				string[] symbolNames;
				while( !attrRange.empty )
				{
					INameExpression symbolNameExpr = attrRange.takeFrontAs!INameExpression("Expected imported symbol name");
					symbolNames ~= symbolNameExpr.name;
				}

				SymbolTableFrame moduleTable = analyzeModuleSymbols(moduleNameExpr.name);

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
					loger.write(`Symbols collector. Analyse child of kind: `, childNode.kind, ` for IDirectiveStatement node: `, node.name);
					loger.internalAssert(childNode, `Child node is null`);
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
			loger.write(`Symbols collector. Analyse child of kind: `, childNode.kind, ` for ICompoundStatement of kind: `, node.kind);
			childNode.accept(this);
		}

	}

	void _visit(ICodeBlockStatement node) { _visit(cast(ICompoundStatement) node); }
	void _visit(IMixedBlockStatement node) { _visit(cast(ICompoundStatement) node); }

	SymbolTableFrame analyzeModuleSymbols(string moduleName)
	{
		import std.range: popBack, empty, back;
		if( auto modFramePtr = moduleName in _moduleSymbols ) {
			loger.internalAssert(*modFramePtr, "Cannot store imported symbols, because symbol table stack is null!");
			return *modFramePtr;
		} else {
			// Try to open, parse and load symbols info from another module
			IvyNode moduleTree = _moduleRepo.getModuleTree(moduleName);

			if( !moduleTree )
				loger.error(`Couldn't load module: `, moduleName);

			SymbolTableFrame moduleTable = new SymbolTableFrame(null, _logerMethod);
			_moduleSymbols[moduleName] = moduleTable;
			_frameStack ~= moduleTable;
			scope(exit) {
				loger.internalAssert(!_frameStack.empty, `Compiler directive collector frame stack is empty!`);
				_frameStack.popBack();
			}

			// Go to find directive definitions in this imported module
			moduleTree.accept(this);
			return moduleTable;
		}
	}

	SymbolTableFrame[string] getModuleSymbols() @property {
		return _moduleSymbols;
	}

	CompilerModuleRepository getModuleRepository() @property {
		return _moduleRepo;
	}

	void run() {
		analyzeModuleSymbols(_mainModuleName);
	}
}