module ivy.types.data.range.integer;

import ivy.types.data.iface.range: IvyDataRange;

class IntegerRange: IvyDataRange
{
	import ivy.types.data: IvyData, IvyDataType;
private:
	ptrdiff_t _current;
	ptrdiff_t _end;

public:
	this( ptrdiff_t begin, ptrdiff_t end )
	{
		assert( begin <= end, `Begin cannot be greather than end in integer range` );
		_current = begin;
		_end = end;
	}

	override {
		bool empty() @property {
			return _current >= _end;
		}

		IvyData front() {
			return IvyData(_current);
		}

		void popFront() {
			++_current;
		}
	}
}