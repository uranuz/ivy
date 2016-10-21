/// Module implements compilation of Ivy abstract syntax tree into bytecode
module ivy.compiler;

import ivy.node;
import ivy.node_visitor;
import ivy.bytecode;
import ivy.interpreter_data;

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

// Minimal element of bytecode is instruction opcode with optional args
struct Instruction
{
	OpCode opcode; // So... it's instruction opcode
	uint[1] args; // One arg for now
}

interface IDirectiveCompiler
{
	void compile( IDirectiveStatement node, ByteCodeCompiler cpl );

}

/// Compiles var directive in corresponding bytecode
class VarCompiler: IDirectiveCompiler
{
	void compile( IDirectiveStatement stmt, ByteCodeCompiler compiler )
	{
		import std.range: empty, back;

		if( !stmt || stmt.name != "var" )
			compilerError( `Expected "var" directive statement!` );
		if( compiler._frameStack.empty )
			compilerError( `Compiler frame stack is empty!` );
		if( !compiler._frameStack.back )
			compilerError( `Compiler's current frame is null!` );

		auto stmtRange = stmt[];
		while( !stmtRange.empty )
		{
			string varName;

			if( auto kwPair = cast(IKeyValueAttribute) stmtRange.front )
			{
				varName = kwPair.name;
				if( !kwPair.value )
					compilerError( "Expected value for 'var' directive" );

				kwPair.value.accept(compiler); // Compile expression for getting value
				stmtRange.popFront();
			}
			else if( auto nameExpr = cast(INameExpression) stmtRange.front )
			{
				varName = nameExpr.name;
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

			// Exactly setting value in nearest context
			compiler._frameStack.back.add( Symbol(varName) );

			uint constIndex = cast(uint) compiler._consts.length;
			compiler._consts ~= TDataNode( varName );

			Instruction instr;
			instr.opcode = OpCode.LoadConst;
			instr.args[0] = constIndex;
			compiler._code ~= instr;

			compiler._code ~= Instruction(OpCode.StoreName);
		}

		if( !stmtRange.empty )
			compilerError( "Expected end of directive after key-value pair. Maybe ';' is missing" );
	}

}

struct CodeChunk
{
	Instruction[] code;
}

enum SymbolScopeType: ubyte { Global, Local }

struct Symbol
{
	string name;
	SymbolScopeType scopeType;
}

class CompilerFrame
{
private:
	Symbol[string] _symbols;

public:
	Symbol* lookup(string name)
	{
		return name in _symbols;
	}

	void add( Symbol symb )
	{
		_symbols[symb.name] = symb;
	}
}


class ByteCodeCompiler: AbstractNodeVisitor
{
private:
	TDataNode[] _consts; // Current set of constant data
	Instruction[] _code; // Current set of instructions

	CodeChunk[] _codeChunks;

	IDirectiveCompiler[string] _dirCompilers;
	CompilerFrame[] _frameStack;


public:
	this()
	{
		_frameStack ~= new CompilerFrame();

		_dirCompilers["var"] = new VarCompiler();
		//_dirCompilers["if"] = new IfCompiler();
		//_dirCompilers["for"] = new ForCompiler();
		//_dirCompilers["def"] = new DefCompiler();
	}


	override {
		void visit(IvyNode node) { assert(0); }

		//Expressions
		void visit(IExpression node) { visit( cast(IvyNode) node ); }

		void visit(ILiteralExpression node)
		{
			LiteralType litType;
			uint constIndex = cast(uint) _consts.length;

			switch( node.literalType )
			{
				case LiteralType.Null:
					_consts ~= TDataNode(null);
					break;
				case LiteralType.Boolean:
					_consts ~= TDataNode( node.toBoolean() );
					break;
				case LiteralType.Integer:
					_consts ~= TDataNode( node.toInteger() );
					break;
				case LiteralType.Floating:
					_consts ~= TDataNode( node.toFloating() );
					break;
				case LiteralType.String:
					_consts ~= TDataNode( node.toStr() );
					break;
				case LiteralType.Array:
					assert( false, "Array literal code generation is not implemented yet!" );
					break;
				case LiteralType.AssocArray:
					assert( false, "Assoc array literal code generation is not implemented yet!" );
					break;
				default:
					assert( false, "Expected literal expression node!" );
					break;
			}

			Instruction instr;
			instr.opcode = OpCode.LoadConst;
			instr.args[0] = constIndex;
			_code ~= instr;
		}

		void visit(INameExpression node)
		{
			import std.range: empty, back;

			if( !node )
				compilerError( "Expected name expression!" );
			if( _frameStack.empty )
				compilerError( "Compiler frame stack is empty!" );
			if( !_frameStack.back )
				compilerError( "Compiler current stack item is null!" );

			uint constIndex = cast(uint) _consts.length;
			_consts ~= TDataNode( node.name );

			if( _frameStack.back.lookup(node.name) )
			{
				// Regular name

				// Load name constant instruction
				Instruction instr;
				instr.opcode = OpCode.LoadConst;
				instr.args[0] = constIndex;
				_code ~= instr;

				// Add name load instruction
				_code ~= Instruction(OpCode.LoadName);

			}
			else
			{
				// Seems that it's built-in name or data context name
			}
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

			_code ~= Instruction(opcode);
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

			_code ~= Instruction(opcode);
		}

		void visit(IAssocArrayPair node) { visit( cast(IExpression) node ); }

		//Statements
		void visit(IStatement node) { visit( cast(IvyNode) node ); }
		void visit(IKeyValueAttribute node) { visit( cast(IvyNode) node ); }

		void visit(IDirectiveStatement node)
		{
			if( auto comp = node.name in _dirCompilers )
			{
				comp.compile( node, this );
			}
			else
			{
				// First of all I'll be trying to load directive with this into machine stack

			}
		}

		void visit(IDataFragmentStatement node)
		{
			// Nothing special. Just store this piece of data into table
			uint constIndex = cast(uint) node.data.length;
			_consts ~= TDataNode(node.data);

			Instruction instr;
			instr.opcode = OpCode.LoadConst;
			instr.args[0] = constIndex;
			_code ~= instr;
		}
		void visit(ICompoundStatement node) { visit( cast(IStatement) node ); }
	}

	// Assembles constants and code chunks into complete module bytecode
	void assemble()
	{
		// TODO: Do it please!
	}

	string toPrettyStr()
	{
		import std.conv;

		string result;
		result ~= "CONSTANTS:\r\n";
		foreach( i, con; _consts )
		{
			result ~= i.text ~ "  " ~ con.toString() ~ "\r\n";
		}
		result ~= "\r\n";

		result ~= "CODE:\r\n";
		foreach( i, instr; _code )
		{
			result ~= i.text ~ "  " ~ instr.opcode.text ~ "  " ~ instr.args.to!string ~ "\r\n";
		}

		return result;
	}

}

