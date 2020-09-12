define('ivy/interpreter/directive/len', [
	'ivy/interpreter/directive/iface',
	'ivy/utils',
	'ivy/types/data/consts'
], function(DirectiveInterpreter, iu, Consts) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
return FirClass(
	function LenDirInterpreter() {
		this._name = 'len';
		this._attrBlocks = [{
			'kind': DirAttrKind.ExprAttr,
			'exprAttrs': [{ 'name': 'value', 'typeName': 'any' }]
		}, {
			'kind': DirAttrKind.BodyAttr,
			'bodyAttr': {}
		}]
	}, DirectiveInterpreter, {
		interpret: function(interp) {
			var value = interp.getValue("value");
			switch( iu.getDataNodeType(value) ) {
				case IvyDataType.String:
				case IvyDataType.Array:
					interp._stack.push(value.length);
					break;
				case IvyDataType.AssocArray:
					interp._stack.push(Object.keys(value).length);
					break;
				default:
					interp.rtError('Cannot get length for value');
			}
		}
	});
});