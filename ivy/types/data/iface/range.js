define('ivy/types/data/iface/range', [], function() {
return FirClass(
	function DataNodeRange() {
		throw new Error('Cannot create instance of abstract class!');
	}, {
		// Method must return first item of range or raise error if range is empty
		front: function() {
			throw new Error('Not implemented!');
		},
		// Method must advance range to the next item
		pop: function() {
			throw new Error('Not implemented!');
		},
		// Method is used to check if range is empty
		empty: function() {
			throw new Error('Not implemented!');
		}
	});
});