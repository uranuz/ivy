import {InterpreterException} from 'ivy/interpreter/exception';
import { IvyData } from 'ivy/types/data/data';
import {ensure} from 'ivy/utils';

var assure = ensure.bind(null, InterpreterException);
export class ExecStack {
	private _stack: IvyData[];
	private _blocks: number[];

	constructor() {
		this._stack = [];
		this._blocks = [];
	}

	/** Add item in the back of stack */
	push(val: IvyData) {
		assure(this._blocks.length, "Cannot push execution stack value without any stask block");
		this._stack.push(val);
	}

	/** Returns last item added into stack */
	get back(): IvyData {
		assure(!this.empty, "Cannot get exec stack \"back\" property, because it is empty!");
		return this._stack[this._stack.length - 1];
	}

	/** Drop last item from stack */
	pop(): IvyData {
		assure(!this.empty, "Cannot remove item from execution stack, because it is empty!");

		return this._stack.pop();
	}

	/** Drop last `count` items from stack */
	popN(count: number): IvyData {
		assure(count <= this.length, "Cannot remove items from execution stack, because there is not enough of them!");
		return this._stack.splice(-count, count);
	}

	/** Check if stack is empty */
	get empty(): boolean {
		return !this.length;
	}

	/** Get length of current block of stack */
	get length(): number {
		return this._stack.length - this._backBlock;
	}

	setAt(val: IvyData, index: number) {
		assure(index < this.length, "Cannot assign item by index that not exists!");
		this._stack[index + this._backBlock] = val;
	}

	at(index: number) {
		assure(index < this.length, "Cannot get item by index that not exists!");
		return this._stack[index + this._backBlock];
	}

	/** Creates new block in stack */
	addBlock(): void {
		this._blocks.push(this._stack.length);
	}

	/** Removes last block from stack */
	removeBlock(): void {
		assure(this._blocks.length, "Cannot remove stack block. Execution stack is empty!");
		this.popN(this.length);
		this._blocks.pop();
	}

	get _backBlock(): number {
		return this._blocks.length? this._blocks[this._blocks.length - 1]: 0;
	}
}