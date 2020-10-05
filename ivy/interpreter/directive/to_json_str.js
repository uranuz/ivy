define('fir/ivy/directive/to_json_str', [
	'ivy/interpreter/directive/utils'
], function(du) {
return FirClass(
	function ToJSONStrDirInterpreter() {
		this._symbol = new du.DirectiveSymbol("to_json_str", [du.DirAttr("value", du.IvyAttrType.Any)]);
	}, du.BaseDirectiveInterpreter, {
		interpret: function(interp) {
			interp._stack.push(du.toStdJSON(interp.getValue("value")));
		}
	});
});