define('ivy/directives', [
	'ivy/errors',
	'ivy/DirectiveInterpreter',
	'ivy/utils',
	'ivy/Consts',
	'fir/common/base64'
], function(
	errors,
	DirectiveInterpreter,
	iu,
	Consts,
	base64
) {
	var
		IvyDataType = Consts.IvyDataType,
		DirAttrKind = Consts.DirAttrKind;
return {
	IntCtorDirInterpreter: __mixinProto(__extends(function IntCtorDirInterpreter() {
		this._name = 'int';
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
				case IvyDataType.Boolean: interp._stack.push(value.boolean? 1: 0); break;
				case IvyDataType.Integer: interp._stack.push(value); break;
				case IvyDataType.String: {
					var parsed = parseInt(value, 10);
					if( isNaN(parsed) || String(parsed) !== value ) {
						interp.rtError('Unable to parse value as Integer');
					}
					this._stack.push(parsed);
					break;
				}
				default:
					interp.rtError('Cannot convert value to Integer');
					break;
			}
		}
	}),

	FloatCtorDirInterpreter: __mixinProto(__extends(function FloatCtorDirInterpreter() {
		this._name = 'float';
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
				case IvyDataType.Boolean: interp._stack.push(value.boolean? 1.0: 0.0); break;
				case IvyDataType.Integer: case IvyDataType.Floating: interp._stack.push(value); break;
				case IvyDataType.String: {
					var parsed = parseFloat(value, 10);
					if( isNaN(parsed) || String(parsed) !== value ) {
						interp.rtError('Unable to parse value as Floating');
					}
					this._stack.push(parsed);
					break;
				}
				default:
					interp.rtError('Cannot convert value to Floating');
					break;
			}
		}
	}),

	StrCtorDirInterpreter: __mixinProto(__extends(function StrCtorDirInterpreter() {
		this._name = 'str';
		this._attrBlocks = [{
			'kind': DirAttrKind.ExprAttr,
			'exprAttrs': [{ 'name': 'value', 'typeName': 'any' }]
		}, {
			'kind': DirAttrKind.BodyAttr,
			'bodyAttr': {}
		}]
	}, DirectiveInterpreter), {
		interpret: function(interp) {
			this._stack.push(String(interp.getValue("value")));
		}
	}),

	HasDirInterpreter: __mixinProto(__extends(function HasDirInterpreter() {
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
	}, DirectiveInterpreter), {
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
	}),

	TypeStrDirInterpreter: __mixinProto(__extends(function TypeStrDirInterpreter() {
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
	}),

	LenDirInterpreter: __mixinProto(__extends(function LenDirInterpreter() {
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
	}),

	EmptyDirInterpreter: __mixinProto(__extends(function EmptyDirInterpreter() {
		this._name = 'empty';
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
	}),

	ToJSONBase64DirInterpreter: __mixinProto(__extends(function ToJSONBase64DirInterpreter() {
		this._name = 'toJSONBase64';
		this._attrBlocks = [{
			'kind': DirAttrKind.ExprAttr,
			'exprAttrs': [{ 'name': 'value', 'typeName': 'any' }]
		}, {
			'kind': DirAttrKind.BodyAttr,
			'bodyAttr': {}
		}]
	}, DirectiveInterpreter), {
		interpret: function(interp) {
			interp._stack.push(
				base64.encodeUTF8(
					JSON.stringify(
						interp.getValue("value"))));
		}
	}),

	ScopeDirInterpreter: __mixinProto(__extends(function ScopeDirInterpreter() {
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
	}),

	DateTimeGetDirInterpreter: __mixinProto(__extends(function DateTimeGetDirInterpreter() {
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
	}, DirectiveInterpreter), {
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
	}),

	RangeDirInterpreter: __mixinProto(__extends(function RangeDirInterpreter() {
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
	}, DirectiveInterpreter), {
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
	}),
};
});