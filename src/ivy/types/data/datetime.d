module ivy.types.data.datetime;

import ivy.types.data.not_impl_class_node: NotImplClassNode;

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
	import ivy.types.data: IvyData, IvyDataType;
	
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

		IvyData __serialize__()
		{
			import ivy.types.data.conv.consts: IvySrlField, IvySrlFieldType;

			return IvyData([
				IvySrlField.type: IvyData(IvySrlFieldType.dateTime),
				IvySrlField.value: IvyData(_dt.toISOExtString())
			]);
		}
	}
protected:
	SysTime _dt;
}