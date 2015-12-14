module declarative.const_folding;

import declarative.node, declarative.expression, declarative.node_visitor;


class ConstFoldVisitor: AbstractNodeVisitor
{
	public override {
		void visit(IExpression node) { visit( cast(IDeclNode) node ); }
		void visit(IOperatorExpression node)
		{
			
		}
		visit( cast(IExpression) node ); }
		void visit(IUnaryExpression node) { visit( cast(IExpression) node ); }
		void visit(IBinaryExpression node) { visit( cast(IExpression) node ); }
	}
}