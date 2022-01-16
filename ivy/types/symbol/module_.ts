import {ICallableSymbol} from 'ivy/types/symbol/iface/callable';
import {Location} from 'ivy/location';
import {SymbolKind} from 'ivy/types/symbol/consts';
import { DirAttr } from 'ivy/types/symbol/dir_attr';

export class ModuleSymbol implements ICallableSymbol {
	private _name: string;
	private _loc: Location;

	constructor(name: string, loc: Location) {
		this._name = name;
		this._loc = loc || new Location();

		if( !this._name.length ) {
			throw new Error('Expected module symbol name');
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
		return SymbolKind.module_;
	}

	get attrs(): DirAttr[] {
		return [];
	}

	getAttr(): DirAttr {
		throw new Error('Module symbol has no attributes');
	}
}