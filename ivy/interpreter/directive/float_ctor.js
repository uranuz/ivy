define('ivy/interpreter/directive/float_ctor', [
	'ivy/interpreter/directive/utils'
], function(du) {
return FirClass(
	function FloatCtorDirInterpreter() {
		this._symbol = new du.DirectiveSymbol("float", [du.DirAttr("value", du.IvyAttrType.Any)]);
	}, du.BaseDirectiveInterpreter, {
		interpret: function(interp) {
			interp._stack.push(du.idat.toFloating(interp.getValue("value")));
		}
	});
});