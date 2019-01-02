define('ivy/directive/ToJSONBase64', [
	'ivy/DirectiveInterpreter',
	'ivy/utils',
	'ivy/Consts',
	'fir/common/base64'
], function(
	DirectiveInterpreter,
	iu,
	Consts,
	base64
) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
	return __mixinProto(__extends(function ToJSONBase64DirInterpreter() {
		this._name = 'toJSONBase64';
		this._attrBlocks = [{
			'kind': DirAttrKind.ExprAttr,
			'exprAttrs': [{ 'name': 'value', 'typeName': 'any' }]
		}, {
			'kind': DirAttrKind.BodyAttr,
			'bodyAttr': {}
		}]
	}, DirectiveInterpreter), {
		interpret: function(interp) {
			interp._stack.push(
				base64.encodeUTF8(
					JSON.stringify(
						interp.getValue("value"))));
		}
	});
});