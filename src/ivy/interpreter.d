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

	TDataNode* findValue( string varName )
	{
		import std.range: empty;
		import std.algorithm: splitter;
		if( varName.empty )
			interpretError( "VariableTable: Variable name cannot be empty" );
		auto nameSplitter = varName.splitter('.');
		TDataNode* nodePtr = nameSplitter.front in _dataDict.assocArray;
		if( nodePtr is null )
			return null;
		nameSplitter.popFront();

		while( !nameSplitter.empty  )
		{
			if( nodePtr.type != DataNodeType.AssocArray )
				return null;

			nodePtr = nameSplitter.front in nodePtr.assocArray;
			nameSplitter.popFront();
			if( nodePtr is null )
				return null;
		}

		return nodePtr;
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

	//IvyRepository _ivyRepository; // Storage for parsed modules

	this(DirectiveObject rootDirObj)
	{
		//_ivyRepository = new IvyRepository;
		_globalFrame = new ExecutionFrame(null, null);

		newFrame(rootDirObj, null); // Create entry point module frame
	}

	void newFrame(DirectiveObject dirObj, ExecutionFrame modFrame)
	{
		_frameStack ~= new ExecutionFrame(dirObj, modFrame);
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
			if( _frameStack.back.canFindValue(varName) )
				return true;

			if( _frameStack.back._moduleFrame.canFindValue(varName) )
				return true;
		}

		if( _globalFrame.canFindValue(varName) )
			return true;

		return false;
	}

	TDataNode* findValue( string varName )
	{
		import std.range: empty, back;

		if( !_frameStack.empty )
		{
			if( TDataNode* valuePtr = _frameStack.back.findValue(varName) )
				return valuePtr;

			if( TDataNode* valuePtr = _frameStack.back._moduleFrame.findValue(varName) )
				return valuePtr;
		}

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
					// Right value was evaluated last so it goes first in the stack
					TDataNode rightVal = _stack.back;
					_stack.popBack();
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
					TDataNode rightVal = _stack.back;
					_stack.popBack();
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
					// Right value was evaluated last so it goes first in the stack
					TDataNode rightVal = _stack.back;
					_stack.popBack();
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
					// Right value was evaluated last so it goes first in the stack
					TDataNode rightVal = _stack.back;
					_stack.popBack();
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
					TDataNode rightVal = _stack.back;
					_stack.popBack();
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

				// Useless unary plus operation
				case OpCode.UnaryPlus:
				{
					assert( _stack.back.type == DataNodeType.Integer || _stack.back.type == DataNodeType.Floating,
						`Operand for unary plus operation must have integer or floating type!` );

					// Do nothing for now:)
					break;
				}

				case OpCode.UnaryMin:
				{
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
					assert( _stack.back.type == DataNodeType.Boolean,
						`Operand for unary minus operation must have boolean type!` );

					_stack.back = ! _stack.back.boolean;
					break;
				}

				case OpCode.Nop:
				{
					// Doing nothing here... What did you expect? :)
					break;
				}

				// Stores data from stack into local context frame variable
				case OpCode.StoreName:
				{
					assert( _stack.back.type == DataNodeType.String,
						`Variable name operand must have string type!` );

					string varName = _stack.back.str;
					_stack.popBack(); // Remove var name from stack

					setValue( varName, _stack.back );
					_stack.popBack(); // Remove var value from stack
					break;
				}

				// Loads data from local context frame variable by index of var name in module constants
				case OpCode.LoadName:
				{
					TDataNode nameNode = getModuleConst( instr.args[0] );
					assert( nameNode.type == DataNodeType.String, `Variable name operand must have string type!` );

					_stack ~= getValue( nameNode.str );
					break;
				}

				case OpCode.ImportModule:
				{
					assert( false, "Unimplemented yet!" );
					break;
				}

				case OpCode.ImportFrom:
				{
					assert( false, "Unimplemented yet!" );
					break;
				}

				case OpCode.InitLoop:
				{
					assert( false, "Unimplemented yet!" );
					break;
				}

				case OpCode.RunIter:
				{
					assert( false, "Unimplemented yet!" );
					break;
				}

				case OpCode.LoadDirective:
				{
					assert( _stack.back.type == DataNodeType.String,
						`Name operand for directive loading instruction should have string type` );
					string varName = _stack.back.str;

					_stack.popBack();

					assert( _stack.back.type == DataNodeType.CodeObject,
						`Code object operand for directive loading instruction should have CodeObject type` );

					CodeObject codeObj = _stack.back.codeObject;
					_stack.popBack(); // Remove code object from stack

					assert( codeObj, `Code object operand for directive loading instruction is null` );
					DirectiveObject dirObj = new DirectiveObject;
					dirObj._name = varName;
					dirObj._codeObj = codeObj;

					setLocalValue( varName, TDataNode(dirObj) ); // Put this directive in context

					break;
				}

				case OpCode.CallDirective:
				{
					import std.range: empty, popBack, back;

					assert( _stack.back.type == DataNodeType.Integer,
						`Expected integer as arguments count in directive call` );

					size_t stackArgCount = instr.args[0];
					writeln( "CallDirective stackArgCount: ", stackArgCount );
					assert( stackArgCount <= _stack.length, "Not enough arguments in execution stack" );
					writeln( "CallDirective _stack: ", _stack );
					assert( _stack[ _stack.length - stackArgCount ].type == DataNodeType.Directive, `Expected directive object operand in directive call operation` );

					DirectiveObject dirObj = _stack[ _stack.length - stackArgCount ].directive;
					assert( dirObj, `Directive object is null!` );

					newFrame( dirObj, getModuleFrame(dirObj._codeObj._moduleObj._name) );

					while( !_stack.empty )
					{
						if( _stack.back.type == DataNodeType.Integer )
						{
							size_t blockArgCount = _stack.back.integer >> 3;
							writeln( "blockArgCount: ", blockArgCount );
							int blockType = _stack.back.integer & 7;
							writeln( "blockType: ", blockType );
							_stack.popBack();

							if( blockType == 1 )
							{
								for( size_t i = 0; i < blockArgCount; ++i )
								{
									assert( !_stack.empty, "Execution stack is empty!" );
									TDataNode attrValue = _stack.back;
									_stack.popBack();
									assert( !_stack.empty, "Execution stack is empty!" );
									assert( _stack.back.type == DataNodeType.String, "Named attribute name must be string!" );
									string attrName = _stack.back.str;
									_stack.popBack();
									setLocalValue( attrName, attrValue );
								}
								writeln( "_stack after parsing named arguments: ", _stack );


							}
							else if( blockType == 2 )
							{

							}
							else
							{
								assert( false, "Unexpected arguments block type" );
							}
						}
						else
						{
							break;
						}
					}

					// TODO: Then let's try to get directive arguments and parse 'em

					assert( !_stack.empty, "Expected directive object to call, but found end of execution stack!" );
					assert( _stack.back.type == DataNodeType.Directive, `Expected directive object operand in directive call operation` );
					_stack.popBack();

					_stack ~= TDataNode(pk);
					codeRange = _frameStack.back._dirObj._codeObj._instrs[];
					pk = 0;

					continue execution_loop;
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

				_stack ~= result; // Get result back
			}

		}
	}
}
