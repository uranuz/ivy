module ivy.types.data.conv.std_to_ivy_json;

import std.json: JSONType, JSONValue;
import ivy.types.data: IvyData;

IvyData toIvyJSON(ref JSONValue src)
{
	final switch( src.type )
	{
		case JSONType.null_:
			return IvyData(null);
		case JSONType.true_:
			return IvyData(true);
		case JSONType.false_:
			return IvyData(false);
		case JSONType.integer:
			return IvyData(cast(ptrdiff_t) src.integer);
		case JSONType.uinteger:
			return IvyData(cast(ptrdiff_t) src.uinteger);
		case JSONType.float_:
			return IvyData(src.floating);
		case JSONType.string:
			return IvyData(src.str);
		case JSONType.array:
		{
			IvyData[] nodeArray;
			nodeArray.length = src.array.length;
			foreach( size_t i, val; src.array ) {
				nodeArray[i] = val.toIvyJSON;
			}
			return IvyData(nodeArray);
		}
		case JSONType.object:
		{
			IvyData[string] nodeAA;
			foreach( string key, val; src.object ) {
				nodeAA[key] = val.toIvyJSON;
			}
			return IvyData(nodeAA);
		}
	}
	assert(false, `This should never happen`);
}