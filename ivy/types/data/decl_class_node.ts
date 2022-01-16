import {BaseClassNode} from 'ivy/types/data/base_class_node';
import {CallableObject} from 'ivy/types/callable_object';
import { DeclClass } from 'ivy/types/data/decl_class';
import { IvyData, IvyDataDict } from 'ivy/types/data/data';

export class DeclClassNode extends BaseClassNode {
	private _type: DeclClass;
	private _dataDict: IvyDataDict;

	constructor(type: DeclClass) {
		super();
		this._type = type;
		this._dataDict = {};

		// Bind all class callables to class instance
		for( let it of this._type._getMethods() ) {
			this._dataDict[it.name] = new CallableObject(it.callable, this);
		}
	}

	__getAttr__(field: string): IvyData {
		if( this._dataDict.hasOwnProperty(field) ) {
			return this._dataDict[field];
		}
		// Find field in a class if there is no such field in the class instance
		return this._type.__getAttr__(field);
	}

	__setAttr__(val: IvyData, field: string): void {
		this._dataDict[field] = val;
	}
}
