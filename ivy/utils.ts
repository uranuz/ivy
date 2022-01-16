

export function reversed(arr: any[]) {
	return new Reversed(arr)
}

interface ReversedState<T> {
	done: boolean;
	value?: T;
}

// Creates reverse iterator over array
export class Reversed<T> {
	private _arr: any[];
	private _i: number;
	private _state: ReversedState<T>;

	constructor(arr: T[]) {
		if( !(arr instanceof Array) ) {
			throw new Error('Expected array');
		}

		this._arr = arr;
		this._i = arr.length;
		this._state = {
			done: false
		};
	}

	next(): ReversedState<T> {
		if( this._i <= 0 ) {
			this._state.done = true;
			delete this._state.value;
		} else {
			this._state.value = this._arr[this._i - 1];
			this._i -= 1;
		}
		return this._state;
	}
}

export function ensure(ExceptionType: any, cond: any) {
	if( cond ) {
		return;
	};
	var message = '';
	Array.prototype.forEach.call(arguments, function(item: any, index: number) {
		if( index > 1 ) {
			message += String(item);
		}
	});

	throw new ExceptionType(message);
}
