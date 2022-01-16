/// Directive call specification
export class CallSpec {
	private _posAttrsCount: number;
	private _hasKwAttrs: boolean;

	constructor(specOrAttrCount?: number, hasKwAttrs?: boolean) {
		if( hasKwAttrs == null ) {
			/// Position attributes count passed in directive call
			this._posAttrsCount = specOrAttrCount >> 1;

			/// Is there keyword attributes in directive call
			this._hasKwAttrs = (1 & specOrAttrCount) != 0;
		} else {
			this._posAttrsCount = specOrAttrCount;
			this._hasKwAttrs = hasKwAttrs;
		}
	}
	get posAttrsCount(): number {
		return this._posAttrsCount;
	}

	get hasKwAttrs(): boolean {
		return this._hasKwAttrs;
	}

	encode(): number {
		return (this._posAttrsCount << 1) + (this._hasKwAttrs? 1: 0);
	}
}