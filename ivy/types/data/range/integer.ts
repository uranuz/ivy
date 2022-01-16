import {IvyException} from 'ivy/exception';
import {IvyDataRange} from 'ivy/types/data/iface/range';
import {IvyData} from 'ivy/types/data/data';

export class IntegerRange implements IvyDataRange {
	private _current: number;
	private _end: number;

	constructor(begin: number, end: number) {
		if( typeof(begin) !== 'number' || typeof(end) !== 'number' ) {
			throw new IvyException('Number range begin and end arguments must be numbers');
		}
		if( begin > end ) {
			throw new IvyException('Begin must not be greater than end');
		}
		this._current = begin;
		this._end = end;
	}

	// Method is used to check if range is empty
	get empty(): boolean {
		return this._current >= this._end;
	}

	// Method must return first item of range or raise error if range is empty
	get front(): IvyData {
		return this._current;
	}

	// Method must advance range to the next item
	pop(): IvyData {
		if( this.empty ) {
			throw new IvyException('Cannot advance empty IntegerRange');
		}
		return this._current++;
	}
}