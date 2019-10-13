module ivy.interpreter.data_node_render;

import ivy.interpreter.data_node: IvyDataType;

/// Варианты типов отрисовки узла данных в буфер:
/// Text - для вывода пользователю в виде текста (не включает отображение значений внутренних типов данных)
/// TextDebug - для вывода данных в виде текста в отладочном режиме (выводятся некоторые данные для узлов внутренних типов)
/// JSON - вывод узлов, которые соответствуют типам в JSON в формате собственно JSON (остальные типы узлов выводим как null)
/// JSONFull - выводим всё максимально в JSON, сериализуя узлы внутренних типов в JSON
enum DataRenderType { Text, TextDebug, HTML, JSON, JSONFull, HTMLDebug };
/// Думаю, нужен ещё флаг isPrettyPrint

private void _writeEscapedString(DataRenderType renderType, OutRange)(auto ref OutRange outRange, string str)
{
	import std.range: put;
	import std.algorithm: canFind;
	enum bool isQuoted = ![DataRenderType.Text, DataRenderType.HTML].canFind(renderType);
	enum bool isHTML = [DataRenderType.HTML, DataRenderType.HTMLDebug].canFind(renderType);
	static if( isQuoted ) {
		outRange.put("\"");
	}
	static if( renderType == DataRenderType.Text ) {
		outRange.put(str); // There is no escaping for plain text render
	}
	else
	{
		size_t chunkStart = 0;

		foreach( size_t i, char symb; str )
		{
			static if( isHTML ) {
				static immutable escapedSymb = `&\"<>`;
			} else {
				static immutable escapedSymb = "\"\\/\b\f\n\r\t";
			}

			if( escapedSymb.canFind(symb) ) {
				outRange.put(str[chunkStart..i]);
				chunkStart = i + 1; // Set chunk start to the next symbol
			}
			
			static if( isHTML )
			{
				switch( symb )
				{
					case '&': outRange.put("&amp;"); break;
					case '\'': outRange.put("&apos;"); break;
					case '"': outRange.put("&quot;"); break;
					case '<': outRange.put("&lt;"); break;
					case '>': outRange.put("&gt;"); break;
					default:	break;
				}
			}
			else
			{
				switch( symb )
				{
					case '\"': outRange.put("\\\""); break;
					case '\\': outRange.put("\\\\"); break;
					case '/': outRange.put("\\/"); break;
					case '\b': outRange.put("\\b"); break;
					case '\f': outRange.put("\\f"); break;
					case '\n': outRange.put("\\n"); break;
					case '\r': outRange.put("\\r"); break;
					case '\t': outRange.put("\\t"); break;
					default:	break;
				}
			}
		}
		outRange.put(str[chunkStart..$]); // Put the rest data into range
	}
	static if( isQuoted ) {
		outRange.put("\"");
	}
}

import std.traits: isInstanceOf;
import ivy.interpreter.data_node: TIvyData, NodeEscapeState;
private void _writeEscapedString(DataRenderType renderType, OutRange, IvyData)(auto ref OutRange outRange, IvyData strNode)
	if( isInstanceOf!(TIvyData, IvyData) )
{
	assert(strNode.type == IvyDataType.String);
	if( strNode.escapeState == NodeEscapeState.Safe && renderType == DataRenderType.HTML ) {
		outRange._writeEscapedString!(DataRenderType.Text)(strNode.str);
	} else {
		outRange._writeEscapedString!(renderType)(strNode.str);
	}
	static if( renderType == DataRenderType.TextDebug ) {
		import std.conv: text;
		outRange.put(` [[` ~ strNode.escapeState.text ~ `]]`);
	}
}

void renderDataNode(DataRenderType renderType, IvyData, OutRange)(
	auto ref IvyData node, auto ref OutRange outRange, size_t maxRecursion = size_t.max)
{
	import std.range: put;
	import std.conv: to;
	import std.algorithm: canFind;

	assert( maxRecursion, "Recursion is too deep!" );

	final switch(node.type) with(IvyDataType)
	{
		case Undef:
			static if( [DataRenderType.Text, DataRenderType.HTML].canFind(renderType) ) {
				outRange.put("");
			} else static if( [DataRenderType.JSON, DataRenderType.JSONFull].canFind(renderType) ) {
				outRange.put("\"undef\""); // Serialize undef as string in JSON
			} else {
				outRange.put("undef");
			}
			break;
		case Null:
			static if( [DataRenderType.Text, DataRenderType.HTML].canFind(renderType) ) {
				outRange.put("");
			} else {
				outRange.put("null");
			}
			break;
		case Boolean:
			outRange.put(node.boolean ? "true" : "false");
			break;
		case Integer:
			outRange.put(node.integer.to!string);
			break;
		case Floating:
			outRange.put(node.floating.to!string);
			break;
		case String:
			outRange._writeEscapedString!renderType(node);
			break;
		case DateTime:
			outRange._writeEscapedString!renderType(node.dateTime.toISOExtString());
			break;
		case Array:
			enum bool asArray = ![DataRenderType.Text, DataRenderType.HTML].canFind(renderType);
			static if( asArray ) outRange.put("[");
			foreach( i, ref el; node.array )
			{
				static if( asArray )	if( i != 0 ) {
					outRange.put(", ");
				}

				renderDataNode!(renderType)(el, outRange, maxRecursion - 1);
			}
			static if( asArray ) outRange.put("]");
			break;
		case AssocArray:
			outRange.put("{");
			size_t i = 0;
			foreach( ref key, ref val; node.assocArray )
			{
				if( i != 0 )
					outRange.put(", ");

				outRange._writeEscapedString!renderType(key);
				outRange.put(": ");

				renderDataNode!(renderType)(val, outRange, maxRecursion - 1);
				++i;
			}
			outRange.put("}");
			break;
		case ClassNode:
			import std.conv: text;
			if( node.classNode )
			{
				IvyData serialized = node.classNode.__serialize__();
				if( serialized.isUndef ) {
					outRange._writeEscapedString!renderType("[[class node]]");
				} else {
					renderDataNode!(renderType)(serialized, outRange, maxRecursion - 1);
				}
			} else {
				outRange._writeEscapedString!renderType("[[class node (null)]]");
			}
			break;
		case CodeObject:
			import std.conv: text;
			outRange._writeEscapedString!renderType(
				node.codeObject?
				"[[code object, size: " ~ node.codeObject._instrs.length.text ~ "]]":
				"[[code object (null)]]"
			);
			break;
		case Callable:
			outRange._writeEscapedString!renderType(
				node.callable?
				"[[callable object, " ~ node.callable._kind.to!string ~ ", " ~ node.callable._name ~ "]]":
				"[[callable object (null)]]"
			);
			break;
		case ExecutionFrame:
			outRange._writeEscapedString!renderType("[[execution frame]]");
			break;
		case DataNodeRange:
			outRange._writeEscapedString!renderType("[[data node range]]");
			break;
		case AsyncResult:
			outRange._writeEscapedString!renderType("[[async result]]");
			break;
		case ModuleObject:
			outRange._writeEscapedString!renderType("[[module object]]");
			break;
	}
}