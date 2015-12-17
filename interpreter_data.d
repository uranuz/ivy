module declarative.interpreter_data;

import std.exception: enforceEx;
import std.traits;

enum DataNodeType { Null, Boolean, Integer, Floating, String, Array, AssocArray, CustomObject };

class DataNodeException : Exception
{
	this(string msg, int line = 0, int pos = 0)
	{
// 		if(line)
// 			super(text(msg, " (Line ", line, ":", pos, ")"));
// 		else
			super(msg);
	}
	this(string msg, string file, size_t line)
	{
		super(msg, file, line);
	}
}

struct DataNode(S)
{
	alias String = S;

	struct Storage {
		union {
			bool boolean;
			long integer;
			double floating;
			String str;
			DataNode[] array;
			DataNode[String] dict;
			Object custom;
		}
	}

	this(T)(auto ref T value)
	{
		assign(value);
	}

	Storage storage;
	private DataNodeType typeTag;

	bool boolean() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.Boolean, "DataNode is not boolean");
		return storage.boolean;
	}
	
	void boolean(bool val) @property
	{
		assign(val);
	}
	
	long integer() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.Integer, "DataNode is not integer");
		return storage.integer;
	}
	
	void integer(long val) @property
	{
		assign(val);
	}
	
	double floating() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.Floating, "DataNode is not floating");
		return storage.floating;
	}
	
	void floating(double val) @property
	{
		assign(val);
	}
	
	String str() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.String, "DataNode is not string");
		return storage.str;
	}
	
	void str(String val) @property
	{
		assign(val);
	}
	
	ref DataNode[] array() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.Array, "DataNode is not array");
		return storage.array;
	}
	
	void array(DataNode[] val) @property
	{
		assign(val);
	}
	
	DataNode[String] dict() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.AssocArray, "DataNode is not dict");
		return storage.dict;
	}
	
	void dict(DataNode[String] val) @property
	{
		assign(val);
	}
	
	DataNodeType type() @property
	{
		return typeTag;
	}
	
	bool empty() @property {
		return type == DataNodeType.Null;
	}
	
	private void assign(T)(auto ref T arg)
	{
		static if( is(T : typeof(null)) )
		{
			typeTag = DataNodeType.Null;
		}
		else static if( is(T : string) )
		{
			typeTag = DataNodeType.String;
			storage.str = arg;
		}
		else static if( is(T : bool) )
		{
			typeTag = DataNodeType.Boolean;
			storage.boolean = arg;
		}
		else static if( isIntegral!T )
		{
			typeTag = DataNodeType.Integer;
			storage.integer = arg;
		}
		else static if( isFloatingPoint!T )
		{
			typeTag = DataNodeType.Floating;
			storage.floating = arg;
		}
		else static if( is(T : Value[Key], Key, Value) )
		{
			static assert(is(Key : String), "AA key must be string");
				typeTag = DataNodeType.AssocArray;
			static if(is(Value : DataNode)) 
			{
				storage.dict = arg;
			}
			else
			{
				DataNode[String] aa;
				foreach(key, value; arg)
					aa[key] = DataNode(value);
				storage.dict = aa;
			}
		}
		else static if( isArray!T )
		{
			typeTag = DataNodeType.Array;
			static if( is(ElementEncodingType!T : DataNode) )
			{
				storage.array = arg;
			}
			else
			{
				DataNode[] new_arg = new DataNode[arg.length];
				foreach(i, e; arg)
					new_arg[i] = DataNode(e);
				storage.array = new_arg;
			}
		}
		else static if(is(T : DataNode))
		{
			typeTag = arg.type;
			storage = arg.storage;
		}
		else
			static assert(false, `unable to convert type "` ~ T.stringof ~ `" to parse node`);
	}
	
	void opAssign(T)(auto ref T value)
	{
		assign(value);
	}
	
	void opIndexAssign(T)(auto ref T value, size_t index)
	{
		enforceEx!DataNodeException( type == DataNodeType.Array, "DataNode is not an array");
		enforceEx!DataNodeException( index < storage.array.length , "DataNode array index is out of range");
		
		storage.array[index] = value;
	}
	
	ref DataNode opIndex(size_t index)
	{
		enforceEx!DataNodeException( type == DataNodeType.Array, "DataNode is not an array");
		enforceEx!DataNodeException( index < storage.array.length, "DataNode array index is out of range");
		
		return storage.array[index];
	}
	
	void opOpAssign(string op : "~", T)(auto ref T arg)
	{
		enforceEx!DataNodeException( type == DataNodeType.Array || type == DataNodeType.Null, "DataNode is not an array");
		
		if( type == DataNodeType.Null )
			this = (DataNode[]).init;
			
		static if( isArray!T )
		{
			static if( is( ElementType!T == DataNode ) )
			{
				storage.array ~= arg.storage.array;
			}
			else
			{
				foreach( ref elem; arg.storage.array )
					storage.array ~= DataNode(elem);
			}
		}
		else static if( is(T == DataNode) )
		{
			storage.array ~= arg;
		}
		else
		{
			storage.array ~= DataNode(arg);
		}
	}
	
	void opIndexAssign(T)(auto ref T value, String key)
	{
		enforceEx!DataNodeException( type == DataNodeType.AssocArray || type == DataNodeType.Null, "DataNode is not a dict or null");
		
		if( type == DataNodeType.Null )
			this = (DataNode[String]).init;
		
		storage.dict[key] = value;
	}
	
	ref DataNode opIndex(String key)
	{
		enforceEx!DataNodeException( type == DataNodeType.AssocArray, "DataNode is not a dict");
		enforceEx!DataNodeException( key in storage.dict, "DataNode dict has no such key");
		
		return storage.dict[key];
	}
	
	auto opBinaryRight(string op: "in")()
	{
		enforceEx!DataNodeException( type == DataNodeType.AssocArray || type == DataNodeType.Null, "DataNode is not a dict or null");
		
		if( type == DataNodeType.Null )
			return null;
		
		return key in storage.dict;
	}
	
	import std.array;
	import std.conv;
	
	static string indentText(string text, size_t times = 1)
	{
		string ind;
		foreach( i; 0..1 )
			ind ~= "  ";
		return ind ~ text.split("\r\n").join("\r\n" ~ ind);
	}
	
	string toString()
	{
		string result;
		
		switch( typeTag ) 
		{
			case DataNodeType.Null : {
				result ~= "null";
				break;
			} case DataNodeType.Boolean : {
				result ~= storage.boolean.to!string;
				break;
			} case DataNodeType.Integer : {
				result ~= storage.integer.to!string;
				break;
			} case DataNodeType.Floating : {
				result ~= storage.floating.to!string;
				break;
			} case DataNodeType.String : {
				result ~= `"` ~ storage.str ~ `"`;
				break;
			} case DataNodeType.Array : {
				foreach( i, ref el; storage.array )
				{
					string arrayStr = indentText( el.toString() );
					result ~= ( i > 0 ? ",\r\n" : "" ) ~ arrayStr ;
				}
				break;
			} case DataNodeType.AssocArray : {
				size_t i = 0;
				foreach( key, ref el; storage.dict )
				{
					string dictStr = indentText( el.toString(), 1 );
					result ~= ( i > 0 ? ",\r\n" : "" ) ~ key ~  ":" ~ dictStr;
					i++;
				}
				break;
			}	default:  {
				assert( false, "Shit happens!!!" );
			}
		}
		result = "\r\n" ~ result;
		return result;
	}
}