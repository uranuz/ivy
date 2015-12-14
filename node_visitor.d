module declarative.node_visitor;

import declarative.node;


class AbstractNodeVisitor
{
	void visit(IDeclNode node) { assert(0); }
	
	//Expressions
	void visit(IExpression node) { visit( cast(IDeclNode) node ); }
	void visit(IOperatorExpression node) { visit( cast(IExpression) node ); }
	void visit(IUnaryExpression node) { visit( cast(IExpression) node ); }
	void visit(IBinaryExpression node) { visit( cast(IExpression) node ); }
	
	//Statements
	void visit(IStatement node) { visit( cast(IDeclNode) node ); }
	void visit(IDeclarationSection node) { visit( cast(IStatement) node ); }
	void visit(IDeclarativeStatement node) { visit( cast(IStatement) node ); }
	void visit(ICompoundStatement node) { visit( cast(IStatement) node ); }
}