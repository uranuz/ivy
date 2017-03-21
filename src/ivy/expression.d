module ivy.expression;

import ivy.node, ivy.common, ivy.node_visitor;

mixin template BaseExpressionImpl(LocationConfig c)
{
	mixin BaseDeclNodeImpl!c;
	
	public @property override
	{
		IStatement asStatement() {
			return null;
		}

		LiteralType literalType() {
			return LiteralType.NotLiteral;
		}

		bool isScalar() {
			assert( 0, "Cannot determine expression type" );
		}

		bool isNullExpr() {
			assert( 0, "Expression is not null expr!" );
		}
	}
	
	public override {
		bool toBoolean() {
			assert( 0, "Expression is not boolean!" );
		}
		
		int toInteger() {
			assert( 0, "Expression is not integer!" );
		}
		
		double toFloating() {
			assert( 0, "Expression is not floating!" );
		}
		
		string toStr() {
			assert( 0, "Expression is not string!" );
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

class UndefExp(LocationConfig c): ILiteralExpression
{
	mixin BaseExpressionImpl!c;

public:
	this(CustLocation loc)
	{
		_location = loc;
	}

	override @property string kind()
	{
		return "undef";
	}

	override @property IvyNode[] children()
	{
		return null;
	}

	override @property LiteralType literalType()
	{
		return LiteralType.Undef;
	}

/+
	string toString() override
	{
		return "undef";
	}
+/
}

class NullExp(LocationConfig c): ILiteralExpression
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
	
	override @property IvyNode[] children()
	{
		return null;
	}
	
	override @property LiteralType literalType()
	{
		return LiteralType.Null;
	}

/+
	string toString() override
	{
		return "null";
	}
+/
}


class BooleanExp(LocationConfig c): ILiteralExpression
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
	
	override @property IvyNode[] children()
	{
		return null;
	}
	
	override @property LiteralType literalType()
	{
		return LiteralType.Boolean;
	}
	
	override bool toBoolean()
	{
		return _value;
	}

/+
	string toString() override
	{
		return _value ? "true" : "false";
	}
+/
}

alias IntegerType = int;

class IntegerExp(LocationConfig c): ILiteralExpression
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
	
	override @property IvyNode[] children()
	{
		return null;
	}
	
	override @property LiteralType literalType()
	{
		return LiteralType.Integer;
	}

	override int toInteger()
	{
		return _value;
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

class FloatExp(LocationConfig c): ILiteralExpression
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
	
	override @property IvyNode[] children()
	{
		return null;
	}
	
	override @property LiteralType literalType()
	{
		return LiteralType.Floating;
	}
	
	override double toFloating()
	{
		return _value;
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

class StringExp(LocationConfig c): ILiteralExpression
{
	mixin BaseExpressionImpl!c;
private:
	StringType _str;

public:
	this(CustLocation location, StringType escapedStr)
	{
		_location = location;
		_str = escapedStr;
	}

	override @property string kind()
	{
		return "string";
	}
	
	override @property IvyNode[] children()
	{
		return null;
	}
	
	override @property LiteralType literalType()
	{
		return LiteralType.String;
	}
	
	override string toStr() 
	{
		return _str;
	}
}

class ArrayLiteralExp(LocationConfig c): ILiteralExpression
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
	
	override @property IvyNode[] children()
	{
		return cast(IvyNode[])  _elements.dup;
	}
	
	override @property LiteralType literalType()
	{
		return LiteralType.Array;
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

class AssocArrayPair(LocationConfig c): IAssocArrayPair
{
	mixin BaseDeclNodeImpl!c;

private:
	string _key;
	IExpression _valueExpr;

public:
	this(CustLocation loc, string name, IExpression value)
	{
		_location = loc;
		_key = name;
		_valueExpr = value;
	}

	override @property {
		string key()
		{
			return _key;
		}

		IExpression value()
		{
			return _valueExpr;
		}
	}

	override @property string kind()
	{
		return "assoc array pair";
	}

	override @property IvyNode[] children()
	{
		return cast(IvyNode[])  [_valueExpr];
	}

}

class AssocArrayLiteralExp(LocationConfig c): ILiteralExpression
{
	mixin BaseExpressionImpl!c;

private:
	IAssocArrayPair[] _pairs;

public:
	this(CustLocation loc, IAssocArrayPair[] pairs)
	{
		_location = loc;
		_pairs = pairs;
	}
	
	override @property string kind()
	{
		return "assoc array literal";
	}
	
	override @property IvyNode[] children()
	{
		return cast(IvyNode[]) _pairs;
	}
	
	override @property LiteralType literalType()
	{
		return LiteralType.AssocArray;
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
	
	override @property IvyNode[] children()
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

//Identifier for IdentifierExp should ne registered somewhere in symbols table
class IdentifierExp(LocationConfig c): INameExpression
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
	
	override @property IvyNode[] children()
	{
		return null;
	}
	
	override @property string name()
	{
		return _id.name;
	}

}


class CallExp(LocationConfig c): IExpression
{
	mixin BaseExpressionImpl!c;
private:
	IExpression _callable;
	IvyNode[] _argList;

public:
	this( CustLocation loc, IExpression callable, IvyNode[] argList )
	{
		_location = loc;
		_callable = callable;
		_argList = argList;
	}
	
	override @property string kind()
	{
		return "call expr";
	}
	
	override @property IvyNode[] children()
	{
		return (cast(IvyNode) _callable) ~ _argList;
	}

}

class BlockExp(LocationConfig c): IExpression
{
	mixin BaseExpressionImpl!c;
private:
	ICompoundStatement _blockStatement;
	
public:
	this( CustLocation loc, ICompoundStatement blockStmt )
	{
		_location = loc;
		_blockStatement = blockStmt;
	}
	
	override @property {
		ICompoundStatement statement()
		{
			return _blockStatement;
		}
		
	}

	
}

