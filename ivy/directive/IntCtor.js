define('ivy/directive/IntCtor', [
	'ivy/DirectiveInterpreter',
	'ivy/utils',
	'ivy/Consts'
], function(DirectiveInterpreter, iu, Consts) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
return FirClass(
	function IntCtorDirInterpreter() {
		this._name = 'int';
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
				case IvyDataType.Boolean: interp._stack.push(value.boolean? 1: 0); break;
				case IvyDataType.Integer: interp._stack.push(value); break;
				case IvyDataType.String: {
					var parsed = parseInt(value, 10);
					if( isNaN(parsed) || String(parsed) !== value ) {
						interp.rtError('Unable to parse value as Integer');
					}
					interp._stack.push(parsed);
					break;
				}
				default:
					interp.rtError('Cannot convert value to Integer');
					break;
			}
		}
	})
});