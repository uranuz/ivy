/// Module implements compilation of Ivy abstract syntax tree into bytecode
module ivy.compiler;

import ivy.node;
import ivy.node_visitor;
import ivy.bytecode;
import ivy.interpreter_data;
import ivy.common;

// If IvyTotalDebug is defined then enable compiler debug
version(IvyTotalDebug) version = IvyCompilerDebug;

class ASTNodeTypeException: IvyException
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}

}

T expectNode(T)( IvyNode node, string msg = null, string file = __FILE__, string func = __FUNCTION__, int line = __LINE__ )
{
	import std.algorithm: splitter;
	import std.range: retro, take, join;
	import std.array: array;
	import std.conv: to;

	string shortFuncName = func.splitter('.').retro.take(2).array.retro.join(".");
	enum shortObjName = T.stringof.splitter('.').retro.take(2).array.retro.join(".");

	T typedNode = cast(T) node;
	if( !typedNode )
		throw new ASTNodeTypeException( shortFuncName ~ "[" ~ line.to!string ~ "]: Expected " ~ shortObjName ~ ":  " ~ msg, file, line );

	return typedNode;
}

T takeFrontAs(T)( IAttributeRange range, string errorMsg = null, string file = __FILE__, string func = __FUNCTION__, int line = __LINE__ )
{
	import std.algorithm: splitter;
	import std.range: retro, take, join;
	import std.array: array;
	import std.conv: to;

	static immutable shortObjName = T.stringof.splitter('.').retro.take(2).array.retro.join(".");
	string shortFuncName = func.splitter('.').retro.take(2).array.retro.join(".");
	string longMsg = shortFuncName ~ "[" ~ line.to!string ~ "]: Expected " ~ shortObjName ~ ":  " ~ errorMsg;

	if( range.empty )
		throw new ASTNodeTypeException( longMsg, file, line );

	T typedAttr = cast(T) range.front;
	if( !typedAttr )
		throw new ASTNodeTypeException( longMsg, file, line );

	range.popFront();

	return typedAttr;
}

T testFrontIs(T)( IAttributeRange range, string errorMsg = null, string file = __FILE__, string func = __FUNCTION__, int line = __LINE__ )
{
	if( range.empty )
		return false;

	T typedNode = cast(T) range.front;

	return typedNode !is null;
}


class IvyCompilerException: IvyException
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}

}

alias TDataNode = DataNode!string;

interface IDirectiveCompiler
{
	void compile( IDirectiveStatement stmt, ByteCodeCompiler compiler );
}

class CompilerModuleRepository
{
	import ivy.lexer_tools: TextForwardRange;
	import ivy.common: LocationConfig;

	alias TextRange = TextForwardRange!(string, LocationConfig());
	alias LogerMethod = void delegate(LogInfo);
private:
	string[] _importPaths;
	string _fileExtension;
	LogerMethod _logerMethod;

	IvyNode[string] _moduleTrees;

public:
	this(string[] importPaths, string fileExtension, LogerMethod logerMethod = null)
	{
		_importPaths = importPaths;
		_fileExtension = fileExtension;
		_logerMethod = logerMethod;
	}

	version(IvyCompilerDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy {
		mixin LogerProxyImpl!(IvyCompilerException, isDebugMode);
		CompilerModuleRepository moduleRepo;

		void sendLogInfo(LogInfoType logInfoType, string msg) {
			if( moduleRepo._logerMethod is null ) {
				return; // There is no loger method, so get out of here
			}
			moduleRepo._logerMethod(LogInfo(msg, logInfoType, getShortFuncName(func), file, line));
		}
	}

	LogerProxy loger(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	void loadModuleFromFile(string moduleName)
	{
		import std.algorithm: splitter, startsWith;
		import std.array: array, join;
		import std.range: only, chain, empty, front;
		import std.path: buildNormalizedPath, isAbsolute;
		import std.file: read, exists, isFile;

		loger.write("loadModuleFromFile attempt to load module: ", moduleName);

		string fileName;
		string[] existingFiles;
		foreach( importPath; _importPaths )
		{
			if( !isAbsolute(importPath) )
				continue;
			
			string fileNameNoExt = buildNormalizedPath( only(importPath).chain( moduleName.splitter('.') ).array );
			// The module name is given. Try to build path to it
			fileName = fileNameNoExt ~ _fileExtension;

			// Check if file name is not empty and located in root path
			if( fileName.empty || !fileName.startsWith( buildNormalizedPath(importPath) ) )
				loger.error(`Incorrect path to module: `, fileName);

			if( std.file.exists(fileName) && std.file.isFile(fileName) ) {
				existingFiles ~= fileName;
			} else if( std.file.exists(fileNameNoExt) && std.file.isDir(fileNameNoExt) ) {
				// If there is no file with exact name then try to find folder with this path
				// and check if there is file with name <moduleName> and <_fileExtension>
				fileName = buildNormalizedPath(fileNameNoExt, moduleName.splitter('.').back) ~ _fileExtension;
				if( std.file.exists(fileName) && std.file.isFile(fileName) ) {
					existingFiles ~= fileName;
				}
			}
		}

		if( existingFiles.length == 0 )
			loger.error(`Cannot load module `, moduleName, ". Searching in import paths:\n", _importPaths.join(",\n") );
		else if( existingFiles.length == 1 )
			fileName = existingFiles.front; // Success
		else
			loger.error(`Found multiple source files in import paths matching module name `, moduleName,
				". Following files matched:\n", existingFiles.join(",\n") );

		loger.write("loadModuleFromFile loading module from file: ", fileName);
		string fileContent = cast(string) std.file.read(fileName);

		import ivy.parser;
		auto parser = new Parser!(TextRange)(fileContent, fileName, _logerMethod);

		_moduleTrees[moduleName] = parser.parse();
	}

	IvyNode getModuleTree(string name)
	{
		if( name !in _moduleTrees )
		{
			loadModuleFromFile( name );
		}

		if( name in _moduleTrees )
		{
			return _moduleTrees[name];
		}
		else
		{
			return null;
		}
	}
}

enum SymbolKind { DirectiveDefinition, Module };

class Symbol
{
	string name;
	SymbolKind kind;
}

class DirectiveDefinitionSymbol: Symbol
{
	DirAttrsBlock!(true)[] dirAttrBlocks;

public:
	this( string name, DirAttrsBlock!(true)[] dirAttrBlocks )
	{
		this.name = name;
		this.kind = SymbolKind.DirectiveDefinition;
		this.dirAttrBlocks = dirAttrBlocks;
	}
}

class ModuleSymbol: Symbol
{
	SymbolTableFrame symbolTable; // TODO: ****????

public:
	this( string name, SymbolTableFrame symbolTable )
	{
		this.name = name;
		this.kind = SymbolKind.Module;
		this.symbolTable = symbolTable;
	}
}

class SymbolTableFrame
{
	alias LogerMethod = void delegate(LogInfo);
	Symbol[string] _symbols;
	SymbolTableFrame _moduleFrame;
	SymbolTableFrame[size_t] _childFrames; // size_t - is index of scope start in source code?
	LogerMethod _logerMethod;

public:
	this(SymbolTableFrame moduleFrame, LogerMethod logerMethod)
	{
		_moduleFrame = moduleFrame;
		_logerMethod = logerMethod;
	}

	version(IvyCompilerDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy {
		mixin LogerProxyImpl!(IvyCompilerException, isDebugMode);
		SymbolTableFrame table;

		void sendLogInfo(LogInfoType logInfoType, string msg) {
			if( table._logerMethod is null ) {
				return; // There is no loger method, so get out of here
			}
			table._logerMethod(LogInfo(msg, logInfoType, getShortFuncName(func), file, line));
		}
	}

	LogerProxy loger(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	Symbol localLookup(string name)
	{
		return _symbols.get(name, null);
	}

	Symbol lookup(string name)
	{
		loger.write(`SymbolTableFrame: Starting compiler symbol lookup: `, name);

		if( Symbol* symb = name in _symbols ) {
			loger.write(`SymbolTableFrame: Symbol: `, name, ` found in frame`);
			return *symb;
		}

		loger.write(`SymbolTableFrame: Couldn't find symbol in frame: `, name);

		// We need to try to look in module symbol table
		if( Symbol symb = moduleLookup(name) ) {
			loger.write(`SymbolTableFrame: Symbol found in imported modules: `, name);
			return symb;
		}

		loger.write(`SymbolTableFrame: Couldn't find symbol in imported modules: `, name);

		if( !_moduleFrame ) {
			loger.write(`SymbolTableFrame: Attempt to find symbol: `, name, ` in module scope failed, because _moduleFrame is null`);
			return null;
		}

		loger.write(`SymbolTableFrame: Attempt to find symbol: `, name, ` in module scope!`);
		return _moduleFrame.lookup(name);
	}

	Symbol moduleLookup(string name)
	{
		import std.algorithm: splitter;
		import std.string: join;
		import std.range: take, drop;
		import std.array: array;

		loger.write(`SymbolTableFrame: Attempt to perform imported modules lookup for symbol: `, name);

		auto splittedName = splitter(name, ".").array;
		for( size_t i = 1; i <= splittedName.length; ++i )
		{
			string namePart = splittedName[].take(i).join(".");
			if( Symbol* symb = namePart in _symbols )
			{
				if( symb.kind == SymbolKind.Module )
				{
					string modSymbolName = splittedName[].drop(i).join(".");
					ModuleSymbol modSymbol = cast(ModuleSymbol) *symb;
					if( Symbol childSymbol = modSymbol.symbolTable.lookup(modSymbolName) )
						return childSymbol;
				}
			}

		}
		return null;
	}

	void add(Symbol symb)
	{
		_symbols[symb.name] = symb;
	}

	SymbolTableFrame getChildFrame(size_t sourceIndex)
	{
		return _childFrames.get(sourceIndex, null);
	}

	SymbolTableFrame newChildFrame(size_t sourceIndex)
	{
		loger.internalAssert(sourceIndex !in _childFrames, `Child frame already exists!`);

		// For now consider if this frame has no module frame - so it is module frame itself
		SymbolTableFrame child = new SymbolTableFrame(_moduleFrame? _moduleFrame: this, _logerMethod);
		_childFrames[sourceIndex] = child;
		return child;
	}

	string toPrettyStr()
	{
		import std.conv;
		string result;

		result ~= "\r\nSYMBOLS:\r\n";
		foreach( symbName, symb; _symbols )
		{
			result ~= symbName ~ ": " ~ symb.kind.to!string ~ "\r\n";
		}

		result ~= "\r\nFRAMES:\r\n";

		foreach( index, frame; _childFrames )
		{
			if( frame )
			{
				result ~= "\r\nFRAME with index " ~ index.to!string ~ "\r\n";
				result ~= frame.toPrettyStr();
			}
			else
			{
				result ~= "\r\nFRAME with index " ~ index.to!string ~ " is null\r\n";
			}
		}

		return result;
	}
}

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
			collector._logerMethod(LogInfo(msg, logInfoType, getShortFuncName(func), file, line));
		}
	}

	LogerProxy loger(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	alias visit = AbstractNodeVisitor.visit;

	public override {
		// Most of these stuff is just empty implementation except directive statements parsing
		void visit(IvyNode node) { assert(0); }

		//Expressions
		void visit(IExpression node) {  }
		void visit(ILiteralExpression node) {  }
		void visit(INameExpression node) {  }
		void visit(IOperatorExpression node) {  }
		void visit(IUnaryExpression node) {  }
		void visit(IBinaryExpression node) {  }
		void visit(IAssocArrayPair node) {  }

		//Statements
		void visit(IStatement node) {  }
		void visit(IKeyValueAttribute node) {  }
		void visit(IDirectiveStatement node)
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
					_frameStack.back.add( new DirectiveDefinitionSymbol(dirNameExpr.name, attrBlocks) );

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
		void visit(IDataFragmentStatement node) {  }
		void visit(ICompoundStatement node)
		{
			foreach( childNode; node[] )
			{
				loger.write(`Symbols collector. Analyse child of kind: `, childNode.kind, ` for ICompoundStatement of kind: `, node.kind);
				childNode.accept(this);
			}

		}
	}

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

	SymbolTableFrame[string] getModuleSymbols() @property
	{
		return _moduleSymbols;
	}

	CompilerModuleRepository getModuleRepository() @property
	{
		return _moduleRepo;
	}

	void run()
	{
		analyzeModuleSymbols(_mainModuleName);
	}
}

/++
	`Var` directive is defined as list of elements. Each of them could be of following forms:
	- Just name of new variable without any value or type (default value will be set, type is `any`)
		{# var a #}
	- Name with initializer value (type is `any`)
		{# var a: "Example" #}
	- Name with type but without any value (`as` context keyword is used to describe type)
		{# var a as str #}
	- Name with initializer and type
		{# var a: "Example" as str #}

	Multiple variables could be defined using one `var` directive
	{# var
			a
			b: "Example"
			c as str
			d: "Example2" as str
	#}
+/
class VarCompiler: IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement stmt, ByteCodeCompiler compiler )
	{
		import std.range: empty, back, empty;

		if( !stmt || stmt.name != "var" )
			compiler.loger.error(`Expected "var" directive statement!`);

		auto stmtRange = stmt[];
		while( !stmtRange.empty )
		{
			size_t varNameConstIndex;
			if( auto kwPair = cast(IKeyValueAttribute) stmtRange.front )
			{
				if( kwPair.name.empty )
					compiler.loger.error(`Variable name cannot be empty`);
				varNameConstIndex = compiler.addConst( TDataNode(kwPair.name) );

				if( !kwPair.value )
					compiler.loger.error("Expected value for 'var' directive");

				kwPair.value.accept(compiler); // Compile expression for getting value
				stmtRange.popFront();
			}
			else if( auto nameExpr = cast(INameExpression) stmtRange.front )
			{
				if( nameExpr.name.empty )
					compiler.loger.error(`Variable name cannot be empty`);
				varNameConstIndex = compiler.addConst( TDataNode(nameExpr.name) );

				stmtRange.popFront();
			}
			else
			{
				compiler.loger.error( `Expected named attribute or name as variable declarator!` );
			}

			if( !stmtRange.empty )
			{
				if( auto asKwdExpr = cast(INameExpression) stmtRange.front )
				{
					if( asKwdExpr.name == "as" )
					{
						// TODO: Try to find out type of variable after `as` keyword
						// Assuming that there will be no variable with name `as` in programme
						stmtRange.popFront(); // Skip `as` keyword

						if( stmtRange.empty )
							compiler.loger.error(`Expected variable type declaration`);

						// For now just skip type expression
						stmtRange.popFront();
					}
				}
			}

			compiler.addInstr( OpCode.StoreLocalName, varNameConstIndex );
		}

		// For now we expect that directive should return some value on the stack
		size_t fakeValueConstIndex = compiler.addConst( TDataNode() );
		compiler.addInstr( OpCode.LoadConst, fakeValueConstIndex );

		if( !stmtRange.empty )
			compiler.loger.error("Expected end of directive after key-value pair. Maybe ';' is missing");
	}
}

/++
	`Set` directive is used to set values of existing variables in context.
	It is defined as list of named attributes where key is variable name
	and attr value is new value for variable in context. Example:
	{# set a: "Example" #}

	Multiple variables could be set using one `set` directive
	{# set
			a: "Example"
			b: 10
			c: { s: 10, k: "Example2" }
	#}
+/
class SetCompiler : IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "set" )
			compiler.loger.error("Expected 'set' directive");

		auto stmtRange = statement[];

		while( !stmtRange.empty )
		{
			IKeyValueAttribute kwPair = stmtRange.takeFrontAs!IKeyValueAttribute("Key-value pair expected");

			if( !kwPair.value )
				compiler.loger.error("Expected value for 'set' directive");

			kwPair.value.accept(compiler); //Evaluating expression

			size_t varNameConstIndex = compiler.addConst( TDataNode( kwPair.name ) );
			compiler.addInstr( OpCode.StoreName, varNameConstIndex );
		}

		// For now we expect that directive should return some value on the stack
		size_t fakeValueConstIndex = compiler.addConst( TDataNode() );
		compiler.addInstr( OpCode.LoadConst, fakeValueConstIndex );

		if( !stmtRange.empty )
			compiler.loger.error("Expected end of directive after key-value pair. Maybe ';' is missing");
	}

}

class IfCompiler: IDirectiveCompiler
{
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "if" )
			compiler.loger.error(`Expected "if" directive statement!`);

		import std.typecons: Tuple;
		import std.range: back, empty;
		alias IfSect = Tuple!(IExpression, "cond", IExpression, "stmt");

		IfSect[] ifSects;
		IExpression elseBody;

		auto stmtRange = statement[];

		IExpression condExpr = stmtRange.takeFrontAs!IExpression( "Conditional expression expected" );
		IExpression bodyStmt = stmtRange.takeFrontAs!IExpression( "'If' directive body statement expected" );

		ifSects ~= IfSect(condExpr, bodyStmt);

		while( !stmtRange.empty )
		{
			compiler.loger.write(`IfCompiler, stmtRange.front: `, stmtRange.front);
			INameExpression keywordExpr = stmtRange.takeFrontAs!INameExpression("'elif' or 'else' keyword expected");
			if( keywordExpr.name == "elif" )
			{
				condExpr = stmtRange.takeFrontAs!IExpression( "'elif' conditional expression expected" );
				bodyStmt = stmtRange.takeFrontAs!IExpression( "'elif' body statement expected" );

				ifSects ~= IfSect(condExpr, bodyStmt);
			}
			else if( keywordExpr.name == "else" )
			{
				elseBody = stmtRange.takeFrontAs!IExpression( "'else' body statement expected" );
				if( !stmtRange.empty )
					compiler.loger.error("'else' statement body expected to be the last 'if' attribute. Maybe ';' is missing");
				break;
			}
			else
			{
				compiler.loger.error("'elif' or 'else' keyword expected");
			}
		}

		// Array used to store instr indexes of jump instructions after each
		// if, elif block, used to jump to the end of directive after block
		// has been executed 
		size_t[] jumpInstrIndexes;
		jumpInstrIndexes.length = ifSects.length;

		foreach( i, ifSect; ifSects )
		{
			ifSect.cond.accept(compiler);

			// Add conditional jump instruction
			// Remember address of jump instruction
			size_t jumpInstrIndex = compiler.addInstr( OpCode.JumpIfFalse );

			// Add `if body` code
			ifSect.stmt.accept(compiler);

			// Instruction to jump after the end of if directive when
			// current body finished
			jumpInstrIndexes[i] = compiler.addInstr( OpCode.Jump );
			
			// Getting address of instruction following after if body
			size_t jumpElseIndex = compiler.getInstrCount();

			compiler.setInstrArg( jumpInstrIndex, jumpElseIndex );
		}

		if( elseBody )
		{
			// Compile elseBody
			elseBody.accept(compiler);
		}
		else
		{
			// It's fake elseBody used to push fake return value onto stack
			size_t emptyNodeConstIndex = compiler.addConst( TDataNode() );
			compiler.addInstr( OpCode.LoadConst, emptyNodeConstIndex );
		}

		size_t afterEndInstrIndex = compiler.getInstrCount();
		compiler.addInstr( OpCode.Nop ); // Need some fake to jump if it's end of code object

		foreach( currIndex; jumpInstrIndexes )
		{
			// Fill all generated jump instructions with address of instr after directive end 
			compiler.setInstrArg( currIndex, afterEndInstrIndex );
		}

		if( !stmtRange.empty )
			compiler.loger.error(`Expected end of "if" directive. Maybe ';' is missing`);

	}

}


class ForCompiler : IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "for" )
			compiler.loger.error("Expected 'for' directive");

		auto stmtRange = statement[];

		INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("For loop variable name expected");

		string varName = varNameExpr.name;
		if( varName.length == 0 )
			compiler.loger.error("Loop variable name cannot be empty");

		INameExpression inAttribute = stmtRange.takeFrontAs!INameExpression("Expected 'in' attribute");

		if( inAttribute.name != "in" )
			compiler.loger.error("Expected 'in' keyword");

		IExpression aggregateExpr = stmtRange.takeFrontAs!IExpression("Expected 'for' aggregate expression");

		// Compile code to calculate aggregate value
		aggregateExpr.accept(compiler);

		ICompoundStatement bodyStmt = stmtRange.takeFrontAs!ICompoundStatement( "Expected loop body statement" );

		if( !stmtRange.empty )
			compiler.loger.error("Expected end of directive after loop body. Maybe ';' is missing");

		// TODO: Check somehow if aggregate has supported type

		// Issue instruction to get iterator from aggregate in execution stack
		compiler.addInstr( OpCode.GetDataRange );

		size_t loopStartInstrIndex = compiler.addInstr( OpCode.RunLoop );
		size_t varNameConstIndex = compiler.addConst( TDataNode(varName) );

		// Issue command to store current loop item in local context with specified name
		compiler.addInstr( OpCode.StoreLocalName, varNameConstIndex );

		bodyStmt.accept(compiler);

		// Drop result that we don't care about in this loop type
		compiler.addInstr( OpCode.PopTop );

		size_t loopEndInstrIndex = compiler.addInstr( OpCode.Jump, loopStartInstrIndex );
		compiler.setInstrArg( loopStartInstrIndex, loopEndInstrIndex );

		// Push fake result to "make all happy" ;)
		size_t fakeResultConstIndex = compiler.addConst( TDataNode() );
		compiler.addInstr( OpCode.LoadConst, fakeResultConstIndex );
	}
}

class AtCompiler : IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "at" )
			compiler.loger.error("Expected 'at' directive");

		auto stmtRange = statement[];

		IvyNode aggregate = stmtRange.takeFrontAs!IvyNode(`Expected "at" aggregate argument`);
		IvyNode indexValue = stmtRange.takeFrontAs!IvyNode(`Expected "at" index value`);

		aggregate.accept(compiler); // Evaluate aggregate
		indexValue.accept(compiler); // Evaluate index
		compiler.addInstr(OpCode.LoadSubscr);

		if( !stmtRange.empty )
			compiler.loger.error(`Expected end of "at" directive after index expression. Maybe ';' is missing. `
				~ `Info: multiple index expressions are not supported yet.`);
	}
}

class SetAtCompiler : IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "setat" )
			compiler.loger.error("Expected 'setat' directive");

		auto stmtRange = statement[];

		IExpression aggregate = stmtRange.takeFrontAs!IExpression(`Expected expression as "at" aggregate argument`);
		IExpression assignedValue = stmtRange.takeFrontAs!IExpression(`Expected expression as "at" value to assign`);
		IExpression indexValue = stmtRange.takeFrontAs!IExpression(`Expected expression as "at" index value`);

		compiler.addInstr(OpCode.StoreSubscr);
		aggregate.accept(compiler); // Evaluate aggregate
		assignedValue.accept(compiler); // Evaluate assigned value
		indexValue.accept(compiler); // Evaluate index

		if( !stmtRange.empty )
			compiler.loger.error(`Expected end of "setat" directive after index expression. Maybe ';' is missing. `
				~ `Info: multiple index expressions are not supported yet.`);
	}
}

class RepeatCompiler : IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "repeat" )
			compiler.loger.error("Expected 'repeat' directive");

		auto stmtRange = statement[];

		INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("Loop variable name expected");

		string varName = varNameExpr.name;
		if( varName.length == 0 )
			compiler.loger.error("Loop variable name cannot be empty");

		INameExpression inAttribute = stmtRange.takeFrontAs!INameExpression("Expected 'in' attribute");

		if( inAttribute.name != "in" )
			compiler.loger.error("Expected 'in' keyword");

		IExpression aggregateExpr = stmtRange.takeFrontAs!IExpression("Expected loop aggregate expression");

		// Compile code to calculate aggregate value
		aggregateExpr.accept(compiler);

		ICompoundStatement bodyStmt = stmtRange.takeFrontAs!ICompoundStatement("Expected loop body statement");

		if( !stmtRange.empty )
			compiler.loger.error("Expected end of directive after loop body. Maybe ';' is missing");

		// Issue instruction to get iterator from aggregate in execution stack
		compiler.addInstr( OpCode.GetDataRange );

		// Creating node for string result on stack
		size_t emptyStrConstIndex = compiler.addConst( TDataNode(TDataNode[].init) );
		compiler.addInstr( OpCode.LoadConst, emptyStrConstIndex );
		
		// RunLoop expects  data node range on the top, but result aggregator
		// can be left on (TOP - 1), so swap these...
		compiler.addInstr( OpCode.SwapTwo );

		// Run our super-duper loop
		size_t loopStartInstrIndex = compiler.addInstr( OpCode.RunLoop );

		// Issue command to store current loop item in local context with specified name
		size_t varNameConstIndex = compiler.addConst( TDataNode(varName) );
		compiler.addInstr( OpCode.StoreLocalName, varNameConstIndex );
		
		// Swap data node range with result, so that we have it on (TOP - 1) when loop body finished
		compiler.addInstr( OpCode.SwapTwo ); 

		bodyStmt.accept(compiler);

		// Apend current result to previous
		compiler.addInstr( OpCode.Append );

		// Put data node range at the TOP and result on (TOP - 1) 
		compiler.addInstr( OpCode.SwapTwo );

		size_t loopEndInstrIndex = compiler.addInstr( OpCode.Jump, loopStartInstrIndex );
		// We need to say RunLoop where to jump when range become empty
		compiler.setInstrArg( loopStartInstrIndex, loopEndInstrIndex );
		
		// Data range is dropped by RunLoop already
	}
}


// Produces OpCode.Nop
class PassInterpreter : IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		compiler.addInstr( Instruction( OpCode.Nop ) );
	}
}

class ExprCompiler: IDirectiveCompiler
{
	override void compile( IDirectiveStatement stmt, ByteCodeCompiler compiler )
	{
		if( !stmt || stmt.name != "expr" )
			compiler.loger.error(`Expected "expr" directive statement!`);

		auto stmtRange = stmt[];
		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "expr" argument!`);

		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( !stmtRange.empty )
		{
			compiler.loger.write("ExprCompiler. At end. stmtRange.front.kind: ", ( cast(INameExpression) stmtRange.front ).name);
			compiler.loger.error(`Expected end of "expr" directive. Maybe ';' is missing`);
		}
			
	}

}

/+
class TextBlockInterpreter: IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "text"  )
			interpretError( "Expected 'var' directive" );

		auto stmtRange = statement[];

		if( stmtRange.empty )
			throw new ASTNodeTypeException("Expected compound statement or expression, but got end of directive");

		interp.opnd = TDataNode.init;

		if( auto expr = cast(IExpression) stmtRange.front )
		{
			expr.accept(interp);
		}
		else if( auto block = cast(ICompoundStatement) stmtRange.front )
		{
			block.accept(interp);
		}
		else
			new ASTNodeTypeException("Expected compound statement or expression");

		stmtRange.popFront(); //Skip attribute of directive

		if( !stmtRange.empty )
			interpretError("Expected only one attribute in 'text' directive");

		import std.array: appender;

		auto result = appender!string();

		writeDataNodeLines( interp.opnd, result, 15 );

		string dat = result.data;

		interp.opnd = result.data;
	}

}
+/

/// Compiles module into module object and saves it into dictionary
class ImportCompiler: IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "import" )
			compiler.loger.error("Expected 'import' directive");

		auto stmtRange = statement[];

		INameExpression moduleNameExpr = stmtRange.takeFrontAs!INameExpression("Expected module name for import");
		if( !stmtRange.empty )
			compiler.loger.error(`Not all attributes for directive "import" were parsed. Maybe ; is missing somewhere`);

		compiler.getOrCompileModule(moduleNameExpr.name); // Module must be compiled before we can import it

		size_t modNameConstIndex = compiler.addConst(TDataNode(moduleNameExpr.name));
		compiler.addInstr(OpCode.LoadConst, modNameConstIndex); // The first is for ImportModule

		compiler.addInstr(OpCode.ImportModule);
		compiler.addInstr(OpCode.SwapTwo); // Swap module return value and imported execution frame
		compiler.addInstr(OpCode.StoreNameWithParents, modNameConstIndex);
	}
}

/// Compiles module into module object and saves it into dictionary
class FromImportCompiler: IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "from" )
			compiler.loger.error("Expected 'from' directive");

		auto stmtRange = statement[];

		INameExpression moduleNameExpr = stmtRange.takeFrontAs!INameExpression("Expected module name for import");

		INameExpression importKwdExpr = stmtRange.takeFrontAs!INameExpression("Expected 'import' keyword, but got end of range");
		if( importKwdExpr.name != "import" )
			compiler.loger.error("Expected 'import' keyword");

		string[] varNames;
		while( !stmtRange.empty )
		{
			INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("Expected imported variable name");
			varNames ~= varNameExpr.name;
		}

		if( !stmtRange.empty )
			compiler.loger.error(`Not all attributes for directive "from" were parsed. Maybe ; is missing somewhere`);

		compiler.getOrCompileModule(moduleNameExpr.name); // Module must be compiled before we can import it

		size_t modNameConstIndex = compiler.addConst(TDataNode(moduleNameExpr.name));
		compiler.addInstr(OpCode.LoadConst, modNameConstIndex);

		compiler.addInstr(OpCode.ImportModule);
		compiler.addInstr(OpCode.SwapTwo); // Swap module return value and imported execution frame
		size_t varNamesConstIndex = compiler.addConst(TDataNode(varNames));
		compiler.addInstr(OpCode.LoadConst, varNamesConstIndex); // Put list of imported names on the stack
		compiler.addInstr(OpCode.FromImport); // Store names from module exec frame into current frame
	}
}

debug import std.stdio;
/// Defines directive using ivy language
class DefCompiler: IDirectiveCompiler
{
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "def" )
			compiler.loger.error("Expected 'def' directive");

		auto stmtRange = statement[];
		INameExpression defNameExpr = stmtRange.takeFrontAs!INameExpression("Expected name for directive definition");

		ICompoundStatement bodyStatement;
		bool isNoscope = false;

		while( !stmtRange.empty )
		{
			ICodeBlockStatement attrsDefBlockStmt = cast(ICodeBlockStatement) stmtRange.front;
			if( !attrsDefBlockStmt )
			{
				break; // Expected to see some attribute declaration
			}

			IDirectiveStatementRange attrDefStmtRange = attrsDefBlockStmt[];

			while( !attrDefStmtRange.empty )
			{
				IDirectiveStatement attrDefStmt = attrDefStmtRange.front;
				IAttributeRange attrsDefStmtAttrRange = attrDefStmt[];

				switch( attrDefStmt.name )
				{
					case "def.kv": {
						break;
					}
					case "def.pos": {
						break;
					}
					case "def.names": {
						break;
					}
					case "def.kwd": {
						break;
					}
					case "def.body": {
						if( bodyStatement )
							compiler.loger.error("Multiple body statements are not allowed!!!");

						if( attrsDefStmtAttrRange.empty )
							compiler.loger.error("Unexpected end of def.body directive!");
						
						// Try to parse noscope flag
						INameExpression noscopeExpr = cast(INameExpression) attrsDefStmtAttrRange.front;
						if( noscopeExpr && noscopeExpr.name == "noscope" )
						{
							isNoscope = true;
							if( attrsDefStmtAttrRange.empty )
								compiler.loger.error("Expected directive body, but end of def.body directive found!");
							attrsDefStmtAttrRange.popFront();
						}

						bodyStatement = cast(ICompoundStatement) attrsDefStmtAttrRange.front; // Getting body AST for statement
						if( !bodyStatement )
							compiler.loger.error("Expected compound statement as directive body statement");

						break;
					}
					default: {
						compiler.loger.error(`Unexpected directive attribute definition statement "` ~ attrDefStmt.name ~ `"`);
						break;
					}
				}
				attrDefStmtRange.popFront(); // Going to the next directive statement in code block
			}
			stmtRange.popFront(); // Go to next attr definition directive
		}

		// Here should go commands to compile directive body
		compiler.loger.internalAssert(bodyStatement, `Directive definition body is null`);

		size_t codeObjIndex;
		{
			import std.algorithm: map;
			import std.array: array;

			Symbol symb = compiler.symbolLookup( defNameExpr.name );
			if( symb.kind != SymbolKind.DirectiveDefinition )
				compiler.loger.error(`Expected directive definition symbol kind`);

			DirectiveDefinitionSymbol dirSymbol = cast(DirectiveDefinitionSymbol) symb;
			assert( dirSymbol, `Directive definition symbol is null` );

			if( !isNoscope )
			{
				// Compiler should enter frame of directive body, identified by index in source code
				compiler.enterScope( bodyStatement.location.index );
			}

			codeObjIndex = compiler.enterNewCodeObject(); // Creating code object

			// Generating code for def.body
			bodyStatement.accept(compiler);

			compiler.currentCodeObject._attrBlocks = dirSymbol.dirAttrBlocks.map!( b => b.toInterpreterBlock() ).array;

			scope(exit) {
				compiler.exitCodeObject();
				if( !isNoscope )
				{
					compiler.exitScope();
				}
			}
		}

		// Add instruction to load code object from module constants
		compiler.addInstr( OpCode.LoadConst, codeObjIndex );

		// Add directive name to module constants
		size_t dirNameConstIndex = compiler.addConst( TDataNode(defNameExpr.name) );

		// Add instruction to load directive name from consts
		compiler.addInstr( OpCode.LoadConst, dirNameConstIndex );

		// Add instruction to create directive object
		compiler.addInstr( OpCode.LoadDirective );
	}
}

class ByteCodeCompiler: AbstractNodeVisitor
{
	alias LogerMethod = void delegate(LogInfo);
private:

	// Dictionary of native compilers for directives
	IDirectiveCompiler[string] _dirCompilers;

	// Dictionary maps module name to it's root symbol table frame
	SymbolTableFrame[string] _modulesSymbolTables;

	// Storage for global compiler's symbols (INativeDirectiveInterpreter's info for now)
	SymbolTableFrame _globalSymbolTable;

	// Compiler's storage for parsed module ASTs
	CompilerModuleRepository _moduleRepo;

	// Dictionary with module objects that compiler produces
	ModuleObject[string] _moduleObjects;

	// Current stack of symbol table frames
	SymbolTableFrame[] _symbolTableStack;

	// Current stack of code objects that compiler produces
	CodeObject[] _codeObjStack;

	string _mainModuleName;

	LogerMethod _logerMethod;


public:
	this(CompilerModuleRepository moduleRepo, SymbolTableFrame[string] symbolTables, string mainModuleName, LogerMethod logerMethod = null)
	{
		_logerMethod = logerMethod;
		_moduleRepo = moduleRepo;
		_modulesSymbolTables = symbolTables;
		_globalSymbolTable = new SymbolTableFrame(null, _logerMethod);

		// Add core directives set:
		_dirCompilers["var"] = new VarCompiler();
		_dirCompilers["set"] = new SetCompiler();
		_dirCompilers["expr"] = new ExprCompiler();
		_dirCompilers["if"] = new IfCompiler();
		_dirCompilers["for"] = new ForCompiler();
		_dirCompilers["repeat"] = new RepeatCompiler();
		_dirCompilers["def"] = new DefCompiler();
		_dirCompilers["import"] = new ImportCompiler();
		_dirCompilers["from"] = new FromImportCompiler();
		_dirCompilers["at"] = new AtCompiler();

		_mainModuleName = mainModuleName;
		enterModuleScope(mainModuleName);
		enterNewCodeObject( newModuleObject(mainModuleName) );
	}

	version(IvyCompilerDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy {
		mixin LogerProxyImpl!(IvyCompilerException, isDebugMode);
		ByteCodeCompiler compiler;

		void sendLogInfo(LogInfoType logInfoType, string msg) {
			if( compiler._logerMethod is null ) {
				return; // There is no loger method, so get out of here
			}
			compiler._logerMethod(LogInfo(msg, logInfoType, getShortFuncName(func), file, line));
		}
	}

	LogerProxy loger(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	void addDirCompilers(IDirectiveCompiler[string] dirCompilers)
	{
		foreach( name, dirCompiler; dirCompilers ) {
			_dirCompilers[name] = dirCompiler;
		}
	}

	void addGlobalSymbols(Symbol[] symbols)
	{
		foreach(symb; symbols) {
			_globalSymbolTable.add(symb);
		}
	}

	void enterModuleScope( string moduleName )
	{
		loger.write( `Enter method` );
		loger.write( `_modulesSymbolTables: `, _modulesSymbolTables );
		if( auto table = moduleName in _modulesSymbolTables )
		{
			loger.internalAssert( *table, `Cannot enter module sybol table frame, because it is null` );
			_symbolTableStack ~= *table;
		}
		else
		{
			loger.error( `Cannot enter module symbol table, because module "` ~ moduleName ~ `" not found!` );
		}
		loger.write( `Exit method` );
	}

	void enterScope( size_t sourceIndex )
	{
		import std.range: empty, back;
		loger.internalAssert( !_symbolTableStack.empty, `Cannot enter nested symbol table, because symbol table stack is empty` );

		SymbolTableFrame childFrame = _symbolTableStack.back.getChildFrame(sourceIndex);
		loger.internalAssert( childFrame, `Cannot enter child symbol table frame, because it's null` );

		_symbolTableStack ~= childFrame;
	}

	void exitScope()
	{
		import std.range: empty, popBack;
		loger.internalAssert( !_symbolTableStack.empty, "Cannot exit frame, because compiler symbol table stack is empty!" );

		_symbolTableStack.popBack();
	}

	ModuleObject newModuleObject( string moduleName )
	{
		if( moduleName in _moduleObjects )
			loger.error( `Cannot create new module object "` ~ moduleName ~ `", because it already exists!` );

		ModuleObject newModObj = new ModuleObject(moduleName, null);
		_moduleObjects[moduleName] = newModObj;
		return newModObj;
	}

	size_t enterNewCodeObject( ModuleObject moduleObj )
	{
		import std.range: back;
		_codeObjStack ~= new CodeObject(moduleObj);
		return this.addConst( TDataNode(_codeObjStack.back) );
	}

	size_t enterNewCodeObject()
	{
		import std.range: back;
		_codeObjStack ~= new CodeObject( this.currentModule() );
		return this.addConst( TDataNode(_codeObjStack.back) );
	}

	void exitCodeObject()
	{
		import std.range: empty, popBack;
		loger.internalAssert( !_codeObjStack.empty, "Cannot exit frame, because compiler code object stack is empty!" );

		_codeObjStack.popBack();
	}

	size_t addInstr( Instruction instr )
	{
		import std.range: empty, back;
		loger.internalAssert( !_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!" );
		loger.internalAssert( _codeObjStack.back, "Cannot add instruction, because current compiler code object is null!" );

		return _codeObjStack.back.addInstr(instr);
	}

	size_t addInstr( OpCode opcode )
	{
		import std.range: empty, back;
		loger.internalAssert( !_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!" );
		loger.internalAssert( _codeObjStack.back, "Cannot add instruction, because current compiler code object is null!" );

		return _codeObjStack.back.addInstr( Instruction(opcode) );
	}

	size_t addInstr( OpCode opcode, size_t arg )
	{
		import std.range: empty, back;
		loger.internalAssert( !_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!" );
		loger.internalAssert( _codeObjStack.back, "Cannot add instruction, because current compiler code object is null!" );

		return _codeObjStack.back.addInstr( Instruction(opcode, arg) );
	}

	void setInstrArg( size_t index, size_t arg )
	{
		import std.range: empty, back;
		loger.internalAssert( !_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!" );
		loger.internalAssert( _codeObjStack.back, "Cannot add instruction, because current compiler code object is null!" );

		return _codeObjStack.back.setInstrArg( index, arg );
	}

	size_t getInstrCount()
	{
		import std.range: empty, back;
		loger.internalAssert( !_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!" );
		loger.internalAssert( _codeObjStack.back, "Cannot add instruction, because current compiler code object is null!" );

		return _codeObjStack.back.getInstrCount();
	}

	size_t addConst( TDataNode value )
	{
		import std.range: empty, back;
		loger.internalAssert( !_codeObjStack.empty, "Cannot add constant, because compiler code object stack is empty!" );
		loger.internalAssert( _codeObjStack.back, "Cannot add constant, because current compiler code object is null!" );
		loger.internalAssert( _codeObjStack.back._moduleObj, "Cannot add constant, because current module object is null!" );

		return _codeObjStack.back._moduleObj.addConst(value);
	}

	ModuleObject currentModule() @property
	{
		import std.range: empty, back;
		loger.internalAssert( !_codeObjStack.empty, "Cannot get current module object, because compiler code object stack is empty!" );
		loger.internalAssert( _codeObjStack.back, "Cannot get current module object, because current compiler code object is null!" );

		return _codeObjStack.back._moduleObj;
	}

	CodeObject currentCodeObject() @property
	{
		import std.range: empty, back;
		loger.internalAssert( !_codeObjStack.empty, "Cannot get current code object, because compiler code object stack is empty!" );

		return _codeObjStack.back;
	}

	Symbol symbolLookup(string name)
	{
		import std.range: empty, back;
		loger.internalAssert( !_symbolTableStack.empty, `Cannot look for symbol, because symbol table stack is empty` );
		loger.internalAssert( _symbolTableStack.back, `Cannot look for symbol, current symbol table frame is null` );

		Symbol symb = _symbolTableStack.back.lookup(name);
		debug {
			loger.write(`symbolLookup, _symbolTableStack symbols:`);
			foreach( lvl, table; _symbolTableStack[] ) {
				loger.write(`	symbols lvl`, lvl, `: `, table._symbols);
				if( table._moduleFrame ) {
					loger.write(`	module symbols lvl`, lvl, `: `, table._moduleFrame._symbols);
				} else {
					loger.write(`	module frame lvl`, lvl, ` is null`);
				}
			}
		}

		if( symb ) {
			return symb;
		}

		loger.internalAssert(_globalSymbolTable, `Compiler's global symbol table is null`);
		symb = _globalSymbolTable.lookup(name);

		if( !symb ) {
			loger.error( `Cannot find symbol "` ~ name ~ `"` );
		}

		return symb;
	}

	ModuleObject mainModule() @property
	{
		loger.internalAssert( _mainModuleName in _moduleObjects, `Cannot get main module object` );
		return _moduleObjects[_mainModuleName];
	}

	ModuleObject getOrCompileModule(string moduleName)
	{
		if( moduleName !in _moduleObjects )
		{
			// Initiate module object compilation on demand
			IvyNode moduleNode = _moduleRepo.getModuleTree(moduleName);
			loger.internalAssert(moduleNode, `Module node is null`);

			loger.write(`Entering new code object`);
			enterNewCodeObject( newModuleObject(moduleName) );
			loger.write(`Entering module scope`);
			enterModuleScope(moduleName);
			loger.write(`Starting compiling module AST`);
			moduleNode.accept(this);
			loger.write(`Finished compiling module AST`);

			scope(exit)
			{
				loger.write(`Exiting compiler scopes`);
				this.exitScope();
				this.exitCodeObject();
				loger.write(`Compiler scopes exited`);
			}
		}

		loger.write(`Exiting method`);
		return _moduleObjects[moduleName];
	}

	override {
		void visit(IvyNode node) { assert(0); }

		//Expressions
		void visit(IExpression node) { visit( cast(IvyNode) node ); }

		void visit(ILiteralExpression node)
		{
			LiteralType litType;
			size_t constIndex;
			switch( node.literalType )
			{
				case LiteralType.Undef:
					constIndex = addConst( TDataNode() ); // Undef is default
					break;
				case LiteralType.Null:
					constIndex = addConst( TDataNode(null) );
					break;
				case LiteralType.Boolean:
					constIndex = addConst( TDataNode( node.toBoolean() ) );
					break;
				case LiteralType.Integer:
					constIndex = addConst( TDataNode( node.toInteger() ) );
					break;
				case LiteralType.Floating:
					constIndex = addConst( TDataNode( node.toFloating() ) );
					break;
				case LiteralType.String:
					constIndex = addConst( TDataNode( node.toStr() ) );
					break;
				case LiteralType.Array:
					uint arrayLen = 0;
					foreach( IvyNode elem; node.children )
					{
						elem.accept(this);
						++arrayLen;
					}
					addInstr( OpCode.MakeArray, arrayLen );
					return; // Return in order to not add extra instr
				case LiteralType.AssocArray:
					uint aaLen = 0;
					foreach( IvyNode elem; node.children )
					{
						IAssocArrayPair aaPair = cast(IAssocArrayPair) elem;
						if( !aaPair )
							loger.error( "Expected assoc array pair!" );

						size_t aaKeyConstIndex = addConst( TDataNode(aaPair.key) );
						addInstr( OpCode.LoadConst, aaKeyConstIndex );

						if( !aaPair.value )
							loger.error( "Expected assoc array value!" );
						aaPair.value.accept(this);

						++aaLen;
					}
					addInstr( OpCode.MakeAssocArray, aaLen );
					return;
				default:
					loger.internalAssert( false, "Expected literal expression node!" );
					break;
			}

			addInstr( OpCode.LoadConst, constIndex );
		}

		void visit(INameExpression node)
		{
			size_t constIndex = addConst( TDataNode( node.name ) );
			// Load name constant instruction
			addInstr( OpCode.LoadName, constIndex );
		}

		void visit(IOperatorExpression node) { visit( cast(IExpression) node ); }
		void visit(IUnaryExpression node)
		{
			loger.internalAssert( node.expr, "Expression expected!" );
			node.expr.accept(this);

			OpCode opcode;
			switch( node.operatorIndex )
			{
				case Operator.UnaryPlus: opcode = OpCode.UnaryPlus; break;
				case Operator.UnaryMin: opcode = OpCode.UnaryMin; break;
				case Operator.Not: opcode = OpCode.UnaryNot; break;
				default:
					loger.internalAssert( false, "Unexpected unary operator type!" );
			}

			addInstr( opcode );
		}
		void visit(IBinaryExpression node)
		{
			import std.range: back;
			import std.conv: to;

			// Generate code that evaluates left and right parts of binary expression and get result on the stack
			loger.internalAssert( node.leftExpr, "Left expr expected!" );
			loger.internalAssert( node.rightExpr, "Right expr expected!" );

			switch( node.operatorIndex )
			{
				case Operator.And, Operator.Or:
				{
					node.leftExpr.accept(this);
					size_t jumpInstrIndex = addInstr(
						node.operatorIndex == Operator.And? OpCode.JumpIfFalseOrPop: OpCode.JumpIfTrueOrPop
					);
					node.rightExpr.accept(this);

					setInstrArg(jumpInstrIndex, _codeObjStack.back._instrs.length);
					return;
				}
				default:
					break; // Check out other operators
			}

			node.leftExpr.accept(this);
			node.rightExpr.accept(this);

			OpCode opcode;
			switch( node.operatorIndex )
			{
				case Operator.Add: opcode = OpCode.Add; break;
				case Operator.Sub: opcode = OpCode.Sub; break;
				case Operator.Mul: opcode = OpCode.Mul; break;
				case Operator.Div: opcode = OpCode.Div; break;
				case Operator.Mod: opcode = OpCode.Mod; break;
				case Operator.Concat: opcode = OpCode.Concat; break;
				case Operator.Equal: opcode = OpCode.Equal; break;
				case Operator.NotEqual: opcode = OpCode.NotEqual; break;
				case Operator.LT: opcode = OpCode.LT; break;
				case Operator.GT: opcode = OpCode.GT; break;
				case Operator.LTEqual: opcode = OpCode.LTEqual; break;
				case Operator.GTEqual: opcode = OpCode.GTEqual; break;
				default:
					loger.internalAssert( false, "Unexpected binary operator type: ", (cast(Operator) node.operatorIndex) );
			}

			addInstr( opcode );
		}

		void visit(IAssocArrayPair node) { visit( cast(IExpression) node ); }

		//Statements
		void visit(IStatement node) { visit( cast(IvyNode) node ); }
		void visit(IKeyValueAttribute node) { visit( cast(IvyNode) node ); }

		void visit(IDirectiveStatement node)
		{
			import std.range: empty, front, popFront;

			if( auto comp = node.name in _dirCompilers )
			{
				comp.compile( node, this );
			}
			else
			{
				auto attrRange = node[];

				Symbol symb = this.symbolLookup( node.name );
				if( symb.kind != SymbolKind.DirectiveDefinition )
					loger.error(`Expected directive definition symbol kind`);

				DirectiveDefinitionSymbol dirSymbol = cast(DirectiveDefinitionSymbol) symb;
				loger.internalAssert( dirSymbol, `Directive definition symbol is null` );

				DirAttrsBlock!(true)[] dirAttrBlocks = dirSymbol.dirAttrBlocks[]; // Getting slice of list

				// Add instruction to load directive object from context by name
				size_t dirNameConstIndex = addConst( TDataNode(node.name) );
				addInstr( OpCode.LoadName, dirNameConstIndex );

				// Keeps count of stack arguments actualy used by this call. First is directive object
				size_t stackItemsCount = 1;

				loger.write(`Entering directive attrs blocks loop`);
				while( !dirAttrBlocks.empty )
				{
					final switch( dirAttrBlocks.front.kind )
					{
						case DirAttrKind.NamedAttr:
						{
							size_t argCount = 0;
							bool[string] argsSet;

							DirAttrsBlock!(true) namedAttrsDef = dirAttrBlocks.front;
							while( !attrRange.empty )
							{
								IKeyValueAttribute keyValueAttr = cast(IKeyValueAttribute) attrRange.front;
								if( !keyValueAttr ) {
									break; // We finished with key-value attributes
								}

								if( keyValueAttr.name !in namedAttrsDef.namedAttrs )
									loger.error(`Unexpected named attribute "` ~ keyValueAttr.name ~ `"`);
								
								if( keyValueAttr.name in argsSet )
									loger.error(`Duplicate named attribute "` ~ keyValueAttr.name ~ `" detected`);

								// Add name of named argument into stack
								size_t nameConstIndex = addConst( TDataNode(keyValueAttr.name) );
								addInstr( OpCode.LoadConst, nameConstIndex );
								++stackItemsCount;

								// Compile value expression (it should put result value on the stack)
								keyValueAttr.value.accept(this);
								++stackItemsCount;

								++argCount;
								argsSet[keyValueAttr.name] = true;
								attrRange.popFront();
							}

							foreach( name, attrDecl; namedAttrsDef.namedAttrs )
							{
								if( name !in argsSet )
								{
									IExpression defVal = namedAttrsDef.namedAttrs[name].defaultValueExpr;

									if( defVal )
									{
										// Add name of named argument into stack
										size_t nameConstIndex = addConst( TDataNode(name) );
										addInstr(OpCode.LoadConst, nameConstIndex);
										++stackItemsCount;

										// Generate code to set default values
										defVal.accept(this);
										++stackItemsCount;
										++argCount;
									}
								}
							}

							// Add instruction to load value that consists of number of pairs in block and type of block
							size_t blockHeader = ( argCount << _stackBlockHeaderSizeOffset ) + DirAttrKind.NamedAttr;
							size_t blockHeaderConstIndex = addConst( TDataNode(blockHeader) );
							addInstr(OpCode.LoadConst, blockHeaderConstIndex);
							++stackItemsCount; // We should count args block header
							break;
						}
						case DirAttrKind.ExprAttr:
						{
							size_t argCount = 0;

							auto exprAttrDefs = dirAttrBlocks.front.exprAttrs[];
							while( !attrRange.empty )
							{
								IExpression exprAttr = cast(IExpression) attrRange.front;
								if( !exprAttr ) {
									break; // We finished with positional attributes
								}

								if( exprAttrDefs.empty ) {
									loger.error(`Got more positional arguments than expected!`);
								}

								exprAttr.accept(this);
								++stackItemsCount;
								++argCount;

								attrRange.popFront(); exprAttrDefs.popFront();
							}

							while( !exprAttrDefs.empty )
							{
								IExpression defVal = exprAttrDefs.front.defaultValueExpr;
								if( !defVal )
									loger.error(`Positional attribute is not passed explicitly and has no default value`);

								defVal.accept(this);
								++stackItemsCount;
								++argCount;
								exprAttrDefs.popFront();
							}

							// Add instruction to load value that consists of number of positional arguments in block and type of block
							size_t blockHeader = ( argCount << _stackBlockHeaderSizeOffset ) + DirAttrKind.ExprAttr;
							size_t blockHeaderConstIndex = addConst( TDataNode(blockHeader) );
							addInstr(OpCode.LoadConst, blockHeaderConstIndex);
							++stackItemsCount; // We should count args block header
							break;
						}
						case DirAttrKind.IdentAttr:
						{
							loger.internalAssert( false );
							// TODO: We should take number of identifiers passed in directive definition
							while( !attrRange.empty ) {
								IExpression identAttr = cast(INameExpression) attrRange.front;
								if( !identAttr ) {
									break;
								}

								attrRange.popFront();
							}
							break;
						}
						case DirAttrKind.KwdAttr:
						{
							loger.internalAssert( false );
							DirAttrsBlock!(true) kwdDef = dirAttrBlocks.front;
							INameExpression kwdAttr = attrRange.takeFrontAs!INameExpression( `Expected keyword attribute` );
							if( kwdDef.keyword != kwdAttr.name )
								loger.error( `Expected "` ~ kwdDef.keyword ~ `" keyword attribute` );
							break;
						}
						case DirAttrKind.BodyAttr:
							break;
					}
					dirAttrBlocks.popFront();
				}
				loger.write(`Exited directive attrs blocks loop`);

				if( !attrRange.empty ) {
					loger.error( `Not all directive attributes processed correctly. Seems that there are unexpected attributes or missing ;` );
				}

				// After all preparations add instruction to call directive
				addInstr( OpCode.RunCallable, stackItemsCount );
			}
		}

		void visit(IDataFragmentStatement node)
		{
			// Nothing special. Just store this piece of data into table
			size_t constIndex = addConst( TDataNode(node.data) );
			addInstr( OpCode.LoadConst, constIndex );
		}

		void visit(ICompoundStatement node)
		{
			loger.internalAssert( false, `Shouldn't fall into this!` );
		}

		void visit(ICodeBlockStatement node)
		{
			if( !node )
				loger.error( "Code block statement node is null!" );
			
			if( node.isListBlock )
			{
				TDataNode emptyArray = TDataNode[].init;
				size_t emptyArrayConstIndex = addConst(emptyArray);
				addInstr( OpCode.LoadConst, emptyArrayConstIndex );
			}
			
			auto stmtRange = node[];
			while( !stmtRange.empty )
			{
				stmtRange.front.accept( this );
				stmtRange.popFront();

				if( node.isListBlock )
				{
					addInstr( OpCode.Append ); // Append result to result array
				}
				else if( !stmtRange.empty )
				{
					addInstr( OpCode.PopTop );
				}
			}
		}

		void visit(IMixedBlockStatement node)
		{
			if( !node )
				loger.error( "Mixed block statement node is null!" );

			TDataNode emptyArray = TDataNode[].init;
			size_t emptyArrayConstIndex = addConst(emptyArray);
			addInstr( OpCode.LoadConst, emptyArrayConstIndex );

			size_t renderDirNameConstIndex = addConst( TDataNode("__render__") );
			size_t resultNameConstIndex = addConst( TDataNode("__result__") );

			// In order to make call to __render__ creating block header for one positional argument
			// witch is currently at the TOP of the execution stack
			size_t blockHeader = ( 1 << _stackBlockHeaderSizeOffset ) + DirAttrKind.NamedAttr; //TODO: Change block type magic constant to enum!
			size_t blockHeaderConstIndex = addConst( TDataNode(blockHeader) ); // Add it to constants

			auto stmtRange = node[];
			while( !stmtRange.empty )
			{
				addInstr( OpCode.LoadName, renderDirNameConstIndex ); // Load __render__ directive
				
				// Add name for key-value argument
				addInstr( OpCode.LoadConst, resultNameConstIndex );
				
				stmtRange.front.accept( this );
				stmtRange.popFront();

				addInstr( OpCode.LoadConst, blockHeaderConstIndex ); // Add argument block header

				// Stack layout is:
				// TOP: argument block header
				// TOP - 1: Current result argument
				// TOP - 2: Current result var name argument
				// TOP - 3: Callable object for __render__
				addInstr( OpCode.RunCallable, 4 );
				
				addInstr( OpCode.Append ); // Append result to result array
			}
		}
	}

	ModuleObject[string] moduleObjects() @property
	{
		return _moduleObjects;
	}

	// Runs main compiler phase starting from main module
	void run()
	{
		// We create __render__ invocation on the result of module execution !!!
		
		IvyNode mainModuleAST = _moduleRepo.getModuleTree(_mainModuleName);

		size_t renderDirNameConstIndex = addConst( TDataNode("__render__") );
		size_t resultNameConstIndex = addConst( TDataNode("__result__") );

		// In order to make call to __render__ creating block header for one positional argument
		// which is currently at the TOP of the execution stack
		size_t blockHeader = ( 1 << _stackBlockHeaderSizeOffset ) + DirAttrKind.NamedAttr;
		size_t blockHeaderConstIndex = addConst( TDataNode(blockHeader) ); // Add it to constants

		addInstr( OpCode.LoadName, renderDirNameConstIndex ); // Load __render__ directive
				
		// Add name for key-value argument
		addInstr( OpCode.LoadConst, resultNameConstIndex );
		
		mainModuleAST.accept(this);

		addInstr( OpCode.LoadConst, blockHeaderConstIndex ); // Add argument block header

		// Stack layout is:
		// TOP: argument block header
		// TOP - 1: Current result argument
		// TOP - 2: Current result var name argument
		// TOP - 3: Callable object for __render__
		addInstr( OpCode.RunCallable, 4 );
	}

	string toPrettyStr()
	{
		import std.conv;
		import std.range: empty, back;

		string result;

		foreach( modName, modObj; _moduleObjects )
		{
			result ~= "\r\nMODULE " ~ modName ~ "\r\n";
			result ~= "\r\nCONSTANTS\r\n";
			foreach( i, con; modObj._consts )
			{
				result ~= i.text ~ "  " ~ con.toString() ~ "\r\n";
			}

			result ~= "\r\nCODE\r\n";
			foreach( i, con; modObj._consts )
			{
				if( con.type == DataNodeType.CodeObject )
				{
					if( !con.codeObject )
					{
						result ~= "\r\nCode object " ~ i.text ~ " is null\r\n";
					}
					else
					{
						result ~= "\r\nCode object " ~ i.text ~ "\r\n";
						foreach( k, instr; con.codeObject._instrs )
						{
							result ~= k.text ~ "  " ~ instr.opcode.text ~ "  " ~ instr.arg.text ~ "\r\n";
						}
					}
				}
			}
			result ~= "\r\nEND OF MODULE " ~ modName ~ "\r\n";

		}

		return result;
	}

}