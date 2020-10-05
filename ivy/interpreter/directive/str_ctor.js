define('ivy/interpreter/directive/str_ctor', [
	'ivy/interpreter/directive/utils'
], function(du) {
return FirClass(
	function StrCtorDirInterpreter() {
		this._symbol = new du.DirectiveSymbol("str", [du.DirAttr("value", du.IvyAttrType.Any)]);
	}, du.BaseDirectiveInterpreter, {
		interpret: function(interp) {
			interp._stack.push(du.idat.toString(interp.getValue("value")));
		}
	});
});