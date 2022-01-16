import { AsyncResultState } from 'ivy/types/data/consts';
import { IvyData } from 'ivy/types/data/data';

declare var jQuery: any;

type DoneFn = (val: IvyData) => void;
type FailFn = (err: Error) => void;

export class AsyncResult {
	private _deferred: any;
	private _state: AsyncResultState;

	constructor() {
		this._deferred = new jQuery.Deferred();
		this._state = AsyncResultState.Init;
	}

	then(doneFn: DoneFn | AsyncResult, failFn?: FailFn): void {
		if (doneFn instanceof AsyncResult) {
			return this._thenImpl(
				doneFn.resolve.bind(doneFn),
				doneFn.reject.bind(doneFn)
			);
		}
		this._thenImpl(doneFn, failFn);
	}

	_thenImpl(doneFn: DoneFn, failFn: FailFn): void {
		if( (doneFn != null) && (typeof doneFn !== 'function') ) {
			throw new Error('doneFn argument expected to be function, undefined or null');
		}
		if( (failFn != null) && (typeof failFn !== 'function') ) {
			throw new Error('failFn argument expected to be function, undefined or null');
		}
		this._deferred.then(doneFn, failFn);
	}

	catch(failFn: FailFn): void {
		if( (failFn != null) && (typeof failFn !== 'function') ) {
			throw new Error('failFn argument expected to be function, undefined or null');
		}
		this._deferred.catch(failFn);
	}

	resolve(value: IvyData): void {
		this._state = AsyncResultState.Success;
		this._deferred.resolve(value);
	}

	reject(error: Error): void {
		this._state = AsyncResultState.Error;
		console.warn(error);
		this._deferred.reject(error);
	}

	get state(): AsyncResultState {
		return this._state;
	}
}