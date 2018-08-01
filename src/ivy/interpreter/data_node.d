module ivy.interpreter.data_node;

import ivy.common: IvyException;
import ivy.code_object: CodeObject;
import ivy.interpreter.data_node_types: CallableObject;
import ivy.interpreter.data_node_render: renderDataNode, DataRenderType;

interface IDataNodeRange
{
	alias TDataNode = DataNode!string;

	bool empty() @property;
	TDataNode front();
	void popFront();
}

interface IClassNode
{
	alias TDataNode = DataNode!string;
	IDataNodeRange opSlice();
	IClassNode opSlice(size_t, size_t);
	TDataNode opIndex(string);
	TDataNode opIndex(size_t);
	TDataNode __getAttr__(string);
	void __setAttr__(TDataNode, string);
	TDataNode __serialize__();
	size_t length() @property;
}

class DataNodeException: IvyException
{
	this(string msg, int line = 0, int pos = 0) {
		super(msg);
	}
	this(string msg, string file, size_t line)
	{
		super(msg, file, line);
	}
}

enum DataNodeType: ubyte {
	Undef,
	Null,
	Boolean,
	Integer,
	Floating,
	DateTime,
	String,
	Array,
	AssocArray,
	ClassNode,
	CodeObject,
	Callable,
	ExecutionFrame,
	DataNodeRange
};

enum NodeEscapeState: ubyte {
	Init, Safe, Unsafe
}

struct DataNode(S)
{
	import std.datetime: SysTime;
	import std.exception: enforce;
	import std.traits;
	import std.conv: text;
	import ivy.interpreter.execution_frame: ExecutionFrame;

	alias String = S;
	alias TDataNode = DataNode!(S);

	struct Storage {
		union {
			bool boolean;
			long integer;
			double floating;
			SysTime dateTime;
			// This is workaround of problem that DataNode is value type
			// and array with it's length copied, and length is not shared between instances.
			// So we put array item into another GC array with 1 item, so it becomes fully reference type
			// TODO: think how to implement it better
			String[] str;
			TDataNode[][] array;
			TDataNode[String] assocArray;
			IClassNode classNode;
			CodeObject codeObject;
			CallableObject callable;
			ExecutionFrame execFrame;
			IDataNodeRange dataRange;
		}
	}

	this(T)(auto ref T value) {
		assign(value);
	}

	private Storage storage;
	private DataNodeType typeTag;
	private NodeEscapeState _escapeState;

	bool boolean() @property
	{
		enforce!DataNodeException(type == DataNodeType.Boolean, "DataNode is not boolean");
		return storage.boolean;
	}

	void boolean(bool val) @property {
		assign(val);
	}

	long integer() @property
	{
		enforce!DataNodeException(type == DataNodeType.Integer, "DataNode is not integer");
		return storage.integer;
	}

	void integer(long val) @property {
		assign(val);
	}

	double floating() @property
	{
		enforce!DataNodeException(type == DataNodeType.Floating, "DataNode is not floating");
		return storage.floating;
	}

	void floating(double val) @property {
		assign(val);
	}

	SysTime dateTime() @property
	{
		enforce!DataNodeException(type == DataNodeType.DateTime, "DataNode is not DateTime");
		return storage.dateTime;
	}

	void dateTime(SysTime val) @property {
		assign(val);
	}

	ref String str() @property
	{
		enforce!DataNodeException(type == DataNodeType.String, "DataNode is not string");
		assert(storage.str.length == 1, "Expected internal storage length of 1");
		return storage.str[0];
	}

	void str(String val) @property {
		assign(val);
	}

	ref TDataNode[] array() @property
	{
		enforce!DataNodeException(type == DataNodeType.Array, "DataNode is not array");
		assert(storage.array.length == 1, "Expected internal storage length of 1");
		return storage.array[0];
	}

	void array(TDataNode[] val) @property {
		assign(val);
	}

	ref TDataNode[String] assocArray() @property
	{
		enforce!DataNodeException(type == DataNodeType.AssocArray, "DataNode is not dict");
		return storage.assocArray;
	}

	void assocArray(TDataNode[String] val) @property {
		assign(val);
	}

	IClassNode classNode() @property {
		enforce!DataNodeException(type == DataNodeType.ClassNode, "DataNode is not class node");
		return storage.classNode;
	}

	void classNode(IClassNode val) @property {
		assign(val);
	}

	CodeObject codeObject() @property
	{
		enforce!DataNodeException(type == DataNodeType.CodeObject, "DataNode is not code object");
		return storage.codeObject;
	}

	void codeObject(CodeObject val) @property {
		assign(val);
	}

	CallableObject callable() @property
	{
		enforce!DataNodeException( type == DataNodeType.Callable, "DataNode is not callable object");
		return storage.callable;
	}

	void callable(CallableObject val) @property {
		assign(val);
	}

	ExecutionFrame execFrame() @property
	{
		enforce!DataNodeException( type == DataNodeType.ExecutionFrame, "DataNode is not a execution frame");
		return storage.execFrame;
	}

	void execFrame(ExecutionFrame val) @property {
		assign(val);
	}

	IDataNodeRange dataRange() @property
	{
		enforce!DataNodeException( type == DataNodeType.DataNodeRange, "DataNode is not a data node range");
		return storage.dataRange;
	}

	void dataRange(IDataNodeRange val) @property {
		assign(val);
	}

	DataNodeType type() @property
	{
		if( typeTag == DataNodeType.ClassNode && storage.classNode is null ) {
			return DataNodeType.Null;
		}
		return typeTag;
	}

	bool empty() @property {
		return isUndef || isNull || (type == DataNodeType.ClassNode && storage.classNode[].empty);
	}

	bool isUndef() @property {
		return type == DataNodeType.Undef;
	}

	bool isNull() @property {
		return type == DataNodeType.Null || (type == DataNodeType.ClassNode && storage.classNode is null);
	}

	private void assign(T)(auto ref T arg)
	{
		static if( is(T : typeof(null)) )
		{
			typeTag = DataNodeType.Null;
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
		else static if( is( T : SysTime ) )
		{
			typeTag = DataNodeType.DateTime;
			storage.dateTime = arg;
		}
		else static if( is(T : string) )
		{
			typeTag = DataNodeType.String;
			storage.str = [arg];
		}
		else static if( isArray!T )
		{
			typeTag = DataNodeType.Array;
			static if( is(ElementEncodingType!T : TDataNode) ) {
				storage.array = [arg];
			}
			else
			{
				TDataNode[] new_arg;
				new_arg.length = arg.length;
				foreach(i, e; arg) {
					new_arg[i] = TDataNode(e);
				}
				storage.array = [new_arg];
			}
		}
		else static if( is(T : Value[Key], Key, Value) )
		{
			static assert(is(Key : String), "AA key must be string");

			if( storage.assocArray is null )
			{
				// Special workaround to make AA allocated somewhere in memory even if it is empty
				storage.assocArray = ["__allocateWorkaround__": TDataNode()];
				storage.assocArray.remove("__allocateWorkaround__");
			}

			if( arg is null ) {
				storage.assocArray.clear(); // Just clear, not set it to null
			}

			typeTag = DataNodeType.AssocArray;
			static if(is(Value : TDataNode)) {
				if( storage.assocArray !is null && arg !is null ) {
					storage.assocArray = arg; // Assign only if it is not null
				}
			}
			else
			{
				storage.assocArray.clear(); // Need to remove old data
				foreach(key, value; arg)
					storage.assocArray[key] = TDataNode(value);
				storage.assocArray.rehash(); // For faster lookups
			}
		}
		else static if( is( T : IClassNode ) )
		{
			typeTag = DataNodeType.ClassNode;
			storage.classNode = arg;
		}
		else static if( is( T : CodeObject ) )
		{
			typeTag = DataNodeType.CodeObject;
			storage.codeObject = arg;
		}
		else static if( is( T : CallableObject ) )
		{
			typeTag = DataNodeType.Callable;
			storage.callable = arg;
		}
		else static if( is( T : ExecutionFrame ) )
		{
			typeTag = DataNodeType.ExecutionFrame;
			storage.execFrame = arg;
		}
		else static if( is( T : IDataNodeRange ) )
		{
			typeTag = DataNodeType.DataNodeRange;
			storage.dataRange = arg;
		}
		else static if(is(T : TDataNode))
		{
			typeTag = arg.type;
			final switch(typeTag)
			{
				case DataNodeType.Undef, DataNodeType.Null:  break;
				case DataNodeType.Boolean: storage.boolean = arg.boolean; break;
				case DataNodeType.Integer: storage.integer = arg.integer; break;
				case DataNodeType.Floating: storage.floating = arg.floating; break;
				case DataNodeType.DateTime: storage.dateTime = arg.dateTime; break;
				case DataNodeType.String: storage.str = arg.storage.str; break;
				case DataNodeType.Array: storage.array = arg.storage.array; break;
				case DataNodeType.AssocArray: storage.assocArray = arg.assocArray; break;
				case DataNodeType.ClassNode: storage.classNode = arg.classNode; break;
				case DataNodeType.CodeObject: storage.codeObject = arg.codeObject; break;
				case DataNodeType.Callable: storage.callable = arg.callable; break;
				case DataNodeType.ExecutionFrame: storage.execFrame = arg.execFrame; break;
				case DataNodeType.DataNodeRange: storage.dataRange = arg.dataRange; break;
			}
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
		enforce!DataNodeException( type == DataNodeType.Array, "DataNode is not an array");
		assert(storage.array.length == 1, "Expected internal storage length of 1");
		enforce!DataNodeException( index < storage.array[0].length , "DataNode array index is out of range");

		storage.array[0][index] = value;
	}

	TDataNode opIndex(size_t index)
	{
		import std.algorithm: canFind;
		enforce!DataNodeException(
			[DataNodeType.Array, DataNodeType.ClassNode].canFind(type),
			"DataNode is not an array or class node, but is: " ~ type.text);
		if( type == DataNodeType.ClassNode ) {
			return storage.classNode is null? TDataNode(): storage.classNode[index];
		}
		assert(storage.array.length == 1, "Expected internal storage length of 1");
		enforce!DataNodeException(index < storage.array[0].length, "DataNode array index is out of range");

		return storage.array[0][index];
	}

	void opOpAssign(string op : "~", T)(auto ref T arg)
	{
		import std.algorithm: canFind;
		enforce!DataNodeException(
			[DataNodeType.Array, DataNodeType.Undef, DataNodeType.Null].canFind(type),
			"DataNode is not an array");

		if( type != DataNodeType.Array )
			this = (TDataNode[]).init;
		assert(storage.array.length == 1, "Expected internal storage length of 1");

		static if( isArray!T )
		{
			static if( is( ElementType!T == TDataNode ) )
			{
				storage.array[0] ~= arg.storage.array[0];
			}
			else
			{
				foreach( ref elem; arg )
					storage.array[0] ~= TDataNode(elem);
			}
		} else static if( is(T == TDataNode) ) {
			storage.array[0] ~= arg;
		} else {
			storage.array[0] ~= TDataNode(arg);
		}
	}

	void opIndexAssign(T)(auto ref T value, String key)
	{
		import std.algorithm: canFind;
		enforce!DataNodeException(
			[DataNodeType.AssocArray, DataNodeType.Null, DataNodeType.Undef].canFind(type),
			"DataNode is not a dict, null or undef");

		if( type != DataNodeType.AssocArray )
			this = (DataNode[String]).init;

		storage.assocArray[key] = value;
	}

	TDataNode opIndex(String key)
	{
		import std.algorithm: canFind;
		enforce!DataNodeException(
			[DataNodeType.AssocArray, DataNodeType.ClassNode].canFind(type),
			"DataNode is not a dict or class node, but is: " ~ type.text);
		if( type == DataNodeType.ClassNode ) {
			return storage.classNode is null? TDataNode(): storage.classNode[key];
		}
		
		enforce!DataNodeException(key in storage.assocArray, "DataNode dict has no such key");

		return storage.assocArray[key];
	}

	auto opBinaryRight(string op: "in")(String key)
	{
		import std.algorithm: canFind;
		enforce!DataNodeException(
			[DataNodeType.AssocArray, DataNodeType.Null, DataNodeType.Undef].canFind(type),
			"DataNode is not a dict, null or undef");

		if( type == DataNodeType.Undef || type == DataNodeType.Null )
			return null;

		return key in storage.assocArray;
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

	static TDataNode makeUndef() {
		TDataNode undef;
		undef.typeTag = DataNodeType.Undef;
		return undef;
	}

	bool opEquals(TDataNode rhs)
	{
		import std.range: zip;
		if( rhs.type != this.type ) {
			return false;
		}
		switch( this.type ) with(DataNodeType)
		{
			case Undef, Null: return true; // Undef and Null values are equal to each other
			case Boolean: return this.boolean == rhs.boolean;
			case Integer: return this.integer == rhs.integer;
			case Floating: return this.floating == rhs.floating;
			case DateTime: return this.dateTime == rhs.dateTime;
			case String: return this.str == rhs.str;
			case Array:
			{
				if( this.array.length != rhs.array.length ) {
					return false;
				}
				foreach( pair; zip(this.array, rhs.array) ) {
					// Use nested opEquals
					if( pair[0] != pair[1] ) {
						return false;
					}
				}
				return true; // All equal - fantastic!
			}
			case AssocArray:
			{
				if( this.assocArray.length != rhs.assocArray.length ) {
					return false;
				}
				foreach( key, val; this.assocArray )
				{
					if( auto valPtr = key in rhs.assocArray )
					{
						// Compare values
						if( *valPtr != val ) {
							return false;
						}
					} else {
						return false; // There is no suck key so they are not equal
					}
				}
				return true; // All keys exist and values are equal - fantastic!
			}
			case CodeObject: return this.codeObject == rhs.codeObject;
			default: throw new Exception(`Cannot compare data nodes of type: ` ~ this.type.text);
		}
	}

	void escapeState(NodeEscapeState state) @property {
		_escapeState = state;
	}

	NodeEscapeState escapeState()  @property {
		return _escapeState;
	}

	string toString()
	{
		import std.array: appender;
		auto result = appender!string();
		renderDataNode!(DataRenderType.Text)(this, result);
		return result.data;
	}

	string toDebugString()
	{
		import std.array: appender;
		auto result = appender!string();
		renderDataNode!(DataRenderType.TextDebug)(this, result);
		return result.data;
	}

	string toJSONString()
	{
		import std.array: appender;
		auto result = appender!string();
		renderDataNode!(DataRenderType.JSON)(this, result);
		return result.data;
	}
}


TDataNode deeperCopy(TDataNode)(auto ref TDataNode node)
{
	final switch( node.type ) with( DataNodeType )
	{
		case Undef, Null, Boolean, Integer, Floating, DateTime:
			// These types of nodes are value types, so make plain copy
			return node;
		case String:
			// String is not a value type, but they are immutable in D implementation,
			// so we only get new slice of existing string
			return node;
		case Array:
		{
			TDataNode[] newArray;
			newArray.length = node.array.length; // Preallocating
			foreach( i, ref el; node.array ) {
				newArray[i] = deeperCopy(el);
			}
			return TDataNode(newArray);
		}
		case AssocArray:
		{
			TDataNode[string] newAA;
			foreach( ref key, ref val; node.assocArray ) {
				newAA[key] = deeperCopy(val);
			}
			return TDataNode(newAA);
		}
		case ClassNode:
			assert( false, `Getting of deeper copy for class node is not implemented for now` );
		case CodeObject:
			// We don't do deeper copy of code object, because it should always be used as constant
			return node;
		case Callable:
			// These types of nodes shouldn't appear in module constants table so leave these not implemented for now
			assert( false, `Getting of deeper copy for callable is not implemented for now` );
		case ExecutionFrame:
			assert( false, `Getting of deeper copy for execution frame is not implemented for now` );
		case DataNodeRange:
			assert( false, `Getting of deeper copy for data node range is not implemented for now` );
	}
}