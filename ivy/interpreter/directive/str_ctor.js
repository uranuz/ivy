define('ivy/interpreter/directive/str_ctor', [
	'ivy/interpreter/directive/iface',
	'ivy/utils',
	'ivy/types/data/consts'
], function(DirectiveInterpreter, iu, Consts) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
return FirClass(
	function StrCtorDirInterpreter() {
		this._name = 'str';
		this._attrBlocks = [{
			'kind': DirAttrKind.ExprAttr,
			'exprAttrs': [{ 'name': 'value', 'typeName': 'any' }]
		}, {
			'kind': DirAttrKind.BodyAttr,
			'bodyAttr': {}
		}]
	}, DirectiveInterpreter, {
		interpret: function(interp) {
			interp._stack.push(String(interp.getValue("value")));
		}
	})
});