define('ivy/interpreter/directive/empty', [
	'ivy/interpreter/directive/utils'
], function(du) {
return FirClass(
	function EmptyDirInterpreter() {
		this._symbol = new du.DirectiveSymbol(`empty`, [DirAttr("value", du.IvyAttrType.Any)]);
	}, du.BaseDirectiveInterpreter, {
		interpret: function(interp) {
			interp._stack.push(du.idat.empty(interp.getValue("value")));
		}
	});
});