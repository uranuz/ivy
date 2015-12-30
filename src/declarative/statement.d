module declarative.statement;

import declarative.common, declarative.node;

mixin template PlainStatementImpl(LocationConfig c)
{
	mixin BaseDeclNodeImpl!c;

	public @property override {
		bool isCompoundStatement()
		{
			return false;
		}
		
		ICompoundStatement asCompoundStatement()
		{
			return null;
		}
		
		bool isDirectiveStatement()
		{
			return false;
		}
		
		IDirectiveStatement asDirectiveStatement()
		{
			return null;
		}
	}
}

class DirectiveStatement(LocationConfig c): IDirectiveStatement
{
	mixin PlainStatementImpl!c;

private:
	string _name;
	IDeclNode[] _attrs;
	
public:

	this( CustLocation loc, string name, IDeclNode[] attributes )
	{
		_location = loc;
		_name = name;
		_attrs = attributes;
	}

	public @property override {
		IDeclNode[] children()
		{
			return _attrs;
		}
		
		string kind()
		{
			return "directive statement";
		}
	}
	
	// string toString();
	
	public @property override {
		string name()
		{
			return _name;
		}
	}
	
	public @property override {
		bool isDirectiveStatement()
		{
			return true;
		}
		
		IDirectiveStatement asDirectiveStatement()
		{
			return this;
		}
	}
	
	public override {
		IAttributesRange opSlice()
		{
			return new Range(this);
		}
		
		IAttributesRange opSlice(size_t begin, size_t end)
		{
			return new Range(this, begin, end);
		}
	
	}
	
	static class Range: IAttributesRange
	{
	private:
		DirectiveStatement!c _statement;
		size_t _begin;
		size_t _end;

	public:

		this(DirectiveStatement!c statement)
		{
			_statement = statement;
			_end = _statement._attrs.length - 1;
		}
		
		this(DirectiveStatement!c statement, size_t begin, size_t end)
		{
			_statement = statement;
			_begin = begin;
			_end = end;
		}
		
		public override {
			@property IDeclNode front()
			{
				return _statement._attrs[_begin];
			}
			
			void popFront() 
			{
				++_begin;
			}
			
			@property IDeclNode back()
			{ 
				return _statement._attrs[_end];
			}
			
			void popBack()
			{
				--_end;
			}
			
			bool empty()
			{
				if( _begin <= _end && _end < _statement._attrs.length )
					return false;
					
				return true;
			}
			//@property size_t length();
			
			@property IAttributesRange save()
			{
				return new Range(_statement, _begin, _end);
			}
			
			IDeclNode opIndex(size_t index)
			{
				return _statement._attrs[index];
			}
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
		
		bool isDirectiveStatement()
		{
			return false;
		}
		
		IDirectiveStatement asDirectiveStatement()
		{
			return null;
		}
	}
	
	public @property override {
		IDeclNode[] children()
		{
			return cast(IDeclNode[]) _statements.dup;
		}
	}
	
	IStatementRange opSlice()
	{
		return new Range(this);
	}
	
	IStatementRange opSlice(size_t begin, size_t end)
	{
		return new Range(this, begin, end);
	}
	
	alias TStatement = typeof(this);
	
	static class Range: IStatementRange
	{
	private:
		TStatement _statement;
		size_t _begin;
		size_t _end;

	public:

		this(TStatement statement)
		{
			_statement = statement;
			_end = _statement._statements.length - 1;
		}
		
		this(TStatement statement, size_t begin, size_t end)
		{
			_statement = statement;
			_begin = begin;
			_end = end;
		}
		
		public override {
			@property IStatement front()
			{
				return _statement._statements[_begin];
			}
			
			void popFront() 
			{
				++_begin;
			}
			
			@property IStatement back()
			{ 
				return _statement._statements[_end];
			}
			
			void popBack()
			{
				--_end;
			}
			
			bool empty()
			{
				if( _begin <= _end && _end < _statement._statements.length )
					return false;
					
				return true;
			}
			//@property size_t length();
			
			@property IStatementRange save()
			{
				return new Range(_statement, _begin, _end);
			}
			
			IStatement opIndex(size_t index)
			{
				return _statement._statements[index];
			}
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



