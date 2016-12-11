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
private:
	DirectiveObject _dirObj;

	/*
		Type of _dataDict should be Undef or Null if directive call or something that represented
		by this ExecutionFrame haven't it's own data scope and uses parent scope for data.
		In other cases _dataDict should be of AssocArray type for storing local variables
	*/
	TDataNode _dataDict;

	ExecutionFrame _moduleFrame;
	
public:
	this(DirectiveObject dirObj, ExecutionFrame modFrame)
	{
		_dirObj = dirObj;
		_moduleFrame = modFrame;

		TDataNode[string] emptyDict;
		_dataDict = emptyDict;
	}

	this(DirectiveObject dirObj, ExecutionFrame modFrame, TDataNode dataDict)
	{
		_dirObj = dirObj;
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

	static TDataNode* findValueInDict( TDataNode* nodePtr, string varName )
	{
		import std.range: empty, take, front, popFront;
		import std.array: array, split;
		if( varName.empty )
			interpretError( "VariableTable: Variable name cannot be empty" );
		string[] nameSplitted = varName.split('.');

		while( !nameSplitted.empty )
		{
			if( nodePtr.type != DataNodeType.AssocArray )
				return null;

			nodePtr = nameSplitted.front in nodePtr.assocArray;
			nameSplitted.popFront();
			if( nodePtr is null )
				return null;
		}
		return nodePtr;
	}

	// Basic method used to search symbols in context
	TDataNode* findValue( string varName )
	{
		writeln( `Searching in _dataDict: `, _dataDict );

		import std.range: empty, take, front, popFront, drop;
		import std.array: array, split, join;
		if( varName.empty )
			interpretError( "VariableTable: Variable name cannot be empty" );

		TDataNode* nodePtr = findValueInDict( &_dataDict, varName );
		if( nodePtr )
			return nodePtr;

		// Reset and try to find in modules
		string[] nameSplitted = varName.split('.');

		for( size_t i = nameSplitted.length; i > 0; --i )
		{
			string sectionName = nameSplitted[].take(i).join(".");
			string attrName = nameSplitted[].drop(i).join(".");
			nodePtr = null;

			TDataNode* modNodePtr = sectionName in _dataDict.assocArray;
			writeln( ` Searching module frame: `, sectionName );

			if( modNodePtr is null )
			{
				writeln( ` Searching module frame: `, sectionName, `, is null` );
				continue;
			}

			if( modNodePtr.type != DataNodeType.ExecutionFrame )
			{
				writeln( ` Searching module frame: `, sectionName, `, is not module` );
				continue; // Go try to find module with shorter name
			}

			ExecutionFrame modExecFrame = modNodePtr.execFrame;
			assert( modExecFrame, `Module execution frame is null` );

			// We do not look in imported module from another module
			nodePtr = findValueInDict( &modExecFrame._dataDict, attrName );

			writeln( ` Searching value in module frame: `, sectionName, `, value is: `, nodePtr.toString() );

			if( nodePtr )
				return nodePtr;
		}

		return null;
	}

	void setValue( string varName, TDataNode value )
	{
		import std.range: empty;
		import std.algorithm: splitter;
		import std.string: join;
		if( varName.empty )
			interpretError("Variable name cannot be empty!");

		TDataNode* valuePtr = findValue(varName);
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
				TDataNode* parentPtr = findValue(splName.join('.'));
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

	override string toString()
	{
		return `<Exec frame for dir object "` ~ _dirObj._name ~ `">`;
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

	this(ModuleObject[string] moduleObjects, string mainModuleName)
	{
		_moduleObjects = moduleObjects;
		assert( mainModuleName in _moduleObjects, `Cannot get main module from module objects!` );

		DirectiveObject rootDirObj = new DirectiveObject;
		rootDirObj._codeObj = _moduleObjects[mainModuleName].mainCodeObject;

		_globalFrame = new ExecutionFrame(null, null);

		newFrame(rootDirObj, null); // Create entry point module frame
	}

	void newFrame(DirectiveObject dirObj, ExecutionFrame modFrame)
	{
		_frameStack ~= new ExecutionFrame(dirObj, modFrame);
	}

	void newFrame(DirectiveObject dirObj, ExecutionFrame modFrame, TDataNode dataDict)
	{
		_frameStack ~= new ExecutionFrame(dirObj, modFrame, dataDict);
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

			// We always search in module's frame, where directive was defined
			if( !_frameStack.back._moduleFrame )
				return null;

			//assert( _frameStack.back._moduleFrame, `Couldn't find variable value in module frame, because it is null!` );
			if( TDataNode* valuePtr = _frameStack.back._moduleFrame.findValue(varName) )
				return valuePtr;
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
			interpretError( "Undefined variable with name '" ~ varName ~ "'" );

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
		assert( _frameStack.back._dirObj, `_frameStack.back._dirObj is null` );
		assert( _frameStack.back._dirObj._codeObj, `_frameStack.back._dirObj._codeObj is null` );
		assert( _frameStack.back._dirObj._codeObj._moduleObj, `_frameStack.back._dirObj._codeObj._moduleObj is null` );

		return _frameStack.back._dirObj._codeObj._moduleObj.getConst(index);
	}

	void execLoop()
	{
		import std.range: empty, back, popBack;
		import std.conv: to, text;
		import std.meta: AliasSeq;
		import std.typecons: tuple;

		assert( !_frameStack.empty, `_frameStack is empty` );
		assert( _frameStack.back, `_frameStack.back is null` );
		assert( _frameStack.back._dirObj, `_frameStack.back._dirObj is null` );
		assert( _frameStack.back._dirObj._codeObj, `_frameStack.back._dirObj._codeObj is null` );

		auto codeRange = _frameStack.back._dirObj._codeObj._instrs[];
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
							assert(false, `This should never happen!` );
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
							assert(false, `This should never happen!` );
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
					_stack ~= getModuleConst( instr.args[0] );
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
					writeln( "OpCode.Append _stack: ", _stack );
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
					writeln( "StoreName _stack: ", _stack );
					assert( !_stack.empty, "Cannot execute StoreName instruction. Expected var value operand, but exec stack is empty!" );
					TDataNode varValue = _stack.back;
					_stack.popBack();

					TDataNode varNameNode = getModuleConst( instr.args[0] );
					assert( varNameNode.type == DataNodeType.String, `Cannot execute StoreName instruction. Variable name const must have string type!` );

					setValue( varNameNode.str, varValue );
					_stack ~= TDataNode(); // For now we must put something onto stack
					break;
				}

				// Stores data from stack into local context frame variable
				case OpCode.StoreLocalName:
				{
					writeln( "StoreLocalName _stack: ", _stack );
					assert( !_stack.empty, "Cannot execute StoreLocalName instruction. Expected var value operand, but exec stack is empty!" );
					TDataNode varValue = _stack.back;
					_stack.popBack();

					TDataNode varNameNode = getModuleConst( instr.args[0] );
					assert( varNameNode.type == DataNodeType.String, `Cannot execute StoreLocalName instruction. Variable name const must have string type!` );

					setLocalValue( varNameNode.str, varValue );
					_stack ~= TDataNode(); // For now we must put something onto stack
					break;
				}

				// Loads data from local context frame variable by index of var name in module constants
				case OpCode.LoadName:
				{
					TDataNode varNameNode = getModuleConst( instr.args[0] );
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

					writeln( `ImportModule _moduleObjects: `, _moduleObjects );
					assert( moduleName in _moduleObjects, "Cannot execute ImportModule instruction. No such module object: " ~ moduleName );

					ExecutionFrame callerFrame = _frameStack.back;

					if( moduleName !in _moduleFrames )
					{
						// Run module here
						ModuleObject modObject = _moduleObjects[moduleName];
						assert( modObject, `Cannot execute ImportModule instruction, because module object "` ~ moduleName ~ `" is null!` );
						CodeObject codeObject = modObject.mainCodeObject;
						assert( codeObject, `Cannot execute ImportModule instruction, because main code object for module "` ~ moduleName ~ `" is null!` );

						DirectiveObject dirObj = new DirectiveObject;
						dirObj._name = `<` ~ moduleName ~ `>`;
						dirObj._codeObj = codeObject;

						newFrame(dirObj, null); // Create entry point module frame

						// Put module frame in frame of the caller
						callerFrame.setValue( moduleName, TDataNode(_frameStack.back) );

						_stack ~= TDataNode(pk+1);
						codeRange = codeObject._instrs[];
						pk = 0;

						// TODO: Finish me ;) ... please
						continue execution_loop;
					}
					else
					{
						// If module is already imported then just put reference to it into caller's frame
						callerFrame.setValue( moduleName, TDataNode(_moduleFrames[moduleName]) );
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
					writeln( `GetDataRange begin _stack: `, _stack );
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
					writeln( "RunLoop beginning _stack: ", _stack );
					assert( !_stack.empty, `Expected data range, but empty execution stack found` );
					assert( _stack.back.type == DataNodeType.DataNodeRange, `Expected DataNodeRange` );
					auto dataRange = _stack.back.dataRange;
					writeln( "RunLoop dataRange.empty: ", dataRange.empty );
					if( dataRange.empty )
					{
						writeln( "RunLoop. Data range is exaused, so exit loop. _stack is: ", _stack );
						assert( instr.args[0] < codeRange.length, `Cannot jump after the end of code object` );
						pk = instr.args[0];
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

					writeln( "RunLoop. Iteration init finished. _stack is: ", _stack );

					break;
				}

				case OpCode.Jump:
				{
					assert( instr.args[0] < codeRange.length, `Cannot jump after the end of code object` );

					pk = instr.args[0];
					continue execution_loop;
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
					writeln( `LoadDirective _stack: `, _stack );

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
					DirectiveObject dirObj = new DirectiveObject;
					dirObj._name = varName;
					dirObj._codeObj = codeObj;

					setLocalValue( varName, TDataNode(dirObj) ); // Put this directive in context
					_stack ~= TDataNode(); // We should return something

					break;
				}

				case OpCode.CallDirective:
				{
					import std.range: empty, popBack, back;

					writeln( "CallDirective stack on init: : ", _stack );

					size_t stackArgCount = instr.args[0];
					assert( stackArgCount > 0, "Directive call must at least have 1 arguments in stack!" );
					writeln( "CallDirective stackArgCount: ", stackArgCount );
					assert( stackArgCount <= _stack.length, "Not enough arguments in execution stack" );
					writeln( "CallDirective _stack: ", _stack );
					assert( _stack[ _stack.length - stackArgCount ].type == DataNodeType.Directive, `Expected directive object operand in directive call operation` );

					DirectiveObject dirObj = _stack[ _stack.length - stackArgCount ].directive;
					assert( dirObj, `Directive object is null!` );

					bool isNoscope = false;
					if( _stack.back.type == DataNodeType.Integer && _stack.back.integer == 3 )
					{
						// There could be noscope attribute as first "block header"
						isNoscope = true;
						_stack.popBack();
					}

					if( isNoscope )
					{
						// If directive is noscope we create frame with _dataDict that is Undef
						newFrame( dirObj, getModuleFrame(dirObj._codeObj._moduleObj._name), TDataNode() );
					}
					else
					{
						newFrame( dirObj, getModuleFrame(dirObj._codeObj._moduleObj._name) );
					}


					if( stackArgCount > 1 ) // If args count is 1 - it mean that there is no arguments
					{
						for( size_t i = 0; i < (stackArgCount - 1); )
						{
							assert( !_stack.empty, `Expected integer as arguments block header, but got empty exec stack!` );
							assert( _stack.back.type == DataNodeType.Integer, `Expected integer as arguments block header!` );
							size_t blockArgCount = _stack.back.integer >> 3;
							writeln( "blockArgCount: ", blockArgCount );
							int blockType = _stack.back.integer & 7;
							assert( (_stack.back.integer & 4 ) == 0, `Seeems that stack is corrupted` );
							writeln( "blockType: ", blockType );

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
									assert( _stack.back.type == DataNodeType.String, "Named attribute name must be string!" );
									string attrName = _stack.back.str;
									_stack.popBack(); ++j;

									setLocalValue( attrName, attrValue );
								}
								i += j; // Increase overall processed stack arguments count (2 items per iteration)
								writeln( "_stack after parsing named arguments: ", _stack );
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
					writeln( "_stack after parsing all arguments: ", _stack );

					// TODO: Then let's try to get directive arguments and parse 'em

					assert( !_stack.empty, "Expected directive object to call, but found end of execution stack!" );
					assert( _stack.back.type == DataNodeType.Directive, `Expected directive object operand in directive call operation` );
					_stack.popBack(); // Drop directive object from stack

					_stack ~= TDataNode(pk+1); // Put next instruction index on the stack to return at
					codeRange = dirObj._codeObj._instrs[]; // Set new instruction range to execute
					pk = 0;

					continue execution_loop;
				}

				case OpCode.MakeArray:
				{
					size_t arrayLen = instr.args[0];
					TDataNode[] newArray;
					newArray.length = arrayLen; // Preallocating is good ;)
					writeln("MakeArray _stack: ", _stack );
					writeln("MakeArray arrayLen: ", arrayLen);
					for( size_t i = arrayLen; i > 0; --i )
					{
						assert( !_stack.empty, `Expected new array element, but got empty stack` );
						// We take array items from the tail, so we must consider it!
						newArray[i-1] =  _stack.back;
						_stack.popBack();
					}
					_stack ~= TDataNode(newArray);

					break;
				}

				default:
				{
					assert( false, "Unexpected code of operation" );
					break;
				}
			}
			++pk;

			if( pk == codeRange.length ) // Ended with this code object
			{
				writeln( "_stack on code object end: ", _stack );
				writeln( "_frameStack on code object end: ", _frameStack );
				assert( !_frameStack.empty, "Frame stack shouldn't be empty yet'" );
				// TODO: Consider case with noscope directive
				_frameStack.popBack(); // Exit out of this frame

				// If frame stack happens to be empty - it mean we nave done with programme
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
				codeRange = _frameStack.back._dirObj._codeObj._instrs[]; // Set old instruction range back

				_stack ~= result; // Get result back
			}

		}
	}

	void setDebugBreakpoint(string modName, string sourceLine)
	{
		// TODO: Add some debug support

	}
}
