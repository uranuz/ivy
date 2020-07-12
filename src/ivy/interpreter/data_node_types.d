module ivy.interpreter.data_node_types;

import ivy.code_object: CodeObject;
import ivy.directive_stuff: DirAttrsBlock, DirAttrKind;
import ivy.interpreter.data_node: IvyNodeRange, IvyData, IvyDataType, IClassNode, NotImplClassNode;
import ivy.interpreter.iface: INativeDirectiveInterpreter;

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

	string moduleName() @property {
		return _codeObj? _codeObj._moduleObj._name: `__global__`;
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

enum DateTimeAttr: string
{
	year = `year`,
	month = `month`,
	day = `day`,
	hour = `hour`,
	minute = `minute`,
	second = `second`,
	millisecond = `millisecond`,
	dayOfWeek = `dayOfWeek`,
	dayOfYear = `dayOfYear`,
	utcMinuteOffset = `utcMinuteOffset`
}

// Хранит дату/время
class IvyDateTime: NotImplClassNode
{
	import std.datetime: SysTime, Month;
	import std.exception: enforce;
public:
	this(SysTime dt) {
		_dt = dt;
	}

	override
	{
		IvyData __getAttr__(string attrName)
		{
			IvyData val;
			switch( attrName )
			{
				case DateTimeAttr.year: val = _dt.year; break;
				case DateTimeAttr.month: val = _dt.month; break;
				case DateTimeAttr.day: val = _dt.day; break;
				case DateTimeAttr.hour: val = _dt.hour; break;
				case DateTimeAttr.minute: val = _dt.minute; break;
				case DateTimeAttr.second: val = _dt.second; break;
				case DateTimeAttr.millisecond: val = cast(ptrdiff_t) _dt.fracSecs.split().msecs; break;
				case DateTimeAttr.dayOfWeek: val = cast(ptrdiff_t) _dt.dayOfWeek; break;
				case DateTimeAttr.dayOfYear: val = cast(ptrdiff_t) _dt.dayOfYear; break;
				case DateTimeAttr.utcMinuteOffset: val = cast(ptrdiff_t) _dt.utcOffset.total!("minutes"); break;
				default:
					enforce(false, `Cannot get DateTime attribute: ` ~ attrName);
			}
			return val;
		}

		void __setAttr__(IvyData val, string attrName)
		{
			import std.conv: text;
			enforce(
				val.type == IvyDataType.Integer,
				`Expected integer as any of datetime attribute value, but got: "` ~ val.type.text);
			int intVal = cast(int) val.integer;
			switch( attrName )
			{
				case DateTimeAttr.year: _dt.year = intVal; break;
				case DateTimeAttr.month: _dt.month = cast(Month) intVal; break;
				case DateTimeAttr.day: _dt.day = intVal; break;
				case DateTimeAttr.hour: _dt.hour = intVal; break;
				case DateTimeAttr.minute: _dt.minute = intVal; break;
				case DateTimeAttr.second: _dt.second = intVal; break;
				//case DateTimeAttr.millisecond: dateAttr = cast(ptrdiff_t) dt.fracSecs.split().msecs; break;
				//case DateTimeAttr.dayOfWeek: dateAttr = cast(ptrdiff_t) dt.dayOfWeek; break;
				//case DateTimeAttr.dayOfYear: dateAttr = cast(ptrdiff_t) dt.dayOfYear; break;
				//case DateTimeAttr.utcMinuteOffset: dateAttr = cast(ptrdiff_t) dt.utcOffset.total!("minutes"); break;
				default:
					enforce(false, `Cannot set DateTime attribute: ` ~ attrName);
			}
		}
		IvyData __serialize__() {
			return IvyData(_dt.toISOExtString());
		}
	}
protected:
	SysTime _dt;
}