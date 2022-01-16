import {IvyData} from 'ivy/types/data/data';

export abstract class IvyDataRange {
	// Method is used to check if range is empty
	abstract get empty(): boolean;

	// Method must return first item of range or raise error if range is empty
	abstract front(): IvyData;

	// Method must advance range to the next item
	abstract pop(): IvyData;
}