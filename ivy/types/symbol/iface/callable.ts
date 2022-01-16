import { DirAttr } from 'ivy/types/symbol/dir_attr';
import {IIvySymbol} from 'ivy/types/symbol/iface/symbol';

export interface ICallableSymbol extends IIvySymbol {
	get attrs(): DirAttr[];
	getAttr(attrName: string): DirAttr;
}