define('ivy/types/data/range/integer', [
	'ivy/exception',
	'ivy/types/data/iface/range'
], function(IvyException, DataNodeRange) {
return FirClass(
	function IntegerRange(begin, end) {
		if( typeof(begin) !== 'number' || typeof(end) !== 'number' ) {
			throw new IvyException('Number range begin and end arguments must be numbers');
		}
		if( begin > end ) {
			throw new IvyException('Begin must not be greater than end');
		}
		this._current = begin;
		this._end = end;
	}, DataNodeRange, {
		// Method must return first item of range or raise error if range is empty
		front: function() {
			return this._current;
		},
		// Method must advance range to the next item
		pop: function() {
			if( this.empty() ) {
				throw new IvyException('Cannot advance empty IntegerRange');
			}
			return this._current++;
		},
		// Method is used to check if range is empty
		empty: function() {
			return this._current >= this._end;
		}
	});
});