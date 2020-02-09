module ivy.ast.expr.misc;

import trifle.location: LocationConfig;

import ivy.ast.iface.expr: IExpression, INameExpression;
import ivy.ast.iface.misc: IIdentifier;
import ivy.ast.common: BaseExpressionImpl;

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

