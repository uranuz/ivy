module ivy.ast.expr.unary;

import trifle.location: LocationConfig;
import ivy.ast.iface: IExpression, IUnaryExpression;
import ivy.ast.common: BaseExpressionImpl;

class UnaryArithmeticExp(LocationConfig c): IUnaryExpression
{
	mixin BaseExpressionImpl!c;

private:
	IExpression _expr;
	int _operatorIndex;

public:
	this(CustLocation loc, int op, IExpression expression)
	{
		_location = loc;
		_operatorIndex = op;
		_expr = expression;
	}

	@property override
	{
		IExpression expr()
		{
			return _expr;
		}
	}

	@property const override{
		int operatorIndex()
		{
			return _operatorIndex;
		}
	}

	override @property string kind()
	{
		return "unary arithmetic expr";
	}

	override @property IvyNode[] children()
	{
		return [_expr];
	}

/+
	string toString() override
	{
		import std.conv: to;

		return _leftExpr.toString() ~ " " ~ _operatorIndex.to!string ~ " " ~ _leftExpr.toString();
	}
+/
}


class LogicalNotExp(LocationConfig c): IUnaryExpression
{
	import ivy.ast.consts: Operator;

	mixin BaseExpressionImpl!c;

private:
	IExpression _expr;

public:
	this(CustLocation loc, IExpression expression)
	{
		_location = loc;
		_expr = expression;
	}

	@property override
	{
		IExpression expr()
		{
			return _expr;
		}
	}

	@property const override{
		int operatorIndex()
		{
			return Operator.Not;
		}
	}

	override @property string kind()
	{
		return "logical not expr";
	}

	override @property IvyNode[] children()
	{
		return [_expr];
	}
}