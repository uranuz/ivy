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
	DataNodeType aggrType() @property;
}

interface IClassNode
{
	alias TDataNode = DataNode!string;
	IDataNodeRange opSlice();
	TDataNode opIndex(string);
	TDataNode opIndex(size_t);
	TDataNode __getAttr__(string);
	void __setAttr__(TDataNode, string);
	TDataNode __serialize__();
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
	Undef, Null, Boolean, Integer, Floating, String, DateTime, Array, AssocArray, ClassNode,
	CodeObject, Callable, ExecutionFrame, DataNodeRange
};

enum NodeEscapeState: ubyte {
	Init, Safe, Unsafe
}

struct DataNode(S)
{
	import std.datetime: SysTime;
	import std.exception: enforceEx;
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
			String str;
			DataNode[] array;
			SysTime dateTime;
			DataNode[String] assocArray;
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
		enforceEx!DataNodeException(type == DataNodeType.Boolean, "DataNode is not boolean");
		return storage.boolean;
	}

	void boolean(bool val) @property {
		assign(val);
	}

	long integer() @property
	{
		enforceEx!DataNodeException(type == DataNodeType.Integer, "DataNode is not integer");
		return storage.integer;
	}

	void integer(long val) @property {
		assign(val);
	}

	double floating() @property
	{
		enforceEx!DataNodeException(type == DataNodeType.Floating, "DataNode is not floating");
		return storage.floating;
	}

	void floating(double val) @property {
		assign(val);
	}

	String str() @property
	{
		enforceEx!DataNodeException(type == DataNodeType.String, "DataNode is not string");
		return storage.str;
	}

	void str(String val) @property {
		assign(val);
	}

	SysTime dateTime() @property
	{
		enforceEx!DataNodeException(type == DataNodeType.DateTime, "DataNode is not DateTime");
		return storage.dateTime;
	}

	void dateTime(SysTime val) @property {
		assign(val);
	}

	ref DataNode[] array() @property
	{
		enforceEx!DataNodeException(type == DataNodeType.Array, "DataNode is not array");
		return storage.array;
	}

	void array(DataNode[] val) @property {
		assign(val);
	}

	ref DataNode[String] assocArray() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.AssocArray, "DataNode is not dict");
		return storage.assocArray;
	}

	void assocArray(DataNode[String] val) @property {
		assign(val);
	}

	IClassNode classNode() @property {
		enforceEx!DataNodeException( type == DataNodeType.ClassNode, "DataNode is not class node");
		return storage.classNode;
	}

	void classNode(IClassNode val) @property {
		assign(val);
	}

	CodeObject codeObject() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.CodeObject, "DataNode is not code object");
		return storage.codeObject;
	}

	void codeObject(CodeObject val) @property {
		assign(val);
	}

	CallableObject callable() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.Callable, "DataNode is not callable object");
		return storage.callable;
	}

	void callable(CallableObject val) @property {
		assign(val);
	}

	ExecutionFrame execFrame() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.ExecutionFrame, "DataNode is not a execution frame");
		return storage.execFrame;
	}

	void execFrame(ExecutionFrame val) @property {
		assign(val);
	}

	IDataNodeRange dataRange() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.DataNodeRange, "DataNode is not a data node range");
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
		else static if( is( T : SysTime ) )
		{
			typeTag = DataNodeType.DateTime;
			storage.dateTime = arg;
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
		else static if( is(T : Value[Key], Key, Value) )
		{
			static assert(is(Key : String), "AA key must be string");

			typeTag = DataNodeType.AssocArray;
			static if(is(Value : DataNode)) {
				storage.assocArray = arg;
			}
			else
			{
				DataNode[String] aa;
				foreach(key, value; arg)
					aa[key] = DataNode(value);
				storage.assocArray = aa;
			}
		}
		else static if( isArray!T )
		{
			typeTag = DataNodeType.Array;
			static if( is(ElementEncodingType!T : DataNode) ) {
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
		else static if(is(T : TDataNode))
		{
			typeTag = arg.type;
			final switch(typeTag)
			{
				case DataNodeType.Undef, DataNodeType.Null:  break;
				case DataNodeType.Boolean: storage.boolean = arg.boolean; break;
				case DataNodeType.Integer: storage.integer = arg.integer; break;
				case DataNodeType.Floating: storage.floating = arg.floating; break;
				case DataNodeType.String: storage.str = arg.str; break;
				case DataNodeType.DateTime: storage.dateTime = arg.dateTime; break;
				case DataNodeType.Array: storage.array = arg.array; break;
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
		enforceEx!DataNodeException( type == DataNodeType.Array, "DataNode is not an array");
		enforceEx!DataNodeException( index < storage.array.length , "DataNode array index is out of range");

		storage.array[index] = value;
	}

	DataNode opIndex(size_t index)
	{
		import std.algorithm: canFind;
		enforceEx!DataNodeException( [DataNodeType.Array, DataNodeType.ClassNode].canFind(type), "DataNode is not an array or class node, but is: " ~ type.text);
		if( type == DataNodeType.ClassNode ) {
			return storage.classNode is null? DataNode(): storage.classNode[index];
		}
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
		enforceEx!DataNodeException( type == DataNodeType.AssocArray || type == DataNodeType.Null || type == DataNodeType.Undef, "DataNode is not a dict, null or undef");

		if( type != DataNodeType.AssocArray )
			this = (DataNode[String]).init;

		storage.assocArray[key] = value;
	}

	DataNode opIndex(String key)
	{
		import std.algorithm: canFind;
		enforceEx!DataNodeException( [DataNodeType.AssocArray, DataNodeType.ClassNode].canFind(type), "DataNode is not a dict or class node, but is: " ~ type.text);
		if( type == DataNodeType.ClassNode ) {
			return storage.classNode is null? DataNode(): storage.classNode[key];
		}
		
		enforceEx!DataNodeException(key in storage.assocArray, "DataNode dict has no such key");

		return storage.assocArray[key];
	}

	auto opBinaryRight(string op: "in")(String key)
	{
		enforceEx!DataNodeException( type == DataNodeType.AssocArray || type == DataNodeType.Null, "DataNode is not a dict, null or undef");

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