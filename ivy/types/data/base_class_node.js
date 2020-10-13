define('ivy/types/data/base_class_node', [
	'ivy/types/data/iface/class_node',
	'ivy/types/data/exception'
], function(
	IClassNode,
	DataExc
) {
var NotImplException = DataExc.NotImplException;
return FirClass(
	function BaseClassNode() {
		this.superproto.constructor.call(this);
	}, IClassNode, {
		/** Analogue to size_t empty() @property; in D impl */
		empty: firProperty(function() {
			// By default implement empty with check for length
			try {
				return this.length == 0;
			} catch(exc) {
				if( !(exc instanceof NotImplException) ) {
					throw exc;
				}
			}
			// If there is no logic of emptyness implemented then consider it's not empty
			return false;
		})
	});
});