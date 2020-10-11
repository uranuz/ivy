define('ivy/types/call_spec', [], function() {
/// Directive call specification
return FirClass(
	function CallSpec(specOrAttrCount, hasKwAttrs) {
		var inst = firPODCtor(this, arguments);
		if( inst ) return inst;

		if( hasKwAttrs == null ) {
			/// Position attributes count passed in directive call
			this._posAttrsCount = specOrAttrCount >> 1;

			/// Is there keyword attributes in directive call
			this._hasKwAttrs = (1 & specOrAttrCount) != 0;
		} else {
			this._posAttrsCount = specOrAttrCount;
			this._hasKwAttrs = hasKwAttrs;
		}
	}, {
		posAttrsCount: firProperty(function() {
			return this._posAttrsCount;
		}),

		hasKwAttrs: firProperty(function() {
			return this._hasKwAttrs;
		}),

		encode: function() {
			return (this._posAttrsCount << 1) + (this._hasKwAttrs? 1: 0);
		}
	});
});