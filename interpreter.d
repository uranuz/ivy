module declarative.interpreter;

import std.stdio, std.conv;

import declarative.node, declarative.node_visitor, declarative.common, declarative.expression;

import declarative.interpreter_data;

interface IInterpreterContext {}

class InterpreterContext: IInterpreterContext
{
public:
	


public:
	



}

interface IDeclarationInterpreter
{
	void interpret(IDeclarativeStatement statement, Interpreter interp);

}

static IDeclarationInterpreter[string] declInterpreters;

shared static this()
{
	declInterpreters["for"] = new ForInterpreter();
	declInterpreters["if"] = new IfInterpreter();
	declInterpreters["pass"] = new PassInterpreter();

}

class ForInterpreter : IDeclarationInterpreter
{
public:
	override void interpret(IDeclarativeStatement statement, Interpreter interp)
	{
	
	}

}

class IfInterpreter : IDeclarationInterpreter
{
public:
	override void interpret(IDeclarativeStatement statement, Interpreter interp)
	{
		assert( statement && statement.name == "if", "If statement must exist and it's name must be 'if'!!!" );
		auto mainSect = statement.mainSection;
		assert( mainSect, "Main section expected!" );
		
		IDeclarationSection[] ifSects = [ mainSect ];
		IDeclarationSection elseSect;
		
		foreach( sect; statement.sections )
		{
			if( sect.name == "elif" )
			{
				ifSects ~= sect;
			}
			else if( sect.name == "else" )
			{
				assert( !elseSect, "Multiple else sections are not alowed!!!" );
				elseSect = sect;
			}
			else
			{
				assert( 0, "Unexpected type of declaration section: " ~ sect.name );
			}
		}
		
		bool lookElse = true;
		
		foreach( ifSect; ifSects )
		{
			auto condExpr = ifSect.plainAttributes[0];
			assert( condExpr, "Conditional expression attribute expected in 'if'!!!" );
			condExpr.accept(interp);
			
			assert( interp.opnd.type == DataNodeType.Boolean, "If conditional expression result must be boolean!!!" );
			
			if( interp.opnd.boolean )
			{
				lookElse = false;
				ifSect.statement.accept(interp);
				
				break;
			}
		}
		
		if( lookElse )
		{
			elseSect.statement.accept(interp);
		}
		
		
	}

}

class PassInterpreter : IDeclarationInterpreter
{
public:
	override void interpret(IDeclarativeStatement statement, Interpreter interp)
	{
	
	}

}


class Interpreter : AbstractNodeVisitor
{
public:
	alias TDataNode = DataNode!string;
	
	TDataNode opnd; //Current operand value

	public override {
		void visit(IDeclNode node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			if( node )
				writeln( "Decl node kind: ", node.kind() );
		}
		
		//Expressions
		void visit(IExpression node)
		{
			writeln( typeof(node).stringof ~ " visited" );
		}
		
		void visit(ILiteralExpression node)
		{
			switch( node.literalType ) with(LiteralType)
			{
				case NotLiteral:
				{
					assert( 0, "Incorrect AST node. ILiteralExpression cannot have NotLiteral literalType property!!!" );
					break;
				}
				case Null:
				{
					opnd = null;
					break;
				}
				case Boolean:
				{
					opnd = node.toBoolean();
					break;
				}
				case Integer:
				{
					opnd = node.toInteger();
					break;
				}
				case Floating:
				{
					opnd = node.toFloating();
					break;
				}
				case String:
				{
					assert( 0, "Not implemented yet!");
					break;
				}
				case Array:
				{
					assert( 0, "Not implemented yet!");
					break;
				}
				case AssocArray:
				{
					assert( 0, "Not implemented yet!");
					break;
				}
				default:
					assert( 0 , "Unexpected LiteralType" );
			}
			
			writeln( typeof(node).stringof ~ " visited" );
		}
		
		void visit(IOperatorExpression node)
		{
			writeln( typeof(node).stringof ~ " visited" );
		}
		
		void visit(IUnaryExpression node)
		{
			import std.conv : to;
			
			writeln( typeof(node).stringof ~ " visited" );
			
			IExpression operandExpr = node.expr;
			int op = node.operatorIndex;
			
			assert( operandExpr, "Unary operator operand shouldn't be null ast object!!!" );
			
			with(Operator)
				assert( op == UnaryPlus || op == UnaryMin || op == Not, "Incorrect unary operator " ~ (cast(Operator) op).to!string  );
			
			opnd = TDataNode.init;
			operandExpr.accept(this); //This must interpret child nodes

			switch(op) with(Operator)
			{
				case UnaryPlus:
				{
					assert( 
						opnd.type == DataNodeType.Integer || opnd.type == DataNodeType.Floating, 
						"Unsupported UnaryPlus operator for type: " ~ opnd.type.to!string
					);
					
					break;
				}
				case UnaryMin:
				{
					assert( 
						opnd.type == DataNodeType.Integer || opnd.type == DataNodeType.Floating, 
						"Unsupported UnaryMin operator for type: " ~ opnd.type.to!string
					);
					
					if( opnd.type == DataNodeType.Integer )
					{
						opnd = -opnd.integer;
					}
					else if( opnd.type == DataNodeType.Floating )
					{
						opnd = -opnd.floating;
					}
					
					break;
				}
				case Not:
				{
					assert( 
						opnd.type == DataNodeType.Boolean, 
						"Unsupported Not operator for type: " ~ opnd.type.to!string
					);
					
					if( opnd.type == DataNodeType.Boolean )
					{
						opnd = !opnd.boolean;
					}
					
					break;
				}
				default:
					assert(0);
			}
		}
		
		void visit(IBinaryExpression node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			
			IExpression leftExpr = node.leftExpr;
			IExpression rightExpr = node.rightExpr;;
			int op = node.operatorIndex;
			
			assert( leftExpr && rightExpr, "Binary operator operands shouldn't be null ast objects!!!" );
			
			with(Operator)
				assert( 
					op == Add || op == Sub || op == Mul || op == Div || op == Mod || //Arithmetic
					op == And || op == Or || op == Xor || //Boolean
					op == Equal || op == NotEqual || op == LT || op == GT || op == LTEqual || op == GTEqual,  //Comparision
					"Incorrect binary operator " ~ (cast(Operator) op).to!string 
				);
			
			opnd = TDataNode.init;
			leftExpr.accept(this);
			TDataNode leftOpnd = opnd;
			
			opnd = TDataNode.init;
			rightExpr.accept(this);
			TDataNode rightOpnd = opnd;
			
			assert( leftOpnd.type == rightOpnd.type, "Operands tags in binary expr must match!!!" );
			
			switch(op) with(Operator)
			{
				case Add:
				{
					assert( 
						leftOpnd.type == DataNodeType.Integer || leftOpnd.type == DataNodeType.Floating, 
						"Unsupported Add operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer + rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating + rightOpnd.floating;
					}
					
					break;
				}
				case Sub:
				{
					assert( 
						leftOpnd.type == DataNodeType.Integer || leftOpnd.type == DataNodeType.Floating, 
						"Unsupported Sub operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer - rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating - rightOpnd.floating;
					}
					
					break;
				}
				case Mul:
				{
					assert( 
						leftOpnd.type == DataNodeType.Integer || leftOpnd.type == DataNodeType.Floating, 
						"Unsupported Mul operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer * rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating * rightOpnd.floating;
					}
					
					break;
				}
				case Div:
				{
					assert( 
						leftOpnd.type == DataNodeType.Integer || leftOpnd.type == DataNodeType.Floating, 
						"Unsupported Sub operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer / rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating / rightOpnd.floating;
					}
					
					break;
				}
				case Mod:
				{
					assert( 
						leftOpnd.type == DataNodeType.Integer || leftOpnd.type == DataNodeType.Floating, 
						"Unsupported Mod operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer % rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating % rightOpnd.floating;
					}
					
					break;
				}
				case And:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean, 
						"Unsupported And operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean && rightOpnd.boolean;
					}

					break;
				}
				case Or:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean, 
						"Unsupported Or operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean || rightOpnd.boolean;
					}

					break;
				}
				case Xor:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean, 
						"Unsupported Xor operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean ^^ rightOpnd.boolean;
					}

					break;
				}
				case Equal:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean ||
						leftOpnd.type == DataNodeType.Integer ||
						leftOpnd.type == DataNodeType.Floating ||
						leftOpnd.type == DataNodeType.String,
						"Unsupported Equal operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean == rightOpnd.boolean;
					}
					else if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer == rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating == rightOpnd.floating;
					}
					else if( leftOpnd.type == DataNodeType.String )
					{
						opnd = leftOpnd.str == rightOpnd.str;
					}

					break;
				}
				case NotEqual:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean ||
						leftOpnd.type == DataNodeType.Integer ||
						leftOpnd.type == DataNodeType.Floating ||
						leftOpnd.type == DataNodeType.String,
						"Unsupported NotEqual operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean != rightOpnd.boolean;
					}
					else if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer != rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating != rightOpnd.floating;
					}
					else if( leftOpnd.type == DataNodeType.String )
					{
						opnd = leftOpnd.str != rightOpnd.str;
					}

					break;
				}
				case LT:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean ||
						leftOpnd.type == DataNodeType.Integer ||
						leftOpnd.type == DataNodeType.Floating ||
						leftOpnd.type == DataNodeType.String,
						"Unsupported LT operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean < rightOpnd.boolean;
					}
					else if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer < rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating < rightOpnd.floating;
					}
					else if( leftOpnd.type == DataNodeType.String )
					{
						opnd = leftOpnd.str < rightOpnd.str;
					}

					break;
				}
				case GT:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean ||
						leftOpnd.type == DataNodeType.Integer ||
						leftOpnd.type == DataNodeType.Floating ||
						leftOpnd.type == DataNodeType.String,
						"Unsupported LT operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean > rightOpnd.boolean;
					}
					else if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer > rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating > rightOpnd.floating;
					}
					else if( leftOpnd.type == DataNodeType.String )
					{
						opnd = leftOpnd.str > rightOpnd.str;
					}

					break;
				}
				default:
					assert(0);
			}
		}
		
		
		//Statements
		void visit(IStatement node)
		{
			writeln( typeof(node).stringof ~ " visited" );
		}
		
		void visit(IDeclarationSection node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			writeln( "Declaration section name: ", node.name );
			foreach( child; node.children )
			{
				if( child )
					child.accept(this);
			}
		}
		
		void visit(IKeyValueAttribute node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			writeln( "Key-value attribute name: ", node.name );
			node.value.accept(this);
		}

		void visit(IDeclarativeStatement node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			writeln( "Declarative statement name: ", node.name );
			foreach( child; node.children )
			{
				if( child )
					child.accept(this);
			}
		}
		
		void visit(ICompoundStatement node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			foreach( child; node.children )
			{
				if( child )
					child.accept(this);
			}
		}
		
	}
}
