define('ivy/directive/Range', [
	'ivy/DirectiveInterpreter',
	'ivy/utils',
	'ivy/Consts',
	'ivy/IntegerRange'
], function(DirectiveInterpreter, iu, Consts, IntegerRange) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
return FirClass(
	function RangeDirInterpreter() {
		this._name = 'range';
		this._attrBlocks = [{
			'kind': DirAttrKind.ExprAttr,
			'exprAttrs': [
				{ 'name': 'begin', 'typeName': 'any' },
				{ 'name': 'end', 'typeName': 'any' }
			]
		}, {
			'kind': DirAttrKind.BodyAttr,
			'bodyAttr': {}
		}]
	}, DirectiveInterpreter, {
		interpret: function(interp) {
			var
				begin = interp.getValue("begin"),
				end = interp.getValue("end");

			if( iu.getDataNodeType(begin) !=  IvyDataType.Integer ) {
				interp.rtError('Expected Integer as "begin" argument');
			}
			if( iu.getDataNodeType(end) !=  IvyDataType.Integer ) {
				interp.rtError('Expected Integer as "end" argument');
			}

			interp._stack.push(new IntegerRange(begin, end));
		}
	});
});