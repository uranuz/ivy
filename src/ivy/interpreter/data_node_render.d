module ivy.interpreter.data_node_render;

import ivy.interpreter.data_node: IvyDataType;

/// Варианты типов отрисовки узла данных в буфер:
/// Text - для вывода пользователю в виде текста (не включает отображение значений внутренних типов данных)
/// TextDebug - для вывода данных в виде текста в отладочном режиме (выводятся некоторые данные для узлов внутренних типов)
/// JSON - вывод узлов, которые соответствуют типам в JSON в формате собственно JSON (остальные типы узлов выводим как null)
/// JSONFull - выводим всё максимально в JSON, сериализуя узлы внутренних типов в JSON
enum DataRenderType { Text, TextDebug, HTML, JSON, JSONFull, HTMLDebug }
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
import ivy.interpreter.data_node: TIvyData, NodeEscapeState;
private void _writeStr(DataRenderType renderType, OutRange, IvyData)(ref OutRange sink, IvyData strNode)
	if( isInstanceOf!(TIvyData, IvyData) )
{
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
	import std.range: put;
	import std.conv: to;
	import std.algorithm: canFind;

	assert( maxRecursion, "Recursion is too deep!" );

	final switch(node.type) with(IvyDataType)
	{
		case Undef:
			static if( [DataRenderType.Text, DataRenderType.HTML].canFind(renderType) ) {
				sink.put("");
			} else static if( [DataRenderType.JSON, DataRenderType.JSONFull].canFind(renderType) ) {
				sink.put("\"undef\""); // Serialize undef as string in JSON
			} else {
				sink.put("undef");
			}
			break;
		case Null:
			static if( [DataRenderType.Text, DataRenderType.HTML].canFind(renderType) ) {
				sink.put("");
			} else {
				sink.put("null");
			}
			break;
		case Boolean:
			sink.put(node.boolean? "true" : "false");
			break;
		case Integer:
			sink.put(node.integer.to!string);
			break;
		case Floating:
			sink.put(node.floating.to!string);
			break;
		case String:
			_writeStr!renderType(sink, node);
			break;
		case DateTime:
			_writeStr!renderType(sink, node.dateTime.toISOExtString());
			break;
		case Array:
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
		case AssocArray:
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
		case ClassNode:
			import std.conv: text;
			if( node.classNode )
			{
				IvyData serialized = node.classNode.__serialize__();
				if( serialized.isUndef ) {
					_writeStr!renderType(sink, "[[class node]]");
				} else {
					renderDataNode!renderType(sink, serialized, maxRecursion - 1);
				}
			} else {
				_writeStr!renderType(sink, "[[class node (null)]]");
			}
			break;
		case CodeObject:
			import std.conv: text;
			_writeStr!renderType(
				sink,
				node.codeObject?
				"[[code object, size: " ~ node.codeObject._instrs.length.text ~ "]]":
				"[[code object (null)]]"
			);
			break;
		case Callable:
			_writeStr!renderType(
				sink,
				node.callable?
				"[[callable object, " ~ node.callable._kind.to!string ~ ", " ~ node.callable._name ~ "]]":
				"[[callable object (null)]]"
			);
			break;
		case ExecutionFrame:
			_writeStr!renderType(sink, "[[execution frame]]");
			break;
		case DataNodeRange:
			_writeStr!renderType(sink, "[[data node range]]");
			break;
		case AsyncResult:
			_writeStr!renderType(sink, "[[async result]]");
			break;
		case ModuleObject:
			_writeStr!renderType(sink, "[[module object]]");
			break;
	}
}