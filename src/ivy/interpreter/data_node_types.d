module ivy.interpreter.data_node_types;

import ivy.code_object: CodeObject;
import ivy.directive_stuff: DirAttrsBlock;
import ivy.interpreter.data_node: IDataNodeRange, DataNode, DataNodeType;
import ivy.interpreter.interpreter: INativeDirectiveInterpreter;

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
		assert(false, `Cannot get attr blocks for callable, because code object and and native interpreter are null`);
	}
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

		DataNodeType aggrType() @property {
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

		DataNodeType aggrType() @property {
			return DataNodeType.AssocArray;
		}
	}
}

class IntegerRange: IDataNodeRange
{
	alias TDataNode = DataNode!string;
private:
	long _current;
	long _end;

public:
	this( long begin, long end )
	{
		assert( begin <= end, `Begin cannot be greather than end in integer range` );
		_current = begin;
		_end = end;
	}

	override {
		bool empty() @property {
			return _current >= _end;
		}

		TDataNode front() {
			return TDataNode(_current);
		}

		void popFront() {
			++_current;
		}

		DataNodeType aggrType() @property {
			return DataNodeType.Array;
		}
	}
}