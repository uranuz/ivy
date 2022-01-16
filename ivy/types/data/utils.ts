import {IvyDataType} from 'ivy/types/data/consts';

import {idat, IvyData} from 'ivy/types/data/data';

export function deeperCopy(val: IvyData): IvyData {
	switch( idat.type(val) ) {
		case IvyDataType.Undef:
		case IvyDataType.Null:
		case IvyDataType.Boolean:
		case IvyDataType.Integer:
		case IvyDataType.Floating:
		case IvyDataType.String:
			// All of these are value types so just return plain copy
			return val;
		case IvyDataType.AssocArray: {
			let newObj: any = {};
			for( let key in val ) {
				if( val.hasOwnProperty(key) ) {
					newObj[key] = deeperCopy(val[key]);
				}
			}
			return newObj;
		}
		case IvyDataType.Array: {
			let newArr: IvyData[] = [];
			newArr.length = val.length; // Preallocate
			for( var i = 0; i < val.length; ++i ) {
				newArr[i] = deeperCopy(val[i]);
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
}