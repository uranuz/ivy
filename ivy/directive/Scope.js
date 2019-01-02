define('ivy/directive/Scope', [
	'ivy/DirectiveInterpreter',
	'ivy/utils',
	'ivy/Consts'
], function(DirectiveInterpreter, iu, Consts) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
	return __mixinProto(__extends(function ScopeDirInterpreter() {
		this._name = 'scope';
		this._attrBlocks = [{
			'kind': DirAttrKind.ExprAttr,
			'exprAttrs': [{ 'name': 'value', 'typeName': 'any' }]
		}, {
			'kind': DirAttrKind.BodyAttr,
			'bodyAttr': {'isNoscope': true}
		}]
	}, DirectiveInterpreter), {
		interpret: function(interp) {
			var frame = interp.independentFrame();
			if( !frame ) {
				interp.rtError('Current frame is null!');
			}
			interp._stack.push(frame._dataDict);
		}
	});
});