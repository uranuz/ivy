import {IDirectiveInterpreter} from 'ivy/interpreter/directive/iface';
import { Interpreter } from 'ivy/interpreter/interpreter';
import {globalSymbol} from 'ivy/types/symbol/global';
import { ICallableSymbol } from 'ivy/types/symbol/iface/callable';

export class DirectiveInterpreter implements IDirectiveInterpreter {
	private _method: Function;
	private _symbol: ICallableSymbol;

	constructor(method: Function, symbol: ICallableSymbol) {
		this._method = method;
		this._symbol = symbol;
	}

	interpret(interp: Interpreter) {
		this._method(interp);
	}

	get symbol(): ICallableSymbol {
		if( this._symbol == null ) {
			throw new Error("Directive symbol is not set for: " + this.constructor['name']);
		}
		return this._symbol;
	}

	get moduleSymbol(): ICallableSymbol {
		return globalSymbol;
	}
}