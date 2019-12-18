define('fir/ivy/directive/ToJSONStr', [
	'ivy/DirectiveInterpreter',
	'ivy/utils',
	'ivy/Consts'
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