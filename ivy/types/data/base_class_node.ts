import {IClassNode} from 'ivy/types/data/iface/class_node';
import {NotImplException} from 'ivy/types/data/exception';
import {IvyDataRange} from 'ivy/types/data/iface/range';
import {IvyData} from 'ivy/types/data/data';
import {CallableObject} from 'ivy/types/callable_object';

export class BaseClassNode implements IClassNode {
	__range__(): IvyDataRange {
		throw new NotImplException('Not implemented');
	}

	__slice__(start: number, end: number): IClassNode {
		throw new NotImplException('Not implemented');
	}

	__getAt__(index: IvyData): IvyData {
		throw new NotImplException('Not implemented');
	}

	__getAttr__(name: string): IvyData {
		throw new NotImplException('Not implemented');
	}

	__setAttr__(value: IvyData, name: string): void {
		throw new NotImplException('Not implemented');
	}

	__call__(): CallableObject {
		throw new NotImplException('Not implemented');
	}

	get length(): number {
		throw new NotImplException('Not implemented');
	}

	get empty(): boolean {
		// By default implement empty with check for length
		try {
			return this.length == 0;
		} catch(exc) {
			if( !(exc instanceof NotImplException) ) {
				throw exc;
			}
		}
		// If there is no logic of emptyness implemented then consider it's not empty
		return false;
	}
}