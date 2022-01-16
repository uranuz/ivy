import {OpCode, Instruction} from 'ivy/bytecode';

import {CallSpec} from 'ivy/types/call_spec';
import {CallableObject} from 'ivy/types/callable_object';
import {AsyncResult} from 'ivy/types/data/async_result';
import {IvyDataType} from 'ivy/types/data/consts';
import {idat, IvyData, IvyDataDict} from 'ivy/types/data/data';
import {ArrayRange} from 'ivy/types/data/range/array';
import {AssocArrayRange} from 'ivy/types/data/range/assoc_array';
import {DeclClass} from 'ivy/types/data/decl_class';
import {deeperCopy} from 'ivy/types/data/utils';
import {GLOBAL_SYMBOL_NAME, SymbolKind} from 'ivy/types/symbol/consts';

import {ensure} from 'ivy/utils';

import {ExecStack} from 'ivy/interpreter/exec_stack';
import {InterpreterException} from 'ivy/interpreter/exception';
import {ExecutionFrame} from 'ivy/interpreter/execution_frame';

import { IvyLogProxy } from 'ivy/log/proxy';
import { InterpreterDirectiveFactory } from 'ivy/interpreter/directive/factory';
import { ModuleObjectCache } from 'ivy/engine/module_object_cache';
import { CodeObject } from 'ivy/types/code_object';
import { ModuleObject } from 'ivy/types/module_object';
import { Location } from 'ivy/location';
import { ExecFrameInfo } from 'ivy/interpreter/exec_frame_info';
import { IDirectiveInterpreter } from 'ivy/interpreter/directive/iface';
import { IClassNode } from 'ivy/types/data/iface/class_node';

enum LoopAction {
	skipPKIncr, // Do not increment pk after loop body execution
	normal, // Increment pk after loop body execution
	await // Increment pk after loop body execution and await
}

var assure = ensure.bind(null, InterpreterException);

export class Interpreter {
	private _log: IvyLogProxy;

	private _moduleObjCache: ModuleObjectCache;
	private _directiveFactory: InterpreterDirectiveFactory;
	private _moduleFrames: { [k: string]: ExecutionFrame };

	private _frameStack: ExecutionFrame[];

	public _stack: ExecStack;

	static _globalCallable: CallableObject;

	constructor(
		moduleObjCache: ModuleObjectCache,
		directiveFactory: InterpreterDirectiveFactory
	) {
		this._log = new IvyLogProxy();
	
		this._moduleObjCache = moduleObjCache;
		this._directiveFactory = directiveFactory;
		this._moduleFrames = {};
	
		this._frameStack = [];
		this._stack = new ExecStack();
	
		this._moduleFrames[GLOBAL_SYMBOL_NAME] = new ExecutionFrame(Interpreter._globalCallable);
	
		// Add custom native directive interpreters to global scope
		directiveFactory.interps.forEach((dirInterp: IDirectiveInterpreter) => {
			this.globalFrame.setValue(dirInterp.symbol.name, new CallableObject(dirInterp));
		});
	}

	static assure = assure;

	execLoop(fResult: AsyncResult) {
		// Save initial execution frame count.
		var initFrameCount = this._frameStack.length;

		var res = this.execLoopImpl(initFrameCount);
		if( this._frameStack.length < initFrameCount ) {
			// If exec frame stack is less than initial then job is done
			fResult.resolve(res);
		}
		// Looks like interpreter was suspended by async operation
	}

	execLoopSync(): IvyData {
		// Save initial execution frame count.
		let initFrameCount = this._frameStack.length;

		let res = this.execLoopImpl(initFrameCount);
		assure(
			this._frameStack.length < initFrameCount,
			"Requested synchronous code execution, but detected that interpreter was suspended!");
		return res;
	}

	execLoopImpl(initFrameCount: number): IvyData {
		assure(this._frameStack.length, "Unable to run interpreter if exec frame is empty");

		let res;
		while( this._frameStack.length >= initFrameCount ) {
			while( this.currentFrame.hasInstrs ) {
				var la = this.execLoopBody();
				if( la === LoopAction.skipPKIncr )
					continue;
				this.currentFrame.nextInstr();
				if( la === LoopAction.await )
					return;
			}

			// We expect to have only the result of directive on the stack
			assure(this._stack.length === 1, "Exec stack should contain 1 item now");

			res = this._stack.pop(); // Take result
			this.removeFrame(); // Exit out of this frame

			if( this._frameStack.length )
				this._stack.push(res); // Put result back if there is a place for it
		}
		return res;
	}

	execLoopBody(): LoopAction {
		var instr = this.currentInstr;
		//console.log(this.currentFrame.callable.symbol.name + ": " + instr.toString());
		switch( instr.opcode ) {
			case OpCode.InvalidCode: {
				assure(false, "Invalid code of operation");
				break;
			}
			case OpCode.Nop: break;

			// Load constant from programme data table into stack
			case OpCode.LoadConst: {
				this._stack.push(this.getModuleConstCopy(instr.arg));
				break;
			}

			// Stack operations
			case OpCode.PopTop: {
				this._stack.pop();
				break;
			}

			// Swaps two top items on the stack
			case OpCode.SwapTwo: {
				let top = this._stack.pop();
				let beforeTop = this._stack.pop();
				this._stack.push(top);
				this._stack.push(beforeTop);
				break;
			}

			case OpCode.DubTop: {
				this._stack.push(this._stack.back);
				break;
			}

			// General unary operations opcodes
			case OpCode.UnaryPlus: {
				let aType = idat.type(this._stack.back);
				assure(
					aType === IvyDataType.Integer || aType == IvyDataType.Floating,
					"Operand for unary plus operation must have integer or floating type!" );
				// Do nothing
				break;
			}

			case OpCode.UnaryMin: {
				let arg = this._stack.pop();
				switch( idat.type(arg) ) {
					case IvyDataType.Integer:
						arg = -idat.integer(arg);
						break;
					case IvyDataType.Floating:
						arg = -idat.floating(arg);
						break;
					default:
						assure(false, "Unexpected type of operand");
						break;
				}
				this._stack.push(arg);
				break;
			}

			case OpCode.UnaryNot: {
				this._stack.push(!idat.toBoolean(this._stack.pop()));
				break;
			}

			// Arithmetic binary operations opcodes
			case OpCode.Add:
			case OpCode.Sub:
			case OpCode.Mul:
			case OpCode.Div:
			case OpCode.Mod: {
				let	right = this._stack.pop();
				let left = this._stack.pop();
				let lType = idat.type(left);
				let res;
				assure(
					lType === idat.type(right),
					"Left and right values of arithmetic operation must have the same integer or floating type!");

				switch( lType ) {
					case IvyDataType.Integer:
						res = this._doBinaryOp(instr.opcode, left, right);
						break;
					case IvyDataType.Floating:
						res = this._doBinaryOp(instr.opcode, left, right);
						break;
					default:
						assure(false, "Unexpected types of operands");
						break;
				}

				this._stack.push(res);
				break;
			}

			// Comparision operations opcodes
			case OpCode.Equal:
			case OpCode.NotEqual: {
				this._stack.push(this._doBinaryOp(instr.opcode, this._stack.pop(), this._stack.pop()));
				break;
			}
			case OpCode.LT:
			case OpCode.GT:
			case OpCode.LTEqual:
			case OpCode.GTEqual: {
				let	right = this._stack.pop();
				let left = this._stack.pop();
				let lType = idat.type(left);
				let res;
				assure(
					lType === idat.type(right),
					"Operands of less or greather comparision must have the same type");
				
				switch( lType ) {
					case IvyDataType.Undef:
					case IvyDataType.Null:
						// Undef and Null are not less or equal to something
						res = false;
						break;
					case IvyDataType.Integer:
					case IvyDataType.Floating:
					case IvyDataType.String:
						res = this._doBinaryOp(instr.opcode, left.integer, right.integer);
						break;
					default:
						assure(false, "Less or greater comparisions doesn't support type ", lType, " yet!");
				}
				this._stack.push(res);
				break;
			}

			// Frame data load/ store
			case OpCode.StoreName:
			case OpCode.StoreGlobalName: {
				let varValue = this._stack.pop();
				let varName = idat.str(this.getModuleConstCopy(instr.arg));

				switch( instr.opcode ) {
					case OpCode.StoreName: this.setValue(varName, varValue); break;
					case OpCode.StoreGlobalName: this.setGlobalValue(varName, varValue); break;
					default: assure(false, "Unexpected instruction opcode");
				}
				break;
			}
			case OpCode.LoadName: {
				let varName: string = idat.str(this.getModuleConstCopy(instr.arg));
				this._stack.push(this.getGlobalValue(varName));
				break;
			}

			// Work with attributes
			case OpCode.StoreAttr: {
				let	attrVal: IvyData = this._stack.pop();
				let attrName: string = idat.str(this._stack.pop());
				let aggr: IvyData = this._stack.pop();
				switch( idat.type(aggr) ) {
					case IvyDataType.Undef:
					case IvyDataType.Null:
					case IvyDataType.Boolean:
					case IvyDataType.Integer:
					case IvyDataType.Floating:
					case IvyDataType.String:
					case IvyDataType.Array:
					case IvyDataType.CodeObject:
					case IvyDataType.Callable:
					case IvyDataType.IvyDataRange:
					case IvyDataType.AsyncResult:
					case IvyDataType.ModuleObject:
					case IvyDataType.ExecutionFrame:
						assure(false, "Unable to set attribute of value with type: ", idat.type(aggr));
						break;
					case IvyDataType.AssocArray:
						aggr[attrName] = attrVal;
						break;
					case IvyDataType.ClassNode:
						aggr.__setAttr__(attrVal, attrName);
						break;
				}
				break;
			}

			// 
			case OpCode.LoadAttr: {
				let attrName: string = idat.str(this._stack.pop());
				let aggr: IvyData = this._stack.pop();

				switch( idat.type(aggr) ) {
					case IvyDataType.Undef:
					case IvyDataType.Null:
					case IvyDataType.Boolean:
					case IvyDataType.Integer:
					case IvyDataType.Floating:
					case IvyDataType.String:
					case IvyDataType.Array:
					case IvyDataType.CodeObject:
					case IvyDataType.Callable:
					case IvyDataType.IvyDataRange:
					case IvyDataType.AsyncResult:
					case IvyDataType.ModuleObject:
						assure(false, "Unable to get attribute of value with type: ", idat.type(aggr));
						break;
					case IvyDataType.AssocArray:
						this._stack.push(aggr[attrName]);
						break;
					case IvyDataType.ClassNode:
						this._stack.push(aggr.__getAttr__(attrName));
						break;
					case IvyDataType.ExecutionFrame:
						this._stack.push(aggr.getValue(attrName));
						break;
				}
				break;
			}

			// Data construction opcodes
			case OpCode.MakeArray: {
				let newArray: IvyData[] = [];

				newArray.length = instr.arg; // Preallocating is good ;)
				for( let i = instr.arg; i > 0; --i ) {
					// We take array items from the tail, so we must consider it!
					newArray[i-1] = this._stack.pop();
				}
				this._stack.push(newArray);
				break;
			}
			case OpCode.MakeAssocArray: {
				let newAA: IvyDataDict = {};

				for( let i = 0; i < instr.arg; ++i ) {
					let val = this._stack.pop();
					let key = idat.str(this._stack.pop());

					newAA[key] = val;
				}
				this._stack.push(newAA);
				break;
			}
			case OpCode.MakeClass: {
				let baseClass: DeclClass = (instr.arg? <DeclClass> idat.classNode(this._stack.pop()): null);
				let classDataDict: IvyDataDict = idat.assocArray(this._stack.pop());
				let className: string = idat.str(this._stack.pop());

				this._stack.push(new DeclClass(className, classDataDict, baseClass));
				break;
			}

			case OpCode.StoreSubscr: {
				let index = this._stack.pop();
				let value = this._stack.pop();
				let aggr = this._stack.pop();

				switch( idat.type(aggr) ) {
					case IvyDataType.Array: {
						assure(
							idat.integer(index) < aggr.length,
							"Index is out of bounds of array");
						aggr[idat.integer(index)] = value;
						break;
					}
					case IvyDataType.AssocArray: {
						aggr[idat.str(index)] = value;
						break;
					}
					case IvyDataType.ClassNode: {
						switch( idat.type(index) ) {
							case IvyDataType.Integer:
								aggr[idat.integer(index)] = value;
								break;
							case IvyDataType.String:
								aggr[idat.str(index)] = value;
								break;
							default:
								assure(false, "Index for class node must be string or integer!");
								break;
						}
						break;
					}
					default:
						assure(false, "Unexpected aggregate type");
				}
				break;
			}

			// Array or assoc array operations
			case OpCode.LoadSubscr: {
				let index: IvyData = this._stack.pop();
				let aggr: IvyData = this._stack.pop();

				switch( idat.type(aggr) ) {
					case IvyDataType.String:
					case IvyDataType.Array: {
						assure(
							idat.integer(index) < aggr.length,
							"Array index must be less than array length");
						this._stack.push(aggr[idat.integer(index)]);
						break;
					}
					case IvyDataType.AssocArray: {
						this._stack.push(aggr[idat.str(index)]);
						break;
					}
					case IvyDataType.ClassNode: {
						this._stack.push(aggr.at(index));
						break;
					}
					default:
						assure(false, "Unexpected type of aggregate: ", aggr.type);
				}
				break;
			}

			case OpCode.LoadSlice: {
				let end: number = idat.integer(this._stack.pop());
				let begin: number = idat.integer(this._stack.pop());
				let aggr: IvyData = this._stack.pop();

				switch( idat.type(aggr) ) {
					case IvyDataType.String:
					case IvyDataType.Array:
						this._stack.push(aggr.slice(begin, end));
						break;
					case IvyDataType.ClassNode:
						this._stack.push(aggr.__slice__(begin, end));
						break;
					default:
						assure(false, "Unexpected aggregate type");
				}
				break;
			}

			// Arrays or strings concatenation
			case OpCode.Concat: {
				let right = this._stack.pop();
				let left = this._stack.pop();
				let lType = idat.type(left);
				assure(
					lType == idat.type(right),
					"Left and right operands for concatenation operation must have the same type!");

				switch( lType ) {
					case IvyDataType.String:
						this._stack.push(left + right);
						break;
					case IvyDataType.Array:
						this._stack.push(left.concat(right));
						break;
					default:
						assure(false, "Unexpected type of operand");
				}
				break;
			}

			case OpCode.Append: {
				let value = this._stack.pop();
				idat.array(this._stack.back).push(value);
				break;
			}

			case OpCode.Insert: {
				let posNode = this._stack.pop();
				let value = this._stack.pop();
				let aggr = idat.array(this._stack.back);

				let pos;
				switch( idat.type(posNode) ) {
					case IvyDataType.Integer:
						pos = posNode;
						break;
					case IvyDataType.Undef:
					case IvyDataType.Null:
						pos = aggr.length; // Act like append
						break;
					default:
						assure(false, "Position argument expected to be an integer or empty (for append), but got: ", posNode);
				}
				assure(
					pos <= aggr.length,
					"Insert position is wrong: ", pos);
				aggr.splice(pos, 0, value);
				break;
			}

			// Flow control opcodes
			case OpCode.JumpIfTrue:
			case OpCode.JumpIfFalse:
			case OpCode.JumpIfTrueOrPop:
			case OpCode.JumpIfFalseOrPop: {
				// This is actual condition to test
				let jumpCond = (
					instr.opcode === OpCode.JumpIfTrue || instr.opcode === OpCode.JumpIfTrueOrPop
				) === idat.toBoolean(this._stack.back);

				if( 
					instr.opcode === OpCode.JumpIfTrue || instr.opcode === OpCode.JumpIfFalse || !jumpCond
				) {
					// In JumpIfTrue, JumpIfFalse we should drop condition from stack anyway
					// But for JumpIfTrueOrPop, JumpIfFalseOrPop drop it only if jumpCond is false
					this._stack.pop();
				}

				if( jumpCond ) {
					this.setJump(instr.arg);
					return LoopAction.skipPKIncr;
				}
				break;
			}

			case OpCode.Jump: {
				this.setJump(instr.arg);
				return LoopAction.skipPKIncr;
			}

			case OpCode.Return: {
				// Set instruction index at the end of code object in order to finish 
				this.setJump(this.currentFrame.callable.codeObject.instrCount);
				let result = this._stack.back;
				// Erase all from the current stack
				this._stack.popN(this._stack.length);
				this._stack.push(result); // Put result on the stack
				return LoopAction.skipPKIncr;
			}

			// Loop initialization and execution
			case OpCode.GetDataRange: {
				let aggr = this._stack.pop();
				let res;
				switch( idat.type(aggr) ) {
					case IvyDataType.Array:
						res = new ArrayRange(aggr);
						break;
					case IvyDataType.AssocArray:
						res = new AssocArrayRange(aggr);
						break;
					case IvyDataType.ClassNode:
						res = aggr.__range__();
						break;
					case IvyDataType.IvyDataRange:
						res = aggr;
						break;
					default: assure(false, 'Expected Array, AssocArray, IvyDataRange or ClassNode as iterable');
				}
				this._stack.push(res); // Push range onto stack
				break;
			}

			case OpCode.RunLoop: {
				let dataRange = idat.dataRange(this._stack.back);
				if( dataRange.empty ) {
					// Drop data range when iteration finished
					this._stack.pop();
					// Jump to instruction after loop
					this.setJump(instr.arg);
					break;
				}

				this._stack.push(dataRange.pop());
				break;
			}

			// Import another module
			case OpCode.ImportModule: {
				if( this.runImportModule(idat.str(this._stack.pop())) )
					return LoopAction.skipPKIncr;
				break;
			}

			case OpCode.FromImport: {
				let importList: IvyData[] = idat.array(this._stack.pop());
				let moduleFrame: ExecutionFrame = idat.execFrame(this._stack.pop());

				for( let nameNode of importList ) {
					let name = idat.str(nameNode);
					this.setValue(name, moduleFrame.getValue(name));
				}
				break;
			}

			case OpCode.LoadFrame: {
				this._stack.push(this.currentFrame);
				break;
			}

			// Preparing and calling directives
			case OpCode.MakeCallable: {
				let callSpec: CallSpec = new CallSpec(instr.arg);
				assure(
					callSpec.posAttrsCount === 0,
					"Positional default attribute values are not expected");

				let codeObject: CodeObject = idat.codeObject(this._stack.pop());

				// Get dict of default attr values from stack if exists
				// We shall not check for odd values here, because we believe compiler can handle it
				let defaults: IvyDataDict = callSpec.hasKwAttrs? idat.assocArray(this._stack.pop()): {};

				this._stack.push(new CallableObject(codeObject, defaults));
				break;
			}

			case OpCode.RunCallable: {
				if( this.runCallableNode(this._stack.pop(), new CallSpec(instr.arg)) )
					return LoopAction.skipPKIncr;
				break;
			}

			case OpCode.Await: {
				let aResult: AsyncResult = idat.asyncResult(this._stack.pop());
				let exitFrames: number = 0;
				aResult.then((data: IvyData) => {
					this._stack.push({
						isError: false,
						data: data
					});
					this.execLoopImpl(exitFrames);
				}, (data: Error) => {
					this._stack.push({
						isError: true,
						data: data
					});
					this.execLoopImpl(exitFrames);
				});
				return LoopAction.await;
			}

			default: assure(false, "Unexpected opcode!!!");
		} // switch

		return LoopAction.normal;
	} // execLoopBody

	get globalFrame(): ExecutionFrame {
		return this._moduleFrames[GLOBAL_SYMBOL_NAME];
	}


	// Method used to add extra global data into interpreter
	// Consider not to bloat it to much ;)
	addExtraGlobals(extraGlobals: IvyDataDict) {
		for( var name in extraGlobals ) {
			if( extraGlobals.hasOwnProperty(name) ) {
				this.globalFrame.setValue(name, extraGlobals[name]);
			}
		}
	}

	get currentFrame(): ExecutionFrame {
		assure(this._frameStack.length > 0, "Execution frame stack is empty!");
		return this._frameStack[this._frameStack.length - 1];
	}

	/** Returns nearest independent execution frame that is not marked `noscope`*/
	get previousFrame(): ExecutionFrame {
		assure(this._frameStack.length > 1, "No previous execution frame exists!");

		return this._frameStack[this._frameStack.length - 2];
	}

	get currentCallable(): CallableObject {
		return this.currentFrame.callable;
	}

	get currentCodeObject(): CodeObject {
		let callable = this.currentCallable;
		if( !callable.isNative ) {
			return callable.codeObject;
		}
		return null;
	}

	get currentModule(): ModuleObject {
		let codeObject = this.currentCodeObject
		if( codeObject ) {
			return codeObject.moduleObject;
		}
		return null;
	}

	setJump(instrIndex: number): void {
		this.currentFrame.setJump(instrIndex);
	}

	get currentInstr(): Instruction {
		if( !this._frameStack.length )
			return null;
		return this.currentFrame.currentInstr;
	}

	get currentInstrLine(): number {
		if( !this._frameStack.length )
			return 0;
		return this.currentFrame.currentInstrLine;
	}

	get currentLocation(): Location {
		if( !this._frameStack.length )
			return null;
		return this.currentFrame.currentLocation;
	}

	get frameStackInfo(): ExecFrameInfo[] {
		return this._frameStack.map(function(it) {
			return it.info;
		});
	}

	getModuleConst(index: number): IvyData {
		var moduleObj = this.currentModule;
		assure(moduleObj != null, "Unable to get module constant");
		return moduleObj.getConst(index);
	}

	getModuleConstCopy(index: number): IvyData {
		return deeperCopy(this.getModuleConst(index));
	}

	// Execute binary operation
	_doBinaryOp(opcode: OpCode, left: IvyData, right: IvyData): IvyData {
		switch( opcode ) {
			// Arithmetic
			case OpCode.Add: return left + right;
			case OpCode.Sub: return left - right;
			case OpCode.Mul: return left * right;
			case OpCode.Div: return left / right;
			case OpCode.Mod: return left % right;

			// Equality comparision
			case OpCode.Equal: return idat.opEquals(left, right);
			case OpCode.NotEqual: return !idat.opEquals(left, right);

			// General comparision
			case OpCode.GT: return left > right;
			case OpCode.LT: return left < right;
			case OpCode.GT: return left > right;
			case OpCode.LTEqual: return left <= right;
			case OpCode.GTEqual: return left >= right;
			default: assure(false, "Unexpected code of binary operation");;
		}
	}

	newFrame(callable: CallableObject, dataDict: IvyDataDict) {
		let symbolName = callable.symbol.name;

		this._frameStack.push(new ExecutionFrame(callable, dataDict));
		this._stack.addBlock();

		if( callable.symbol.kind === SymbolKind.module_ ) {
			assure(symbolName != GLOBAL_SYMBOL_NAME, "Cannot create module name with name: ", GLOBAL_SYMBOL_NAME);
			this._moduleFrames[symbolName] = this.currentFrame;
		}
	}

	removeFrame(): void {
		assure(this._frameStack.length, "Execution frame stack is empty!");
		this._stack.removeBlock();
		this._frameStack.pop();
	}

	findValueFrame(varName: string): ExecutionFrame {
		return this.findValueFrameImpl(varName, false);
	}

	findValueFrameGlobal(varName: string): ExecutionFrame {
		return this.findValueFrameImpl(varName, true);
	}

	// Returns execution frame for variable
	findValueFrameImpl(varName: string, globalSearch: boolean): ExecutionFrame {
		let currFrame = this.currentFrame;

		if( currFrame.hasValue(varName) )
			return currFrame;

		if( globalSearch ) {
			let modFrame = this._getModuleFrame(currFrame.callable);
			if( modFrame.hasValue(varName) )
				return modFrame;

			if( this.globalFrame.hasValue(varName) )
				return this.globalFrame;
		}
		// By default store vars in local frame
		return currFrame;
	}

	hasValue(varName: string): boolean {
		return this.findValueFrame(varName).hasValue(varName);
	}

	getValue(varName: string): IvyData {
		return this.findValueFrame(varName).getValue(varName);
	}

	getGlobalValue(varName: string): IvyData {
		return this.findValueFrameGlobal(varName).getValue(varName);
	}

	setValue(varName: string, value: IvyData): void {
		this.findValueFrame(varName).setValue(varName, value);
	}

	setGlobalValue(varName: string, value: IvyData): void {
		this.findValueFrameGlobal(varName).setValue(varName, value);
	}

	_getModuleFrame(callable: CallableObject): ExecutionFrame {
		let moduleName = callable.moduleSymbol.name;
		let moduleFrame = this._moduleFrames[moduleName];
		assure(
			moduleFrame != null,
			"Module frame with name: ", moduleFrame, " of callable: ", moduleName, " does not exist!");
		return moduleFrame;
	}

	_extractCallArgs(callable: CallableObject, kwAttrs: IvyDataDict, callSpec: CallSpec) {
		kwAttrs = kwAttrs || {};
		callSpec = callSpec || new CallSpec();

		let attrSymbols = callable.symbol.attrs;
		let defaults = callable.defaults;

		if( callSpec.hasKwAttrs )
			kwAttrs = idat.assocArray(this._stack.pop());

		assure(
			callSpec.posAttrsCount <= attrSymbols.length,
			"Positional parameters count is more than expected arguments count");

		let callArgs: any = {};

		// Getting positional arguments from stack (in reverse order)
		for( let idx = callSpec.posAttrsCount; idx > 0; --idx ) {
			callArgs[attrSymbols[idx - 1].name] = this._stack.pop();
		}

		// Getting named parameters from kwArgs
		for( let idx = callSpec.posAttrsCount; idx < attrSymbols.length; ++idx ) {
			let attr = attrSymbols[idx];
			if( kwAttrs.hasOwnProperty(attr.name) ) {
				callArgs[attr.name] = kwAttrs[attr.name];
			} else{
				// We should get default value if no value is passed from outside
				assure(
					defaults.hasOwnProperty(attr.name),
					"Expected value for attr: ",
					attr.name,
					", that has no default value"
				);
				callArgs[attr.name] = deeperCopy(defaults[attr.name]);
			}
		}

		// Set "context-variable" for callables that has it...
		if( kwAttrs.hasOwnProperty("this") ) {
			callArgs["this"] =  kwAttrs["this"];
		} else if( idat.type(callable.context) != IvyDataType.Undef ) {
			callArgs["this"] = callable.context;
		}

		return callArgs;
	}

	runCallableNode(callableNode: IvyData, callSpec: CallSpec) {
		// Skip instruction index increment
		return this._runCallableImpl(this.asCallable(callableNode), null, callSpec);
	}

	runCallable(callable: CallableObject, kwAttrs?: IvyDataDict) {
		return this._runCallableImpl(callable, kwAttrs); // Skip _pk increment
	}

	_runCallableImpl(callable: CallableObject, kwAttrs: IvyDataDict, callSpec?: CallSpec) {
		var callArgs = this._extractCallArgs(callable, kwAttrs, callSpec);

		if( this._frameStack.length )
			this.currentFrame.nextInstr(); // Set next instruction to execute after callable

		this.newFrame(callable, callArgs);

		if( callable.isNative ) {
			// Run native directive interpreter
			callable.dirInterp.interpret(this);
			return false;
		}
		return true; // Skip instruction index increment
	}

	runImportModule(moduleName: string) {
		var moduleObject = this._moduleObjCache.get(moduleName);
		var moduleFrame = this._moduleFrames[moduleName];

		assure(moduleObject, "No such module object: ", moduleName);
		if( moduleFrame ) {
			// Module is imported already. Just push it's frame onto stack
			this._stack.push(moduleFrame); 
			return false;
		}
		return this.runCallable(new CallableObject(moduleObject.mainCodeObject));
	}

	importModule(moduleName: string) {
		var fResult = new AsyncResult();
		try {
			if( this.runImportModule(moduleName) )
				// Need to run interpreter to import module
				this.execLoop(fResult);
			else
				// Module is imported already. Just return it
				fResult.resolve(this._stack.back);
		} catch(ex) {
			fResult.reject(ex);
		}
		return fResult;
	}

	execCallable(callable: CallableObject, kwArgs?: IvyDataDict) {
		var fResult = new AsyncResult();
		try {
			this.runCallable(callable, kwArgs);
			this.execLoop(fResult);
		} catch(ex) {
			fResult.reject(this.updateNLogError(ex));
		}
		return fResult;
	}

	execCallableSync(callable: CallableObject, kwArgs?: IvyDataDict): IvyData {
		this.runCallable(callable, kwArgs);
		return this.execLoopSync();
	}

	execClassMethodSync(classNode: IClassNode, method: string, kwArgs?: IvyDataDict) {
		return this.execCallableSync(idat.callable(classNode.__getAttr__(method)), kwArgs);
	}

	execClassMethod(classNode: IClassNode, method: string, kwArgs?: IvyDataDict) {
		return this.execCallable(idat.callable(classNode.__getAttr__(method)), kwArgs);
	}

	/// Updates exception with frame stack info of interpreter
	updateError(ex: Error) {
		return ex;
		/*
		return ex.castSwitch!(
			(IvyInterpretException interpEx) {
				interpEx.frameStackInfo = this.frameStackInfo;
				return interpEx;
			},
			(IvyException ivyEx) {
				return ivyEx; // It's good exception. Do nothing more...
			},
			(Throwable anyEx) {
				auto updEx = new IvyInterpretException(ex.msg, ex.file, ex.line, anyEx);
				updEx.frameStackInfo = this.frameStackInfo;
				return updEx;
			},
			() {
				auto updEx = new IvyInterpretException("Unhandled error");
				updEx.frameStackInfo = this.frameStackInfo;
				return updEx;
			}
		)();
		*/
	}

	/// Updates exception with frame stack info of interpreter and writes it to log
	updateNLogError(ex: Error) {
		var updEx = this.updateError(ex);
		this._log.error(updEx.message);
		return updEx;
	}

	asCallable(callableNode: IvyData) {
		// If class node passed there, then we shall get callable from it by calling "__call__"
		if( idat.type(callableNode) === IvyDataType.ClassNode )
			return callableNode.__call__();

		// Else we expect that callable passed here
		return idat.callable(callableNode);
	}
}