module declarative.const_folding;

import std.stdio;

import declarative.node, declarative.expression, declarative.node_visitor;

/+
class ConstFoldVisitor: AbstractNodeVisitor
{
public:
	
	alias visit = AbstractNodeVisitor.visit;
	
	public override {
		void visit(IDeclNode node) { writeln( typeof(node).stringof ~ " visited" ); }
		void visit(IExpression node) { writeln( typeof(node).stringof ~ " visited" ); }
		void visit(ILiteralExpression node) { writeln( typeof(node).stringof ~ " visited" ); }
		void visit(IOperatorExpression node) { writeln( typeof(node).stringof ~ " visited" ); }
		void visit(IUnaryExpression node) { writeln( typeof(node).stringof ~ " visited" ); }
		void visit(IBinaryExpression node) { writeln( typeof(node).stringof ~ " visited" ); }
	}
	
	this() {}
}
+/


class ConstFoldVisitor: AbstractNodeVisitor
{
public:
	IDeclNode result;

	LiteralType lastLiteralType;
	
	alias visit = AbstractNodeVisitor.visit;
	
	public override {
		void visit(IDeclNode node) { writeln( typeof(node).stringof ~ " visited" ); }
		void visit(IExpression node) { writeln( typeof(node).stringof ~ " visited" ); }
		void visit(ILiteralExpression node)
		{ 
			writeln( typeof(node).stringof ~ " visited" );
		}
		
		void visit(IOperatorExpression node) { writeln( typeof(node).stringof ~ " visited" ); }
		
		void visit(IUnaryExpression node) 
		{ 
			writeln( typeof(node).stringof ~ " visited" ); 
			if( node.expr )
			{
				node.expr.accept(this);
			}
		}
		
		void visit(IBinaryExpression node) 
		{ 
			writeln( typeof(node).stringof ~ " visited" );
			if( node.leftExpr && node.rightExpr )
			{
				if( !node.leftExpr.literalType )
				{
					node.leftExpr.accept(this);
				}
				
				if( !node.rightExpr.literalType )
				{
					node.rightExpr.accept(this);
				}
			}
		}
	}
	
	this() {}
	
	private IExpression doScalarBinaryOp(IExpression left, IExpression right, Operator op)
	{
		IExpression expr;
		
		if( left && right )
		{
			switch(op) with (Operator)
			{
				case Add:
				{
				
					break;
				}
				case Sub:
				{
				
					break;
				}
				case Mul:
				{
				
					break;
				}
				case Div:
				{
				
					break;
				}
				case Mod:
				{
				
					break;
				}
				case Equal:
				{
				
					break;
				}
				case NotEqual:
				{
				
					break;
				}
				case LT:
				{
				
					break;
				}
				case GT:
				{
				
					break;
				}
				case LTEqual:
				{
				
					break;
				}
				case GTEqual:
				{
				
					break;
				}
				default:
				{
					assert( 0, "Const folding: unsupported binary operator type!!!");
					break;
				}
			}
		}
		
		return expr;
	}
}