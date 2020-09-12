define('fir/ivy/directive/to_json_str', [
	'ivy/interpreter/directive/iface',
	'ivy/utils',
	'ivy/types/data/consts'
], function(
	DirectiveInterpreter,
	iu,
	Consts
) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
return FirClass(
	function ToJSONStrDirInterpreter() {
		this._name = 'to_json_str';
		this._attrBlocks = [{
			'kind': DirAttrKind.ExprAttr,
			'exprAttrs': [{ 'name': 'value', 'typeName': 'any' }]
		}, {
			'kind': DirAttrKind.BodyAttr,
			'bodyAttr': {}
		}]
	}, DirectiveInterpreter, {
		interpret: function(interp) {
			interp._stack.push(iu.toStdJSON(interp.getValue("value")));
		}
	});
});