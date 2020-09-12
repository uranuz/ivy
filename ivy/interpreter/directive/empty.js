define('ivy/interpreter/directive/empty', [
	'ivy/interpreter/directive/iface',
	'ivy/utils',
	'ivy/types/data/consts'
], function(DirectiveInterpreter, iu, Consts) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
return FirClass(
	function EmptyDirInterpreter() {
		this._name = 'empty';
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
			switch( iu.getDataNodeType(value) )
			{
				case IvyDataType.Undef: case IvyDataType.Null:
					interp._stack.push(true);
					break;
				case IvyDataType.Integer:
				case IvyDataType.Floating:
				case IvyDataType.DateTime:
				case IvyDataType.Boolean:
					// Considering numbers just non-empty there. Not try to interpret 0 or 0.0 as logical false,
					// because in many cases they could be treated as significant values
					// DateTime and Boolean are not empty too, because we cannot say what value should be treated as empty
					interp._stack.push(false);
					break;
				case IvyDataType.String:
				case IvyDataType.Array:
					interp._stack.push(!value.length);
					break;
				case IvyDataType.AssocArray:
					interp._stack.push(!Object.keys(value).length);
					break;
				case IvyDataType.DataNodeRange:
					interp._stack.push(value.empty());
					break;
				case IvyDataType.ClassNode:
					// Basic check for ClassNode for emptyness is that it should not be null reference
					// If some interface method will be introduced to check for empty then we shall consider to check it too
					interp._stack.push(false);
					break;
				default:
					interp.rtError('Cannot test value for emptyness');
					break;
			}
		}
	});
});