module ivy.interpreter.data_node;

import ivy.common: IvyException;
import ivy.code_object: CodeObject;
import ivy.interpreter.data_node_types: CallableObject;
import ivy.interpreter.data_node_render: renderDataNode, DataRenderType;

interface IvyNodeRange
{
	bool empty() @property;
	IvyData front();
	void popFront();
}

interface IClassNode
{
	IvyNodeRange opSlice();
	IClassNode opSlice(size_t, size_t);
	IvyData opIndex(string);
	IvyData opIndex(size_t);
	IvyData __getAttr__(string);
	void __setAttr__(IvyData, string);
	IvyData __serialize__();
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

enum IvyDataType: ubyte {
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

public alias IvyData = TIvyData!string;

struct TIvyData(S)
{
	import std.datetime: SysTime;
	import std.exception: enforce;
	import std.traits;
	import std.conv: text;
	import ivy.interpreter.execution_frame: ExecutionFrame;

	alias String = S;
	alias MIvyData = TIvyData!(S);

	struct Storage {
		union {
			bool boolean;
			long integer;
			double floating;
			SysTime dateTime;
			// This is workaround of problem that IvyData is value type
			// and array with it's length copied, and length is not shared between instances.
			// So we put array item into another GC array with 1 item, so it becomes fully reference type
			// TODO: think how to implement it better
			String[] str;
			MIvyData[][] array;
			MIvyData[String] assocArray;
			IClassNode classNode;
			CodeObject codeObject;
			CallableObject callable;
			ExecutionFrame execFrame;
			IvyNodeRange dataRange;
		}
	}

	this(T)(auto ref T value) {
		assign(value);
	}

	private Storage storage;
	private IvyDataType typeTag;
	private NodeEscapeState _escapeState;

	bool boolean() @property
	{
		enforce!DataNodeException(type == IvyDataType.Boolean, "IvyData is not boolean");
		return storage.boolean;
	}

	void boolean(bool val) @property {
		assign(val);
	}

	long integer() @property
	{
		enforce!DataNodeException(type == IvyDataType.Integer, "IvyData is not integer");
		return storage.integer;
	}

	void integer(long val) @property {
		assign(val);
	}

	double floating() @property
	{
		enforce!DataNodeException(type == IvyDataType.Floating, "IvyData is not floating");
		return storage.floating;
	}

	void floating(double val) @property {
		assign(val);
	}

	SysTime dateTime() @property
	{
		enforce!DataNodeException(type == IvyDataType.DateTime, "IvyData is not DateTime");
		return storage.dateTime;
	}

	void dateTime(SysTime val) @property {
		assign(val);
	}

	ref String str() @property
	{
		enforce!DataNodeException(type == IvyDataType.String, "IvyData is not string");
		assert(storage.str.length == 1, "Expected internal storage length of 1");
		return storage.str[0];
	}

	void str(String val) @property {
		assign(val);
	}

	ref MIvyData[] array() @property
	{
		enforce!DataNodeException(type == IvyDataType.Array, "IvyData is not array");
		assert(storage.array.length == 1, "Expected internal storage length of 1");
		return storage.array[0];
	}

	void array(MIvyData[] val) @property {
		assign(val);
	}

	ref MIvyData[String] assocArray() @property
	{
		enforce!DataNodeException(type == IvyDataType.AssocArray, "IvyData is not dict");
		return storage.assocArray;
	}

	void assocArray(MIvyData[String] val) @property {
		assign(val);
	}

	IClassNode classNode() @property {
		enforce!DataNodeException(type == IvyDataType.ClassNode, "IvyData is not class node");
		return storage.classNode;
	}

	void classNode(IClassNode val) @property {
		assign(val);
	}

	CodeObject codeObject() @property
	{
		enforce!DataNodeException(type == IvyDataType.CodeObject, "IvyData is not code object");
		return storage.codeObject;
	}

	void codeObject(CodeObject val) @property {
		assign(val);
	}

	CallableObject callable() @property
	{
		enforce!DataNodeException( type == IvyDataType.Callable, "IvyData is not callable object");
		return storage.callable;
	}

	void callable(CallableObject val) @property {
		assign(val);
	}

	ExecutionFrame execFrame() @property
	{
		enforce!DataNodeException( type == IvyDataType.ExecutionFrame, "IvyData is not a execution frame");
		return storage.execFrame;
	}

	void execFrame(ExecutionFrame val) @property {
		assign(val);
	}

	IvyNodeRange dataRange() @property
	{
		enforce!DataNodeException( type == IvyDataType.DataNodeRange, "IvyData is not a data node range");
		return storage.dataRange;
	}

	void dataRange(IvyNodeRange val) @property {
		assign(val);
	}

	IvyDataType type() @property
	{
		if( typeTag == IvyDataType.ClassNode && storage.classNode is null ) {
			return IvyDataType.Null;
		}
		return typeTag;
	}

	bool empty() @property {
		return isUndef || isNull || (type == IvyDataType.ClassNode && storage.classNode[].empty);
	}

	bool isUndef() @property {
		return type == IvyDataType.Undef;
	}

	bool isNull() @property {
		return type == IvyDataType.Null || (type == IvyDataType.ClassNode && storage.classNode is null);
	}

	private void assign(T)(auto ref T arg)
	{
		static if( is(T : typeof(null)) )
		{
			typeTag = IvyDataType.Null;
		}
		else static if( is(T : bool) )
		{
			typeTag = IvyDataType.Boolean;
			storage.boolean = arg;
		}
		else static if( isIntegral!T )
		{
			typeTag = IvyDataType.Integer;
			storage.integer = arg;
		}
		else static if( isFloatingPoint!T )
		{
			typeTag = IvyDataType.Floating;
			storage.floating = arg;
		}
		else static if( is( T : SysTime ) )
		{
			typeTag = IvyDataType.DateTime;
			storage.dateTime = arg;
		}
		else static if( is(T : string) )
		{
			typeTag = IvyDataType.String;
			storage.str = [arg];
		}
		else static if( isArray!T )
		{
			typeTag = IvyDataType.Array;
			static if( is(ElementEncodingType!T : MIvyData) ) {
				storage.array = [arg];
			}
			else
			{
				MIvyData[] new_arg;
				new_arg.length = arg.length;
				foreach(i, e; arg) {
					new_arg[i] = MIvyData(e);
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
				storage.assocArray = ["__allocateWorkaround__": MIvyData()];
				storage.assocArray.remove("__allocateWorkaround__");
			}

			if( arg is null ) {
				storage.assocArray.clear(); // Just clear, not set it to null
			}

			typeTag = IvyDataType.AssocArray;
			static if(is(Value : MIvyData)) {
				if( storage.assocArray !is null && arg !is null ) {
					storage.assocArray = arg; // Assign only if it is not null
				}
			}
			else
			{
				storage.assocArray.clear(); // Need to remove old data
				foreach(key, value; arg)
					storage.assocArray[key] = MIvyData(value);
				storage.assocArray.rehash(); // For faster lookups
			}
		}
		else static if( is( T : IClassNode ) )
		{
			typeTag = IvyDataType.ClassNode;
			storage.classNode = arg;
		}
		else static if( is( T : CodeObject ) )
		{
			typeTag = IvyDataType.CodeObject;
			storage.codeObject = arg;
		}
		else static if( is( T : CallableObject ) )
		{
			typeTag = IvyDataType.Callable;
			storage.callable = arg;
		}
		else static if( is( T : ExecutionFrame ) )
		{
			typeTag = IvyDataType.ExecutionFrame;
			storage.execFrame = arg;
		}
		else static if( is( T : IvyNodeRange ) )
		{
			typeTag = IvyDataType.DataNodeRange;
			storage.dataRange = arg;
		}
		else static if(is(T : MIvyData))
		{
			typeTag = arg.type;
			final switch(typeTag)
			{
				case IvyDataType.Undef, IvyDataType.Null:  break;
				case IvyDataType.Boolean: storage.boolean = arg.boolean; break;
				case IvyDataType.Integer: storage.integer = arg.integer; break;
				case IvyDataType.Floating: storage.floating = arg.floating; break;
				case IvyDataType.DateTime: storage.dateTime = arg.dateTime; break;
				case IvyDataType.String: storage.str = arg.storage.str; break;
				case IvyDataType.Array: storage.array = arg.storage.array; break;
				case IvyDataType.AssocArray: storage.assocArray = arg.assocArray; break;
				case IvyDataType.ClassNode: storage.classNode = arg.classNode; break;
				case IvyDataType.CodeObject: storage.codeObject = arg.codeObject; break;
				case IvyDataType.Callable: storage.callable = arg.callable; break;
				case IvyDataType.ExecutionFrame: storage.execFrame = arg.execFrame; break;
				case IvyDataType.DataNodeRange: storage.dataRange = arg.dataRange; break;
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
		enforce!DataNodeException( type == IvyDataType.Array, "IvyData is not an array");
		assert(storage.array.length == 1, "Expected internal storage length of 1");
		enforce!DataNodeException( index < storage.array[0].length , "IvyData array index is out of range");

		storage.array[0][index] = value;
	}

	MIvyData opIndex(size_t index)
	{
		import std.algorithm: canFind;
		enforce!DataNodeException(
			[IvyDataType.Array, IvyDataType.ClassNode].canFind(type),
			"IvyData is not an array or class node, but is: " ~ type.text);
		if( type == IvyDataType.ClassNode ) {
			return storage.classNode is null? MIvyData(): storage.classNode[index];
		}
		assert(storage.array.length == 1, "Expected internal storage length of 1");
		enforce!DataNodeException(index < storage.array[0].length, "IvyData array index is out of range");

		return storage.array[0][index];
	}

	void opOpAssign(string op : "~", T)(auto ref T arg)
	{
		import std.algorithm: canFind;
		enforce!DataNodeException(
			[IvyDataType.Array, IvyDataType.Undef, IvyDataType.Null].canFind(type),
			"IvyData is not an array");

		if( type != IvyDataType.Array )
			this = (MIvyData[]).init;
		assert(storage.array.length == 1, "Expected internal storage length of 1");

		static if( isArray!T )
		{
			static if( is( ElementType!T == MIvyData ) )
			{
				storage.array[0] ~= arg.storage.array[0];
			}
			else
			{
				foreach( ref elem; arg )
					storage.array[0] ~= MIvyData(elem);
			}
		} else static if( is(T == MIvyData) ) {
			storage.array[0] ~= arg;
		} else {
			storage.array[0] ~= MIvyData(arg);
		}
	}

	void opIndexAssign(T)(auto ref T value, String key)
	{
		import std.algorithm: canFind;
		enforce!DataNodeException(
			[IvyDataType.AssocArray, IvyDataType.Null, IvyDataType.Undef].canFind(type),
			"IvyData is not a dict, null or undef");

		if( type != IvyDataType.AssocArray )
			this = (MIvyData[String]).init;

		storage.assocArray[key] = value;
	}

	MIvyData opIndex(String key)
	{
		import std.algorithm: canFind;
		enforce!DataNodeException(
			[IvyDataType.AssocArray, IvyDataType.ClassNode].canFind(type),
			"IvyData is not a dict or class node, but is: " ~ type.text);
		if( type == IvyDataType.ClassNode ) {
			return storage.classNode is null? MIvyData(): storage.classNode[key];
		}
		
		enforce!DataNodeException(key in storage.assocArray, "IvyData dict has no such key");

		return storage.assocArray[key];
	}

	auto opBinaryRight(string op: "in")(String key)
	{
		import std.algorithm: canFind;
		enforce!DataNodeException(
			[IvyDataType.AssocArray, IvyDataType.Null, IvyDataType.Undef].canFind(type),
			"IvyData is not a dict, null or undef");

		if( type == IvyDataType.Undef || type == IvyDataType.Null )
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

	static MIvyData makeUndef() {
		MIvyData undef;
		undef.typeTag = IvyDataType.Undef;
		return undef;
	}

	bool opEquals(MIvyData rhs)
	{
		import std.range: zip;
		if( rhs.type != this.type ) {
			return false;
		}
		switch( this.type ) with(IvyDataType)
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


IvyData deeperCopy(IvyData)(auto ref IvyData node)
{
	final switch( node.type ) with( IvyDataType )
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
			IvyData[] newArray;
			newArray.length = node.array.length; // Preallocating
			foreach( i, ref el; node.array ) {
				newArray[i] = deeperCopy(el);
			}
			return IvyData(newArray);
		}
		case AssocArray:
		{
			IvyData[string] newAA;
			foreach( ref key, ref val; node.assocArray ) {
				newAA[key] = deeperCopy(val);
			}
			return IvyData(newAA);
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