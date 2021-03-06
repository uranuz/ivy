module ivy.ast.expr.misc;

import ivy.ast.iface.expr: IExpression, INameExpression;
import ivy.ast.iface.misc: IIdentifier;
import ivy.ast.common: BaseExpressionImpl;

//Identifier for IdentifierExp should ne registered somewhere in symbols table
class IdentifierExp: INameExpression
{
	mixin BaseExpressionImpl;
private:
	IIdentifier _id;

public:
	this( Location loc, IIdentifier id )
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


class CallExp: IExpression
{
	mixin BaseExpressionImpl;
private:
	IExpression _callable;
	IvyNode[] _argList;

public:
	this( Location loc, IExpression callable, IvyNode[] argList )
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
