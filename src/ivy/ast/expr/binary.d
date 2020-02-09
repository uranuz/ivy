module ivy.ast.expr.binary;

import trifle.location: LocationConfig;

import ivy.ast.iface: IExpression, IBinaryExpression;
import ivy.ast.common: BaseExpressionImpl;

mixin template BinaryArithmeticExpressionImpl()
{
	private int _operatorIndex;
	private IExpression _leftExpr;
	private IExpression _rightExpr;

	public @property const override {
		int operatorIndex()
		{
			return _operatorIndex;
		}
	}

	public @property override {
		IExpression leftExpr()
		{
			return _leftExpr;
		}

		IExpression rightExpr()
		{
			return _rightExpr;
		}
	}

}


class ArrayIndexExp(LocationConfig c): IExpression
{
	mixin BaseExpressionImpl!c;

private:
	IExpression _arrayExp;
	IExpression _indexExp;

public:
	this(CustLocation loc, IExpression arrayExp, IExpression indexExp )
	{
		_location = loc;
		_arrayExp = arrayExp;
		_indexExp = indexExp;
	}

	override @property string kind()
	{
		return "array index expression";
	}

	override @property IvyNode[] children()
	{
		return cast(IvyNode[]) [_arrayExp, _indexExp];
	}


}



class BinaryArithmeticExp(LocationConfig c): IBinaryExpression
{
	mixin BaseExpressionImpl!c;
	mixin BinaryArithmeticExpressionImpl;

private:


public:
	this(CustLocation loc, int op, IExpression left, IExpression right)
	{
		_location = loc;
		_operatorIndex = op;
		_leftExpr = left;
		_rightExpr = right;
	}

	override @property string kind()
	{
		return "binary arithmetic expr";
	}

	override @property IvyNode[] children()
	{
		return [_leftExpr, _rightExpr];
	}
}


class BinaryLogicalExp(LocationConfig c): IBinaryExpression
{
	mixin BaseExpressionImpl!c;
	mixin BinaryArithmeticExpressionImpl;

public:
	this(CustLocation loc, int op, IExpression left, IExpression right)
	{
		_location = loc;
		_operatorIndex = op;
		_leftExpr = left;
		_rightExpr = right;
	}

	override @property string kind()
	{
		return "binary logical expr";
	}

	override @property IvyNode[] children()
	{
		return [_leftExpr, _rightExpr];
	}

}

class CompareExp(LocationConfig c): IBinaryExpression
{
	mixin BaseExpressionImpl!c;
	mixin BinaryArithmeticExpressionImpl;

public:
	this(CustLocation loc, int op, IExpression left, IExpression right)
	{
		_location = loc;
		_operatorIndex = op;
		_leftExpr = left;
		_rightExpr = right;
	}

	override @property string kind()
	{
		return "compare expr";
	}

	override @property IvyNode[] children()
	{
		return [_leftExpr, _rightExpr];
	}

/+
	string toString() override
	{
		import std.conv: to;

		return _leftExpr.toString() ~ " " ~ _operatorIndex.to!string ~ " " ~ _leftExpr.toString();
	}
+/
}