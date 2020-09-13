define('ivy/types/symbol/directive', [
	'ivy/types/symbol/iface/callable',
	'ivy/location',
	'ivy/types/symbol/dir_body_attrs'
], function(
	ICallableSymbol,
	Location,
	DirBodyAttrs
) {
return FirClass(
	function DirectiveSymbol(name, locOrAttrs, attrsOrBodyAttrs, bodyAttrs) {
		if( locOrAttrs instanceof Location ) {
			this._init(name, locOrAttrs, attrsOrBodyAttrs, bodyAttrs);
		} else {
			this._init(name, Location(`__global__`), locOrAttrs, attrsOrBodyAttrs);
		}
	}, ICallableSymbol, {
		_init: function(name, loc, attrs, bodyAttrs) {
			this._name = name;
			this._loc = loc;
			this._attrs = attrs || [];
			this._bodyAttrs = bodyAttrs || DirBodyAttrs();

			if( !this._name.length ) {
				throw new Error('Expected directive symbol name');
			}
			if( !(this._loc instanceof Location) ) {
				throw new Error('Expected instance of Location');
			}
			if( !(this._bodyAttrs instanceof DirBodyAttrs) ) {
				throw new Error('Expected instance of DirBodyAttrs');
			}
			this._reindexAttrs();
		},

		_reindexAttrs: function() {
			for( var i = 0; i < this.attrs.length; ++i ) {
				var attr = this.attrs[i];
				if( this._attrIndexes[attr.name] != null ) {
					throw new Error('Duplicate attribite name for directive symbol: ' + this._name);
				}
				this._attrIndexes[attr.name] = i;
			}
		},

		name: firProperty(function() {
			return this._name;
		}),

		location: firProperty(function() {
			return this._loc;
		}),

		attrs: firProperty(function() {
			return this._attrs;
		}),

		getAttr: function(attrName) {
			var idx = this._attrIndexes[attrName];
			if( idx == null ) {
				throw new Error('No attribute with name "' + attrName + '" for directive "' + this._name + '"');
			}
			return this._attrs[idx];
		},

		bodyAttrs: firProperty(function() {
			return this._bodyAttrs;
		})
	}
);
});