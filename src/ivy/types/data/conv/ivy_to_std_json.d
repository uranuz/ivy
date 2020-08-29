module ivy.types.data.conv.ivy_to_std_json;

import std.json: JSONValue;
import ivy.types.data: IvyData, IvyDataType;

JSONValue toStdJSON(ref IvyData src)
{
	final switch( src.type )
	{
		case IvyDataType.Undef: case IvyDataType.Null:
			return JSONValue(null);
		case IvyDataType.Boolean:
			return JSONValue(src.boolean);
		case IvyDataType.Integer:
			return JSONValue(src.integer);
		case IvyDataType.Floating:
			return JSONValue(src.floating);
		case IvyDataType.String:
			return JSONValue(src.str);
		case IvyDataType.Array:
		{
			JSONValue[] nodeArray;
			nodeArray.length = src.array.length;
			foreach( size_t i, val; src.array ) {
				nodeArray[i] = val.toStdJSON;
			}
			return JSONValue(nodeArray);
		}
		case IvyDataType.AssocArray:
		{
			JSONValue[string] nodeAA;
			foreach( string key, val; src.assocArray ) {
				if( val.type != IvyDataType.Undef ) {
					nodeAA[key] = val.toStdJSON;
				}
			}
			return JSONValue(nodeAA);
		}
	}
	assert(false, `This should never happen`);
}

enum IVY_TYPE_FIELD = "_t";
enum IVY_VALUE_FIELD = "_v";

JSONValue toStdJSON2(IvyData con)
{
	final switch( con.type )
	{
		case IvyDataType.Undef: return JSONValue("undef");
		case IvyDataType.Null: return JSONValue();
		case IvyDataType.Boolean: return JSONValue(con.boolean);
		case IvyDataType.Integer: return JSONValue(con.integer);
		case IvyDataType.Floating: return JSONValue(con.floating);
		case IvyDataType.String: return JSONValue(con.str);
		case IvyDataType.Array: {
			JSONValue[] arr;
			foreach( IvyData node; con.array ) {
				arr ~= toStdJSON(node);
			}
			return JSONValue(arr);
		}
		case IvyDataType.AssocArray: {
			JSONValue[string] arr;
			foreach( string key, IvyData node; con.assocArray ) {
				arr[key] ~= toStdJSON(node);
			}
			return JSONValue(arr);
		}
		case IvyDataType.CodeObject: {
			JSONValue jCode = [
				IVY_TYPE_FIELD: JSONValue(con.type),
				"name": JSONValue(con.codeObject.symbol.name),
				"moduleObject": JSONValue(con.codeObject.moduleObject.symbol.name),
			];
			JSONValue[] jInstrs;
			foreach( instr; con.codeObject._instrs ) {
				jInstrs ~= JSONValue([ JSONValue(instr.opcode), JSONValue(instr.arg) ]);
			}
			jCode["instrs"] = jInstrs;
			JSONValue[] jAttrBlocks;
			import ivy.directive_stuff: DirAttrKind;
			foreach( ref attrBlock; con.codeObject._attrBlocks )
			{
				JSONValue jBlock = ["kind": attrBlock.kind];
				final switch( attrBlock.kind )
				{
					case DirAttrKind.NamedAttr:
					{
						JSONValue[string] block;
						foreach( key, va; attrBlock.namedAttrs ) {
							block[key] = _valueAttrToStdJSON(va);
						}
						jBlock["namedAttrs"] = block;
						break;
					}
					case DirAttrKind.ExprAttr:
					{
						JSONValue[] block;
						foreach( va; attrBlock.exprAttrs ) {
							block ~= _valueAttrToStdJSON(va);
						}
						jBlock["exprAttrs"] = block;
						break;
					}
					case DirAttrKind.BodyAttr:
					{
						jBlock["bodyAttr"] = [
							"isNoscope": attrBlock.bodyAttr.isNoscope,
							"isNoescape": attrBlock.bodyAttr.isNoescape
						];
						break;
					}
				}
				jAttrBlocks ~= jBlock;
			}
			jCode["attrBlocks"] = jAttrBlocks;
			return jCode;
		}
		case IvyDataType.Callable:
		case IvyDataType.ClassNode:
		case IvyDataType.ExecutionFrame:
		case IvyDataType.DataNodeRange:
		case IvyDataType.AsyncResult:
		case IvyDataType.ModuleObject: {
			return JSONValue([IVY_TYPE_FIELD: con.type]);
		}
	}
	assert(false);
}

JSONValue _valueAttrToStdJSON(VA)(auto ref VA va) {
	return JSONValue([
		"name": va.name,
		"typeName": va.typeName
	]);
}