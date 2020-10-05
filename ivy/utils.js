define('ivy/utils', [
	'exports'
], function(
	iutil
) {
Object.assign(iutil, {
	back: function(arr) {
		if( !(arr instanceof Array) ) {
			throw new Error('Expected array');
		}
		if( arr.length === 0 ) {
			throw new Error('Cannot get back item, because array is empty!');
		}
		return arr[arr.length-1];
	},

	// Creates reverse iterator over array
	reversed: FirClass(function Reversed(arr) {
		var inst = firPODCtor(this, Reversed, arguments);
		if( inst ) return inst;

		if( !(arr instanceof Array) ) {
			throw new Error('Expected array');
		}

		this._arr = arr;
		this._i = arr.length;
		this._state = {
			done: false
		};
	}, {
		next: function() {
			if( this._i <= 0 ) {
				this._state.done = true;
				delete this._state.value;
			} else {
				this._state.value = this._arr[this._i - 1];
				this._i -= 1;
			}
			return this._state;
		}
	}),

	enforce: function(ExceptionType, cond) {
		if( cond ) {
			return;
		};
		var message = '';
		Array.prototype.forEach.call(arguments, function(item, index) {
			if( index > 1 ) {
				message += String(item);
			}
		});

		throw new ExceptionType(message);
	}
});
});