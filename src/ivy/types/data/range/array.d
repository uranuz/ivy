module ivy.types.data.range.array;

import ivy.types.data.iface.range: IvyDataRange;

class ArrayRange: IvyDataRange
{
	import ivy.types.data: IvyData;
private:
	IvyData[] _array;

public:
	this( IvyData[] arr )
	{
		_array = arr;
	}

	override {
		bool empty() @property
		{
			import std.range: empty;
			return _array.empty;
		}

		IvyData front()
		{
			import std.range: front;
			return _array.front;
		}

		void popFront()
		{
			import std.range: popFront;
			_array.popFront();
		}
	}
}