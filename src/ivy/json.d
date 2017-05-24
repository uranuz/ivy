/// This module serves to parse JSON data directly into Ivy internal data format
module ivy.json;

import ivy.interpreter_data;
import ivy.lexer_tools;
import ivy.common;

class IvyJSONException: Exception
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}
}

struct JSONParser(S = string, LocationConfig c = LocationConfig.init)
{
	alias String = S;
	alias SourceRange = TextForwardRange!(String, c);
	alias Char = SourceRange.Char;
	alias TDataNode = DataNode!(String);

private:
	SourceRange _source;

public:
	this(SourceRange src)
	{
		_source = src.save;
	}

	this(String src)
	{
		_source = SourceRange(src);
	}

	import std.ascii: isDigit, isWhite;

	void error(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		import std.conv: to;
		throw new IvyJSONException(`Parsing error in: ` ~ _source.str ~ `..: ` ~ msg, file, line);
	}

	String parseString()
	{
		import std.array: appender;
		
		assert( getChar() == '\"', "Expected \"" );
		_source.popFront(); // Skip "
		
		auto buf = appender!String();

		while( !_source.empty )
		{
			if( _source.front == '\\' )
			{
				_source.popFront();
				switch( _source.front )
				{
					case '"': buf.put('"');   break;
					case '\\': buf.put('\\'); break;
					case '/': buf.put('/');   break;
					case 'b': buf.put('\b');  break;
					case 'f': buf.put('\f');  break;
					case 'n': buf.put('\n');  break;
					case 'r': buf.put('\r');  break;
					case 't': buf.put('\t');  break;
					case 'u': assert(false, "UTF escape sequences parsing not implemented yet!"); break;

					default:
						error( "Unexpected escape sequence..." );
				}
				
				_source.popFront(); // Skip escaped character
			}
			else if( _source.front == '\"' )
			{
				break; // Found end of string
			}
			else
			{
				buf.put(_source.front);
				_source.popFront();
			}
		}

		if( _source.empty || _source.front != '"' )
			error( "Expected \"" );
		_source.popFront(); // Skip "

		return buf.data;
	}

	void skipWhitespace()
	{
		while( !_source.empty )
		{
			if( !isWhite(_source.front) )
				break;
			_source.popFront(); // Skip whitespace character
		}
	}

	Char getChar()
	{
		this.skipWhitespace();
		return _source.front;
	}

	void parseInteger()
	{
		if( _source.empty || !isDigit(_source.front) ) error(`Expected digit`);

		while( !_source.empty )
		{
			if( !isDigit(_source.front) )
				break;
			_source.popFront();
		}
	}

	TDataNode parseNumber()
	{
		import std.conv: to;
		assert( isDigit( getChar() ) || getChar() == '-', `Expected number` );

		auto beginRange = _source.save;
		if( getChar() == '-' )
			_source.popFront();
		
		parseInteger();
		bool isFloat = false;
		if( _source.front == '.' )
		{
			_source.popFront(); // Skip point
			parseInteger();
			isFloat = true;
		}

		String strValue= _source.str[ beginRange.index .. _source.index ];
		if( isFloat )
			return TDataNode( strValue.to!double );
		else
			return TDataNode( strValue.to!int );
	}

	TDataNode parseValue()
	{
		while( !_source.empty )
		{
			Char ch = getChar();
			switch( ch )
			{
				case '{':
				{
					_source.popFront(); // Skip {
					TDataNode[String] assocArray;
					while( !_source.empty && getChar() != '}' )
					{
						string key = parseString();

						if( !_source.empty && getChar() != ':' )
							error( "Expected :" );
						
						_source.popFront(); // Skip :

						TDataNode value = parseValue();
						assocArray[key] = value;
						
						if( getChar() == '}' )
							break;
						
						if( _source.empty || getChar() != ',' )
							error( `Expected ,` );
						_source.popFront(); // Skip ,
					}

					if( _source.empty || _source.front != '}' )
						error("Expected }");
					_source.popFront(); // Skip }

					return TDataNode(assocArray);
				}
				case '[':
				{
					_source.popFront(); // Skip [
					TDataNode[] nodeArray;
					while( !_source.empty && getChar() != ']' )
					{
						nodeArray ~= parseValue();
						if( getChar() == ']' )
							break;
						
						if( getChar() != ',' )
							error( `Expected ,` );
						_source.popFront(); // Skip ,
					}

					if( _source.empty || _source.front != ']' )
						error("Expected ]");
					_source.popFront(); // Skip ]

					return TDataNode(nodeArray);
				}
				case '"':
					return TDataNode(parseString());
				case '0': .. case '9':
				case '-':
					return parseNumber();
				case 't':
					if( !_source.match("true") )
						error( "Expected true" );
					return TDataNode(true);
				case 'f':
					if( !_source.match("false") )
						error( "Expected false" );
					return TDataNode(false);
				case 'n':
					if( !_source.match("null") )
						error( "Expected null" );
					return TDataNode(null);
				default:
					error( "Unexpected escaped character" );
			}
		}

		return TDataNode();
	}
}

/// Interface method to parse JSON string into ivy internal data format
auto parseIvyJSON(S)(S src)
{
	auto parser = JSONParser!(S)(src);
	return parser.parseValue();
}

import std.json;
auto toIvyJSON(ref JSONValue src)
{
	alias TDataNode = DataNode!string;

	final switch( src.type )
	{
		case JSON_TYPE.NULL:
			return TDataNode(null);
		case JSON_TYPE.TRUE:
			return TDataNode(true);
		case JSON_TYPE.FALSE:
			return TDataNode(false);
		case JSON_TYPE.INTEGER:
			return TDataNode(src.integer);
		case JSON_TYPE.UINTEGER:
			return TDataNode(src.uinteger);
		case JSON_TYPE.FLOAT:
			return TDataNode(src.floating);
		case JSON_TYPE.STRING:
			return TDataNode(src.str);
		case JSON_TYPE.ARRAY:
		{
			TDataNode[] nodeArray;
			nodeArray.length = src.array.length;
			foreach( size_t i, val; src.array ) {
				nodeArray[i] = val.toIvyJSON;
			}
			return TDataNode(nodeArray);
		}
		case JSON_TYPE.OBJECT:
		{
			TDataNode[string] nodeAA;
			foreach( string key, val; src.object ) {
				nodeAA[key] = val.toIvyJSON;
			}
			return TDataNode(nodeAA);
		}
	}
	assert(false, `Shouldn't be reached!`);
}