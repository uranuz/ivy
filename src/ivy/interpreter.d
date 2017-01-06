module ivy.interpreter;

import std.stdio, std.conv;

import ivy.node, ivy.node_visitor, ivy.common, ivy.expression;

import ivy.interpreter_data;

alias TDataNode = DataNode!string;


class InterpretException: Exception
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}

}

void interpretError(string msg, string file = __FILE__, size_t line = __LINE__)
{
	throw new InterpretException(msg, file, line);
}

class ExecutionFrame
{
//private:
	CallableObject _callableObj;

	/*
		Type of _dataDict should be Undef or Null if directive call or something that represented
		by this ExecutionFrame haven't it's own data scope and uses parent scope for data.
		In other cases _dataDict should be of AssocArray type for storing local variables
	*/
	TDataNode _dataDict;

	ExecutionFrame _moduleFrame;
	
public:
	this(CallableObject callableObj, ExecutionFrame modFrame)
	{
		_callableObj = callableObj;
		_moduleFrame = modFrame;

		TDataNode[string] emptyDict;
		_dataDict = emptyDict;
	}

	this(CallableObject callableObj, ExecutionFrame modFrame, TDataNode dataDict)
	{
		_callableObj = callableObj;
		_moduleFrame = modFrame;
		_dataDict = dataDict;
	}

	TDataNode getValue( string varName )
	{
		auto varValuePtr = findValue(varName);
		if( varValuePtr is null )
			interpretError( "VariableTable: Cannot find variable with name: " ~ varName );
		return *varValuePtr;
	}
	
	bool canFindValue( string varName )
	{
		return cast(bool)( findValue(varName) );
	}
	
	DataNodeType getDataNodeType( string varName )
	{
		auto varValuePtr = findValue(varName);
		if( varValuePtr is null )
			interpretError( "VariableTable: Cannot find variable with name: " ~ varName );
		return varValuePtr.type;
	}

	// Basic method used to search symbols in context
	TDataNode* findLocalValue( string varName, bool addParentDicts )
	{
		debug writeln("Start findLocalValue for varName: ", varName);
		import std.range: empty, front, popFront;
		import std.array: split;
		if( varName.empty )
			interpretError( "VariableTable: Variable name cannot be empty" );

		TDataNode *nodePtr;
		if( _dataDict.type == DataNodeType.AssocArray )
			nodePtr = &_dataDict;
		else
			interpretError( "VariableTable: cannot find variable in execution frame, because callable doesn't have it's on scope!" );

		string[] nameSplitted = varName.split('.');
		while( !nameSplitted.empty )
		{
			if( nodePtr.type == DataNodeType.AssocArray )
			{
				TDataNode* tmpNodePtr = nameSplitted.front in nodePtr.assocArray;
				
				// Special hack to add parent dicts when importing some modules from nested folder,
				// but we don't add extra parent dicts into foreign module frames
				if( !tmpNodePtr && addParentDicts )
				{
					nodePtr.assocArray[nameSplitted.front] = (TDataNode[string]).init;
					nodePtr = &nodePtr.assocArray[nameSplitted.front];
				}
				else
				{
					nodePtr = tmpNodePtr;
				}
			}
			else if( nodePtr.type == DataNodeType.ExecutionFrame )
			{
				if( !nodePtr.execFrame )
					interpretError( `Cannot find value, because execution frame is null!!!` );

				if( nodePtr.execFrame._dataDict.type != DataNodeType.AssocArray )
					interpretError( `Cannot find value, because execution frame data dict is not of assoc array type!!!` );
				nodePtr = nameSplitted.front in nodePtr.execFrame._dataDict.assocArray;
			}
			else
			{
				return null;
			}
			
			nameSplitted.popFront();
			if( nodePtr is null )
				return null;
		}

		return nodePtr;
	}

	TDataNode* findValue(string varName, bool addParentDicts = false)
	{
		TDataNode* nodePtr = findLocalValue(varName, addParentDicts);
		if( nodePtr )
			return nodePtr;
		
		if( _moduleFrame )
			return _moduleFrame.findLocalValue(varName, addParentDicts);
		
		return null;
	}

	void setValue( string varName, TDataNode value, bool addParentDicts = false )
	{
		import std.range: empty;
		import std.algorithm: splitter;
		import std.string: join;
		if( varName.empty )
			interpretError("Variable name cannot be empty!");

		TDataNode* valuePtr = findValue(varName, addParentDicts);
		if( valuePtr )
		{
			*valuePtr = value;
		}
		else
		{
			auto splName = splitter(varName, '.');
			string shortName = splName.back;
			splName.popBack(); // Trim actual name

			if( splName.empty )
			{
				_dataDict[shortName] = value;
			}
			else
			{
				// Try to find parent
				TDataNode* parentPtr = findValue(splName.join('.'), addParentDicts);
				if( parentPtr is null )
					interpretError( `Cannot create new variable "` ~ varName ~ `", because parent not exists!` );

				if( parentPtr.type != DataNodeType.AssocArray )
					interpretError( `Cannot create new value "` ~ varName ~ `", because parent is not of assoc array type!` );
				// I think we shouldn't be able to add new variables to another module scope, only modify them

				(*parentPtr)[shortName] = value;
			}

		}
	}
	
	void removeValue( string varName )
	{
		import std.range: empty;
		import std.algorithm: splitter;
		import std.string: join;
		if( varName.empty )
			interpretError("Variable name cannot be empty!");

		auto splName = splitter(varName, '.');
		string shortName = splName.back;
		splName.popBack(); // Trim actual name
		if( splName.empty )
		{
			_dataDict.assocArray.remove( shortName );
		}
		else
		{
			// Try to find parent
			TDataNode* parentPtr = findValue(splName.join('.'));

			if( parentPtr is null )
				interpretError( `Cannot delete variable "` ~ varName ~ `", because parent not exists!` );

			if( parentPtr.type != DataNodeType.AssocArray )
				interpretError( `Cannot delete value "` ~ varName ~ `", because parent is not of assoc array type!` );

			(*parentPtr)[shortName].assocArray.remove(shortName);
		}
	}

	bool hasOwnScope() @property
	{
		return _dataDict.type == DataNodeType.AssocArray;
	}
	
	CallableKind callableKind() @property
	{
		return _callableObj._kind;
	}

	override string toString()
	{
		return `<Exec frame for dir object "` ~ _callableObj._name ~ `">`;
	}

}

class RenderDirInterpreter: INativeDirectiveInterpreter
{
	void interpret( Interpreter interp )
	{
		import std.array: appender;
		TDataNode result = interp.getValue("__result__");

		auto renderedResult = appender!string();
		result.writeDataNodeLines(renderedResult);
		interp._stack ~= TDataNode(renderedResult.data);
	}
}

import ivy.bytecode;

class Interpreter
{
public:
	alias String = string;
	alias TDataNode = DataNode!String;

	TDataNode[] _stack;
	ExecutionFrame[] _frameStack;
	ExecutionFrame _globalFrame;
	ExecutionFrame[string] _moduleFrames;
	ModuleObject[string] _moduleObjects;

	this(ModuleObject[string] moduleObjects, string mainModuleName, TDataNode dataDict)
	{
		_moduleObjects = moduleObjects;
		assert( mainModuleName in _moduleObjects, `Cannot get main module from module objects!` );

		CallableObject rootCallableObj = new CallableObject;
		rootCallableObj._codeObj = _moduleObjects[mainModuleName].mainCodeObject;
		rootCallableObj._kind = CallableKind.Module;
		rootCallableObj._name = "__main__";

		_globalFrame = new ExecutionFrame(null, null);

		// Add native directive interpreter __render__ to global scope
		CallableObject renderDirInterp = new CallableObject();
		renderDirInterp._name = "__render__";
		renderDirInterp._dirInterp = new RenderDirInterpreter();
		_globalFrame.setValue( "__render__", TDataNode(renderDirInterp) );

		newFrame(rootCallableObj, null, dataDict); // Create entry point module frame
	}

	void newFrame(CallableObject callableObj, ExecutionFrame modFrame)
	{
		_frameStack ~= new ExecutionFrame(callableObj, modFrame);
	}

	void newFrame(CallableObject callableObj, ExecutionFrame modFrame, TDataNode dataDict)
	{
		_frameStack ~= new ExecutionFrame(callableObj, modFrame, dataDict);
	}

	void removeFrame()
	{
		import std.range: popBack;
		_frameStack.popBack();
	}

	ExecutionFrame getModuleFrame(string modName)
	{
		if( modName !in _moduleFrames )
		{
			_moduleFrames[modName] = new ExecutionFrame(null, _globalFrame);
		}

		return _moduleFrames[modName];
	}

	bool canFindValue( string varName )
	{
		import std.range: empty, back;

		if( !_frameStack.empty )
		{
			assert( _frameStack.back, `Couldn't test variable existence, because frame stack is null!` );
			if( _frameStack.back.canFindValue(varName) )
				return true;

			assert( _frameStack.back._moduleFrame, `Couldn't test variable existence in module frame, because it is null!` );
			if( _frameStack.back._moduleFrame.canFindValue(varName) )
				return true;
		}

		assert( _globalFrame, `Couldn't test variable existence in global frame, because it is null!` );
		if( _globalFrame.canFindValue(varName) )
			return true;

		return false;
	}

	TDataNode* findValue( string varName )
	{
		import std.range: empty, back, popBack;

		if( !_frameStack.empty )
		{
			auto frameStackSlice = _frameStack[];

			for( ; !frameStackSlice.empty; frameStackSlice.popBack() )
			{
				assert( frameStackSlice.back, `Couldn't find variable value, because execution frame is null!` );
				if( !frameStackSlice.back.hasOwnScope )
				{
					continue; // Let's try to find in parent
				}

				if( TDataNode* valuePtr = frameStackSlice.back.findValue(varName) )
					return valuePtr;
			}
		}

		assert( _globalFrame, `Couldn't find variable value in global frame, because it is null!` );
		if( TDataNode* valuePtr = _globalFrame.findValue(varName) )
			return valuePtr;

		return null;
	}

	TDataNode getValue( string varName )
	{
		TDataNode* valuePtr = findValue(varName);

		if( valuePtr is null )
		{
			debug {
				foreach( i, frame; _frameStack[] )
				{
					writeln( `Scope frame lvl `, i, `, _dataDict: `, frame._dataDict );
				}
			}

			interpretError( "Undefined variable with name '" ~ varName ~ "'" );
		}

		return *valuePtr;
	}

	void setValue( string varName, TDataNode value )
	{
		import std.range: empty;
		TDataNode* valuePtr = findValue(varName);
		if( valuePtr is null )
			interpretError( `Cannot set variable "` ~ varName ~ `", because cannot find it. Use setLocalValue to decare new variable!` );

		*valuePtr = value;
	}

	void setLocalValue( string varName, TDataNode value )
	{
		import std.range: empty, popBack, back;
		import std.algorithm: splitter;

		if( _frameStack.empty )
			interpretError("Cannot set local var value, because frame stack is empty!");

		_frameStack.back.setValue(varName, value);
	}

	bool hasLocalValue( string varName )
	{
		import std.range: empty, back;

		if( _frameStack.empty )
			return false;

		return _frameStack.back.canFindValue( varName );
	}

	void removeLocalValue( string varName )
	{
		import std.range: empty, back;

		if( _frameStack.empty )
			interpretError("Cannot remove local value, because frame stack is empty!");

		return _frameStack.back.removeValue( varName );
	}

	TDataNode getModuleConst( size_t index )
	{
		import std.range: back, empty;
		import std.conv: text;
		assert( !_frameStack.empty, `_frameStack is empty` );
		assert( _frameStack.back, `_frameStack.back is null` );
		assert( _frameStack.back._callableObj, `_frameStack.back._callableObj is null` );
		assert( _frameStack.back._callableObj._codeObj, `_frameStack.back._callableObj._codeObj is null` );
		assert( _frameStack.back._callableObj._codeObj._moduleObj, `_frameStack.back._callableObj._codeObj._moduleObj is null` );

		return _frameStack.back._callableObj._codeObj._moduleObj.getConst(index);
	}

	void execLoop()
	{
		import std.range: empty, back, popBack;
		import std.conv: to, text;
		import std.meta: AliasSeq;
		import std.typecons: tuple;

		assert( !_frameStack.empty, `_frameStack is empty` );
		assert( _frameStack.back, `_frameStack.back is null` );
		assert( _frameStack.back._callableObj, `_frameStack.back._callableObj is null` );
		assert( _frameStack.back._callableObj._codeObj, `_frameStack.back._callableObj._codeObj is null` );

		auto codeRange = _frameStack.back._callableObj._codeObj._instrs[];
		size_t pk = 0;

		execution_loop:
		for( ; pk < codeRange.length; )
		{
			Instruction instr = codeRange[pk];
			switch( instr.opcode )
			{
				// Base arithmetic operations execution
				case OpCode.Add, OpCode.Sub, OpCode.Mul, OpCode.Div, OpCode.Mod:
				{
					import std.conv: to;
					assert( !_stack.empty, "Cannot execute " ~ instr.opcode.to!string ~ " instruction. Expected right operand, but exec stack is empty!" );
					// Right value was evaluated last so it goes first in the stack
					TDataNode rightVal = _stack.back;
					_stack.popBack();

					assert( !_stack.empty, "Cannot execute " ~ instr.opcode.to!string ~ " instruction. Expected left operand, but exec stack is empty!" );
					TDataNode leftVal = _stack.back;
					assert( ( leftVal.type == DataNodeType.Integer || leftVal.type == DataNodeType.Floating ) && leftVal.type == rightVal.type,
						`Left and right values of arithmetic operation must have the same integer or floating type!` );

					arithm_op_switch:
					switch( instr.opcode )
					{
						foreach( arithmOp; AliasSeq!(
							tuple(OpCode.Add, "+"),
							tuple(OpCode.Sub, "-"),
							tuple(OpCode.Mul, "*"),
							tuple(OpCode.Div, "/"),
							tuple(OpCode.Mod, "%")) )
						{
							case arithmOp[0]: {
								if( leftVal.type == DataNodeType.Integer )
								{
									mixin( `_stack.back = leftVal.integer ` ~ arithmOp[1] ~ ` rightVal.integer;` );
								}
								else
								{
									mixin( `_stack.back = leftVal.floating ` ~ arithmOp[1] ~ ` rightVal.floating;` );
								}
								break arithm_op_switch;
							}
						}
						default:
							assert( false, `This should never happen!` );
					}
					break;
				}

				// Logical binary operations
				case OpCode.And, OpCode.Or, OpCode.Xor:
				{
					import std.conv: to;
					assert( !_stack.empty, "Cannot execute " ~ instr.opcode.to!string ~ " instruction. Expected right operand, but exec stack is empty!" );
					TDataNode rightVal = _stack.back;
					_stack.popBack();

					assert( !_stack.empty, "Cannot execute " ~ instr.opcode.to!string ~ " instruction. Expected left operand, but exec stack is empty!" );
					TDataNode leftVal = _stack.back;
					assert( leftVal.type == DataNodeType.Boolean && leftVal.type == rightVal.type,
						`Left and right values of arithmetic operation must have boolean type!` );

					logical_op_switch:
					switch( instr.opcode )
					{
						foreach( logicalOp; AliasSeq!(
							tuple(OpCode.And, "&&"),
							tuple(OpCode.Or, "||"),
							tuple(OpCode.Xor, "^^")) )
						{
							case logicalOp[0]: {
								mixin( `_stack.back = leftVal.boolean ` ~ logicalOp[1] ~ ` rightVal.boolean;` );
								break logical_op_switch;
							}
						}
						default:
							assert( false, `This should never happen!` );
					}
					break;
				}

				// Comparision operations
				case OpCode.LT, OpCode.GT, OpCode.LTEqual, OpCode.GTEqual:
				{
					import std.conv: to;
					assert( !_stack.empty, "Cannot execute " ~ instr.opcode.to!string ~ " instruction. Expected right operand, but exec stack is empty!" );
					// Right value was evaluated last so it goes first in the stack
					TDataNode rightVal = _stack.back;
					_stack.popBack();

					assert( !_stack.empty, "Cannot execute " ~ instr.opcode.to!string ~ " instruction. Expected left operand, but exec stack is empty!" );
					TDataNode leftVal = _stack.back;
					assert( leftVal.type == rightVal.type, `Left and right operands of comparision must have the same type` );

					compare_op_switch:
					switch( instr.opcode )
					{
						foreach( compareOp; AliasSeq!(
							tuple(OpCode.LT, "<"),
							tuple(OpCode.GT, ">"),
							tuple(OpCode.LTEqual, "<="),
							tuple(OpCode.GTEqual, ">=")) )
						{
							case compareOp[0]: {
								switch( leftVal.type )
								{
									case DataNodeType.Undef, DataNodeType.Null:
										// Undef and Null are not less or equal to something
										_stack.back = TDataNode(false);
										break;
									case DataNodeType.Integer:
										mixin( `_stack.back = leftVal.integer ` ~ compareOp[1] ~ ` rightVal.integer;` );
										break;
									case DataNodeType.Floating:
										mixin( `_stack.back = leftVal.floating ` ~ compareOp[1] ~ ` rightVal.floating;` );
										break;
									case DataNodeType.String:
										mixin( `_stack.back = leftVal.str ` ~ compareOp[1] ~ ` rightVal.str;` );
										break;
									default:
										assert( false, `Less or greater comparision doesn't support type "` ~ leftVal.type.to!string ~ `" yet!` );
								}
								break compare_op_switch;
							}
						}
						default:
							assert(false, `This should never happen!` );
					}
					break;
				}

				// Shallow equality comparision
				case OpCode.Equal:
				{
					assert( !_stack.empty, "Cannot execute Equal instruction. Expected right operand, but exec stack is empty!" );
					// Right value was evaluated last so it goes first in the stack
					TDataNode rightVal = _stack.back;
					_stack.popBack();

					assert( !_stack.empty, "Cannot execute Equal instruction. Expected left operand, but exec stack is empty!" );
					TDataNode leftVal = _stack.back;
					assert( leftVal.type == rightVal.type, `Left and right operands of comparision must have the same type` );

					cmp_type_switch:
					switch( leftVal.type )
					{
						case DataNodeType.Undef, DataNodeType.Null:
							// Undef and Null are not less or equal to something
							_stack.back = TDataNode(false);
							break;

						foreach( typeAndField; AliasSeq!(
							tuple(DataNodeType.Boolean, "boolean"),
							tuple(DataNodeType.Integer, "integer"),
							tuple(DataNodeType.Floating, "floating"),
							tuple(DataNodeType.String, "str")) )
						{
							case typeAndField[0]:
								mixin( `_stack.back = leftVal.` ~ typeAndField[1] ~ ` == rightVal.` ~ typeAndField[1] ~ `;` );
								break cmp_type_switch;
						}
						default:
							break;
					}
					break;
				}

				// Load constant from programme data table into stack
				case OpCode.LoadConst:
				{
					_stack ~= getModuleConst( instr.arg );
					break;
				}

				// Concatenates two arrays or strings and puts result onto stack
				case OpCode.Concat:
				{
					assert( !_stack.empty, "Cannot execute Concat instruction. Expected right operand, but exec stack is empty!" );
					TDataNode rightVal = _stack.back;
					_stack.popBack();

					assert( !_stack.empty, "Cannot execute Concat instruction. Expected left operand, but exec stack is empty!" );
					TDataNode leftVal = _stack.back;
					assert( ( leftVal.type == DataNodeType.String || leftVal.type == DataNodeType.Array ) && leftVal.type == rightVal.type,
						`Left and right values for concatenation operation must have the same string or array type!`
					);

					if( leftVal.type == DataNodeType.String )
					{
						_stack.back = leftVal.str ~ rightVal.str;
					}
					else
					{
						_stack.back = leftVal.array ~ rightVal.array;
					}

					break;
				}

				case OpCode.Append:
				{
					debug writeln( "OpCode.Append _stack: ", _stack );
					import std.conv: to;
					assert( !_stack.empty, "Cannot execute Append instruction. Expected right operand, but exec stack is empty!" );
					TDataNode rightVal = _stack.back;
					_stack.popBack();

					assert( !_stack.empty, "Cannot execute Concat instruction. Expected left operand, but exec stack is empty!" );
					TDataNode leftVal = _stack.back;
					_stack.popBack();
					assert( leftVal.type == DataNodeType.Array, "Left operand for Append instruction expected to be array, but got: " ~ leftVal.type.to!string );

					leftVal ~= rightVal;
					_stack ~= leftVal;

					break;
				}

				// Useless unary plus operation
				case OpCode.UnaryPlus:
				{
					assert( !_stack.empty, "Cannot execute UnaryPlus instruction. Operand expected, but exec stack is empty!" );
					assert( _stack.back.type == DataNodeType.Integer || _stack.back.type == DataNodeType.Floating,
						`Operand for unary plus operation must have integer or floating type!` );

					// Do nothing for now:)
					break;
				}

				case OpCode.UnaryMin:
				{
					assert( !_stack.empty, "Cannot execute UnaryMin instruction. Operand expected, but exec stack is empty!" );
					assert( _stack.back.type == DataNodeType.Integer || _stack.back.type == DataNodeType.Floating,
						`Operand for unary minus operation must have integer or floating type!` );

					if( _stack.back.type == DataNodeType.Integer )
					{
						_stack.back = - _stack.back.integer;
					}
					else
					{
						_stack.back = - _stack.back.floating;
					}

					break;
				}

				case OpCode.UnaryNot:
				{
					assert( !_stack.empty, "Cannot execute UnaryNot instruction. Operand expected, but exec stack is empty!" );
					assert( _stack.back.type == DataNodeType.Boolean,
						`Operand for unary not operation must have boolean type!` );

					_stack.back = ! _stack.back.boolean;
					break;
				}

				case OpCode.Nop:
				{
					// Doing nothing here... What did you expect? :)
					break;
				}

				// Stores data from stack into context variable
				case OpCode.StoreName:
				{
					debug writeln( "StoreName _stack: ", _stack );
					assert( !_stack.empty, "Cannot execute StoreName instruction. Expected var value operand, but exec stack is empty!" );
					TDataNode varValue = _stack.back;
					_stack.popBack();

					TDataNode varNameNode = getModuleConst( instr.arg );
					assert( varNameNode.type == DataNodeType.String, `Cannot execute StoreName instruction. Variable name const must have string type!` );

					setValue( varNameNode.str, varValue );
					break;
				}

				// Stores data from stack into local context frame variable
				case OpCode.StoreLocalName:
				{
					debug writeln( "StoreLocalName _stack: ", _stack );
					assert( !_stack.empty, "Cannot execute StoreLocalName instruction. Expected var value operand, but exec stack is empty!" );
					TDataNode varValue = _stack.back;
					_stack.popBack();

					TDataNode varNameNode = getModuleConst( instr.arg );
					assert( varNameNode.type == DataNodeType.String, `Cannot execute StoreLocalName instruction. Variable name const must have string type!` );

					setLocalValue( varNameNode.str, varValue );
					break;
				}

				// Loads data from local context frame variable by index of var name in module constants
				case OpCode.LoadName:
				{
					TDataNode varNameNode = getModuleConst( instr.arg );
					assert( varNameNode.type == DataNodeType.String, `Cannot execute LoadName instruction. Variable name operand must have string type!` );

					_stack ~= getValue( varNameNode.str );
					break;
				}

				case OpCode.ImportModule:
				{
					assert( !_stack.empty, "Cannot execute ImportModule instruction. Expected module name operand, but exec stack is empty!" );
					assert( _stack.back.type == DataNodeType.String, "Cannot execute ImportModule instruction. Module name operand must be a string!" );
					string moduleName = _stack.back.str;
					_stack.popBack();

					debug writeln( `ImportModule _moduleObjects: `, _moduleObjects );
					assert( moduleName in _moduleObjects, "Cannot execute ImportModule instruction. No such module object: " ~ moduleName );

					ExecutionFrame callerFrame = _frameStack.back;

					if( moduleName !in _moduleFrames )
					{
						// Run module here
						ModuleObject modObject = _moduleObjects[moduleName];
						assert( modObject, `Cannot execute ImportModule instruction, because module object "` ~ moduleName ~ `" is null!` );
						CodeObject codeObject = modObject.mainCodeObject;
						assert( codeObject, `Cannot execute ImportModule instruction, because main code object for module "` ~ moduleName ~ `" is null!` );

						CallableObject callableObj = new CallableObject;
						callableObj._name = moduleName;
						callableObj._kind = CallableKind.Module;
						callableObj._codeObj = codeObject;

						newFrame(callableObj, null); // Create entry point module frame

						// Put module frame in frame of the caller
						callerFrame.setValue( moduleName, TDataNode(_frameStack.back), true );

						_stack ~= TDataNode(pk+1);
						codeRange = codeObject._instrs[];
						pk = 0;

						// TODO: Finish me ;) ... please
						continue execution_loop;
					}
					else
					{
						// If module is already imported then just put reference to it into caller's frame
						callerFrame.setValue( moduleName, TDataNode(_moduleFrames[moduleName]), true );
					}

					break;
				}

				case OpCode.ImportFrom:
				{
					assert( false, "Unimplemented yet!" );
					break;
				}

				case OpCode.GetDataRange:
				{
					import std.range: empty, back, popBack;
					assert( !_stack.empty, `Expected aggregate type for loop, but empty execution stack found` );
					debug writeln( `GetDataRange begin _stack: `, _stack );
					assert( _stack.back.type == DataNodeType.Array || _stack.back.type == DataNodeType.AssocArray,
						`Expected array or assoc array as loop aggregate` );

					TDataNode dataRange;
					switch( _stack.back.type )
					{
						case DataNodeType.Array:
						{
							dataRange = new ArrayRange(_stack.back.array);
							break;
						}
						case DataNodeType.AssocArray:
						{
							dataRange = new AssocArrayRange(_stack.back.assocArray);
							break;
						}
						default:
							assert( false, `This should never happen!` );
					}
					_stack.popBack(); // Drop aggregate from stack
					_stack ~= dataRange; // Push range onto stack

					break;
				}

				case OpCode.RunLoop:
				{
					debug writeln( "RunLoop beginning _stack: ", _stack );
					assert( !_stack.empty, `Expected data range, but empty execution stack found` );
					assert( _stack.back.type == DataNodeType.DataNodeRange, `Expected DataNodeRange` );
					auto dataRange = _stack.back.dataRange;
					debug writeln( "RunLoop dataRange.empty: ", dataRange.empty );
					if( dataRange.empty )
					{
						debug writeln( "RunLoop. Data range is exaused, so exit loop. _stack is: ", _stack );
						assert( instr.arg < codeRange.length, `Cannot jump after the end of code object` );
						pk = instr.arg;
						_stack.popBack(); // Drop data range from stack as we no longer need it
						break;
					}

					switch( dataRange.aggrType )
					{
						case DataNodeType.Array:
						{
							_stack ~= dataRange.front;
							break;
						}
						case DataNodeType.AssocArray:
						{
							assert( dataRange.front.type == DataNodeType.Array, `Expected array as assoc array key-value pair` );
							TDataNode[] aaPair = dataRange.front.array;
							assert( aaPair.length > 1, `Assoc array pair must have two items` );
							_stack ~= aaPair[0];
							_stack ~= aaPair[1];

							break;
						}
						default:
							assert( false, `Unexpected range aggregate type!` );
					}

					// TODO: For now we just move range forward as take current value from it
					// Maybe should fix it and make it move after loop block finish
					dataRange.popFront();

					debug writeln( "RunLoop. Iteration init finished. _stack is: ", _stack );

					break;
				}

				case OpCode.Jump:
				{
					assert( instr.arg < codeRange.length, `Cannot jump after the end of code object` );

					pk = instr.arg;
					continue execution_loop;
				}

				case OpCode.JumpIfFalse:
				{
					import std.algorithm: canFind;
					assert( !_stack.empty, `Cannot evaluate logical value, because stack is empty` );
					assert( [ DataNodeType.Boolean, DataNodeType.Undef, DataNodeType.Null ].canFind(_stack.back.type),
						`Expected null, undef or boolean in logical context as jump condition` );
					assert( instr.arg < codeRange.length, `Cannot jump after the end of code object` );
					TDataNode condNode = _stack.back;
					_stack.popBack();
					
					if( condNode.type == DataNodeType.Boolean && condNode.boolean )
					{
						break;
					}
					else
					{
						pk = instr.arg;
						continue execution_loop;
					}
				}

				case OpCode.PopTop:
				{
					assert( !_stack.empty, "Cannot pop value from stack, because stack is empty" );
					_stack.popBack();
					break;
				}

				// Swaps two top items on the stack 
				case OpCode.SwapTwo:
				{
					assert( _stack.length > 1, "Stack must have at least two items to swap" );
					TDataNode tmp = _stack[$-1];
					_stack[$-1] = _stack[$-2];
					_stack[$-2] = tmp;
					break;
				}

				case OpCode.LoadDirective:
				{
					debug writeln( `LoadDirective _stack: `, _stack );

					assert( _stack.back.type == DataNodeType.String,
						`Name operand for directive loading instruction should have string type` );
					string varName = _stack.back.str;

					_stack.popBack();

					assert( !_stack.empty, `Expected directive code object, but got empty execution stack!` );
					assert( _stack.back.type == DataNodeType.CodeObject,
						`Code object operand for directive loading instruction should have CodeObject type` );

					CodeObject codeObj = _stack.back.codeObject;
					_stack.popBack(); // Remove code object from stack

					assert( codeObj, `Code object operand for directive loading instruction is null` );
					CallableObject dirObj = new CallableObject;
					dirObj._name = varName;
					dirObj._codeObj = codeObj;

					setLocalValue( varName, TDataNode(dirObj) ); // Put this directive in context
					_stack ~= TDataNode(); // We should return something

					break;
				}

				case OpCode.RunCallable:
				{
					import std.range: empty, popBack, back;

					debug writeln( "RunCallable stack on init: : ", _stack );

					size_t stackArgCount = instr.arg;
					assert( stackArgCount > 0, "Call must at least have 1 arguments in stack!" );
					debug writeln( "RunCallable stackArgCount: ", stackArgCount );
					assert( stackArgCount <= _stack.length, "Not enough arguments in execution stack" );
					debug writeln( "RunCallable _stack: ", _stack );
					debug writeln( "RunCallable callable type: ", _stack[ _stack.length - stackArgCount ].type );
					assert( _stack[ _stack.length - stackArgCount ].type == DataNodeType.Callable, `Expected directive object operand in directive call operation` );

					CallableObject callableObj = _stack[ _stack.length - stackArgCount ].callable;
					assert( callableObj, `Callable object is null!` );

					bool isNoscope = false;
					if( _stack.back.type == DataNodeType.Integer && _stack.back.integer == 3 )
					{
						// There could be noscope attribute as first "block header"
						isNoscope = true;
						_stack.popBack();
					}

					ExecutionFrame moduleFrame;
					if( callableObj._codeObj )
					{
						moduleFrame = getModuleFrame( callableObj._codeObj._moduleObj._name );
					}
					else
					{
						moduleFrame = getModuleFrame( "__main__" );
					}

					if( isNoscope )
					{
						// If directive is noscope we create frame with _dataDict that is Undef
						newFrame( callableObj, moduleFrame, TDataNode() );
					}
					else
					{
						newFrame( callableObj, moduleFrame );
					}


					if( stackArgCount > 1 ) // If args count is 1 - it mean that there is no arguments
					{
						for( size_t i = 0; i < (stackArgCount - 1); )
						{
							assert( !_stack.empty, `Expected integer as arguments block header, but got empty exec stack!` );
							assert( _stack.back.type == DataNodeType.Integer, `Expected integer as arguments block header!` );
							size_t blockArgCount = _stack.back.integer >> 3;
							debug writeln( "blockArgCount: ", blockArgCount );
							int blockType = _stack.back.integer & 7;
							assert( (_stack.back.integer & 4 ) == 0, `Seeems that stack is corrupted` );
							debug writeln( "blockType: ", blockType );

							_stack.popBack();
							++i; // Block header was eaten, so increase counter

							if( blockType == 1 )
							{
								size_t j = 0;
								while( j < 2 * blockArgCount )
								{
									assert( !_stack.empty, "Execution stack is empty!" );
									TDataNode attrValue = _stack.back;
									_stack.popBack(); ++j; // Parallel bookkeeping ;)

									assert( !_stack.empty, "Execution stack is empty!" );
									debug writeln( `RunCallable debug, _stack is: `, _stack );
									assert( _stack.back.type == DataNodeType.String, "Named attribute name must be string!" );
									string attrName = _stack.back.str;
									_stack.popBack(); ++j;

									setLocalValue( attrName, attrValue );
								}
								i += j; // Increase overall processed stack arguments count (2 items per iteration)
								debug writeln( "_stack after parsing named arguments: ", _stack );
							}
							else if( blockType == 2 )
							{
								assert( false, "Interpreting positional arguments not implemented yet!" );
							}
							else
							{
								assert( false, "Unexpected arguments block type" );
							}

						}
					}
					debug writeln( "_stack after parsing all arguments: ", _stack );

					assert( !_stack.empty, "Expected directive object to call, but found end of execution stack!" );
					assert( _stack.back.type == DataNodeType.Callable, `Expected directive object operand in directive call operation` );
					_stack.popBack(); // Drop directive object from stack

					if( callableObj._codeObj )
					{
						_stack ~= TDataNode(pk+1); // Put next instruction index on the stack to return at
						codeRange = callableObj._codeObj._instrs[]; // Set new instruction range to execute
						pk = 0;
						continue execution_loop;
					}
					else
					{
						assert( callableObj._dirInterp, `Callable object expected to have non null code object or native directive interpreter object!` );
						callableObj._dirInterp.interpret(this); // Run native directive interpreter
						
						if( !isNoscope )
						{
							_frameStack.popBack(); // Drop context from stack after end of execution
						}
					}

					break;
				}

				case OpCode.MakeArray:
				{
					size_t arrayLen = instr.arg;
					TDataNode[] newArray;
					newArray.length = arrayLen; // Preallocating is good ;)
					debug writeln("MakeArray _stack: ", _stack );
					debug writeln("MakeArray arrayLen: ", arrayLen);
					for( size_t i = arrayLen; i > 0; --i )
					{
						assert( !_stack.empty, `Expected new array element, but got empty stack` );
						// We take array items from the tail, so we must consider it!
						newArray[i-1] = _stack.back;
						_stack.popBack();
					}
					_stack ~= TDataNode(newArray);

					break;
				}

				case OpCode.MakeAssocArray:
				{
					size_t aaLen = instr.arg;
					TDataNode[string] newAssocArray;

					for( size_t i = 0; i < aaLen; ++i )
					{
						assert( !_stack.empty, `Expected assoc array value, but got empty stack` );
						TDataNode val = _stack.back;
						_stack.popBack();

						assert( !_stack.empty, `Expected assoc array key, but got empty stack` );
						assert( _stack.back.type == DataNodeType.String, `Expected string as assoc array key` );
						
						newAssocArray[_stack.back.str] = val;
						_stack.popBack();
					}
					_stack ~= TDataNode(newAssocArray);
					break;
				}

				default:
				{
					assert( false, "Unexpected code of operation: " ~ instr.opcode.text );
					break;
				}
			}
			++pk;

			if( pk == codeRange.length ) // Ended with this code object
			{
				debug writeln( "_stack on code object end: ", _stack );
				debug writeln( "_frameStack on code object end: ", _frameStack );
				assert( !_frameStack.empty, "Frame stack shouldn't be empty yet'" );
				// TODO: Consider case with noscope directive
				_frameStack.popBack(); // Exit out of this frame

				// If frame stack happens to be empty - it means that we nave done with programme
				if( _frameStack.empty )
					break;

				// Else we expect to have result of directive on the stack
				assert( !_stack.empty, "Expected directive result, but execution stack is empty!" );
				TDataNode result = _stack.back;
				_stack.popBack(); // We saved result - so drop it!

				assert( !_stack.empty, "Expected integer as instruction pointer, but got end of execution stack" );
				assert( _stack.back.type == DataNodeType.Integer, "Expected integer as instruction pointer" );
				pk = cast(size_t) _stack.back.integer;
				_stack.popBack(); // Drop return address
				codeRange = _frameStack.back._callableObj._codeObj._instrs[]; // Set old instruction range back

				_stack ~= result; // Get result back
			}

		}
	}

	void setDebugBreakpoint(string modName, string sourceLine)
	{
		// TODO: Add some debug support

	}
}
