define('ivy/types/data/range/assoc_array', [
	'ivy/exception',
	'ivy/types/data/iface/range'
], function(IvyException, DataNodeRange) {
return FirClass(
	function AssocArrayRange(aggr) {
		if( aggr != null && aggr instanceof Object ) {
			throw new IvyException('Expected AssocArray as AssocArrayRange aggregate');
		}
		this._keys = Object.keys(aggr);
		this._i = 0;
	}, DataNodeRange, {
		// Method must return first item of range or raise error if range is empty
		front: function() {
			if( this.empty() ) {
				throw new IvyException('Cannot get front element of empty AssocArrayRange');
			}
			return this._keys[this._i];
		},
		// Method must advance range to the next item
		pop: function() {
			if( this.empty() ) {
				throw new IvyException('Cannot advance empty AssocArrayRange');
			}
			return this._keys[(this._i)++];
		},
		// Method is used to check if range is empty
		empty: function() {
			return this._i >= this._keys.length;
		}
	});
});