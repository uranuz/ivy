module declarative.statement;

import declarative.common, declarative.node;

mixin template PlainStatementImpl(LocationConfig c, T = IDeclNode)
{
	mixin BaseDeclNodeImpl!(c, T);

	public @property override {
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
	IDeclarationSection _mainSection;
	IDeclarationSection[] _sections;
	
public:

	this(CustLocation location, IDeclarationSection mainSec, IDeclarationSection[] sections)
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
	
		IDeclarationSection mainSection()
		{
			return _mainSection;
		}
		
		IDeclarationSection[] sections()
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
	IDeclNode[] _plainAttrs;
	IKeyValueAttribute[] _keyValueAttrs;
	
	IStatement _statement;

public:
	this( CustLocation loc, string name, IDeclNode[] plainAttrs, IKeyValueAttribute[] keyValueAttrs, IStatement stmt )
	{
		_location = loc;
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
		
		IDeclNode[] plainAttributes()
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
			return _plainAttrs ~ cast(IDeclNode[])(_keyValueAttrs) ~ cast(IDeclNode)(_statement);
		}
		
		string kind()
		{
			return "statement section";
		}
	}

}

class KeyValueAttribute(LocationConfig c): IKeyValueAttribute
{
	mixin BaseDeclNodeImpl!c;

private:
	string _name;
	IDeclNode _value;
	
public:
	
	this(CustLocation loc, string attrName, IDeclNode val )
	{
		_location = loc;
		_name = attrName;
		_value = val;
	}
	
	override @property {
		string kind()
		{
			return "key-value attribute";
		}
	
		IDeclNode[] children()
		{
			return  [ cast(IDeclNode) _value ];
		}
	}
	
	override @property {
		string name()
		{
			return _name;
		}
		
		IDeclNode value()
		{
			return _value;
		}
	}
}

mixin template BaseBlockStatementImpl(LocationConfig c)
{
	mixin BaseDeclNodeImpl!(c);
private:
	IStatement[] _statements;

public:
	public @property override {
		bool isCompoundStatement()
		{
			return true;
		}
		
		ICompoundStatement asCompoundStatement()
		{
			return this;
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
	
	import std.range: empty;
	
	override IStatement opIndex(size_t index)
	{
		return _statements[index];
	}
	
	override @property {
		IStatement first()
		{
			return _statements.empty ? null : _statements[0];
		}
		
		IStatement last()
		{
			return _statements.empty ? null : _statements[_statements.length - 1];
		}
	}
	
	public @property override {
		IDeclNode[] children()
		{
			return cast(IDeclNode[]) _statements.dup;
		}
	}

}

class CodeBlockStatement(LocationConfig c): ICompoundStatement
{
	mixin BaseBlockStatementImpl!c;
	
private:


public:
	this(CustLocation loc, IStatement[] stmts)
	{
		_location = loc;
		_statements = stmts;
	}
	
	public @property override {
		string kind()
		{
			return "code block statement";
		}
	}
}

class MixedBlockStatement(LocationConfig c): ICompoundStatement
{
	mixin BaseBlockStatementImpl!c;
private:

public:
	this(CustLocation loc, IStatement[] stmts)
	{
		_location = loc;
		_statements = stmts;
	}
	
	public @property override {
		string kind()
		{
			return "mixed block statement";
		}
	}

}


class DataFragmentStatement(LocationConfig c): IStatement
{
	mixin PlainStatementImpl!c;
private:

public:
	this(CustLocation loc)
	{
		_location = loc;
	}
	
	public @property override {
		IDeclNode[] children()
		{
			return null;
		}
		
		string kind()
		{
			return "data fragment statement";
		}
	}
}

class RawDataBlockStatement(LocationConfig c): IStatement
{
	mixin PlainStatementImpl!c;
private:

public:
	this(CustLocation loc, IStatement[] stmts)
	{
		_location = loc;
		_statements = stmts;
	}
	
	public @property override {
		IDeclNode[] children()
		{
			return null;
		}
		
		string kind()
		{
			return "raw data block statement";
		}
	}
}



