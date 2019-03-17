define('ivy/directive/Has', [
	'ivy/DirectiveInterpreter',
	'ivy/utils',
	'ivy/Consts'
], function(DirectiveInterpreter, iu, Consts) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
return FirClass(
	function HasDirInterpreter() {
		this._name = 'has';
		this._attrBlocks = [{
			'kind': DirAttrKind.ExprAttr,
			'exprAttrs': [
				{ 'name': 'collection', 'typeName': 'any' },
				{ 'name': 'key', 'typeName': 'any' }
			]
		}, {
			'kind': DirAttrKind.BodyAttr,
			'bodyAttr': {}
		}]
	}, DirectiveInterpreter, {
		interpret: function(interp) {
			var
				collection = interp.getValue("collection"),
				key = interp.getValue("key");
			switch( iu.getDataNodeType(collection) )
			{
				case IvyDataType.AssocArray:
					if( iu.getDataNodeType(key) !== IvyDataType.String ) {
						interp.rtError('Expected String as attribute name');
					}
					interp._stack.push(collection[key] !== undefined);
					break;
				case IvyDataType.Array:
					interp._stack.push(collection.indexOf(key) >= 0);
					break;
				default:
					interp.rtError('Unexpected collection type');
					break;
			}
		}
	});
});