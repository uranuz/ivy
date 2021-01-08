define('ivy/types/binded_callable', [
	'ivy/types/iface/callable_object'
], function(
	ICallableObject
) {
return FirClass(
	function BindedCallable(callable, context) {
		this._callable = callable;
		this._context = context;
	}, ICallableObject, {
		isNative: firProperty(function() {
			return this._callable.isNative;
		}),

		dirInterp: firProperty(function() {
			return this._callable.dirInterp;
		}),

		codeObject: firProperty(function() {
			return this._callable.codeObject;
		}),

		symbol: firProperty(function() {
			return this._callable.symbol;
		}),

		moduleSymbol: firProperty(function() {
			return this._callable.moduleSymbol
		}),

		defaults: firProperty(function() {
			return this._callable.defaults;
		}),

		context: firProperty(function() {
			return this._context;
		})
	});
});