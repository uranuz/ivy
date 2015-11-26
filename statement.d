module declarative.statement;

import declarative.common, declarative.node;

mixin template PlainStatementImpl(LocationConfig c, T = IDeclNode)
{
	mixin BaseDeclNodeImpl!(c, T);

	@property {
		bool isCompoundStatement()
		{
			return false;
		}
		
		ICompoundStatement asCompoundStatement()
		{
			return null;
		}
		
		bool isDeclarativeStatement()
		{
			return false;
		}
		
		IDeclarativeStatement asDeclarativeStatement()
		{
			return null;
		}
	}
}

class DeclarativeStatement(LocationConfig c): IDeclarativeStatement
{
	mixin PlainStatementImpl!c;

private:
	IStatementSection _mainSection;
	IStatementSection[] _sections;
	
public:

	this(CustLocation location, IStatementSection mainSec, IStatementSection[] sections)
	{
		_location = location;
		_mainSection = mainSec;
		_sections = sections;
	}

	public @property override {
		IDeclNode[] children()
		{
			return cast(IDeclNode[])( _mainSection ~ _sections );
		}
		
		string kind()
		{
			return "statement";
		}
	}
	
	// string toString();
	
	public @property override {
		string name()
		{
			if( _mainSection )
				return _mainSection.name;
				
			return null;
		}
	
		IDeclNode mainSection()
		{
			return _mainSection;
		}
		
		IDeclNode[] sections()
		{
			return _sections;
		}
	}
	
	public @property override {
		bool isDeclarativeStatement()
		{
			return true;
		}
		
		IDeclarativeStatement asDeclarativeStatement()
		{
			return this;
		}
	}
	
}

class DeclarationSection(LocationConfig c): IDeclarationSection
{
	mixin PlainStatementImpl!c;
private:
	string _name;
	IExpression[] _plainAttrs;
	IKeyValueAttribute[] _keyValueAttrs;
	
	IStatement _statement;

public:
	this( CustLocation loc, string name, IExpression[] plainAttrs, IKeyValueAttribute[] keyValueAttrs, IStatement stmt )
	{
		_location = location;
		_name = name;
		_plainAttrs = plainAttrs;
		_keyValueAttrs = keyValueAttrs;
		_statement = stmt;
	}


	public @property override {
		string name()
		{
			return _name;
		}
		
		IExpression[] plainAttributes()
		{
			return _plainAttrs;
		}
		
		IKeyValueAttribute[] keyValueAttributes()
		{
			return _keyValueAttrs;
		}
		
		IStatement statement()
		{
			return _statement;
		}
	}
	
	public @property override {
		IDeclNode[] children()
		{
			return cast(IDeclNode[])( _plainAttrs ~ _keyValueAttrs ~ _body );
		}
		
		string kind()
		{
			return "statement section";
		}
	}


}

/+
class PlainAttribute: IPlainAttribute
{
	mixin BaseDeclNodeImpl!c;
private:
	IExpression _expr;
	
public:
	this(CustLocation loc, IExpression expr)
	{
		_location = loc;
		_expr = expr;
	}

	override @property {
		string kind()
		{
			return "plain attribute";
		}
	
		IDeclNode[] children()
		{
			return  [ cast(IDeclNode) _expr ];
		}
	}
	
	override @property {
		IExpression expression()
		{
			return _expr;		
		}
	}

}
+/

class KeyValueAttribute(LocationConfig c): IKeyValueAttribute
{
	mixin BaseDeclNodeImpl!c;

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
	
	override @property {
		string kind()
		{
			return "key-value attribute";
		}
	
		IDeclNode[] children()
		{
			return  [ cast(IDeclNode) _expr ];
		}
	}
	
	override @property {
		string name()
		{
			return _name;
		}
		
		IExpression expression()
		{
			return _expr;		
		}
	}
}

class BlockStatement(LocationConfig c): ICompoundStatement
{
	mixin PlainStatementImpl!c;
	
private:
	IStatement[] _statements;

public:
	this(CustLocation loc, IStatement[] stmts)
	{
		_location = loc;
		_statements = stmts;
	}
	
	public @property override {
		bool isCompound()
		{
			return true;
		}
		
		ICompoundStatement asCompoundStatement()
		{
			return this;
		}
	
	}
	
	public @property override {
		IStatement[] statements()
		{
			return _statements;
		}
	}
}

enum TextBlockType { Mixed, Raw };

class TextBlockStatement(LocationConfig c): IStatement
{
	mixin PlainStatementImpl!c;
private:
	TextBlockType _textBlockType;
	size_t _indent;
	

public:
	this(CustLocation loc, TextBlockType blockType, size_t indent = 0)
	{
		_location = loc;
		_textBlockType = blockType;
		_indent = indent;
	}

	public @property override {
		IDeclNode[] children()
		{
			return null;
		}
		
		string kind()
		{
			return "text block statement";
		}
	}
}



