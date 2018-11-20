module ivy.interpreter.data_node_types;

import ivy.code_object: CodeObject;
import ivy.directive_stuff: DirAttrsBlock, DirAttrKind;
import ivy.interpreter.data_node: IvyNodeRange, IvyData, IvyDataType;
import ivy.interpreter.interpreter: INativeDirectiveInterpreter;

enum CallableKind { ScopedDirective, NoscopeDirective, Module, Package }

/**
	Callable object is representation of directive or module prepared for execution.
	Consists of it's code object (that will be executed) and some context (module for example)
*/
class CallableObject
{
	import std.exception: enforce;
	
	this() {}
	this(string name, CodeObject codeObject, CallableKind kind = CallableKind.ScopedDirective)
	{
		_name = name;
		_codeObj = codeObject;
		_kind = kind;
	}
	this(string name, INativeDirectiveInterpreter dirInterp, CallableKind kind = CallableKind.ScopedDirective)
	{
		_name = name;
		_dirInterp = dirInterp;
		_kind = kind;
	}

	string _name; // Name of directive
	CallableKind _kind; // Used to know whether is's directive or module, or package module
	CodeObject _codeObj; // Code object related to this directive

	// If this is natively implemented directive then _codeObj is null, but this must not be null
	INativeDirectiveInterpreter _dirInterp;


	DirAttrsBlock[] attrBlocks() @property
	{
		if( _codeObj ) {
			return _codeObj._attrBlocks;
		} else if( _dirInterp ) {
			return _dirInterp.attrBlocks;
		}
		assert(false, `Cannot get attr blocks for callable, because code object and and native interpreter are null`);
	}

	bool isNoscope() @property
	{
		import std.conv: text;
		enforce(attrBlocks.length > 0, `Attr block count must be > 1`);
		enforce(
			attrBlocks[$-1].kind == DirAttrKind.BodyAttr,
			`Last attr block definition expected to be BodyAttr, but got: ` ~ attrBlocks[$-1].kind.text);
		return attrBlocks[$-1].bodyAttr.isNoscope;
	}
}

class ArrayRange: IvyNodeRange
{
private:
	IvyData[] _array;

public:
	this( IvyData[] arr )
	{
		_array = arr;
	}

	override {
		bool empty() @property
		{
			import std.range: empty;
			return _array.empty;
		}

		IvyData front()
		{
			import std.range: front;
			return _array.front;
		}

		void popFront()
		{
			import std.range: popFront;
			_array.popFront();
		}
	}
}

class AssocArrayRange: IvyNodeRange
{
private:
	IvyData[string] _assocArray;
	string[] _keys;

public:
	this( IvyData[string] assocArr )
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

		IvyData front()
		{
			import std.range: front;
			return IvyData(_keys.front);
		}

		void popFront()
		{
			import std.range: popFront;
			_keys.popFront();
		}
	}
}

class IntegerRange: IvyNodeRange
{
private:
	ptrdiff_t _current;
	ptrdiff_t _end;

public:
	this( ptrdiff_t begin, ptrdiff_t end )
	{
		assert( begin <= end, `Begin cannot be greather than end in integer range` );
		_current = begin;
		_end = end;
	}

	override {
		bool empty() @property {
			return _current >= _end;
		}

		IvyData front() {
			return IvyData(_current);
		}

		void popFront() {
			++_current;
		}
	}
}