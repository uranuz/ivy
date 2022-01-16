import {BaseClassNode} from 'ivy/types/data/base_class_node';
import {DateTimeAttr} from 'ivy/types/data/consts';
import {IvySrlField, IvySrlFieldType} from 'ivy/types/data/conv/consts';
import {idat} from 'ivy/types/data/data';
import {ensure} from 'ivy/utils';
import {IvyException} from'ivy/exception';

var assure = ensure.bind(null, IvyException);
export class IvyDateTime extends BaseClassNode {
	private _dt: Date;
	constructor(dt: Date) {
		super();
		this._dt = dt || new Date;
	}
	__getAttr__(attrName: string) {
		var val;
		switch( <DateTimeAttr> attrName ) {
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
				assure(false, "Cannot get DateTime attribute: " + attrName);
		}
		return val;
	}

	__setAttr__(val: any, attrName: string) {
		var intVal = idat.integer(val);
		switch( <DateTimeAttr> attrName ) {
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
				assure(false, "Cannot set DateTime attribute: " + attrName);
		}
	}

	__serialize__() {
		var r: any = {};
		r[IvySrlField.type] = IvySrlFieldType.dateTime;
		r[IvySrlField.value] = this._dt.toISOString()
		return r;
	}
}
