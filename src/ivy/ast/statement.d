module ivy.ast.statement;

import ivy.ast.common: BaseDeclNodeImpl;
import ivy.ast.iface;

mixin template PlainStatementImpl()
{
	mixin BaseDeclNodeImpl;

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

class DirectiveStatement: IDirectiveStatement
{
	mixin PlainStatementImpl;

private:
	string _name;
	IvyNode[] _attrs;

public:

	this(Location loc, string name, IvyNode[] attributes)
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
		DirectiveStatement _statement;
		size_t _begin;
		size_t _end;

	public:

		this(DirectiveStatement statement)
		{
			_statement = statement;
			_end = _statement._attrs.length - 1;
		}

		this(DirectiveStatement statement, size_t begin, size_t end)
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

class KeyValueAttribute: IKeyValueAttribute
{
	mixin BaseDeclNodeImpl;

private:
	string _name;
	IvyNode _value;

public:

	this(Location loc, string attrName, IvyNode val )
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

mixin template BaseBlockStatementImpl(alias IRange = IStatementRange)
{
	import ivy.ast.common: BaseExpressionImpl;

	mixin BaseExpressionImpl;
	//mixin BaseDeclNodeImpl!(c);
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

class CodeBlockStatement: ICodeBlockStatement
{
	mixin BaseBlockStatementImpl!(IDirectiveStatementRange);
	private bool _isListBlock;

public:
	this(Location loc, IDirectiveStatement[] stmts, bool isList)
	{
		_location = loc;
		_statements = stmts;
		_isListBlock = isList;
	}

	public @property override {
		string kind()
		{
			return _isListBlock ? "code list statement" : "code block statement";
		}

		bool isListBlock()
		{
			return _isListBlock;
		}
	}
}

class MixedBlockStatement: IMixedBlockStatement
{
	mixin BaseBlockStatementImpl;
private:

public:
	this(Location loc, IStatement[] stmts)
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

class DataFragmentStatement: IDataFragmentStatement
{
	mixin PlainStatementImpl;
private:
	string _data;

public:
	this(Location loc, string data)
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
