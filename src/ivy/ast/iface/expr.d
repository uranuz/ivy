module ivy.ast.iface.expr;

import ivy.ast.iface.node: IvyNode;

interface IExpression: IvyNode
{
	import ivy.ast.iface.statement: IStatement;
	import ivy.ast.consts: LiteralType;

	@property {
		IStatement asStatement();

		LiteralType literalType();

		bool isScalar();
		bool isNullExpr();
	}

	bool toBoolean();
	int toInteger();
	double toFloating();
	string toStr();
}

interface IPlainExpression: IExpression
{
}

interface IAssocArrayPair: IvyNode
{
	@property {
		string key();
		IExpression value();
	}
}


interface ILiteralExpression: IPlainExpression
{
}

interface IOperatorExpression: IPlainExpression
{
	@property const {
		int operatorIndex();
	}
}

interface IUnaryExpression: IOperatorExpression
{
	@property
	{
		IExpression expr();
	}
}

interface IBinaryExpression: IOperatorExpression
{
	@property {
		IExpression leftExpr();
		IExpression rightExpr();
	}
}

interface INameExpression: IPlainExpression
{
	@property string name();
}