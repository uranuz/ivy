module ivy.interpreter_data;

import std.exception: enforceEx;
import std.traits;

enum DataNodeType { Undef, Null, Boolean, Integer, Floating, String, Array, AssocArray, CodeObject, Directive, ClassObject };

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

interface IClassObject
{
	@property int typeId();
	@property string typeName();
	//override string toString();

}

/**
	Module is inner runtime representation of source file.
	It consists of list of constants, list of code objects and other data
*/
class ModuleObject
{
	alias TDataNode = DataNode!string;

	string _name; // Module name that used to reference it in source code
	string _fileName; // Source file name for this module
	size_t _entryPointIndex; // Index of directive in _consts that is entry point to module

	TDataNode[] _consts; // List of constant data for this module

public:
	this( string name, string fileName )
	{
		_name = name;
		_fileName = fileName;
	}

	// Append const to list and return it's index
	// This function can return index of already existing object if it's equal to passed data
	size_t addConst( TDataNode data )
	{
		size_t index = _consts.length;
		_consts ~= data;
		return index;
	}

	TDataNode getConst( size_t index )
	{
		import std.conv: text;
		assert( index < _consts.length, `There is no constant with index ` ~ index.text ~ ` in module "` ~ _name ~ `"`);
		return _consts[index];
	}

	CodeObject getMainCodeObject()
	{
		import std.conv: text;
		assert( _entryPointIndex < _consts.length, `Cannot get main code object, because there is no constant with index ` ~ _entryPointIndex.text );
		assert( _consts[_entryPointIndex].type == DataNodeType.CodeObject, `Cannot get main code object, because const with index ` ~ _entryPointIndex.text ~ ` is not code object`  );

		return _consts[_entryPointIndex].codeObject;
	}
}

/**
	Code object is inner runtime representation of chunk of source file.
	Usually it's representation of directive.
	Code object consists of list of instructions and other metadata
*/
class CodeObject
{
	import ivy.bytecode: Instruction;

	Instruction[] _instrs; // Plain list of instructions
	ModuleObject _moduleObj; // Module object which contains this code object

public:
	this( ModuleObject moduleObj )
	{
		_moduleObj = moduleObj;
	}

	size_t addInstr( Instruction instr )
	{
		size_t index = _instrs.length;
		_instrs ~= instr;
		return index;
	}

	void setInstrArg0( size_t index, uint arg )
	{
		assert( index < _instrs.length, "Cannot set argument 0 of instruction, because instruction not exists!" );
		_instrs[index].args[0] = arg;
	}

	size_t getInstrCount()
	{
		return _instrs.length;
	}
}

/**
	Directive object is representation of directive prepared for execution.
	Consists of it's code object (that will be executed) and some context (module for example)
*/
class DirectiveObject
{
	string _name; // Name of directive
	CodeObject _codeObj; // Code object related to this directive

	this()
	{
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
			DataNode[String] assocArray;
			CodeObject codeObject;
			DirectiveObject directive;
			IClassObject obj;
		}
	}

	this(T)(auto ref T value)
	{
		assign(value);
	}

	private Storage storage;
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
	
	ref DataNode[String] assocArray() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.AssocArray, "DataNode is not dict");
		return storage.assocArray;
	}
	
	void assocArray(DataNode[String] val) @property
	{
		assign(val);
	}

	CodeObject codeObject() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.CodeObject, "DataNode is not code object");
		return storage.codeObject;
	}

	void codeObject(CodeObject val) @property
	{
		assign(val);
	}

	DirectiveObject directive() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.Directive, "DataNode is not a directive");
		return storage.directive;
	}

	void directive(DirectiveObject val) @property
	{
		assign(val);
	}
	
	IClassObject obj() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.ClassObject, "DataNode is not class object");
		return storage.obj;
	}
	
	void obj(IClassObject val) @property
	{
		assign(val);
	}
	
	DataNodeType type() @property
	{
		return typeTag;
	}
	
	bool empty() @property {
		return type == DataNodeType.Undef || type == DataNodeType.Null;
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
		else static if( is( T : CodeObject ) )
		{
			typeTag = DataNodeType.CodeObject;
			storage.codeObject = arg;
		}
		else static if( is( T : DirectiveObject ) )
		{
			typeTag = DataNodeType.Directive;
			storage.directive = arg;
		}
		else static if( is( T : IClassObject ) )
		{
			typeTag = DataNodeType.ClassObject;
			storage.obj = arg;
		}
		else static if( is(T : Value[Key], Key, Value) )
		{
			static assert(is(Key : String), "AA key must be string");
				typeTag = DataNodeType.AssocArray;
			static if(is(Value : DataNode)) 
			{
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
		
		storage.assocArray[key] = value;
	}
	
	ref DataNode opIndex(String key)
	{
		enforceEx!DataNodeException( type == DataNodeType.AssocArray, "DataNode is not a dict");
		enforceEx!DataNodeException( key in storage.assocArray, "DataNode dict has no such key");
		
		return storage.assocArray[key];
	}
	
	auto opBinaryRight(string op: "in")()
	{
		enforceEx!DataNodeException( type == DataNodeType.AssocArray || type == DataNodeType.Null, "DataNode is not a dict or null");
		
		if( type == DataNodeType.Null )
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
	
	string toString()
	{
		import std.array: appender;
		auto result = appender!string();
		writeDataNodeAsString(this, result);		
		return result.data;
	}
}

void writeDataNodeLines(TDataNode, OutRange)(
	TDataNode node, ref OutRange outRange, size_t linesRecursion = 1 , size_t maxRecursion = size_t.max)
{	
	import std.range: put;
	import std.conv: to;
	
	assert( maxRecursion, "Recursion is too deep!" );
	
	final switch( node.type ) with( DataNodeType )
	{
		case Undef:
			outRange.put( "" );
			break;
		case Null:
			outRange.put( "" );
			break;
		case Boolean:
			outRange.put( node.boolean ? "true" : "false"  );
			break;
		case Integer:
			outRange.put( node.integer.to!string );
			break;
		case Floating:
			outRange.put( node.floating.to!string );
			break;
		case String:
			outRange.put( node.str );
			break;
		case Array:
			foreach( i, ref el; node.array )
			{
				if( linesRecursion == 0 )
				{
					writeDataNodeAsString(el, outRange, maxRecursion - 1);
				}
				else
				{			
					//if( i != 0 )
						//outRange.put( "\r\n" );
						
					writeDataNodeLines(el, outRange, linesRecursion - 1, maxRecursion - 1);
				}
			}
			break;
		case AssocArray:
			writeDataNodeAsString(node, outRange, maxRecursion - 1);
			break;
		case CodeObject:
			outRange.put( "<code object>" );
			break;
		case CodeObject:
			outRange.put( "<directive object>" );
			break;
		case ClassObject:
			assert(0);
			//outRange.put( node.obj.toString() );
			break;
	}
}

void writeDataNodeAsString(TDataNode, OutRange)(
	TDataNode node, ref OutRange outRange, size_t maxRecursion = size_t.max)
{
	import std.range: put;
	import std.conv: to;
	
	assert( maxRecursion, "Recursion is too deep!" );
	
	final switch( node.type ) with( DataNodeType )
	{
		case Undef:
			outRange.put( "" );
			break;
		case Null:
			outRange.put( "" );
			break;
		case Boolean:
			outRange.put( node.boolean ? "true" : "false"  );
			break;
		case Integer:
			outRange.put( node.integer.to!string );
			break;
		case Floating:
			outRange.put( node.floating.to!string );
			break;
		case String:
			outRange.put( "\"" );
			outRange.put(  node.str );
			outRange.put( "\"" );
			break;
		case Array:
			outRange.put( "[" );
			foreach( i, ref el; node.array )
			{
				if( i != 0 )
					outRange.put( ", " );

				writeDataNodeAsString(el, outRange, maxRecursion - 1);	
			}
			outRange.put( "]");
			break;
		case AssocArray:
		{
			outRange.put( "{");
			size_t i = 0;
			foreach( ref key, ref val; node.assocArray )
			{
				if( i != 0 )
					outRange.put( ", ");
				
				outRange.put( key);
				outRange.put( ": ");

				writeDataNodeAsString(val, outRange, maxRecursion - 1);	
				++i;
			}
			outRange.put( "}");
			break;
		}
		case CodeObject:
			outRange.put( "<code object>" );
			break;
		case Directive:
			outRange.put( "<directive object>" );
			break;
		case ClassObject:
			assert(0);
			//outRange.put(  node.obj.toString() );
			break;
	}
	
}
