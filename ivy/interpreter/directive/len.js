define('ivy/interpreter/directive/len', [
	'ivy/interpreter/directive/utils'
], function(du) {
return FirClass(
	function LenDirInterpreter() {
		this._symbol = new du.DirectiveSymbol(`len`, [du.DirAttr("value", du.IvyAttrType.Any)]);
	}, du.BaseDirectiveInterpreter, {
		interpret: function(interp) {
			interp._stack.push(du.idat.length(interp.getValue("value")));
		}
	});
});