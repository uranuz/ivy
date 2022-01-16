import {ensure} from 'ivy/utils';
import {IvyException} from 'ivy/exception';
import { IDirectiveInterpreter } from 'ivy/interpreter/directive/iface';
import { ICallableSymbol } from 'ivy/types/symbol/iface/callable';

var assure = ensure.bind(null, IvyException);
export class InterpreterDirectiveFactory {
	private _baseFactory: InterpreterDirectiveFactory;
	private _dirInterps: IDirectiveInterpreter[];
	private _indexes: { [k: string]: number };

	constructor(baseFactory?: InterpreterDirectiveFactory) {
		this._baseFactory = baseFactory;
		this._dirInterps = [];
		this._indexes = {};
	}

	get(name: string): IDirectiveInterpreter {
		var intPtr = this._indexes[name];
		if( intPtr != null )
			return this._dirInterps[intPtr];
		if( this._baseFactory )
			return this._baseFactory.get(name);
		return null;
	}

	add(dirInterp: IDirectiveInterpreter) {
		var name = dirInterp.symbol.name;
		assure(!this._indexes.hasOwnProperty(name), "Directive interpreter with name: " + name + " already added");
		this._indexes[name] = this._dirInterps.length;
		this._dirInterps.push(dirInterp);
	}

	get interps(): IDirectiveInterpreter[] {
		return this._dirInterps.concat(this._getBaseInterps());
	}

	get symbols(): ICallableSymbol[] {
		return this._dirInterps.map(function(it) { return it.symbol }).concat(this._getBaseSymbols());
	}

	_getBaseInterps(): IDirectiveInterpreter[] {
		return this._baseFactory? this._baseFactory.interps: [];
	}

	_getBaseSymbols(): ICallableSymbol[] {
		return this._baseFactory? this._baseFactory.symbols: [];
	}
}