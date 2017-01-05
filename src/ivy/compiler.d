/// Module implements compilation of Ivy abstract syntax tree into bytecode
module ivy.compiler;

import ivy.node;
import ivy.node_visitor;
import ivy.bytecode;
import ivy.interpreter_data;

class ASTNodeTypeException: Exception
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


class CompilerException: Exception
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}

}

void compilerError(string msg, string file = __FILE__, size_t line = __LINE__)
{
	throw new CompilerException(msg, file, line);
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

private:
	string _rootPath;
	string _fileExtension;
	IvyNode[string] _moduleTrees;

public:
	this( string rootPath = ".", string fileExtension = ".ivy" )
	{
		_rootPath = rootPath;
		_fileExtension = fileExtension;
	}

	void loadModuleFromFile(string moduleName)
	{
		import std.algorithm: splitter, startsWith;
		import std.array: array;
		import std.range: only, chain, empty;
		import std.path: buildNormalizedPath;
		import std.file: read;

		// The module name is given. Try to build path to it
		string fileName = buildNormalizedPath( only(_rootPath).chain( moduleName.splitter('.') ).array ) ~ _fileExtension;
		debug writeln( "loadModuleFromFile fileName: ", fileName, ", rootPath: ", buildNormalizedPath(_rootPath) );

		// Check if file name is not empty and located in root path
		if( fileName.empty || !fileName.startsWith( buildNormalizedPath(_rootPath) ) )
			compilerError( `Incorrect path to module: ` ~ fileName );

		string fileContent = cast(string) std.file.read(fileName);

		import ivy.parser;
		auto parser = new Parser!(TextRange)(fileContent, fileName);

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


class AttributeDeclaration
{
	string attrName;
	string attrType;
	IExpression defaultValueExpr;

	this( string name, string type, IExpression defValue )
	{
		attrName = name;
		attrType = type;
		defaultValueExpr = defValue;
	}
}

enum DirDefAttrType { NamedAttr, ExprAttr, IdentAttr, KwdAttr, NoscopeAttr, BodyAttr }

class DirectiveDefinitionBlock
{
	DirDefAttrType type;

	this( DirDefAttrType type )
	{
		this.type = type;
	}
}

class NamedAttrsDefBlock: DirectiveDefinitionBlock
{
	AttributeDeclaration[string] namedDecls;

	this() { super( DirDefAttrType.NamedAttr ); }

	this( AttributeDeclaration[string] namedDecls )
	{
		super( DirDefAttrType.NamedAttr );
		this.namedDecls = namedDecls;
	}

}

class ExprAttrsDefBlock: DirectiveDefinitionBlock
{
	AttributeDeclaration[] exprDecls;

	this() { super( DirDefAttrType.ExprAttr ); }

	this( AttributeDeclaration[] exprDecls )
	{
		super( DirDefAttrType.ExprAttr );
		this.exprDecls = exprDecls;
	}
}

class IdentAttrsDefBlock: DirectiveDefinitionBlock
{
	string[] names;

	this() { super( DirDefAttrType.IdentAttr ); }

	this( string[] names )
	{
		super( DirDefAttrType.IdentAttr );
		this.names = names;
	}
}

class KwdAttrDef: DirectiveDefinitionBlock
{
	string keyword;

	this() { super( DirDefAttrType.KwdAttr ); }

	this( string keyword )
	{
		super( DirDefAttrType.KwdAttr );
		this.keyword = keyword;
	}
}

class BodyAttrDef: DirectiveDefinitionBlock
{
	ICompoundStatement bodyAST;

	this() { super( DirDefAttrType.BodyAttr ); }

	this( ICompoundStatement bodyAST )
	{
		super( DirDefAttrType.BodyAttr );
		this.bodyAST = bodyAST;
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
	DirectiveDefinitionBlock[] dirDefBlocks;

public:
	this( string name, DirectiveDefinitionBlock[] dirDefBlocks )
	{
		this.name = name;
		this.kind = SymbolKind.DirectiveDefinition;
		this.dirDefBlocks = dirDefBlocks;
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
	Symbol[string] _symbols;
	SymbolTableFrame _moduleFrame;
	SymbolTableFrame[size_t] _childFrames; // size_t - is index of scope start in source code?

public:
	this(SymbolTableFrame moduleFrame)
	{
		_moduleFrame = moduleFrame;
	}

	Symbol localLookup(string name)
	{
		return _symbols.get(name, null);
	}

	Symbol lookup(string name)
	{
		if( Symbol* symb = name in _symbols )
			return *symb;

		// We need to try to look in module symbol table
		if( Symbol symb = moduleLookup(name) )
			return symb;

		if( !_moduleFrame )
			return null;

		return _moduleFrame.lookup(name);
	}

	Symbol moduleLookup(string name)
	{
		import std.algorithm: splitter;
		import std.string: join;
		import std.range: take, drop;
		import std.array: array;

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

	void add( Symbol symb )
	{
		_symbols[symb.name] = symb;
	}

	SymbolTableFrame getChildFrame(size_t sourceIndex)
	{
		return _childFrames.get(sourceIndex, null);
	}

	SymbolTableFrame newChildFrame(size_t sourceIndex)
	{
		if( sourceIndex in _childFrames )
			compilerError( `Child frame already exists!` );

		SymbolTableFrame child = new SymbolTableFrame(_moduleFrame);
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
private:
	CompilerModuleRepository _moduleRepo;
	SymbolTableFrame[string] _moduleSymbols;
	string[] _moduleStack;
	SymbolTableFrame[] _frameStack;

public:
	this( CompilerModuleRepository moduleRepo, string mainModuleName )
	{
		import std.range: back;
		_moduleRepo = moduleRepo;
		_moduleStack ~= mainModuleName;
		_frameStack ~= new SymbolTableFrame(null);
		_moduleSymbols[mainModuleName] = _frameStack.back;
	}

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

			if( node.name == "def" )
			{
				//if( !_currentFrame )
				//	compilerError( "Current symbol table frame is null" );

				IAttributeRange defAttrsRange = node[];

				INameExpression dirNameExpr = defAttrsRange.takeFrontAs!INameExpression("Expected directive name");
				ICodeBlockStatement attrsDefBlockStmt = defAttrsRange.takeFrontAs!ICodeBlockStatement("Expected code block as directive attributes definition");

				IDirectiveStatementRange attrsDefStmtRange = attrsDefBlockStmt[];

				bool isNoscope = false;
				ICompoundStatement bodyStmt;

				DirectiveDefinitionBlock[] dirDefBlocks;

				attr_def_stmts_loop:
				while( !attrsDefStmtRange.empty )
				{
					IDirectiveStatement attrsDefStmt = attrsDefStmtRange.front; // Current attributes definition statement
					IAttributeRange attrsDefStmtAttrRange = attrsDefStmt[]; // Range on attributes of attributes definition statement

					switch( attrsDefStmt.name )
					{
						case "def.kv": {
							NamedAttrsDefBlock attrDefBlock = new NamedAttrsDefBlock();
							while( !attrsDefStmtAttrRange.empty )
							{
								AttributeDeclaration attrDecl = analyzeValueAttr(attrsDefStmtAttrRange);
								if( !attrDecl )
								{
									attrsDefStmtRange.popFront();
									continue attr_def_stmts_loop;
								}

								if( attrDecl.attrName in attrDefBlock.namedDecls )
									compilerError( `Named attribute "` ~ attrDecl.attrName ~ `" already defined in directive definition` );

								attrDefBlock.namedDecls[attrDecl.attrName] = attrDecl;
							}

							dirDefBlocks ~= attrDefBlock;
							break;
						}
						case "def.pos":
						{
							ExprAttrsDefBlock attrDefBlock = new ExprAttrsDefBlock();
							while( !attrsDefStmtAttrRange.empty )
							{
								AttributeDeclaration attrDecl = analyzeValueAttr(attrsDefStmtAttrRange);
								if( !attrDecl )
								{
									attrsDefStmtRange.popFront();
									continue attr_def_stmts_loop;
								}


								if( attrDefBlock.exprDecls.canFind!( (it, needle) => it.attrName == needle )(attrDecl.attrName) )
									compilerError( `Named attribute "` ~ attrDecl.attrName ~ `" already defined in directive definition` );

								attrDefBlock.exprDecls ~= attrDecl;
							}

							dirDefBlocks ~= attrDefBlock;
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
								compilerError( `Multiple body statements are not allowed!` );

							if( attrsDefStmtAttrRange.empty )
								compilerError( "Unexpected end of def.body directive!" );
							
							// Try to parse noscope flag
							INameExpression noscopeExpr = cast(INameExpression) attrsDefStmtAttrRange.front;
							if( noscopeExpr && noscopeExpr.name == "noscope" )
							{
								isNoscope = true;
								if( attrsDefStmtAttrRange.empty )
									compilerError( "Expected directive body, but end of def.body directive found!" );
								attrsDefStmtAttrRange.popFront();
							}

							bodyStmt = cast(ICompoundStatement) attrsDefStmtAttrRange.front; // Getting body AST for statement
							if( !bodyStmt )
								compilerError( "Expected compound statement as directive body statement" );

							break;
						default:
							break;
					}

					attrsDefStmtRange.popFront();
				}

				if( _frameStack.empty )
					compilerError( `Cannot store symbol, because fu** you.. Oops.. because symbol table frame stack is empty` );
				if( !_frameStack.back )
					compilerError( `Cannot store symbol, because symbol table frame is null` );
				// Add directive definition into existing frame
				_frameStack.back.add( new DirectiveDefinitionSymbol(dirNameExpr.name, dirDefBlocks) );

				if( bodyStmt && !isNoscope )
				{
					// Create new frame for body if not forbidden
					_frameStack ~= _frameStack.back.newChildFrame(bodyStmt.location.index);
				}

				scope(exit)
				{
					if( bodyStmt && !isNoscope )
					{
						_frameStack.popBack();
					}
				}

				if( bodyStmt )
				{
					// Analyse nested tree
					bodyStmt.accept(this);
				}

				if( !defAttrsRange.empty )
					compilerError( `Expected end of directive definition statement. Maybe ; is missing` );
			}
			else if( node.name == "import" )
			{
				IAttributeRange attrRange = node[];
				if( attrRange.empty )
					compilerError( `Expected module name in import statement, but got end of directive` );

				INameExpression moduleNameExpr = attrRange.takeFrontAs!INameExpression("Expected module name in import directive");

				if( !attrRange.empty )
					compilerError( `Expected end of import directive, maybe ; is missing` );

				// Try to open, parse and load symbols info from another module
				IvyNode moduleTree = _moduleRepo.getModuleTree( moduleNameExpr.name );

				if( !moduleTree )
					compilerError( `Couldn't load module: ` ~ moduleNameExpr.name );

				{
					_moduleStack ~= moduleNameExpr.name;
					_frameStack ~= new SymbolTableFrame(null);
					_moduleSymbols[moduleNameExpr.name] = _frameStack.back;
					scope(exit)
					{
						assert( !_moduleStack.empty, `Compiler directive collector module stack is empty!` );
						_moduleStack.popBack(); // We will exit module when finish with it
						assert( !_frameStack.empty, `Compiler directive collector frame stack is empty!` );
						_frameStack.popBack();
					}

					// Go to find directive definitions in this imported module
					moduleTree.accept(this);
				}

				assert( !_frameStack.empty, "Cannot store imported symbols, because symbol table frame stack is empty!" );
				assert( _frameStack.back, "Cannot store imported symbols, because symbol table stack is null!" );
				_frameStack.back.add( new ModuleSymbol(moduleNameExpr.name, _moduleSymbols[moduleNameExpr.name] ) );

			}
			else
			{
				foreach( childNode; node )
				{
					childNode.accept(this);
				}
			}

			// TODO: Check if needed to analyse other directive attributes scopes
		}
		void visit(IDataFragmentStatement node) {  }
		void visit(ICompoundStatement node)
		{
			foreach( childNode; node )
			{
				childNode.accept(this);
			}

		}
	}

	AttributeDeclaration analyzeValueAttr(IAttributeRange attrRange)
	{
		string attrName;
		string attrType;
		IExpression defaultValueExpr;

		if( auto kwPair = cast(IKeyValueAttribute) attrRange.front )
		{
			attrName = kwPair.name;
			defaultValueExpr = cast(IExpression) kwPair.value;
			if( !defaultValueExpr )
				compilerError( `Expected attribute default value expression!` );

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
			return null;
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
						compilerError( `Expected attr type definition, but got end of attrs range!` );

					auto attrTypeExpr = cast(INameExpression) attrRange.front;
					if( !attrTypeExpr )
						compilerError( `Expected attr type definition!` );

					attrType = attrTypeExpr.name; // Getting type of attribute as string (for now)

					attrRange.popFront(); // Skip type expression
				}
			}
		}

		return new AttributeDeclaration(attrName, attrType, defaultValueExpr);
	}

	string currentModuleName() @property
	{
		import std.range: back, empty;
		if( _moduleStack.empty )
			return null;

		return _moduleStack.back;
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
		import std.range: back;
		IvyNode ast = _moduleRepo.getModuleTree( _moduleStack.back );
		ast.accept(this);
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
			compilerError( `Expected "var" directive statement!` );

		auto stmtRange = stmt[];
		while( !stmtRange.empty )
		{
			size_t varNameConstIndex;
			if( auto kwPair = cast(IKeyValueAttribute) stmtRange.front )
			{
				if( kwPair.name.empty )
					compilerError( `Variable name cannot be empty` );
				varNameConstIndex = compiler.addConst( TDataNode(kwPair.name) );

				if( !kwPair.value )
					compilerError( "Expected value for 'var' directive" );

				kwPair.value.accept(compiler); // Compile expression for getting value
				stmtRange.popFront();
			}
			else if( auto nameExpr = cast(INameExpression) stmtRange.front )
			{
				if( nameExpr.name.empty )
					compilerError( `Variable name cannot be empty` );
				varNameConstIndex = compiler.addConst( TDataNode(nameExpr.name) );

				stmtRange.popFront();
			}
			else
			{
				compilerError( `Expected named attribute or name as variable declarator!` );
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
							compilerError( `Expected variable type declaration` );

						// For now just skip type expression
						stmtRange.popFront();
					}
				}
			}

			compiler.addInstr( OpCode.StoreLocalName, varNameConstIndex );
		}

		if( !stmtRange.empty )
			compilerError( "Expected end of directive after key-value pair. Maybe ';' is missing" );
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
class SetInterpreter : IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "set"  )
			compilerError( "Expected 'set' directive" );

		auto stmtRange = statement[];

		while( !stmtRange.empty )
		{
			IKeyValueAttribute kwPair = stmtRange.takeFrontAs!IKeyValueAttribute("Key-value pair expected");

			if( !kwPair.value )
				compilerError( "Expected value for 'set' directive" );

			kwPair.value.accept(compiler); //Evaluating expression

			size_t varNameConstIndex = compiler.addConst( TDataNode( kwPair.name ) );
			compiler.addInstr( OpCode.StoreName, varNameConstIndex );
		}

		if( !stmtRange.empty )
			compilerError( "Expected end of directive after key-value pair. Maybe ';' is missing" );
	}

}

class IfCompiler: IDirectiveCompiler
{
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "if" )
			compilerError( `Expected "if" directive statement!` );

		import std.typecons: Tuple;
		import std.range: back, empty;
		alias IfSect = Tuple!(IExpression, "cond", IStatement, "stmt");

		IfSect[] ifSects;
		IStatement elseBody;

		auto stmtRange = statement[];

		IExpression condExpr = stmtRange.takeFrontAs!IExpression( "Conditional expression expected" );
		IStatement bodyStmt = stmtRange.takeFrontAs!IStatement( "'If' directive body statement expected" );

		ifSects ~= IfSect(condExpr, bodyStmt);

		while( !stmtRange.empty )
		{
			INameExpression keywordExpr = stmtRange.takeFrontAs!INameExpression("'elif' or 'else' keyword expected");
			if( keywordExpr.name == "elif" )
			{
				condExpr = stmtRange.takeFrontAs!IExpression( "'elif' conditional expression expected" );
				bodyStmt = stmtRange.takeFrontAs!IStatement( "'elif' body statement expected" );

				ifSects ~= IfSect(condExpr, bodyStmt);
			}
			else if( keywordExpr.name == "else" )
			{
				elseBody = stmtRange.takeFrontAs!IStatement( "'else' body statement expected" );
				if( !stmtRange.empty )
					compilerError("'else' statement body expected to be the last 'if' attribute. Maybe ';' is missing");
				break;
			}
			else
			{
				compilerError("'elif' or 'else' keyword expected");
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
			compilerError( `Expected end of "if" directive. Maybe ';' is missing` );

	}

}


class ForCompiler : IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "for"  )
			compilerError( "Expected 'for' directive" );

		auto stmtRange = statement[];

		INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("For loop variable name expected");

		string varName = varNameExpr.name;
		if( varName.length == 0 )
			compilerError("Loop variable name cannot be empty");

		INameExpression inAttribute = stmtRange.takeFrontAs!INameExpression("Expected 'in' attribute");

		if( inAttribute.name != "in" )
			compilerError( "Expected 'in' keyword" );

		IExpression aggregateExpr = stmtRange.takeFrontAs!IExpression("Expected 'for' aggregate expression");

		// Compile code to calculate aggregate value
		aggregateExpr.accept(compiler);

		ICompoundStatement bodyStmt = stmtRange.takeFrontAs!ICompoundStatement( "Expected loop body statement" );

		if( !stmtRange.empty )
			compilerError( "Expected end of directive after loop body. Maybe ';' is missing" );

		// TODO: Check somehow if aggregate has supported type

		// Issue instruction to get iterator from aggregate in execution stack
		compiler.addInstr( OpCode.GetDataRange );

		size_t loopStartInstrIndex = compiler.addInstr( OpCode.RunLoop );
		size_t varNameConstIndex = compiler.addConst( TDataNode(varName) );

		// Issue command to store current loop item in local context with specified name
		compiler.addInstr( OpCode.StoreLocalName, varNameConstIndex );
		compiler.addInstr( OpCode.PopTop ); // Drop extra empty node left from StoreLocalName

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

class RepeatCompiler : IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "repeat"  )
			compilerError( "Expected 'repeat' directive" );

		auto stmtRange = statement[];

		INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("Loop variable name expected");

		string varName = varNameExpr.name;
		if( varName.length == 0 )
			compilerError("Loop variable name cannot be empty");

		INameExpression inAttribute = stmtRange.takeFrontAs!INameExpression("Expected 'in' attribute");

		if( inAttribute.name != "in" )
			compilerError( "Expected 'in' keyword" );

		IExpression aggregateExpr = stmtRange.takeFrontAs!IExpression("Expected loop aggregate expression");

		// Compile code to calculate aggregate value
		aggregateExpr.accept(compiler);

		ICompoundStatement bodyStmt = stmtRange.takeFrontAs!ICompoundStatement( "Expected loop body statement" );

		if( !stmtRange.empty )
			compilerError( "Expected end of directive after loop body. Maybe ';' is missing" );

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
		compiler.addInstr( OpCode.PopTop ); // Drop extra empty node left from StoreLocalName
		
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
			compilerError( `Expected "expr" directive statement!` );

		auto stmtRange = stmt[];
		if( stmtRange.empty )
			compilerError( `Expected node as "expr" argument!` );

		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( !stmtRange.empty )
			compilerError( `Expected end of "expr" directive. Maybe ';' is missing` );
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
private:
	string _importPath = "test/";

public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "import"  )
			compilerError( "Expected 'import' directive" );

		auto stmtRange = statement[];

		INameExpression moduleNameExpr = stmtRange.takeFrontAs!INameExpression("Expected module name for import");
		if( !stmtRange.empty )
			compilerError( `Not all attributes for directive "import" were parsed. Maybe ; is missing somewhere` );

		ModuleObject modObject = compiler.getOrCompileModule(moduleNameExpr.name);

		size_t modNameConstIndex = compiler.addConst( TDataNode(moduleNameExpr.name) );
		compiler.addInstr( OpCode.LoadConst, modNameConstIndex );

		compiler.addInstr( OpCode.ImportModule );
	}

}

import std.stdio;
/// Defines directive using ivy language
class DefCompiler: IDirectiveCompiler
{
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "def" )
			compilerError( "Expected 'def' directive" );

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
							compilerError( "Multiple body statements are not allowed!!!" );

						if( attrsDefStmtAttrRange.empty )
							compilerError( "Unexpected end of def.body directive!" );
						
						// Try to parse noscope flag
						INameExpression noscopeExpr = cast(INameExpression) attrsDefStmtAttrRange.front;
						if( noscopeExpr && noscopeExpr.name == "noscope" )
						{
							isNoscope = true;
							if( attrsDefStmtAttrRange.empty )
								compilerError( "Expected directive body, but end of def.body directive found!" );
							attrsDefStmtAttrRange.popFront();
						}

						bodyStatement = cast(ICompoundStatement) attrsDefStmtAttrRange.front; // Getting body AST for statement
						if( !bodyStatement )
							compilerError( "Expected compound statement as directive body statement" );

						break;
					}
					default: {
						compilerError( `Unexpected directive attribute definition statement "` ~ attrDefStmt.name ~ `"` );
						break;
					}
				}
				attrDefStmtRange.popFront(); // Going to the next directive statement in code block
			}
			stmtRange.popFront(); // Go to next attr definition directive
		}

		// Here should go commands to compile directive body

		size_t codeObjIndex;
		{
			if( !isNoscope )
			{
				// Compiler should enter frame of directive body, identified by index in source code
				compiler.enterScope( bodyStatement.location.index );
			}

			codeObjIndex = compiler.enterNewCodeObject(); // Creating code object

			// Generating code for def.body
			bodyStatement.accept(compiler);

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
private:

	// Dictionary of native compilers for directives
	IDirectiveCompiler[string] _dirCompilers;

	// Dictionary maps module name to it's root symbol table frame
	SymbolTableFrame[string] _modulesSymbolTables;

	// Compiler's storage for parsed module ASTs
	CompilerModuleRepository _moduleRepo;

	// Dictionary with module objects that compiler produces
	ModuleObject[string] _moduleObjects;

	// Current stack of symbol table frames
	SymbolTableFrame[] _symbolTableStack;

	// Current stack of code objects that compiler produces
	CodeObject[] _codeObjStack;

	string _mainModuleName;

public:
	this( CompilerModuleRepository moduleRepo, SymbolTableFrame[string] symbolTables, string mainModuleName )
	{
		_moduleRepo = moduleRepo;
		_modulesSymbolTables = symbolTables;

		_dirCompilers["var"] = new VarCompiler();
		_dirCompilers["expr"] = new ExprCompiler();
		_dirCompilers["if"] = new IfCompiler();
		_dirCompilers["for"] = new ForCompiler();
		_dirCompilers["repeat"] = new RepeatCompiler();
		_dirCompilers["def"] = new DefCompiler();
		_dirCompilers["import"] = new ImportCompiler();

		_mainModuleName = mainModuleName;
		enterModuleScope(mainModuleName);
		enterNewCodeObject( newModuleObject(mainModuleName) );
	}

	void enterModuleScope( string moduleName )
	{
		debug writeln( `_modulesSymbolTables: `, _modulesSymbolTables );
		if( auto table = moduleName in _modulesSymbolTables )
		{
			assert( *table, `Cannot enter module sybol table frame, because it is null` );
			_symbolTableStack ~= *table;
		}
		else
		{
			compilerError( `Cannot enter module symbol table, because module "` ~ moduleName ~ `" not found!` );
		}
	}

	void enterScope( size_t sourceIndex )
	{
		import std.range: empty, back;
		assert( !_symbolTableStack.empty, `Cannot enter nested symbol table, because symbol table stack is empty` );

		SymbolTableFrame childFrame = _symbolTableStack.back.getChildFrame(sourceIndex);
		assert( childFrame, `Cannot enter child symbol table frame, because it's null` );

		_symbolTableStack ~= childFrame;
	}

	void exitScope()
	{
		import std.range: empty, popBack;
		assert( !_symbolTableStack.empty, "Cannot exit frame, because compiler symbol table stack is empty!" );

		_symbolTableStack.popBack();
	}

	ModuleObject newModuleObject( string moduleName )
	{
		if( moduleName in _moduleObjects )
			compilerError( `Cannot create new module object "` ~ moduleName ~ `", because it already exists!` );

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
		assert( !_codeObjStack.empty, "Cannot exit frame, because compiler code object stack is empty!" );

		_codeObjStack.popBack();
	}

	size_t addInstr( Instruction instr )
	{
		import std.range: empty, back;
		assert( !_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!" );
		assert( _codeObjStack.back, "Cannot add instruction, because current compiler code object is null!" );

		return _codeObjStack.back.addInstr(instr);
	}

	size_t addInstr( OpCode opcode )
	{
		import std.range: empty, back;
		assert( !_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!" );
		assert( _codeObjStack.back, "Cannot add instruction, because current compiler code object is null!" );

		return _codeObjStack.back.addInstr( Instruction(opcode) );
	}

	size_t addInstr( OpCode opcode, size_t arg )
	{
		import std.range: empty, back;
		assert( !_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!" );
		assert( _codeObjStack.back, "Cannot add instruction, because current compiler code object is null!" );

		return _codeObjStack.back.addInstr( Instruction(opcode, arg) );
	}

	void setInstrArg( size_t index, size_t arg )
	{
		import std.range: empty, back;
		assert( !_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!" );
		assert( _codeObjStack.back, "Cannot add instruction, because current compiler code object is null!" );

		return _codeObjStack.back.setInstrArg( index, arg );
	}

	size_t getInstrCount()
	{
		import std.range: empty, back;
		assert( !_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!" );
		assert( _codeObjStack.back, "Cannot add instruction, because current compiler code object is null!" );

		return _codeObjStack.back.getInstrCount();
	}

	size_t addConst( TDataNode value )
	{
		import std.range: empty, back;
		assert( !_codeObjStack.empty, "Cannot add constant, because compiler code object stack is empty!" );
		assert( _codeObjStack.back, "Cannot add constant, because current compiler code object is null!" );
		assert( _codeObjStack.back._moduleObj, "Cannot add constant, because current module object is null!" );

		return _codeObjStack.back._moduleObj.addConst(value);
	}

	ModuleObject currentModule() @property
	{
		import std.range: empty, back;
		assert( !_codeObjStack.empty, "Cannot get current module object, because compiler code object stack is empty!" );
		assert( _codeObjStack.back, "Cannot get current module object, because current compiler code object is null!" );

		return _codeObjStack.back._moduleObj;
	}

	CodeObject currentCodeObject() @property
	{
		import std.range: empty, back;
		assert( !_codeObjStack.empty, "Cannot get current code object, because compiler code object stack is empty!" );

		return _codeObjStack.back;
	}

	Symbol symbolLookup(string name)
	{
		import std.range: empty, back;
		assert( !_symbolTableStack.empty, `Cannot look for symbol, because symbol table stack is empty` );
		assert( _symbolTableStack.back, `Cannot look for symbol, current symbol table frame is null` );

		Symbol symb = _symbolTableStack.back.lookup(name);
		if( !symb )
			compilerError( `Cannot find symbol "` ~ name ~ `"` );

		return symb;
	}

	ModuleObject mainModule() @property
	{
		assert( _mainModuleName in _moduleObjects, `Cannot get main module object` );
		return _moduleObjects[_mainModuleName];
	}

	ModuleObject getOrCompileModule(string moduleName)
	{
		if( moduleName !in _moduleObjects )
		{
			// Initiate module object compilation on demand
			IvyNode moduleNode = _moduleRepo.getModuleTree(moduleName);

			enterNewCodeObject( newModuleObject(moduleName) );
			enterModuleScope( moduleName );
			moduleNode.accept(this);

			scope(exit)
			{
				this.exitScope();
				this.exitCodeObject();
			}
		}

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
							compilerError( "Expected assoc array pair!" );

						size_t aaKeyConstIndex = addConst( TDataNode(aaPair.key) );
						addInstr( OpCode.LoadConst, aaKeyConstIndex );

						if( !aaPair.value )
							compilerError( "Expected assoc array value!" );
						aaPair.value.accept(this);

						++aaLen;
					}
					addInstr( OpCode.MakeAssocArray, aaLen );
					return;
				default:
					assert( false, "Expected literal expression node!" );
					break;
			}

			addInstr( OpCode.LoadConst, constIndex );
		}

		void visit(INameExpression node)
		{
			/*
			import std.range: empty, back;

			if( !node )
				compilerError( "Expected name expression!" );
			if( _symbolTableStack.empty )
				compilerError( "Compiler symbol table stack is empty!" );
			if( !_symbolTableStack.back )
				compilerError( "Compiler current symbol table frame is null!" );

			size_t constIndex = addConst( TDataNode( node.name ) );
			if( _symbolTableStack.back.lookup(node.name) )
			{
				// Regular name

				// TODO: Maybe set index of constant with name to load instead of LoadConst
				// Load name constant instruction
				addInstr( OpCode.LoadConst, constIndex );

				// Add name load instruction
				addInstr( OpCode.LoadName );
			}
			else
			{
				// Seems that it's built-in name or data context name
				assert( false, `Cannot find variable with name "` ~ node.name ~ `"!` );
			}
			*/
			size_t constIndex = addConst( TDataNode( node.name ) );
			// Load name constant instruction
			addInstr( OpCode.LoadName, constIndex );
		}

		void visit(IOperatorExpression node) { visit( cast(IExpression) node ); }
		void visit(IUnaryExpression node)
		{
			assert( node.expr, "Expression expected!" );
			node.expr.accept(this);

			OpCode opcode;
			switch( node.operatorIndex )
			{
				case Operator.UnaryPlus:
					opcode = OpCode.UnaryPlus;
					break;
				case Operator.UnaryMin:
					opcode = OpCode.UnaryMin;
					break;
				case Operator.Not:
					opcode = OpCode.UnaryNot;
					break;
				default:
					assert( false, "Unexpected unary operator type!" );
					break;
			}

			addInstr( opcode );
		}
		void visit(IBinaryExpression node)
		{
			// Generate code that evaluates left and right parts of binary expression and get result on the stack
			assert( node.leftExpr, "Left expr expected!" );
			node.leftExpr.accept(this);
			assert( node.rightExpr, "Right expr expected!" );
			node.rightExpr.accept(this);

			OpCode opcode;
			switch( node.operatorIndex )
			{
				case Operator.Add:
					opcode = OpCode.Add;
					break;
				case Operator.Sub:
					opcode = OpCode.Sub;
					break;
				case Operator.Mul:
					opcode = OpCode.Mul;
					break;
				case Operator.Div:
					opcode = OpCode.Div;
					break;
				case Operator.Mod:
					opcode = OpCode.Mod;
					break;
				case Operator.Concat:
					opcode = OpCode.Concat;
					break;
				case Operator.And:
					opcode = OpCode.And;
					break;
				case Operator.Or:
					opcode = OpCode.Or;
					break;
				case Operator.Xor:
					opcode = OpCode.Xor;
					break;
				case Operator.Equal:
					opcode = OpCode.Equal;
					break;
				case Operator.LT:
					opcode = OpCode.LT;
					break;
				case Operator.GT:
					opcode = OpCode.GT;
					break;
				default:
					assert( false, "Unexpected binary operator type!" );
					break;
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
					compilerError(`Expected directive definition symbol kind`);

				DirectiveDefinitionSymbol dirSymbol = cast(DirectiveDefinitionSymbol) symb;
				assert( dirSymbol, `Directive definition symbol is null` );

				DirectiveDefinitionBlock[] dirDefBlocks = dirSymbol.dirDefBlocks[]; // Getting slice of list
				bool isNoscope = false;
				foreach( dirDef; dirDefBlocks )
				{
					// Quick workaround to find if directive is noscope
					if( dirDef.type == DirDefAttrType.NoscopeAttr )
					{
						isNoscope = true;
						break;
					}
				}

				// Add instruction to load directive object from context by name
				size_t dirNameConstIndex = addConst( TDataNode(node.name) );
				addInstr( OpCode.LoadName, dirNameConstIndex );

				// Keeps count of stack arguments actualy used by this call. First is directive object
				size_t stackItemsCount = 1;

				while( !attrRange.empty )
				{
					while( !dirDefBlocks.empty )
					{
						assert( dirDefBlocks.front, `dirDefBlocks.front is null` );

						switch( dirDefBlocks.front.type )
						{
							case DirDefAttrType.NamedAttr:
							{
								size_t argCount = 0;
								bool[string] argsSet;

								NamedAttrsDefBlock namedAttrsDef = cast(NamedAttrsDefBlock) dirDefBlocks.front;
								assert( namedAttrsDef, `namedAttrsDef is null` );
								while( !attrRange.empty )
								{
									IKeyValueAttribute keyValueAttr = cast(IKeyValueAttribute) attrRange.front;
									if( !keyValueAttr )
									{
										break; // We finished with key-value attributes
									}

									if( keyValueAttr.name !in namedAttrsDef.namedDecls )
										compilerError( `Unexpected named attribute "` ~ keyValueAttr.name ~ `"` );

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

								foreach( name, attrDecl; namedAttrsDef.namedDecls )
								{
									if( name !in argsSet )
									{
										IExpression defVal = namedAttrsDef.namedDecls[name].defaultValueExpr;

										if( defVal )
										{
											// Add name of named argument into stack
											size_t nameConstIndex = addConst( TDataNode(name) );
											addInstr( OpCode.LoadConst, nameConstIndex );
											++stackItemsCount;

											// Generate code to set default values
											defVal.accept(this);
											++stackItemsCount;
											++argCount;
										}
									}
								}

								// Add instruction to load value that consists of number of pairs in block and type of block
								size_t blockHeader = ( argCount << 3 ) + 1; // TODO: Change magic const to enum
								size_t blockHeaderConstIndex = addConst( TDataNode( blockHeader ) );
								addInstr( OpCode.LoadConst, blockHeaderConstIndex );
								++stackItemsCount; // We should count args block header
								break;
							}
							case DirDefAttrType.ExprAttr:
							{
								size_t argCount = 0;

								ExprAttrsDefBlock exprAttrsDef = cast(ExprAttrsDefBlock) dirDefBlocks.front;
								assert( exprAttrsDef, `exprAttrsDef is null` );
								while( !attrRange.empty )
								{
									IExpression exprAttr = cast(IExpression) attrRange.front;
									if( !exprAttr )
									{
										break; // We finished with key-value attributes
									}
									exprAttr.accept(this);
									++stackItemsCount;

									attrRange.popFront();
								}

								// Add instruction to load value that consists of number of positional arguments in block and type of block
								size_t blockHeader = ( argCount << 3 ) + 2; // TODO: Change magic const to enum
								size_t blockHeaderConstIndex = addConst( TDataNode( blockHeader ) );
								addInstr( OpCode.LoadConst, blockHeaderConstIndex );
								++stackItemsCount; // We should count args block header
								break;
							}
							case DirDefAttrType.IdentAttr:
							{
								while( !attrRange.empty )
								{

									attrRange.popFront();
								}
								break;
							}
							case DirDefAttrType.KwdAttr:
							{
								KwdAttrDef kwdDef = cast(KwdAttrDef) dirDefBlocks.front;
								assert( kwdDef, `kwdDef is null` );
								INameExpression kwdAttr = attrRange.takeFrontAs!INameExpression( `Expected keyword attribute` );
								if( kwdDef.keyword != kwdAttr.name )
									compilerError( `Expected "` ~ kwdDef.keyword ~ `" keyword attribute` );
								break;
							}
							default:
								assert( false, `Unexpected type of directive definition attr block!` );
						}
						dirDefBlocks.popFront();
					}
				}

				if( isNoscope )
				{
					// For now interpreter expects noscope flag to be the top of the stack "block header"
					size_t noscopeFlagConstIndex = addConst( TDataNode(3) ); // TODO: Change magic const to enum
					addInstr( OpCode.LoadConst, noscopeFlagConstIndex );
					++stackItemsCount; // We should count flag
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
			if( !node )
				compilerError( "Compound statement node is null!" );

			TDataNode emptyArray = TDataNode[].init;
			size_t emptyArrayConstIndex = addConst(emptyArray);
			addInstr( OpCode.LoadConst, emptyArrayConstIndex );

			size_t renderDirNameConstIndex = addConst( TDataNode("__render__") );
			size_t resultNameConstIndex = addConst( TDataNode("__result__") );

			// In order to make call to __render__ creating block header for one positional argument
			// witch is currently at the TOP of the execution stack
			size_t blockHeader = ( 1 << 3 ) + 1; //TODO: Change block type magic constant to enum!
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
		// witch is currently at the TOP of the execution stack
		size_t blockHeader = ( 1 << 3 ) + 1; //TODO: Change block type magic constant to enum!
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

// Representation of programme ready for execution
class ExecutableProgramme
{
private:
	ModuleObject[string] _moduleObjects;
	string _mainModuleName;

public:
	this( ModuleObject[string] moduleObjects, string mainModuleName )
	{
		_moduleObjects = moduleObjects;
		_mainModuleName = mainModuleName;
	}

	/// Run programme main module with arguments passed as mainModuleScope parameter
	TDataNode run( TDataNode mainModuleScope = TDataNode() )
	{
		import std.range: back;

		import ivy.interpreter: Interpreter;
		Interpreter interp = new Interpreter(_moduleObjects, _mainModuleName, mainModuleScope );
		interp.execLoop();

		return interp._stack.back;
	}
}

/// Simple method that can be used to compile source file and get executable
ExecutableProgramme compileFile(string sourceFileName, string rootPath)
{
	import std.path: extension, stripExtension, relativePath, dirSeparator, dirName;
	import std.array: split, join, empty;

	if( rootPath.empty )
		rootPath = sourceFileName.dirName();

	// Calculating main module name
	string mainModuleName = sourceFileName.relativePath(rootPath).stripExtension().split(dirSeparator).join('.');

	// Creating object that manages reading source files, parse and store them as AST
	auto compilerModuleRepo = new CompilerModuleRepository( rootPath, extension(sourceFileName) );

	// Preliminary compiler phase that analyse imported modules and stores neccessary info about directives
	auto symbCollector = new CompilerSymbolsCollector(compilerModuleRepo, mainModuleName);
	symbCollector.run(); // Run analyse

	// Main compiler phase that generates bytecode for modules
	auto compiler = new ByteCodeCompiler( compilerModuleRepo, symbCollector.getModuleSymbols(), mainModuleName );
	compiler.run(); // Run compilation itself

	// Creating additional object that stores all neccessary info for user
	return new ExecutableProgramme(compiler.moduleObjects, mainModuleName);
}