import {InterpreterDirectiveFactory} from 'ivy/interpreter/directive/factory';
import {IvyDataType, NodeEscapeState} from 'ivy/types/data/consts';
import {idat, IvyData} from 'ivy/types/data/data';
import {DataRenderType, renderDataNode2} from 'ivy/types/data/render';
import {IvyAttrType} from 'ivy/types/symbol/consts';
import {DirAttr} from 'ivy/types/symbol/dir_attr';
import {makeDir} from 'ivy/interpreter/directive/utils';
import {DeclClassNode} from 'ivy/types/data/decl_class_node';
import { Interpreter } from 'ivy/interpreter/interpreter';
import { IntegerRange } from 'ivy/types/data/range/integer';
import { DeclClass } from 'ivy/types/data/decl_class';

export const ivyDirFactory = new InterpreterDirectiveFactory();

export function boolCtorFn(value: IvyData): boolean {
	return idat.toBoolean(value);
}

export function intCtorFn(value: IvyData): number {
	return idat.toInteger(value);
}

export function floatCtorFn(value: IvyData): number {
	return value.toFloating();
}

export function strCtorFn(value: IvyData): string {
	return idat.toString(value);
}

export function hasFn(collection: IvyData, key: IvyData): boolean
{
	switch( idat.type(collection) )
	{
		case IvyDataType.AssocArray:
			return collection.hasOwnProperty(idat.str(key));
		case IvyDataType.Array:
			return collection.includes(key);
		default:
			Interpreter.assure(false, "Expected array or assoc array as first \"has\" directive attribute, but got: ", collection.type);
			break;
	}
}

export function typeStrFn(value: IvyData): string {
	return IvyDataType[idat.type(value)];
}

export function lenFn(value: IvyData): number {
	return idat.length(value);
}

export function emptyFn(value: IvyData): boolean {
	return idat.empty(value);
}

export function scopeFn(interp: Interpreter): IvyData {
	return interp.previousFrame.dict;
}

export function rangeFn(begin: number, end: number) {
	return new IntegerRange(begin, end);
}

export function toJSONStrFn(value: IvyData, interp: Interpreter): IvyData
{
	var res = renderDataNode2(DataRenderType.JSON, value, interp);
	//res.escapeState = NodeEscapeState.Safe;
	return res;
}

export function newAllocFn(class_: DeclClass): DeclClassNode {
	return new DeclClassNode(class_);
}

ivyDirFactory.add(makeDir(boolCtorFn, "bool", [
	new DirAttr("value", IvyAttrType.Any)
]));
ivyDirFactory.add(makeDir(intCtorFn, "int", [
	new DirAttr("value", IvyAttrType.Any)
]));
ivyDirFactory.add(makeDir(floatCtorFn, "float", [
	new DirAttr("value", IvyAttrType.Any)
]));
ivyDirFactory.add(makeDir(strCtorFn, "str", [
	new DirAttr("value", IvyAttrType.Any)
]));
ivyDirFactory.add(makeDir(hasFn, "has", [
	new DirAttr("collection", IvyAttrType.Any),
	new DirAttr("key", IvyAttrType.Any)
]));
ivyDirFactory.add(makeDir(typeStrFn, "typestr", [
	new DirAttr("value", IvyAttrType.Any)
]));
ivyDirFactory.add(makeDir(lenFn, "len", [
	new DirAttr("value", IvyAttrType.Any)
]));
ivyDirFactory.add(makeDir(emptyFn, "empty", [
	new DirAttr("value", IvyAttrType.Any)
]));
ivyDirFactory.add(makeDir(scopeFn, "scope"));
ivyDirFactory.add(makeDir(rangeFn, "range", [
	new DirAttr("begin", IvyAttrType.Any),
	new DirAttr("end", IvyAttrType.Any)
]));
ivyDirFactory.add(makeDir(toJSONStrFn, "to_json_str", [
	new DirAttr("value", IvyAttrType.Any)
]));
ivyDirFactory.add(makeDir(newAllocFn, "__new_alloc__", [
	new DirAttr("class_", IvyAttrType.Any)
]));

