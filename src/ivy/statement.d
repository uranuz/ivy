module ivy.statement;

import ivy.common, ivy.node, ivy.node_visitor;

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
	IvyNode[] _attrs;
	
public:

	this( CustLocation loc, string name, IvyNode[] attributes )
	{
		_location = loc;
		_name = name;
		_attrs = attributes;
	}

	public @property override {
		IvyNode[] children()
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
		IAttributeRange opSlice()
		{
			return new Range(this);
		}
		
		IAttributeRange opSlice(size_t begin, size_t end)
		{
			return new Range(this, begin, end);
		}
	
	}
	
	static class Range: IAttributeRange
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
			@property IvyNode front()
			{
				return _statement._attrs[_begin];
			}
			
			void popFront() 
			{
				++_begin;
			}
			
			@property IvyNode back()
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
			
			@property IAttributeRange save()
			{
				return new Range(_statement, _begin, _end);
			}
			
			IvyNode opIndex(size_t index)
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
	IvyNode _value;
	
public:
	
	this(CustLocation loc, string attrName, IvyNode val )
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
	
		IvyNode[] children()
		{
			return  [ cast(IvyNode) _value ];
		}
	}
	
	override @property {
		string name()
		{
			return _name;
		}
		
		IvyNode value()
		{
			return _value;
		}
	}
}

mixin template BaseBlockStatementImpl(LocationConfig c, alias IRange = IStatementRange)
{
	mixin BaseDeclNodeImpl!(c);
	alias IStmt = typeof(IRange.front);
private:
	IStmt[] _statements;

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
		IvyNode[] children()
		{
			return cast(IvyNode[]) _statements.dup;
		}
	}
	
	IRange opSlice()
	{
		return new Range(this);
	}
	
	IRange opSlice(size_t begin, size_t end)
	{
		return new Range(this, begin, end);
	}
	
	alias TStatement = typeof(this);
	
	static class Range: IRange
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
			@property IStmt front()
			{
				return _statement._statements[_begin];
			}
			
			void popFront() 
			{
				++_begin;
			}
			
			@property IStmt back()
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
			
			@property IRange save()
			{
				return new Range(_statement, _begin, _end);
			}
			
			IStmt opIndex(size_t index)
			{
				return _statement._statements[index];
			}
		}
	}
}

class CodeBlockStatement(LocationConfig c): ICodeBlockStatement
{
	mixin BaseBlockStatementImpl!(c, IDirectiveStatementRange);

public:
	this(CustLocation loc, IDirectiveStatement[] stmts)
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

class DataFragmentStatement(LocationConfig c): IDataFragmentStatement
{
	mixin PlainStatementImpl!c;
private:
	string _data;

public:
	this(CustLocation loc, string data)
	{
		_location = loc;
		_data = data;
	}
	
	public @property override {
		IvyNode[] children()
		{
			return null;
		}
		
		string kind()
		{
			return "data fragment statement";
		}
	}
	
	public @property override {
		string data()
		{
			return _data;
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
		IvyNode[] children()
		{
			return null;
		}
		
		string kind()
		{
			return "raw data block statement";
		}
	}
}



