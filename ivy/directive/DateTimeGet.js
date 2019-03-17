define('ivy/directive/DateTimeGet', [
	'ivy/DirectiveInterpreter',
	'ivy/utils',
	'ivy/Consts'
], function(DirectiveInterpreter, iu, Consts) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
return FirClass(
	function DateTimeGetDirInterpreter() {
		this._name = 'dtGet';
		this._attrBlocks = [{
			'kind': DirAttrKind.ExprAttr,
			'exprAttrs': [
				{ 'name': 'value', 'typeName': 'any' },
				{ 'name': 'field', 'typeName': 'any' }
			]
		}, {
			'kind': DirAttrKind.BodyAttr,
			'bodyAttr': {}
		}]
	}, DirectiveInterpreter, {
		interpret: function(interp) {
			var
				dt = interp.getValue("value"), dtType = iu.getDataNodeType(dt),
				field = interp.getValue("field");
			
			if( [IvyDataType.Undef, IvyDataType.Null].indexOf(dtType) >= 0 ) {
				// Will not fail if it is null or undef, but just return it!
				interp._stack.push(value);
				return;
			}

			if( dtType !== IvyDataType.DateTime ) {
				interp.rtError('Expected DateTime as first argument in dtGet');
			}
			if( iu.getDataNodeType(field) !== IvyDataType.String ) {
				interp.rtError('Expected String as second argument in dtGet');
			}
			switch( field ) {
				case "year": interp._stack.push(dt.getFullYear()); break;
				case "month": interp._stack.push(dt.getMonth() + 1); break; // In JS month starts from 0
				case "day": interp._stack.push(dt.getDate()); break;
				case "hour": interp._stack.push(dt.getHours()); break;
				case "minute": interp._stack.push(dt.getMinutes()); break;
				case "second": interp._stack.push(dt.getSeconds()); break;
				case "millisecond": interp._stack.push(dt.getMilliseconds()); break;
				case "dayOfWeek": interp._stack.push(dt.getDay()); break;
				case "dayOfYear": this.rtError('Unimplemented yet, sorry'); break;
				case "utcMinuteOffset" : interp._stack.push(dt.getTimezoneOffset()); break;
				default:
					interp.rtError('Unexpected date field specifier');
			}
		}
	});
});