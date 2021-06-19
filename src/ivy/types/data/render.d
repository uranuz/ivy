module ivy.types.data.render;

/// Варианты типов отрисовки узла данных в буфер:
enum DataRenderType
{
	/// Text - для вывода пользователю в виде текста (не включает отображение значений внутренних типов данных)
	Text,
	/// TextDebug - для вывода данных в виде текста в отладочном режиме (выводятся некоторые данные для узлов внутренних типов)
	TextDebug,
	HTML,
	/// JSON - вывод узлов, которые соответствуют типам в JSON в формате собственно JSON (остальные типы узлов выводим как null)
	JSON,
	/// JSONFull - выводим всё максимально в JSON, сериализуя узлы внутренних типов в JSON
	JSONFull,
	HTMLDebug
}
/// Думаю, нужен ещё флаг isPrettyPrint

private void _writeStr(DataRenderType renderType, OutRange)(ref OutRange sink, string src)
{
	static if( renderType == DataRenderType.Text ) {
		sink.put(src); // There is no escaping for plain text render
	} else {
		import std.algorithm: canFind;

		enum bool isQuoted = ![DataRenderType.Text, DataRenderType.HTML].canFind(renderType);
		enum bool isHTML = [DataRenderType.HTML, DataRenderType.HTMLDebug].canFind(renderType);
		static if( isHTML ) {
			import trifle.escaped_string_writer: writeHTMLStr;
			writeHTMLStr(sink, src, isQuoted);
		} else {
			import trifle.escaped_string_writer: writeQuotedStr;
			writeQuotedStr(sink, src, isQuoted);
		}
	}
}

import std.traits: isInstanceOf;
import ivy.types.data: TIvyData, NodeEscapeState;
private void _writeStrNode(DataRenderType renderType, OutRange, IvyData)(ref OutRange sink, IvyData strNode)
	if( isInstanceOf!(TIvyData, IvyData) )
{
	import ivy.types.data: IvyDataType;

	assert(strNode.type == IvyDataType.String);
	if( strNode.escapeState == NodeEscapeState.Safe && renderType == DataRenderType.HTML ) {
		_writeStr!(DataRenderType.Text)(sink, strNode.str);
	} else {
		_writeStr!renderType(sink, strNode.str);
	}
	static if( renderType == DataRenderType.TextDebug ) {
		import std.conv: text;
		sink.put(` [[` ~ strNode.escapeState.text ~ `]]`);
	}
}

void renderDataNode(DataRenderType renderType, IvyData, OutRange, Interp...)(
	ref OutRange sink,
	auto ref IvyData node,
	Interp interp
) {
	import ivy.types.data: IvyDataType;
	import ivy.types.data.iface.class_node: IClassNode;
	import ivy.types.callable_object: CallableObject;

	import std.range: put;
	import std.conv: to;
	import std.algorithm: canFind, each;
	import object: byKeyValue;

	final switch(node.type)
	{
		case IvyDataType.Undef:
			static if( [DataRenderType.Text, DataRenderType.HTML].canFind(renderType) ) {
				sink.put("");
			} else static if( [DataRenderType.JSON, DataRenderType.JSONFull].canFind(renderType) ) {
				sink.put("\"undef\""); // Serialize undef as string in JSON
			} else {
				sink.put("undef");
			}
			break;
		case IvyDataType.Null:
			static if( [DataRenderType.Text, DataRenderType.HTML].canFind(renderType) ) {
				sink.put("");
			} else {
				sink.put("null");
			}
			break;
		case IvyDataType.Boolean:
			sink.put(node.boolean? "true" : "false");
			break;
		case IvyDataType.Integer:
			sink.put(node.integer.to!string);
			break;
		case IvyDataType.Floating:
			sink.put(node.floating.to!string);
			break;
		case IvyDataType.String:
			_writeStrNode!renderType(sink, node);
			break;
		case IvyDataType.Array: {
			enum bool asArray = ![DataRenderType.Text, DataRenderType.HTML].canFind(renderType);
			static if( asArray ) sink.put("[");
			node.array.each!((i, el) {
				static if( asArray ) if( i != 0 ) {
					sink.put(", ");
				}

				renderDataNode!renderType(sink, el, interp);
			});
			static if( asArray ) sink.put("]");
			break;
		}
		case IvyDataType.AssocArray: {
			sink.put("{");
			node
			.assocArray
			.byKeyValue
			.each!((i, pair) {
				if( i != 0 ) {
					sink.put(", ");
				}

				_writeStr!renderType(sink, pair.key);
				sink.put(": ");

				renderDataNode!renderType(sink, pair.value, interp);
			})();
			sink.put("}");
			break;
		}
		case IvyDataType.ClassNode:
		{
			static if( interp.length > 0 ) {
				_renderClassNode!renderType(sink, node.classNode, interp[0]);
			} else {
				_writeStr!renderType(sink, "[[class node]]");
			}
			break;
		}
		case IvyDataType.CodeObject:
			_writeStr!renderType(sink, "[[code object: " ~ node.codeObject.symbol.name ~ "]]");
			break;
		case IvyDataType.Callable:
			_writeStr!renderType(sink, "[[callable object: " ~ node.callable.symbol.name ~ "]]");
			break;
		case IvyDataType.ExecutionFrame:
			_writeStr!renderType(sink, "[[execution frame]]");
			break;
		case IvyDataType.DataNodeRange:
			_writeStr!renderType(sink, "[[data node range]]");
			break;
		case IvyDataType.AsyncResult:
			_writeStr!renderType(sink, "[[async result]]");
			break;
		case IvyDataType.ModuleObject:
			_writeStr!renderType(sink, "[[module object]]");
			break;
	}
}

void _renderClassNode(DataRenderType renderType, ClsNode, OutRange, Interp)(
	ref OutRange sink,
	ClsNode classNode,
	Interp interp
) {
	import std.algorithm: canFind;

	enum bool useRender = [
		DataRenderType.Text,
		DataRenderType.TextDebug,
		DataRenderType.HTML,
		DataRenderType.HTMLDebug,
	].canFind(renderType);

	static if( useRender ) {
		import std.traits: isInstanceOf, TemplateOf;
		static if( isInstanceOf!(FirControlRender, OutRange) ) {
			auto firRender = FirControlRender!(OutRange.OutRange, typeof(interp))(*sink._outRange, classNode, interp);
		} else {
			auto firRender = FirControlRender!(OutRange, typeof(interp))(sink, classNode, interp);
		}
		renderDataNode!renderType(firRender, interp.execClassMethodSync(classNode, "render"), interp);
	} else {
		renderDataNode!renderType(sink, interp.execClassMethodSync(classNode, "__serialize__"), interp);
	}
}


string renderDataNode2(DataRenderType renderType, IvyData, Interp...)(
	auto ref IvyData val,
	Interp interp
) {
	import std.array: appender;

	auto sink = appender!string();
	renderDataNode!renderType(sink, val, interp);
	return sink.data;
}

struct FirControlRender(O, Interp)
{
	import std.range: empty;
	import trifle.parse_utils: front, popFront;

	import ivy.types.data.iface.class_node: IClassNode;

	alias OutRange = O;

	OutRange* _outRange;
	IClassNode _classNode;
	Interp _interp;

	ParseState _state;
	bool _isQuotedAttr = false;

	enum ParseState: ubyte {
		init,
		tagOpened,
		tagClosed
	}


	this(ref OutRange outRange, IClassNode classNode, Interp interp)
	{
		this._outRange = &outRange;
		this._classNode = classNode;
		this._interp = interp;
	}

	void put(string val)
	{
		if (this._state == ParseState.tagClosed) {
			// If tag is closed then just put rest data to out range
			(*this._outRange).put(val);
			return;
		}
		
		while( !val.empty )
		{
			this.put(val.front);
			// Move to the next character
			val.popFront();
		}
	}

	void put(char ch)
	{
		import std.conv: to;

		this._handleChar(ch);
		// Put character into output
		(*this._outRange).put(ch.to!string);
	}


	void _handleChar(char ch)
	{
		if( ch == '"' )
		{
			// Handle quotes around tag attributes and toggle "quoted" mode
			this._isQuotedAttr = !this._isQuotedAttr;
			return;
		}
		if( this._isQuotedAttr ) {
			// If we are in quoted mode then don't analyze tag open/ close...
			return;
		}
		if( ch == '<' && this._state == ParseState.init ) {
			// If we are in init state then detect that first tag was opened...
			this._state = ParseState.tagOpened;
			return;
		}
		if( ch == '>' && this._state == ParseState.tagOpened )
		{
			// If first tag was opened then detect that it was closed
			this._state = ParseState.tagClosed;
			// Inject extra data before closing tag
			this._injectExtras();
		}
	}

	void _injectExtras()
	{
		import ivy.types.data: IvyData;

		import std.base64: Base64;

		string moduleName = this._classNode.__getAttr__("moduleName").str;
		string encodedOpts = cast(string) Base64.encode(
			cast(ubyte[]) renderDataNode2!(DataRenderType.JSON)(IvyData(this._classNode), this._interp));

		(*this._outRange).put(" data-fir-module=\"");
		(*this._outRange).put(moduleName);
		(*this._outRange).put("\" data-fir-opts=\"");
		(*this._outRange).put(encodedOpts);
		(*this._outRange).put("\"");
	}
}
