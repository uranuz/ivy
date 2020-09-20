define('ivy/types/data/utils', [
	'exports',
	'ivy/types/data/consts',
	'ivy/types/data/data'
], function(
	exports,
	Consts,
	idat
) {
var
IvyDataType = Consts.IvyDataType,
iutil = {
	back: function(arr) {
		if( arr.length === 0 ) {
			throw new Error('Cannot get back item, because array is empty!');
		}
		return arr[arr.length-1];
	},
	reversed: function(arr)
	{
		if( !(arr instanceof Array) ) {
			throw new Error('Expected array');
		}
		var i = arr.length;
		return {
			next: function() {
				return i > 0? {
					done: false,
					value: arr[i-1]
				}: {
					done: true
				}
			}
		}
	},
	deeperCopy: function(val) {
		switch( idat.type(val) ) {
			case IvyDataType.Undef:
			case IvyDataType.Null:
			case IvyDataType.Boolean:
			case IvyDataType.Integer:
			case IvyDataType.Floating:
			case IvyDataType.String:
				// All of these are value types so just return plain copy
				return val;
			case IvyDataType.DateTime:
				// Copy date object
				return new Date(val.getTime());
			case IvyDataType.AssocArray: {
				var newObj = {};
				for( var key in val ) {
					if( val.hasOwnProperty(key) ) {
						newObj[key] = this.deeperCopy(val[key]);
					}
				}
				return newObj;
			}
			case IvyDataType.Array: {
				var newArr = [];
				newArr.length = val.length; // Preallocate
				for( var i = 0; i < val.length; ++i ) {
					newArr[i] = this.deeperCopy(val[i]);
				}
				return newArr;
			}
			case IvyDataType.CodeObject:
			case IvyDataType.Callable:
				// CodeObject's and Callable's are constants so don't do copy
				return val;
			default:
				throw new Error('Getting of deeper copy for this type is not implemented for now');
		}
	},
	
};
// For now use CommonJS format to resolve cycle dependencies
for( var key in iutil ) {
	if( iutil.hasOwnProperty(key) ) {
		exports[key] = iutil[key];
	}
}
});