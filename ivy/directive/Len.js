define('ivy/directive/Len', [
	'ivy/DirectiveInterpreter',
	'ivy/utils',
	'ivy/Consts'
], function(DirectiveInterpreter, iu, Consts) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
	return __mixinProto(__extends(function LenDirInterpreter() {
		this._name = 'len';
		this._attrBlocks = [{
			'kind': DirAttrKind.ExprAttr,
			'exprAttrs': [{ 'name': 'value', 'typeName': 'any' }]
		}, {
			'kind': DirAttrKind.BodyAttr,
			'bodyAttr': {}
		}]
	}, DirectiveInterpreter), {
		interpret: function(interp) {
			var value = interp.getValue("value");
			switch( iu.getDataNodeType(value) ) {
				case IvyDataType.String:
				case IvyDataType.Array:
					this._stack.push(value.length);
					break;
				case IvyDataType.AssocArray:
					this._stack.push(Object.keys(value).length);
					break;
				default:
					interp.rtError('Cannot get length for value');
			}
		}
	});
});