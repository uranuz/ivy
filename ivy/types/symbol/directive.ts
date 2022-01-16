import {ICallableSymbol} from 'ivy/types/symbol/iface/callable';
import {Location} from 'ivy/location';
import {SymbolKind} from 'ivy/types/symbol/consts';
import { DirAttr } from 'ivy/types/symbol/dir_attr';

export class DirectiveSymbol implements ICallableSymbol {
	private _name: string;
	private _loc: Location;
	private _attrs: DirAttr[];
	private _attrIndexes: any;

	constructor(name: string, locOrAttrs: Location | DirAttr[], attrs?: DirAttr[]) {
		if( locOrAttrs instanceof Location ) {
			this._init(name, locOrAttrs, attrs);
		} else {
			this._init(name, new Location("__global__"), attrs);
		}
	}

	_init(name: string, loc: Location, attrs: DirAttr[]): void {
		this._name = name;
		this._loc = loc;
		this._attrs = attrs || [];
		this._attrIndexes = {};

		if( !this._name.length ) {
			throw new Error('Expected directive symbol name');
		}
		if( !(this._loc instanceof Location) ) {
			throw new Error('Expected instance of Location');
		}
		this._reindexAttrs();
	}

	_reindexAttrs(): void {
		for( var i = 0; i < this.attrs.length; ++i ) {
			var attr = this.attrs[i];
			if( this._attrIndexes[attr.name] != null ) {
				throw new Error('Duplicate attribite name for directive symbol: ' + this._name);
			}
			this._attrIndexes[attr.name] = i;
		}
	}

	get name(): string {
		return this._name;
	}

	get location(): Location {
		return this._loc;
	}

	get kind(): SymbolKind {
		return SymbolKind.directive;
	}

	get attrs(): DirAttr[] {
		return this._attrs;
	}

	getAttr(attrName: string): DirAttr {
		var idx: number = this._attrIndexes[attrName];
		if( idx == null ) {
			throw new Error('No attribute with name "' + attrName + '" for directive "' + this.name + '"');
		}
		return this._attrs[idx];
	}
}