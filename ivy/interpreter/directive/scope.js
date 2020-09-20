define('ivy/interpreter/directive/scope', [
	'ivy/interpreter/directive/utils',
	'ivy/types/symbol/dir_body_attrs'
], function(du, DirBodyAttrs) {
return FirClass(
	function ScopeDirInterpreter() {
		this._symbol = new du.DirectiveSymbol(`scope`, [], DirBodyAttrs(/*isNoscope=*/true));
	}, du.BaseDirectiveInterpreter, {
		interpret: function(interp) {
			interp._stack.push(interp.independentFrame._dataDict);
		}
	});
});