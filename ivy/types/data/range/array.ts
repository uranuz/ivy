import {IvyException} from 'ivy/exception';
import {IvyDataRange} from 'ivy/types/data/iface/range';
import {IvyData} from 'ivy/types/data/data';

export class ArrayRange implements IvyDataRange {
	private _array: IvyData[];
	private _i: number;

	constructor(aggr: IvyData[]) {
		if( !(aggr instanceof Array) ) {
			throw new IvyException('Expected array as ArrayRange aggregate');
		}
		this._array = aggr;
		this._i = 0;
	}

	// Method is used to check if range is empty
	get empty(): boolean {
		return this._i >= this._array.length;
	}

	// Method must return first item of range or raise error if range is empty
	get front(): IvyData {
		if( this.empty ) {
			throw new IvyException('Cannot get front element of empty ArrayRange');
		}
		return this._array[this._i];
	}

	// Method must advance range to the next item
	pop(): IvyData {
		if( this.empty ) {
			throw new IvyException('Cannot advance empty ArrayRange');
		}
		return this._array[(this._i)++];
	}
}