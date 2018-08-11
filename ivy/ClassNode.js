define('ivy/ClassNode', [], function() {
	function ClassNode() {
		throw new Error('Cannot create instance of abstract class!');
	};
	return __mixinProto(ClassNode, {
		/** Analogue to IDataNodeRange opSlice(); in D impl */
		range: function() {
			throw new Error('Not implemented!');
		},
		/** Analogue to IClassNode opSlice(size_t, size_t); in D impl */
		slice: function(start, end) {
			throw new Error('Not implemented!');
		},
		/** Analogue to:
		 * TDataNode opIndex(string);
		 * TDataNode opIndex(size_t);
		 * in D impl */
		at: function(index) {
			throw new Error('Not implemented!');
		},
		/** Analogue to TDataNode __getAttr__(string); in D impl */
		getAttr: function(name) {
			throw new Error('Not implemented!');
		},
		/** Analogue to void __setAttr__(TDataNode, string); in D impl */
		setAttr: function(value, name) {
			throw new Error('Not implemented!');
		},
		/** Analogue to TDataNode __serialize__(); in D impl */
		serialize: function() {
			throw new Error('Not implemented!');
		},
		/** Analogue to size_t length() @property; in D impl */
		getLength: function() {
			throw new Error('Not implemented!');
		}
	});
});