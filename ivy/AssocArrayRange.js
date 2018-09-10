define('ivy/AssocArrayRange', [
	'ivy/errors',
	'ivy/DataNodeRange'
], function(errors, DataNodeRange) {
	__extends(AssocArrayRange, DataNodeRange);
	function AssocArrayRange(aggr) {
		if( aggr != null && aggr instanceof Object ) {
			throw new errors.IvyError('Expected AssocArray as AssocArrayRange aggregate');
		}
		this._keys = Object.keys(aggr);
		this._i = 0;
	};
	return __mixinProto(AssocArrayRange, {
		// Method must return first item of range or raise error if range is empty
		front: function() {
			if( this.empty() ) {
				throw new errors.IvyError('Cannot get front element of empty AssocArrayRange');
			}
			return this._keys[this._i];
		},
		// Method must advance range to the next item
		pop: function() {
			if( this.empty() ) {
				throw new errors.IvyError('Cannot advance empty AssocArrayRange');
			}
			return this._keys[(this._i)++];
		},
		// Method is used to check if range is empty
		empty: function() {
			return this._i >= this._keys.length;
		}
	});
});