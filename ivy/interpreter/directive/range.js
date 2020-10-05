define('ivy/interpreter/directive/range', [
	'ivy/interpreter/directive/utils',
	'ivy/types/data/range/integer'
], function(du, IntegerRange) {
return FirClass(
	function RangeDirInterpreter() {
		this._symbol = new du.DirectiveSymbol("range", [
			du.DirAttr("begin", du.IvyAttrType.Any),
			du.DirAttr("end", du.IvyAttrType.Any)
		]);
	}, du.BaseDirectiveInterpreter, {
		interpret: function(interp) {
			interp._stack.push(
				new IntegerRange(
					du.idat.integer(interp.getValue("begin")),
					du.idat.integer(interp.getValue("end"))));
		}
	});
});