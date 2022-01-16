import {CodeObject} from 'ivy/types/code_object';
import {ensure} from 'ivy/utils';
import {IvyException} from 'ivy/exception';
import { IDirectiveInterpreter } from 'ivy/interpreter/directive/iface';
import { IvyData, IvyDataDict } from 'ivy/types/data/data';

var assure = ensure.bind(null, IvyException);

export class CallableObject {
	private _codeObject: CodeObject;
	private _dirInterp: IDirectiveInterpreter;
	private _defaults: IvyDataDict;
	private _context?: IvyData;

	constructor(someCallable: CodeObject | CallableObject | IDirectiveInterpreter, defaultsOrContext?: IvyDataDict | IvyData) {
		if(someCallable instanceof CodeObject) {
			this._codeObject = someCallable;
			this._defaults = defaultsOrContext || {};
			this._context = void(0);
		} else if(someCallable instanceof CallableObject) {
			if( someCallable.isNative ) {
				this._dirInterp = someCallable.dirInterp;
			} else {
				this._codeObject = someCallable.codeObject;
			}
			this._defaults = someCallable.defaults;
			this._context = defaultsOrContext;
		} else {
			this._dirInterp = someCallable;
			this._defaults = {};
			this._context = void(0);
		}
	}

	get isNative(): boolean {
		return !!this._dirInterp;
	}

	get dirInterp(): IDirectiveInterpreter {
		assure(this._dirInterp, "Callable is not a native dir interpreter");
		return this._dirInterp;
	}

	get codeObject(): CodeObject {
		assure(this._codeObject, "Callable is not an ivy code object");
		return this._codeObject;
	}

	get symbol() {
		if( this.isNative ) {
			return this._dirInterp.symbol;
		}
		return this._codeObject.symbol;
	}

	get moduleSymbol() {
		if( this.isNative ) {
			return this.dirInterp.moduleSymbol;
		}
		return this.codeObject.moduleObject.symbol;
	}

	get defaults(): IvyDataDict {
		return this._defaults;
	}
	
	set defaults(val) {
		this._defaults = val
	}

	get context(): IvyData {
		return this._context;
	}
}