/// Module implements compilation of Ivy abstract syntax tree into bytecode
module ivy.compiler;

import ivy.node;
import ivy.node_visitor;
import ivy.bytecode;

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


struct Instruction
{
	OpCode code;
	uint[2] args;
}

// Implements atomic unit of compiled code (usualy it is directive's code)
class CodeObject
{
	Instruction[] code;
	TDataNode[] consts;

}

interface IDirectiveCompiler
{
	void compile( IDirectiveStatement node, BytecodeCompiler cpl );

}


/// Compiles var directive in corresponding bytecode
class VarCompiler: IDirectiveCompiler
{
	void compile( IDirectiveStatement stmt, BytecodeCompiler compiler )
	{
		if( !stmt || stmt.name != "var" )
			compilerError( `Expected "var" directive statement!` );



	}

}



class BytecodeCompiler: AbstractNodeVisitor
{
private:
	ProgrammeObject _prog;

public:
	this()
	{
		_prog = new ProgrammeObject();
	}


	override {
		void visit(IvyNode node) { assert(0); }

		//Expressions
		void visit(IExpression node) { visit( cast(IvyNode) node ); }
		void visit(ILiteralExpression node)
		{
			LiteralType litType;
			size_t constIndex = _prog.data.length;

			switch( node.literalType )
			{
				case LiteralType.Null:
					_prog.data ~= TDataNode(null);
					break;
				case LiteralType.Boolean:
					_prog.data ~= node.toBoolean();
					break;
				case LiteralType.Integer:
					_prog.data ~= node.toInteger();
					break;
				case LiteralType.Floating:
					_prog.data ~= node.toFloating();
					break;
				case LiteralType.String:
					_prog.data ~= node.toStr();
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

			Instruction opn;
			opn.code = OpCode.LoadConst;
			opn.args[0] = constIndex;
			_prog.code ~= opn;
		}
		void visit(INameExpression node) { visit( cast(IExpression) node ); }
		void visit(IOperatorExpression node) { visit( cast(IExpression) node ); }
		void visit(IUnaryExpression node) {
			assert( node.expr, "Expression expected!" );
			node.expr.accept(this);

			OpCode code;
			switch( node.operatorIndex )
			{
				case Operator.UnaryPlus:
					code = OpCode.UnaryPlus;
					break;
				case Operator.UnaryMin:
					code = OpCode.UnaryMin;
					break;
				case Operator.Not:
					code = OpCode.UnaryNot;
					break;
				default:
					assert( false, "Unexpected unary operator type!" );
					break;
			}

			_prog.code ~= Instruction(code);
		}
		void visit(IBinaryExpression node)
		{
			// Generate code that evaluates left and right parts of binary expression and get result on the stack
			assert( node.leftExpr, "Left expr expected!" );
			node.leftExpr.accept(this);
			assert( node.rightExpr, "Right expr expected!" );
			node.rightExpr.accept(this);

			OpCode code;
			switch( node.operatorIndex )
			{
				case Operator.Add:
					code = OpCode.Add;
					break;
				case Operator.Sub:
					code = OpCode.Sub;
					break;
				case Operator.Mul:
					code = OpCode.Mul;
					break;
				case Operator.Div:
					code = OpCode.Div;
					break;
				case Operator.Mod:
					code = OpCode.Mod;
					break;
				case Operator.Concat:
					code = OpCode.Concat;
					break;
				case Operator.And:
					code = OpCode.And;
					break;
				case Operator.Or:
					code = OpCode.Or;
					break;
				case Operator.Xor:
					code = OpCode.Xor;
					break;
				/*
				case Operator.Equal:
					code = OpCode.Equal;
					break;
				case Operator.NotEqual:
					code = OpCode.NotEqual;
					break;
				case Operator.LT:
					code = OpCode.LT;
					break;
				case Operator.GT:
					code = OpCode.
					break;
				*/
				default:
					assert( false, "Unexpected binary operator type!" );
					break;
			}

			_prog.code ~= Instruction(code);
		}
		void visit(IAssocArrayPair node) { visit( cast(IExpression) node ); }

		//Statements
		void visit(IStatement node) { visit( cast(IvyNode) node ); }
		void visit(IKeyValueAttribute node) { visit( cast(IvyNode) node ); }

		void compileDefDirective(IDirectiveStatement node)
		{


		}

		void visit(IDirectiveStatement node)
		{
			if( node.name == "def" )
			{
				// It's special case. Will compile it separatley in section of programme
				compileDefDirective(node);
			}
			else
			{
				// Other directives will be searched in controller
				//node
			}
		}

		void visit(IDataFragmentStatement node)
		{
			// Nothing special. Just store this piece of data into table
			size_t constIndex = node.data.length;
			_prog.data ~= TDataNode(node.data);

			Instruction opn;
			opn.code = OpCode.LoadConst;
			opn.args[0] = constIndex;
			_prog.code ~= opn;
		}
		void visit(ICompoundStatement node) { visit( cast(IStatement) node ); }
	}

}

