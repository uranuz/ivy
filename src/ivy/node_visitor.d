module ivy.node_visitor;

import ivy.node;


class AbstractNodeVisitor
{
	void visit(IvyNode node) { assert(0); }
	
	//Expressions
	void visit(IExpression node) { visit( cast(IvyNode) node ); }
	void visit(ILiteralExpression node) { visit( cast(IExpression) node ); }
	void visit(INameExpression node) { visit( cast(IExpression) node ); }
	void visit(IOperatorExpression node) { visit( cast(IExpression) node ); }
	void visit(IUnaryExpression node) { visit( cast(IExpression) node ); }
	void visit(IBinaryExpression node) { visit( cast(IExpression) node ); }
	void visit(IAssocArrayPair node) { visit( cast(IExpression) node ); }
	
	//Statements
	void visit(IStatement node) { visit( cast(IvyNode) node ); }
	void visit(IKeyValueAttribute node) { visit( cast(IvyNode) node ); }
	void visit(IDirectiveStatement node) { visit( cast(IStatement) node ); }
	void visit(IDataFragmentStatement node) { visit( cast(IStatement) node ); }
	void visit(ICompoundStatement node) { visit( cast(IStatement) node ); }
	void visit(ICodeBlockStatement node) { visit( cast(ICompoundStatement) node ); }
	void visit(IMixedBlockStatement node) { visit( cast(ICompoundStatement) node ); }
}