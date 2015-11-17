module declarative.statement;

import declarative.common, declarative.node;

class Statement(LocationConfig c): IStatement
{
private:
	enum locConfig = c;
	alias CustLocation = CustomizedLocation!locConfig;

	private CustLocation _location;
	
	string _name;
	IDeclNode _parent;
	
	IDeclNode[] _plainAttrs;
	IDeclNode[] _keyValueAttrs;
	IDeclNode _mainBody;
	IDeclNode[] _continuations;
	
public:

	this(string name)
	{
		_name = name;
	}

	this(CustLocation location, string name, IDeclNode[] plainAttrs, IDeclNode[] keyValueAttrs, IDeclNode mainBody, IDeclNode[] continuations)
	{
		_location = location;
		_name = name;
		_plainAttrs = plainAttrs;
		_keyValueAttrs = keyValueAttrs;
		_mainBody = mainBody;
		_continuations = continuations;
	}

	public @property override {
		IDeclNode parent()
		{
			return _parent;
		}
		IDeclNode[] children()
		{
			return cast(IDeclNode[])( _plainAttrs[] ~ _keyValueAttrs[] ~ _mainBody ~ _continuations[] );
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

		string kind()
		{
			return "statement";
		}
	}
	
	public @property override
	{
		void parent(IDeclNode node)
		{
			_parent = node;
		}
	}
	
	// string toString();
	
	@property override {
	
		IDeclNode[] plainAttributes()
		{
			return _plainAttrs;
		}
		IDeclNode[] keyValueAttributes()
		{
			return _keyValueAttrs;
		}
		
		IDeclNode mainBody()
		{
			return _mainBody;
		}
		IDeclNode[] statementContinuations()
		{
			return _continuations;
		}
	}
	
}

class KeyValueAttribute(LocationConfig c): IDeclNode
{
	import declarative.expression: BaseExpressionImpl;
	
	mixin BaseExpressionImpl!c;

private:
	string _name;
	IExpression _expr;
	
public:
	
	this(CustLocation loc, string attrName, IExpression expr )
	{
		_location = loc;
		_name = attrName;
		_expr = expr;
	}
	
	override @property string kind()
	{
		return "key-value attribute";
	}
	
	override @property IDeclNode[] children()
	{
		return  [ cast(IDeclNode) _expr ];
	}
}

// class DefaultBlock: IDeclNode
// {


// }

// class CodeBlock: IDeclNode
// {
	

// }


// class MixedBlock: IDeclNode
// {

// }

// class RawTextBlock: IDeclNode
// {


// }


// class ExprEvalBlock: IDeclNode
// {

// }




