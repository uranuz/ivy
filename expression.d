module declarative.expression;

import declarative.node, declarative.common;

mixin template BaseExpressionImpl(LocationConfig c, T = IDeclNode)
{
	enum locConfig = c;
	alias CustLocation = CustomizedLocation!locConfig;
	
	private T _parentNode;
	private CustLocation _location;
	
	public @property override
	{ 
		T parent()
		{
			return _parentNode;
		}
	
		Location location() const
		{
			return _location.toLocation();
		}
		
		PlainLocation plainLocation() const
		{
			return _location.toPlainLocation();
		}
		
		ExtendedLocation extLocation() const
		{
			return _location.toExtendedLocation();
		}
		
		LocationConfig locationConfig() const
		{
			return _location.config;
		}
	}
	
	public @property override
	{
		void parent(IDeclNode node)
		{
			_parentNode = node;
		}
	}
}

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

class NullExp(LocationConfig c): IExpression
{
	mixin BaseExpressionImpl!c;
	
public:
	this(CustLocation loc)
	{
		_location = loc;
	}
	
	override @property string kind()
	{
		return "null";
	}
	
	override @property IDeclNode[] children()
	{
		return null;
	}

/+
	string toString() override
	{
		return "null";
	}
+/
}


class BooleanExp(LocationConfig c): IExpression
{
	mixin BaseExpressionImpl!c;
	
private:
	bool _value;

public:
	this(CustLocation loc, bool val)
	{
		_location = loc;
		_value = val;
	}
	
	override @property string kind()
	{
		return "boolean";
	}
	
	override @property IDeclNode[] children()
	{
		return null;
	}

/+
	string toString() override
	{
		return _value ? "true" : "false";
	}
+/
}

alias IntegerType = int;

class IntegerExp(LocationConfig c): IExpression
{
	mixin BaseExpressionImpl!c;
	
private:
	IntegerType _value;
	
public:
	this(CustLocation loc, IntegerType val)
	{
		_location = loc;
		_value = val;
	}

	override @property string kind()
	{
		return "integer";
	}
	
	override @property IDeclNode[] children()
	{
		return null;
	}

/+
	string toString() override
	{
		import std.conv: to;
		
		return _value.to!string;
	}
+/
}

alias FloatType = double;

class FloatExp(LocationConfig c): IExpression
{
	mixin BaseExpressionImpl!c;
	
private:
	FloatType _value;

public:
	this(CustLocation loc, FloatType val)
	{
		_location = loc;
		_value = val;
	}
	
	override @property string kind()
	{
		return "floating";
	}
	
	override @property IDeclNode[] children()
	{
		return null;
	}
	
	
/+
	string toString() override
	{
		import std.conv: to;
		
		return _value.to!string;
	}
+/
}

alias StringType = string;

class StringExp(LocationConfig c): IExpression
{
	mixin BaseExpressionImpl!c;

private:
	StringType _value;
	
public:
	this(CustLocation loc, StringType val)
	{
		_location = loc;
		_value = val;
	}

	override @property string kind()
	{
		return "string";
	}
	
	override @property IDeclNode[] children()
	{
		return null;
	}
	
/+
	string toString() override
	{
		import std.conv: to;
		
		return _value.to!string;
	}
+/
}

class ArrayLiteralExp(LocationConfig c): IExpression
{
	mixin BaseExpressionImpl!c;

private: 
	IExpression[] _elements;
	
public:
	this(CustLocation loc, IExpression[] elements)
	{
		_location = loc;
		_elements = elements;
	}
	
	override @property string kind()
	{
		return "array literal";
	}
	
	override @property IDeclNode[] children()
	{
		return cast(IDeclNode[])  _elements.dup;
	}
	
/+
	string toString() override
	{
		string result = "[ ";
		foreach( i, el; elements )
		{
			result ~= ( i == 0 ? "" : ", " ) ~ el.toString() ;
		}
		result ~= " ]\n";
		return result;
	}
+/
}


class AssocArrayLiteralExp(LocationConfig c): IExpression
{
	mixin BaseExpressionImpl!c;

private:
	IExpression[] _keys;
	IExpression[] _values;

public:
	this(CustLocation loc, IExpression[] keys, IExpression[] values)
	{
		_location = loc;
		_keys = keys;
		_values = values;
	}
	
	override @property string kind()
	{
		return "assoc array literal";
	}
	
	override @property IDeclNode[] children()
	{
		return cast(IDeclNode[])( _keys ~ _values );
	}

/+
	string toString() override
	{
		string result = "{ ";
		foreach( i, key; _keys )
		{
			result ~= ( i == 0 ? "" : ", " ) ~ key.toString() ~ ": " ~ _values[i].toString();
		}
		result ~= " }\n";
		return result;
	}
+/
}


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
	
	override @property IDeclNode[] children()
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
	
	override @property IDeclNode[] children()
	{
		return [_leftExpr, _rightExpr];
	}
}

class LogicalNotExp(LocationConfig c): IUnaryExpression
{
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
	
	override @property IDeclNode[] children()
	{
		return [_expr];
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
	
	override @property IDeclNode[] children()
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
	
	override @property IDeclNode[] children()
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

class IdentifierExp(LocationConfig c): IExpression
{
	mixin BaseExpressionImpl!c;
private:
	IIdentifier _id;
	
public:
	this( CustLocation loc, IIdentifier id )
	{
		_location = loc;
		_id = id;
	}
	
	override @property string kind()
	{
		return "identifier expr";
	}
	
	override @property IDeclNode[] children()
	{
		return null;
	}

}


class CallExp(LocationConfig c): IExpression
{
	mixin BaseExpressionImpl!c;
private:
	IIdentifier _id;
	IExpression[] _argList;

public:
	this( CustLocation loc, IIdentifier id, IExpression[] argList )
	{
		_location = loc;
		_id = id;
		_argList = argList;
	}
	
	override @property string kind()
	{
		return "call expr";
	}
	
	override @property IDeclNode[] children()
	{
		return cast(IDeclNode[]) _argList;
	}



}