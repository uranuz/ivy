module ivy.types.data.datetime;

import ivy.types.data.decl_class_node: DeclClassNode;

// Хранит дату/время
class IvyDateTime: DeclClassNode
{
	import ivy.types.data: IvyData, IvyDataType;
	import ivy.types.data.consts: DateTimeAttr;
	import ivy.interpreter.directive.base: IvyMethodAttr;
	import ivy.types.data.decl_class: DeclClass, makeClass;

	import std.datetime: SysTime, Month;
	import std.exception: enforce;
public:
	this(SysTime dt)
	{
		super(_declClass);

		this._dt = dt;
	}

	override
	{
		IvyData __getAttr__(string attrName)
		{
			IvyData val;
			switch( attrName )
			{
				case DateTimeAttr.year: val = this._dt.year; break;
				case DateTimeAttr.month: val = this._dt.month; break;
				case DateTimeAttr.day: val = this._dt.day; break;
				case DateTimeAttr.hour: val = this._dt.hour; break;
				case DateTimeAttr.minute: val = this._dt.minute; break;
				case DateTimeAttr.second: val = this._dt.second; break;
				case DateTimeAttr.millisecond: val = cast(ptrdiff_t) this._dt.fracSecs.split().msecs; break;
				case DateTimeAttr.dayOfWeek: val = cast(ptrdiff_t) this._dt.dayOfWeek; break;
				case DateTimeAttr.dayOfYear: val = cast(ptrdiff_t) this._dt.dayOfYear; break;
				case DateTimeAttr.utcMinuteOffset: val = cast(ptrdiff_t) this._dt.utcOffset.total!("minutes"); break;
				default:
					return super.__getAttr__(attrName);
			}
			return val;
		}

		void __setAttr__(IvyData val, string attrName)
		{
			int intVal = cast(int) val.integer;
			switch( attrName )
			{
				case DateTimeAttr.year: this._dt.year = intVal; break;
				case DateTimeAttr.month: this._dt.month = cast(Month) intVal; break;
				case DateTimeAttr.day: this._dt.day = intVal; break;
				case DateTimeAttr.hour: this._dt.hour = intVal; break;
				case DateTimeAttr.minute: this._dt.minute = intVal; break;
				case DateTimeAttr.second: this._dt.second = intVal; break;
				//case DateTimeAttr.millisecond: dateAttr = cast(ptrdiff_t) dt.fracSecs.split().msecs; break;
				//case DateTimeAttr.dayOfWeek: dateAttr = cast(ptrdiff_t) dt.dayOfWeek; break;
				//case DateTimeAttr.dayOfYear: dateAttr = cast(ptrdiff_t) dt.dayOfYear; break;
				//case DateTimeAttr.utcMinuteOffset: dateAttr = cast(ptrdiff_t) dt.utcOffset.total!("minutes"); break;
				default:
					enforce(false, "Cannot set DateTime attribute: " ~ attrName);
			}
		}
	}

	@IvyMethodAttr()
	IvyData __serialize__()
	{
		import ivy.types.data.conv.consts: IvySrlField, IvySrlFieldType;

		return IvyData([
			IvySrlField.type: IvyData(IvySrlFieldType.dateTime),
			IvySrlField.value: IvyData(this._dt.toISOExtString())
		]);
	}

	private __gshared DeclClass _declClass;
	
	shared static this()
	{
		_declClass = makeClass!(typeof(this))("DateTime");
	}

protected:
	SysTime _dt;
}