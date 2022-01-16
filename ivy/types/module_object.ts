import {CodeObject} from 'ivy/types/code_object';
import { IvyData } from 'ivy/types/data/data';
import { ModuleSymbol } from 'ivy/types/symbol/module_';
//import {NodeEscapeState} from 'ivy/types/data/consts';

export class ModuleObject {
	private _consts: IvyData[];

	constructor(symbol: ModuleSymbol) {
		this._consts = [];
		this.addConst(new CodeObject(symbol, this));
	}

	// Append const to list and return it's index
	addConst(data: IvyData) {
		// Get index of added constant
		var index = this._consts.length;
		// Consider all constants are Safe by default
		//data.escapeState = NodeEscapeState.Safe;
		this._consts.push(data);
		return index;
	}

	getConst(index: number): IvyData {
		if( index >= this._consts.length ) {
			throw Error('There is no module const with specified index!');
		}
		return this._consts[index];
	}

	get mainCodeObject(): CodeObject {
		return this.getConst(0);
	}

	get symbol(): ModuleSymbol {
		return this.mainCodeObject.symbol as ModuleSymbol;
	}
	
	get name(): string {
		return this.symbol.name
	}

	get fileName(): string {
		return this.symbol.location.fileName;
	}
}