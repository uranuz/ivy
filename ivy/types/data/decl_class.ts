import {BaseClassNode} from 'ivy/types/data/base_class_node';
import {CallableObject} from 'ivy/types/callable_object';
import {IvyDataType} from 'ivy/types/data/consts';
import {idat, IvyData, IvyDataDict} from 'ivy/types/data/data';
import {makeDir} from 'ivy/interpreter/directive/utils';

class CallableKV {
	public name: string;
	public callable: CallableObject;

	constructor(name: string, callable: CallableObject) {
		this.name = name;
		this.callable = callable;
	}
}

function __emptyInit__() {
	// Default __init__ that does nothing
}

export class DeclClass extends BaseClassNode {
	private _name: string ;
	private _dataDict: IvyDataDict;
	private _baseClass: DeclClass;

	constructor(name: string, dataDict: IvyDataDict, baseClass?: DeclClass) {
		super();
		this._name = name;
		this._dataDict = dataDict;
		this._baseClass = baseClass || null;

		var initCallable;
		try {
			initCallable = idat.callable(this.__getAttr__("__init__"));
		} catch(Exception) {
			// Maybe there is no __init__ for class, so create it...
			this.__setAttr__(new CallableObject(DeclClass.i__emptyInit__), "__init__");
			initCallable = idat.callable(this.__getAttr__("__init__"));
		}

		try {
			// Put default values from __init__ to __new__
			var newCallable = this.__call__();
			newCallable.defaults = initCallable.defaults;
			// We need to bind __new__ callable to class object to be able to make instances
			this.__setAttr__(new CallableObject(newCallable, this), "__new__");
		} catch(Exception) {
			// Seems that it is build in class that cannot be created by user
		}
	}

	__getAttr__(field: string): IvyData {
		if( !this._dataDict.hasOwnProperty(field) ) {
			throw new Error("No attribute with name: " + field + " for class: " + this.name);
		}
		return this._dataDict[field];
	}

	__setAttr__(val: IvyData, field: string): void {
		this._dataDict[field] = val;
	}

	__call__(): CallableObject {
		return idat.callable(this.__getAttr__("__new__"));
	}

	__serialize__() {
		return "<class " + this._name + ">";
	}

	get name(): string {
		return this._name;
	}

	_getThisMethods(): CallableKV[] {
		// Return all class callables
		return Object.entries(this._dataDict).filter((it) => {
			return idat.type(it[1]) === IvyDataType.Callable
		}).map((it) => {
			return new CallableKV(it[0], idat.callable(it[1]));
		});
	}

	_getBaseMethods(): CallableKV[] {
		return (this._baseClass == null)? []: this._baseClass._getMethods();
	}

	_getMethods(): CallableKV[] {
		return Array.prototype.concat(this._getBaseMethods(), this._getThisMethods());
	}

	static i__emptyInit__: any = makeDir(__emptyInit__, "__init__");
}