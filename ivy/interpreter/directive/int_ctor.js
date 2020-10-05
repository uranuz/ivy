define('ivy/interpreter/directive/int_ctor', [
	'ivy/interpreter/directive/utils'
], function(du) {
return FirClass(
	function IntCtorDirInterpreter() {
		this._symbol = new du.DirectiveSymbol("int", [du.DirAttr("value", du.IvyAttrType.Any)]);
	}, du.BaseDirectiveInterpreter, {
		interpret: function(interp) {
			interp._stack.push(du.idat.toInteger(interp.getValue("value")));
		}
	});
});