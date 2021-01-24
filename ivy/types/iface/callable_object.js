define('ivy/types/iface/callable_object', [
	'ivy/types/data/exception'
], function(
	DataExc
) {
var NotImplException = DataExc.NotImplException;
return FirClass(
	function ICallableObject() {
		throw new NotImplException('Cannot create instance of abstract class!');
	}, {
		isNative: firProperty(function() {
			throw new NotImplException('Not implemented!');
		}),

		dirInterp: firProperty(function() {
			throw new NotImplException('Not implemented!');
		}),

		codeObject: firProperty(function() {
			throw new NotImplException('Not implemented!');
		}),

		symbol: firProperty(function() {
			throw new NotImplException('Not implemented!');
		}),

		moduleSymbol: firProperty(function() {
			throw new NotImplException('Not implemented!');
		}),

		defaults: firProperty(function() {
			throw new NotImplException('Not implemented!');
		}),

		context: firProperty(function() {
			throw new NotImplException('Not implemented!');
		})
	});
});