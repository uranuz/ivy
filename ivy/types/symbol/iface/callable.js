define('ivy/types/symbol/iface/callable', [
	'ivy/types/symbol/iface/symbol'
], function(IIvySymbol) {
return FirClass(
	function ICallableSymbol() {
		throw new Error('Cannot create instance of interface')
	}, IIvySymbol
);
});