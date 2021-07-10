define('ivy/types/data/render', [
	'exports',
	'ivy/types/data/consts',
	'ivy/types/data/control_render',
	'ivy/types/data/data'
], function(
	exports,
	DataConsts,
	FirControlRender,
	idat
) {
var
	IvyDataType = DataConsts.IvyDataType,
	DataRenderType = {
		Text: 0,
		TextDebug: 1,
		HTML: 2,
		JSON: 3,
		JSONFull: 4,
		HTMLDebug: 5
	};

var appender = FirClass(function appender() {
		this._data = '';
	}, {
		put: function(val) {
			this._data += val;
		},

		data: firProperty(function() {
			return this._data;
		})
	});

function _writeStr(renderType, sink, src) {
	if( renderType == DataRenderType.Text ) {
		sink.put(src); // There is no escaping for plain text render
	} else {
		var
			isQuoted = ![DataRenderType.Text, DataRenderType.HTML].includes(renderType);
			isHTML = [DataRenderType.HTML, DataRenderType.HTMLDebug].includes(renderType);
		if( isHTML ) {
			writeHTMLStr(sink, src, isQuoted);
		} else {
			writeQuotedStr(sink, src, isQuoted);
		}
	}
}

function writeHTMLStr(sink, src, isQuoted) {
	sink.put(src);
}

function writeQuotedStr(sink, src, isQuoted) {
	sink.put(src);
}

function renderDataNode(renderType, sink, node, interp) {
	switch(node.type) {
		case IvyDataType.Undef:
			if( [DataRenderType.Text, DataRenderType.HTML].includes(renderType) ) {
				sink.put("");
			} else if( [DataRenderType.JSON, DataRenderType.JSONFull].includes(renderType) ) {
				sink.put("\"undef\""); // Serialize undef as string in JSON
			} else {
				sink.put("undef");
			}
			break;
		case IvyDataType.Null:
			if( [DataRenderType.Text, DataRenderType.HTML].includes(renderType) ) {
				sink.put("");
			} else {
				sink.put("null");
			}
			break;
		case IvyDataType.Boolean:
			sink.put(node? "true" : "false");
			break;
		case IvyDataType.Integer:
			sink.put(String(node));
			break;
		case IvyDataType.Floating:
			sink.put(String(node));
			break;
		case IvyDataType.String:
			_writeStr(renderType, sink, node);
			break;
		case IvyDataType.Array: {
			var asArray = ![DataRenderType.Text, DataRenderType.HTML].includes(renderType);
			if( asArray ) sink.put("[");
			node.forEach(function(el, i) {
				if( asArray && i != 0 ) {
					sink.put(", ");
				}

				renderDataNode(renderType, sink, el, interp);
			});
			if( asArray ) sink.put("]");
			break;
		}
		case IvyDataType.AssocArray: {
			sink.put("{");
			Object.entries(node).forEach(function(pair, i) {
				if( i != 0 ) {
					sink.put(", ");
				}

				_writeStr(renderType, sink, pair[0]);
				sink.put(": ");

				renderDataNode(renderType, sink, pair[1], interp);
			})();
			sink.put("}");
			break;
		}
		case IvyDataType.ClassNode: {
			if( interp != null ) {
				_renderClassNode(renderType, sink, node, interp);
			} else {
				_writeStr(renderType, sink, "[[class node]]");
			}
			break;
		}
		case IvyDataType.CodeObject:
			_writeStr(renderType, sink, "[[code object: " + node.symbol.name + "]]");
			break;
		case IvyDataType.Callable:
			_writeStr(renderType, sink, "[[callable object: " + node.symbol.name + "]]");
			break;
		case IvyDataType.ExecutionFrame:
			_writeStr(renderType, sink, "[[execution frame]]");
			break;
		case IvyDataType.DataNodeRange:
			_writeStr(renderType, sink, "[[data node range]]");
			break;
		case IvyDataType.AsyncResult:
			_writeStr(renderType, sink, "[[async result]]");
			break;
		case IvyDataType.ModuleObject:
			_writeStr(renderType, sink, "[[module object]]");
			break;
	}
}

function renderDataNode2(renderType, node, interp) {
	var sink = new appender();
	this.renderDataNode(renderType, sink, node, interp);
	return sink.data;
}

function _renderClassNode(renderType, sink, classNode, interp) {
	var
		useRender = [
			DataRenderType.Text,
			DataRenderType.TextDebug,
			DataRenderType.HTML,
			DataRenderType.HTMLDebug,
		].includes(renderType),
		firRender;

	if( useRender ) {
		if( interp instanceof FirControlRender ) {
			firRender = FirControlRender(sink._outRange, classNode, interp);
		} else {
			firRender = FirControlRender(sink, classNode, interp);
		}
		renderDataNode(renderType, firRender, interp.execClassMethodSync(classNode, "render"), interp);
	} else {
		renderDataNode(renderType, sink, interp.execClassMethodSync(classNode, "__serialize__"), interp);
	}
}

Object.assign(exports, {
	DataRenderType: DataRenderType,
	appender: appender,
	renderDataNode: renderDataNode,
	renderDataNode2: renderDataNode2
});

});