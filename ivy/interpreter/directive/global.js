define('ivy/interpreter/directive/global', [
	'ivy/interpreter/directive/base',
	'ivy/types/symbol/global',
	'ivy/types/callable_object'
], function(
	BaseDirectiveInterpreter,
	globalSymbol,
	CallableObject
) {
var GlobalDirInterpreter = FirClass(
	function GlobalDirInterpreter() {
		this._symbol = globalSymbol;
	}, BaseDirectiveInterpreter, {
		interpret: function(interp) {
			throw new Error("This is not expected to be executed");
		}
	}),
	globalDirective = new GlobalDirInterpreter,
	globalCallable = new CallableObject(globalDirective);
return globalCallable;
});
