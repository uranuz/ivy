import {IvyData} from 'ivy/types/data/data';
import {IvyDataRange} from 'ivy/types/data/iface/range';
import {CallableObject} from 'ivy/types/callable_object';

export abstract class IClassNode {
	/** Analogue to IvyDataRange opSlice(); in D impl */
	abstract __range__(): IvyDataRange;

	/** Analogue to IClassNode opSlice(size_t, size_t); in D impl */
	abstract __slice__(start: number, end: number): IClassNode;

	/** Analogue to IvyData opIndex(IvyData); in D impl */
	abstract __getAt__(index: IvyData): IvyData;

	/** Analogue to IvyData __getAttr__(string); in D impl */
	abstract __getAttr__(name: string): IvyData;

	/** Analogue to void __setAttr__(IvyData, string); in D impl */
	abstract __setAttr__(value: IvyData, name: string): void;

	/** Analogue to CallableObject __call__(); in D impl */
	abstract __call__(): CallableObject;

	/** Analogue to size_t length() @property; in D impl */
	abstract get length(): number;

	/** Analogue to size_t empty() @property; in D impl */
	abstract get empty(): boolean;
}