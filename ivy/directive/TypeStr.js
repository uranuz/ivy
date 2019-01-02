define('ivy/directive/TypeStr', [
	'ivy/DirectiveInterpreter',
	'ivy/utils',
	'ivy/Consts'
], function(DirectiveInterpreter, iu, Consts) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
	return __mixinProto(__extends(function TypeStrDirInterpreter() {
		this._name = 'typestr';
		this._attrBlocks = [{
			'kind': DirAttrKind.ExprAttr,
			'exprAttrs': [{ 'name': 'value', 'typeName': 'any' }]
		}, {
			'kind': DirAttrKind.BodyAttr,
			'bodyAttr': {}
		}]
	}, DirectiveInterpreter), {
		interpret: function(interp) {
			var valueType = iu.getDataNodeType(interp.getValue("value"));
			if( valueType >= Consts.IvyDataTypeItems.length ) {
				interp.rtError('Unable to get type-string for value');
			}
			this._stack.push(Consts.IvyDataTypeItems[valueType]);
		}
	});
});