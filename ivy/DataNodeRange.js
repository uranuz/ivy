define('ivy/DataNodeRange', [], function() {
	function DataNodeRange() {
		throw new Error('Cannot create instance of abstract class!');
	};
	return __mixinProto(DataNodeRange, {
		// Method must return first item of range or raise error if range is empty
		front: function() {
			throw new Error('Not implemented!');
		},
		// Method must advance range to the next item
		popFront: function() {
			throw new Error('Not implemented!');
		},
		// Method is used to check if range is empty
		empty: function() {
			throw new Error('Not implemented!');
		}
	});
});