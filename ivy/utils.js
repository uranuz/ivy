define('ivy/utils', [], function() {
	return {
		back: function(arr) {
			if( arr.length === 0 ) {
				throw Error('Cannot get back item, becaise array is empty!');
			}
			return arr[arr.length-1];
		}
	};
});