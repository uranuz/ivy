module ivy.interpreter_data;

import std.exception: enforceEx;
import std.traits;

enum DataNodeType { Undef, Null, Boolean, Integer, Floating, String, Array, AssocArray, CodeObject, Callable, ExecutionFrame, DataNodeRange };

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
	size_t _entryPointIndex; // Index of callable in _consts that is entry point to module

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

	CodeObject mainCodeObject() @property
	{
		import std.conv: text;
		assert( _entryPointIndex < _consts.length, `Cannot get main code object, because there is no constant with index ` ~ _entryPointIndex.text );
		assert( _consts[_entryPointIndex].type == DataNodeType.CodeObject, `Cannot get main code object, because const with index ` ~ _entryPointIndex.text ~ ` is not code object`  );

		return _consts[_entryPointIndex].codeObject;
	}
}


struct DirValueAttr(bool isForCompiler = false)
{
	string name;
	string typeName;

	static if( isForCompiler )
	{
		import ivy.node: IExpression;
		
		IExpression defaultValueExpr;
		this( string name, string typeName, IExpression defValue )
		{
			this.name = name;
			this.typeName = typeName;
			this.defaultValueExpr = defValue;
		}
	}
	else
	{
		this( string name, string typeName )
		{
			this.name = name;
			this.typeName = typeName;
		}
	}

	DirValueAttr!(false) toInterpreterValue() {
		return DirValueAttr!(false)(name, typeName);
	}
}

// We pass callable attributes by blocks. Every attribute block has size an type
// Size and type stored in single integer argument in stack preceding the block
// Size is major binary part of this integer denoted by bit offset:
enum size_t _stackBlockHeaderSizeOffset = 4;
// To have some validity check bit between size and block type must always be zero
// The following mask is used to check for validity:
enum size_t _stackBlockHeaderCheckMask = 0b1000;
// And there is mask to extract type of block
enum size_t _stackBlockHeaderTypeMask = 0b111;


enum DirAttrKind { NamedAttr, ExprAttr, IdentAttr, KwdAttr, NoscopeAttr, BodyAttr };

static this()
{
	static assert( DirAttrKind.max <= _stackBlockHeaderTypeMask, `DirAttrKind set of values exeeded of defined limit` );
}

struct DirAttrsBlock(bool isForCompiler = false)
{
	alias TValueAttr = DirValueAttr!(isForCompiler);

	static if( isForCompiler ) {
		import ivy.node: ICompoundStatement;
	}

	static struct Storage {
		union {
			TValueAttr[string] namedAttrs;
			TValueAttr[] exprAttrs;
			string[] names;
			string keyword;

			static if( isForCompiler ) {
				ICompoundStatement bodyAST;
			}
		}
	}

	private DirAttrKind _kind;
	private Storage _storage;

	this( DirAttrKind attrKind, TValueAttr[string] attrs )
	{
		assert( attrKind == DirAttrKind.NamedAttr, `Expected NamedAttr kind for attr block` );
		
		_kind = attrKind;
		_storage.namedAttrs = attrs;
	}

	this( DirAttrKind attrKind, TValueAttr[] attrs )
	{
		assert( attrKind == DirAttrKind.ExprAttr, `Expected ExprAttr kind for attr block` );
		
		_kind = attrKind;
		_storage.exprAttrs = attrs;
	}

	this( DirAttrKind attrKind, string[] names )
	{
		assert( attrKind == DirAttrKind.IdentAttr, `Expected IdentAttr kind for attr block` );
		
		_kind = attrKind;
		_storage.names = names;
	}

	this( DirAttrKind attrKind, string kwd )
	{
		assert( attrKind == DirAttrKind.KwdAttr, `Expected Keyword kind for attr block` );
		
		_kind = attrKind;
		_storage.keyword = kwd;
	}

	static if( isForCompiler )
	{
		this( DirAttrKind attrKind, ICompoundStatement bodyAST )
		{
			assert( attrKind == DirAttrKind.BodyAttr, `Expected BodyAttr kind for attr block` );
			
			_kind = attrKind;
			_storage.bodyAST = bodyAST;
		}
	}

	this( DirAttrKind attrKind )
	{
		_kind = attrKind;
	}

	DirAttrKind kind() @property {
		return _kind;
	}

	void kind(DirAttrKind value) @property {
		_kind = value;
	}

	void namedAttrs( TValueAttr[string] attrs ) @property {
		_storage.namedAttrs = attrs;
		_kind = DirAttrKind.NamedAttr;
	}

	TValueAttr[string] namedAttrs() @property {
		assert( _kind == DirAttrKind.NamedAttr, `Directive attrs block is not of NamedAttr kind` );
		return _storage.namedAttrs;
	}

	void exprAttrs( TValueAttr[] attrs ) @property {
		_storage.exprAttrs = attrs;
		_kind = DirAttrKind.ExprAttr;
	}

	TValueAttr[] exprAttrs() @property {
		assert( _kind == DirAttrKind.ExprAttr, `Directive attrs block is not of ExprAttr kind` );
		return _storage.exprAttrs;
	}

	void names(string[] names) @property {
		_storage.names = names;
		_kind = DirAttrKind.IdentAttr;
	}

	string[] names() @property {
		assert( _kind == DirAttrKind.IdentAttr, `Directive attrs block is not of IdentAttr kind` );
		return _storage.names;
	}

	void keyword(string value) @property {
		_storage.keyword = value;
		_kind = DirAttrKind.KwdAttr;
	}

	string keyword() @property {
		assert( _kind == DirAttrKind.KwdAttr, `Directive attrs block is not of KwdAttr kind` );
		return _storage.keyword;
	}

	static if( isForCompiler )
	{
		void bodyAST(ICompoundStatement stmt) @property {
			_storage.bodyAST = stmt;
			_kind = DirAttrKind.BodyAttr;
		}

		ICompoundStatement bodyAST() @property {
			assert( _kind == DirAttrKind.BodyAttr, `Directive attrs block is not of BodyAttr kind` );
			return _storage.bodyAST;
		}
	}

	DirAttrsBlock!(false) toInterpreterBlock()
	{
		import std.algorithm: map;
		import std.array: array;

		final switch( _kind )
		{
			case DirAttrKind.NamedAttr: {
				DirValueAttr!(false)[string] attrs;
				foreach( key, ref currAttr; _storage.namedAttrs ) {
					attrs[key] = currAttr.toInterpreterValue();
				}
				return DirAttrsBlock!(false)( _kind, attrs );
			}
			case DirAttrKind.ExprAttr:
				return DirAttrsBlock!(false)( _kind, _storage.exprAttrs.map!( a => a.toInterpreterValue() ).array );
			case DirAttrKind.IdentAttr:
				return DirAttrsBlock!(false)( _kind, _storage.names );
			case DirAttrKind.KwdAttr:
				return DirAttrsBlock!(false)( _kind, _storage.keyword );
			case DirAttrKind.NoscopeAttr, DirAttrKind.BodyAttr:
				return DirAttrsBlock!(false)( _kind );
		}
		assert( false, `This should never happen` );
	}

	string toString()
	{
		import std.conv: to;
		final switch( _kind ) with( DirAttrKind )
		{
			case NamedAttr:
			case ExprAttr:
			case IdentAttr:
			case KwdAttr:
			case NoscopeAttr: 
			case BodyAttr:
				return `<` ~ _kind.to!string ~ ` attrs block>`;
		}
	}
}

/**
	Code object is inner runtime representation of chunk of source file.
	Usually it's representation of directive or module.
	Code object consists of list of instructions and other metadata
*/
class CodeObject
{
	import ivy.bytecode: Instruction;

	Instruction[] _instrs; // Plain list of instructions
	DirAttrsBlock!(false)[] _attrBlocks;
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

	void setInstrArg( size_t index, size_t arg )
	{
		assert( index < _instrs.length, "Cannot set argument 0 of instruction, because instruction not exists!" );
		_instrs[index].arg = arg;
	}

	size_t getInstrCount()
	{
		return _instrs.length;
	}
}

interface INativeDirectiveInterpreter
{
	import ivy.interpreter: Interpreter;
	void interpret( Interpreter interp );

	DirAttrsBlock!(false)[] attrBlocks() @property;
}

enum CallableKind { ScopedDirective, NoscopeDirective, Module, Package }

/**
	Callable object is representation of directive or module prepared for execution.
	Consists of it's code object (that will be executed) and some context (module for example)
*/
class CallableObject
{
	string _name; // Name of directive
	CallableKind _kind; // Used to know whether is's directive or module, or package module
	CodeObject _codeObj; // Code object related to this directive
	
	// If this is natively implemented directive then _codeObj is null, but this must not be null
	INativeDirectiveInterpreter _dirInterp;

	this() {}

	DirAttrsBlock!(false)[] attrBlocks() @property
	{
		if( _codeObj ) {
			return _codeObj._attrBlocks;
		} else if( _dirInterp ) {
			return _dirInterp.attrBlocks;
		}
		assert( false, `Cannot get attr blocks for callable, because code object and and native interpreter are null` );
	}
}

interface IDataNodeRange
{
	alias TDataNode = DataNode!string;

	bool empty() @property;
	TDataNode front();
	void popFront();
	DataNodeType aggrType() @property;
}

class ArrayRange: IDataNodeRange
{
	alias TDataNode = DataNode!string;

private:
	TDataNode[] _array;

public:
	this( TDataNode[] arr )
	{
		_array = arr;
	}

	override {
		bool empty() @property
		{
			import std.range: empty;
			return _array.empty;
		}

		TDataNode front()
		{
			import std.range: front;
			return _array.front;
		}

		void popFront()
		{
			import std.range: popFront;
			_array.popFront();
		}

		DataNodeType aggrType() @property
		{
			return DataNodeType.Array;
		}
	}
}

class AssocArrayRange: IDataNodeRange
{
	alias TDataNode = DataNode!string;
private:
	TDataNode[string] _assocArray;
	string[] _keys;

public:
	this( TDataNode[string] assocArr )
	{
		_assocArray = assocArr;
		_keys = _assocArray.keys;
	}

	override {
		bool empty() @property
		{
			import std.range: empty;
			return _keys.empty;
		}

		TDataNode front()
		{
			import std.range: front;
			return _assocArray[_keys.front];
		}

		void popFront()
		{
			import std.range: popFront;
			_keys.popFront();
		}

		DataNodeType aggrType() @property
		{
			return DataNodeType.AssocArray;
		}
	}
}

import ivy.interpreter: ExecutionFrame;

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
			CallableObject callable;
			ExecutionFrame execFrame;
			IDataNodeRange dataRange;
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

	CallableObject callable() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.Callable, "DataNode is not callable object");
		return storage.callable;
	}

	void callable(CallableObject val) @property
	{
		assign(val);
	}

	ExecutionFrame execFrame() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.ExecutionFrame, "DataNode is not a execution frame");
		return storage.execFrame;
	}

	void execFrame(ExecutionFrame val) @property
	{
		assign(val);
	}

	IDataNodeRange dataRange() @property
	{
		enforceEx!DataNodeException( type == DataNodeType.DataNodeRange, "DataNode is not a data node range");
		return storage.dataRange;
	}

	void dataRange(IDataNodeRange val) @property
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
		enforceEx!DataNodeException( type == DataNodeType.AssocArray || type == DataNodeType.Null || type == DataNodeType.Undef, "DataNode is not a dict, null or undef");
		
		if( type != DataNodeType.AssocArray )
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
			outRange.put( node.boolean ? "true" : "false" );
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
				//if( linesRecursion == 0 )
				//{
					//writeDataNodeAsString(el, outRange, maxRecursion - 1);
				//}
				//else
				//{			
					//if( i != 0 )
						//outRange.put( "\r\n" );
						
					writeDataNodeLines(el, outRange, linesRecursion - 1, maxRecursion - 1);
				//}
			}
			break;
		case AssocArray:
			writeDataNodeAsString(node, outRange, maxRecursion - 1);
			break;
		case CodeObject:
			import std.conv: text;
			if( node.codeObject )
			{
				outRange.put( "<code object, size: " ~ node.codeObject._instrs.length.text ~ ">" );
			}
			else
			{
				outRange.put( "<code object (null)>" );
			}
			break;
		case Callable:
			outRange.put( "<callable object, " ~ node.callable._kind.to!string ~ ">" );
			break;
		case ExecutionFrame:
			outRange.put( "<execution frame>" );
			break;
		case DataNodeRange:
			outRange.put( "<data node range>" );
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
			outRange.put( "undef" );
			break;
		case Null:
			outRange.put( "null" );
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
			import std.conv: text;
			if( node.codeObject )
			{
				outRange.put( "<code object, size: " ~ node.codeObject._instrs.length.text ~ ">" );
			}
			else
			{
				outRange.put( "<code object (null)>" );
			}
			break;
		case Callable:
			import std.conv: text;
			if( node.callable )
			{
				outRange.put( "<callable object, " ~ node.callable._kind.to!string ~ ">" );
			}
			else
			{
				outRange.put( "<directive object (null)>" );
			}
			break;
		case ExecutionFrame:
			debug {
				outRange.put( "<execution frame: " );
				writeDataNodeAsString( node.execFrame._dataDict, outRange, maxRecursion - 1);
				outRange.put( ">" );
			} else {
				outRange.put( "<execution frame>" );
			}

			break;
		case DataNodeRange:
			outRange.put( "<data node range>" );
			break;
	}
	
}

TDataNode deeperCopy(TDataNode)(auto ref TDataNode node)
{
	final switch( node.type ) with( DataNodeType )
	{
		case Undef, Null, Boolean, Integer, Floating:
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