module ivy.compiler.symbol_collector;

import ivy.common;
import ivy.directive_stuff;
import ivy.parser.node;
import ivy.parser.node_visitor: AbstractNodeVisitor;
import ivy.compiler.common;
import ivy.compiler.compiler: takeFrontAs;
import ivy.compiler.module_repository;
import ivy.compiler.symbol_table;


class CompilerSymbolsCollector: AbstractNodeVisitor
{
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

		void sendLogInfo(LogInfoType logInfoType, string msg) {
			if( collector._logerMethod is null ) {
				return; // There is no loger method, so get out of here
			}
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

				bool isNoscope = false;
				ICompoundStatement bodyStmt;

				DirAttrsBlock!(true)[] attrBlocks;

				alias TValueAttr = DirValueAttr!(true);

				attr_def_stmts_loop:
				while( !attrsDefStmtRange.empty )
				{
					IDirectiveStatement attrsDefStmt = attrsDefStmtRange.front; // Current attributes definition statement
					IAttributeRange attrsDefStmtAttrRange = attrsDefStmt[]; // Range on attributes of attributes definition statement

					switch( attrsDefStmt.name )
					{
						case "def.kv":
						{
							TValueAttr[string] namedAttrs;
							while( !attrsDefStmtAttrRange.empty )
							{
								auto parsed = analyzeValueAttr(attrsDefStmtAttrRange);
								if( parsed.empty )
								{
									attrsDefStmtRange.popFront();
									continue attr_def_stmts_loop;
								}

								TValueAttr attrDecl = parsed.attr;

								if( attrDecl.name in namedAttrs )
									loger.error(`Named attribute "`, attrDecl.name, `" already defined in directive definition`);

								namedAttrs[attrDecl.name] = attrDecl;
							}

							attrBlocks ~= DirAttrsBlock!(true)( DirAttrKind.NamedAttr, namedAttrs );
							break;
						}
						case "def.pos":
						{
							TValueAttr[] exprAttrs;
							while( !attrsDefStmtAttrRange.empty )
							{
								auto parsed = analyzeValueAttr(attrsDefStmtAttrRange);
								if( parsed.empty )
								{
									attrsDefStmtRange.popFront();
									continue attr_def_stmts_loop;
								}

								TValueAttr attrDecl = parsed.attr;

								if( exprAttrs.canFind!( (it, needle) => it.name == needle )(attrDecl.name) )
									loger.error(`Named attribute "`, attrDecl.name, `" already defined in directive definition`);

								exprAttrs ~= attrDecl;
							}

							attrBlocks ~= DirAttrsBlock!(true)( DirAttrKind.ExprAttr, exprAttrs );
							break;
						}
						case "def.names":
							assert( false, `Not implemented yet!` );
							break;
						case "def.kwd":
							assert( false, `Not implemented yet!` );
							break;
						case "def.body":
							if( bodyStmt )
								loger.error(`Multiple body statements are not allowed!`);

							if( attrsDefStmtAttrRange.empty )
								loger.error("Unexpected end of def.body directive!");

							// Try to parse noscope flag
							INameExpression noscopeExpr = cast(INameExpression) attrsDefStmtAttrRange.front;
							if( noscopeExpr && noscopeExpr.name == "noscope" )
							{
								isNoscope = true;
								if( attrsDefStmtAttrRange.empty )
									loger.error("Expected directive body, but end of def.body directive found!");
								attrsDefStmtAttrRange.popFront();
							}

							bodyStmt = cast(ICompoundStatement) attrsDefStmtAttrRange.front; // Getting body AST for statement
							if( !bodyStmt )
								loger.error("Expected compound statement as directive body statement");

							attrBlocks ~= DirAttrsBlock!(true)( DirAttrKind.BodyAttr, DirAttrsBlock!(true).TBodyTuple(bodyStmt, isNoscope) );

							break;
						default:
							break;
					}

					attrsDefStmtRange.popFront();
				}

				if( _frameStack.empty )
					loger.error(`Cannot store symbol, because fu** you.. Oops.. because symbol table frame stack is empty`);
				if( !_frameStack.back )
					loger.error(`Cannot store symbol, because symbol table frame is null`);
				// Add directive definition into existing frame
				_frameStack.back.add(new DirectiveDefinitionSymbol(dirNameExpr.name, attrBlocks));

				if( bodyStmt && !isNoscope )
				{
					// Create new frame for body if not forbidden
					_frameStack ~= _frameStack.back.newChildFrame(bodyStmt.location.index);
				}

				scope(exit)
				{
					if( bodyStmt && !isNoscope ) {
						_frameStack.popBack();
					}
				}

				if( bodyStmt )
				{
					// Analyse nested tree
					bodyStmt.accept(this);
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

	auto analyzeValueAttr(IAttributeRange attrRange)
	{
		import std.typecons: Tuple;
		alias Result = Tuple!( DirValueAttr!(true), `attr`, bool, `empty` );

		string attrName;
		string attrType;
		IExpression defaultValueExpr;

		if( auto kwPair = cast(IKeyValueAttribute) attrRange.front )
		{
			attrName = kwPair.name;
			defaultValueExpr = cast(IExpression) kwPair.value;
			if( !defaultValueExpr )
				loger.error(`Expected attribute default value expression!`);

			attrRange.popFront(); // Skip named attribute
		}
		else if( auto nameExpr = cast(INameExpression) attrRange.front )
		{
			attrName = nameExpr.name;
			attrRange.popFront(); // Skip variable name
		}
		else
		{
			// Just get out of there if nothing matched
			return Result( DirValueAttr!(true).init, true );
		}

		if( !attrRange.empty )
		{
			// Try to parse optional type definition
			if( auto asKwdExpr = cast(INameExpression) attrRange.front )
			{
				if( asKwdExpr.name == "as" )
				{
					// TODO: Try to find out type of attribute after `as` keyword
					// Assuming that there will be no named attribute with name `as` in programme
					attrRange.popFront(); // Skip `as` keyword

					if( attrRange.empty )
						loger.error(`Expected attr type definition, but got end of attrs range!`);

					auto attrTypeExpr = cast(INameExpression) attrRange.front;
					if( !attrTypeExpr )
						loger.error(`Expected attr type definition!`);

					attrType = attrTypeExpr.name; // Getting type of attribute as string (for now)

					attrRange.popFront(); // Skip type expression
				}
			}
		}

		return Result( DirValueAttr!(true)(attrName, attrType, defaultValueExpr), false );
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