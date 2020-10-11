define('ivy/interpreter/directive/typestr', [
	'ivy/interpreter/directive/utils',
	'ivy/types/data/consts'
], function(du, DataConsts) {
return FirClass(
	function TypeStrDirInterpreter() {
		this._symbol = new du.DirectiveSymbol("typestr", [du.DirAttr("value", du.IvyAttrType.Any)]);
	}, du.BaseDirectiveInterpreter, {
		interpret: function(interp) {
			var valueType = du.idat.type(interp.getValue("value"));
			interp.log.internalAssert(
				valueType < DataConsts.IvyDataTypeItems.length,
				"Unable to get type-string for value");
			interp._stack.push(Consts.IvyDataTypeItems[valueType]);
		}
	});
});