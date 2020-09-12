define('ivy/types/data/range/array', [
	'ivy/errors',
	'ivy/types/data/iface/range'
], function(errors, DataNodeRange) {
return FirClass(
	function ArrayRange(aggr) {
		if( !(aggr instanceof Array) ) {
			throw new errors.IvyError('Expected array as ArrayRange aggregate');
		}
		this._array = aggr;
		this._i = 0;
	}, DataNodeRange, {
		// Method must return first item of range or raise error if range is empty
		front: function() {
			if( this.empty() ) {
				throw new errors.IvyError('Cannot get front element of empty ArrayRange');
			}
			return this._array[this._i];
		},
		// Method must advance range to the next item
		pop: function() {
			if( this.empty() ) {
				throw new errors.IvyError('Cannot advance empty ArrayRange');
			}
			return this._array[(this._i)++];
		},
		// Method is used to check if range is empty
		empty: function() {
			return this._i >= this._array.length;
		}
});
});