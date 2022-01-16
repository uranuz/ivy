import {IvyException} from 'ivy/exception';
import {IvyDataRange} from	'ivy/types/data/iface/range';
import {IvyData, IvyDataDict} from 'ivy/types/data/data';

export class AssocArrayRange implements IvyDataRange {
	private _keys: string[];
	private _i: number;

	constructor(aggr: IvyDataDict) {
		if( aggr != null && aggr instanceof Object ) {
			throw new IvyException('Expected AssocArray as AssocArrayRange aggregate');
		}
		this._keys = Object.keys(aggr);
		this._i = 0;
	}

	// Method is used to check if range is empty
	get empty(): boolean {
		return this._i >= this._keys.length;
	}

	// Method must return first item of range or raise error if range is empty
	get front(): IvyData {
		if( this.empty ) {
			throw new IvyException('Cannot get front element of empty AssocArrayRange');
		}
		return this._keys[this._i];
	}

	// Method must advance range to the next item
	pop(): IvyData {
		if( this.empty ) {
			throw new IvyException('Cannot advance empty AssocArrayRange');
		}
		return this._keys[(this._i)++];
	}
}