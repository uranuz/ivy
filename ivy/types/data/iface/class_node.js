define('ivy/types/data/iface/class_node', [
	'ivy/types/data/exception'
], function(DataExc) {
var NotImplException = DataExc.NotImplException;
return FirClass(
	function IClassNode() {
		throw new Error('Cannot create instance of abstract class!');
	}, {
		/** Analogue to IvyNodeRange opSlice(); in D impl */
		__range__: function() {
			throw new NotImplException('Not implemented!');
		},
		/** Analogue to IClassNode opSlice(size_t, size_t); in D impl */
		__slice__: function(start, end) {
			throw new NotImplException('Not implemented!');
		},
		/** Analogue to:
		 * IvyData opIndex(string);
		 * IvyData opIndex(size_t);
		 * in D impl */
		__getAt__: function(index) {
			throw new NotImplException('Not implemented!');
		},
		/** Analogue to IvyData __getAttr__(string); in D impl */
		__getAttr__: function(name) {
			throw new NotImplException('Not implemented!');
		},
		/** Analogue to void __setAttr__(IvyData, string); in D impl */
		__setAttr__: function(value, name) {
			throw new NotImplException('Not implemented!');
		},
		/** Analogue to IvyData __serialize__(); in D impl */
		__serialize__: function() {
			throw new NotImplException('Not implemented!');
		},
		/** Analogue to size_t length() @property; in D impl */
		length: firProperty(function() {
			throw new NotImplException('Not implemented!');
		}),
		/** Analogue to size_t empty() @property; in D impl */
		empty: firProperty(function() {
			throw new NotImplException('Not implemented!');
		})
	});
});