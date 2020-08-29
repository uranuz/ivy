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
private void _writeStr(DataRenderType renderType, OutRange, IvyData)(ref OutRange sink, IvyData strNode)
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

void renderDataNode(DataRenderType renderType, IvyData, OutRange)(
	ref OutRange sink,
	auto ref IvyData node,
	size_t maxRecursion = size_t.max
) {
	import ivy.types.data: IvyDataType;

	import std.range: put;
	import std.conv: to;
	import std.algorithm: canFind;

	assert( maxRecursion, "Recursion is too deep!" );

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
			_writeStr!renderType(sink, node);
			break;
		case IvyDataType.Array:
			enum bool asArray = ![DataRenderType.Text, DataRenderType.HTML].canFind(renderType);
			static if( asArray ) sink.put("[");
			foreach( i, ref el; node.array )
			{
				static if( asArray )	if( i != 0 ) {
					sink.put(", ");
				}

				renderDataNode!renderType(sink, el, maxRecursion - 1);
			}
			static if( asArray ) sink.put("]");
			break;
		case IvyDataType.AssocArray:
			sink.put("{");
			size_t i = 0;
			foreach( ref key, ref val; node.assocArray )
			{
				if( i != 0 )
					sink.put(", ");

				_writeStr!renderType(sink, key);
				sink.put(": ");

				renderDataNode!renderType(sink, val, maxRecursion - 1);
				++i;
			}
			sink.put("}");
			break;
		case IvyDataType.ClassNode:
			renderDataNode!renderType(sink, node.classNode.__serialize__(), maxRecursion - 1);
			break;
		case IvyDataType.CodeObject:
			import std.conv: text;
			_writeStr!renderType(sink, "[[code object, size: " ~ node.codeObject._instrs.length.text ~ "]]");
			break;
		case IvyDataType.Callable:
			_writeStr!renderType(sink, "[[callable object, " ~ node.callable.symbol.name ~ "]]");
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