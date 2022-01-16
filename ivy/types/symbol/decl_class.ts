import {ICallableSymbol} from 'ivy/types/symbol/iface/callable';
import {Location} from 'ivy/location';
import {SymbolKind} from 'ivy/types/symbol/consts';
import { DirAttr } from 'ivy/types/symbol/dir_attr';


export class DeclClassSymbol implements ICallableSymbol {
	private _name: string;
	private _loc: Location;
	private _initSymbol: ICallableSymbol;

	constructor(name: string, loc: Location) {
		this._name = name;
		this._loc = loc;
		this._initSymbol = null;
	
		if( !this._name.length ) {
			throw new Error('Expected directive symbol name');
		}
		if( !(this._loc instanceof Location) ) {
			throw new Error('Expected instance of Location');
		}
	}

	get name(): string {
		return this._name;
	}

	get location(): Location {
		return this._loc;
	}

	get kind(): SymbolKind {
		return SymbolKind.declClass;
	}

	get attrs(): DirAttr[] {
		return this.initSymbol.attrs;
	}

	getAttr(attrName: string): DirAttr {
		return this.initSymbol.getAttr(attrName);
	}

	get initSymbol(): ICallableSymbol {
		return this._initSymbol;
	}

	set initSymbol(symb: ICallableSymbol) {
		this._initSymbol = symb;
	}
}
