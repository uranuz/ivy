define('ivy/interpreter/directive/typestr', [
	'ivy/interpreter/directive/iface',
	'ivy/utils',
	'ivy/types/data/consts'
], function(DirectiveInterpreter, iu, Consts) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
return FirClass(
	function TypeStrDirInterpreter() {
		this._name = 'typestr';
		this._attrBlocks = [{
			'kind': DirAttrKind.ExprAttr,
			'exprAttrs': [{ 'name': 'value', 'typeName': 'any' }]
		}, {
			'kind': DirAttrKind.BodyAttr,
			'bodyAttr': {}
		}]
	}, DirectiveInterpreter, {
		interpret: function(interp) {
			var valueType = iu.getDataNodeType(interp.getValue("value"));
			if( valueType >= Consts.IvyDataTypeItems.length ) {
				interp.rtError('Unable to get type-string for value');
			}
			interp._stack.push(Consts.IvyDataTypeItems[valueType]);
		}
	});
});