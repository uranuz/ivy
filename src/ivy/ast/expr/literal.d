module ivy.ast.expr.literal;

import ivy.ast.common: BaseExpressionImpl;
import ivy.ast.iface.expr;

class UndefExp: ILiteralExpression
{
	mixin BaseExpressionImpl;

public:
	this(Location loc)
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

class NullExp: ILiteralExpression
{
	mixin BaseExpressionImpl;

public:
	this(Location loc)
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


class BooleanExp: ILiteralExpression
{
	mixin BaseExpressionImpl;

private:
	bool _value;

public:
	this(Location loc, bool val)
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

class IntegerExp: ILiteralExpression
{
	mixin BaseExpressionImpl;

private:
	IntegerType _value;

public:
	this(Location loc, IntegerType val)
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

class FloatExp: ILiteralExpression
{
	mixin BaseExpressionImpl;

private:
	FloatType _value;

public:
	this(Location loc, FloatType val)
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

class StringExp: ILiteralExpression
{
	mixin BaseExpressionImpl;
private:
	StringType _str;

public:
	this(Location location, StringType escapedStr)
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

class ArrayLiteralExp: ILiteralExpression
{
	mixin BaseExpressionImpl;

private:
	IExpression[] _elements;

public:
	this(Location loc, IExpression[] elements)
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


class AssocArrayPair: IAssocArrayPair
{
	import ivy.ast.common: BaseDeclNodeImpl;

	mixin BaseDeclNodeImpl;

private:
	string _key;
	IExpression _valueExpr;

public:
	this(Location loc, string name, IExpression value)
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

class AssocArrayLiteralExp: ILiteralExpression
{
	mixin BaseExpressionImpl;

private:
	IAssocArrayPair[] _pairs;

public:
	this(Location loc, IAssocArrayPair[] pairs)
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