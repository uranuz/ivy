module ivy.types.data.range.assoc_array;

import ivy.types.data.iface.range: IvyDataRange;

class AssocArrayRange: IvyDataRange
{
	import ivy.types.data: IvyData;
private:
	IvyData[string] _assocArray;
	string[] _keys;

public:
	this( IvyData[string] assocArr )
	{
		_assocArray = assocArr;
		_keys = _assocArray.keys;
	}

	override {
		bool empty() @property
		{
			import std.range: empty;
			return _keys.empty;
		}

		IvyData front()
		{
			import std.range: front;
			return IvyData(_keys.front);
		}

		void popFront()
		{
			import std.range: popFront;
			_keys.popFront();
		}
	}
}