define('ivy/types/data/datetime', [
	'ivy/types/data/base_class_node',
	'ivy/types/data/consts',
	'ivy/types/data/conv/consts',
	'ivy/types/data/data',
	'ivy/utils',
	'ivy/exception'
], function(
	BaseClassNode,
	DataConsts,
	ConvConsts,
	idat,
	iutil,
	IvyException
) {
var
	DateTimeAttr = DataConsts.DateTimeAttr,
	IvySrlField = ConvConsts.IvySrlField,
	IvySrlFieldType = ConvConsts.IvySrlFieldType,
	enforce = iutil.enforce.bind(iutil, IvyException);
return FirClass(
	function IvyDateTime(dt) {
		this._dt = dt || new DateTime;
	}, BaseClassNode, {
		__getAttr__: function(attrName) {
			var val;
			switch( attrName )
			{
				case DateTimeAttr.year: val = this._dt.getFullYear(); break;
				case DateTimeAttr.month: val = this._dt.getMonth() + 1; break;
				case DateTimeAttr.day: val = this._dt.getDate(); break;
				case DateTimeAttr.hour: val = this._dt.getHours(); break;
				case DateTimeAttr.minute: val = this._dt.getMinutes(); break;
				case DateTimeAttr.second: val = this._dt.getSeconds(); break;
				case DateTimeAttr.millisecond: val = this._dt.getMilliseconds(); break;
				case DateTimeAttr.dayOfWeek: val = this._dt.getDay(); break;
				//case DateTimeAttr.dayOfYear: val = this._dt.dayOfYear; break;
				case DateTimeAttr.utcMinuteOffset: val = this._dt.getTimezoneOffset(); break;
				default:
					enforce(false, "Cannot get DateTime attribute: " + attrName);
			}
			return val;
		},

		__setAttr__: function(val, attrName) {
			var intVal = idat.integer(val);
			switch( attrName )
			{
				case DateTimeAttr.year: this._dt.setFullYear(intVal); break;
				case DateTimeAttr.month: this._dt.setMonth(intVal - 1); break;
				case DateTimeAttr.day: this._dt.setDate(intVal); break;
				case DateTimeAttr.hour: this._dt.setHours(intVal); break;
				case DateTimeAttr.minute: this._dt.setMinutes(intVal); break;
				case DateTimeAttr.second: this._dt.setSeconds(intVal); break;
				//case DateTimeAttr.millisecond: dateAttr = cast(ptrdiff_t) dt.fracSecs.split().msecs; break;
				//case DateTimeAttr.dayOfWeek: dateAttr = cast(ptrdiff_t) dt.dayOfWeek; break;
				//case DateTimeAttr.dayOfYear: dateAttr = cast(ptrdiff_t) dt.dayOfYear; break;
				//case DateTimeAttr.utcMinuteOffset: dateAttr = cast(ptrdiff_t) dt.utcOffset.total!("minutes"); break;
				default:
					enforce(false, "Cannot set DateTime attribute: " + attrName);
			}
		},

		__serialize__: function() {
			var r = {};
			r[IvySrlField.type] = IvySrlFieldType.dateTime;
			r[IvySrlField.value] = this._dt.toISOExtString()
			return r;
		}
	});
});
