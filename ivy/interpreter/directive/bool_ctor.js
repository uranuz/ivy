define('ivy/interpreter/directive/bool_ctor', [
	'ivy/interpreter/directive/utils'
], function(du) {
return FirClass(
	function BoolCtorDirInterpreter() {
		this._symbol = new du.DirectiveSymbol("bool", [du.DirAttr("value", du.IvyAttrType.Any)]);
	}, du.BaseDirectiveInterpreter, {
		interpret: function(interp) {
			interp._stack.push(du.idat.toBoolean(interp.getValue("value")));
		}
	});
});