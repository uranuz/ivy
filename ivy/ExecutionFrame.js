define('ivy/ExecutionFrame', [
	'ivy/Consts',
	'ivy/utils',
	'ivy/errors'
], function(
	Consts, iu, errors
) {
var
	FrameSearchMode = Consts.FrameSearchMode,
	DataNodeType = Consts.DataNodeType;
function ExecutionFrame(callableObj, modFrame, dataDict, isNoscope) {
	this._callableObj = callableObj;
	this._moduleFrame = modFrame;
	this._dataDict = dataDict || {};
	this._isNoscope = isNoscope || false;
};
return __mixinProto(ExecutionFrame, {
	getValue: function(varName) {
		var result = this.findValue(varName, FrameSearchMode.get);
		if( result.node === undefined && !result.allowUndef ) {
			throw new errors.IvyError('Cannot find variable with name: ' + varName);
		}
		return result.node;
	},

	canFindValue: function(varName) {
		return this.findValue(varName, FrameSearchMode.tryGet).node !== undefined;
	},

	getDataNodeType(varName) {
		var result = this.findValue(varName, FrameSearchMode.get);
		if( result.node === undefined ) {
			throw new errors.IvyError('Cannot find variable with name: ' + varName);
		}
		return iu.getDataNodeType(result.node);
	},
	// Basic method used to search symbols in context
	// This method searches inside current frame without taking _moduleFrame into account
	findLocalValue: function(varName, mode) {
		if( !varName ) {
			throw new errors.IvyError('Variable name cannot be empty');
		}

		var
			node = this._dataDict,
			nameSplitted = varName.split('.'),
			allowUndef = false,
			parent,
			namePart;

		for( var partIdx = 0; partIdx < nameSplitted.length; ++partIdx )
		{
			namePart = nameSplitted[partIdx];
			// Determines if in get mode we can return undef without error
			allowUndef = (nameSplitted.length - partIdx) === 1 && nameSplitted.length > 1;
			parent = node;
			node = undefined;

			switch( iu.getDataNodeType(parent) )
			{
				case DataNodeType.AssocArray:
				{
					var nodePtr = parent[namePart];
					if( nodePtr !== undefined ) {
						// If node exists in assoc array then push it as next parent node (or as a result if it's the last)
						node = nodePtr;
					} else {
						if( mode === FrameSearchMode.setWithParents ) {
							// In setWithParents mode we create parent nodes as assoc array if they are not exist
							parent[namePart] = {};
							node = parent[namePart];
						} else if( mode === FrameSearchMode.set ) {
							if( (nameSplitted.length - partIdx) === 1 ) {
								return {
									allowUndef: allowUndef,
									parent: parent
								};
							} else {
								// Only parent node should get there. And if it's not exists then issue an error in the set mode
								//loger.error(`Cannot set node with name: ` ~ varName ~ `, because parent node: ` ~ namePart.text ~ ` not exist!`);
								// Upd: In case when we using `set` in noscope directive we go into module scope of noscope directive
								// and failing to find parent object to place variable in it. In that case we should just say that
								// nothing is found instead if error and then go and find in parent scope of noscope directive
								return {allowUndef: false};
							}
						} else {
							return {allowUndef: allowUndef};
						}
					}
					break;
				}
				case DataNodeType.ExecutionFrame:
				{
					if( iu.getDataNodeType(parent._dataDict) !== DataNodeType.AssocArray )
					{
						if( mode === FrameSearchMode.tryGet ) {
							return {allowUndef: allowUndef};
						} else {
							throw new errors.IvyError(
								'Cannot find node, because execution frame data dict is not of assoc array type!!!');
						}
					}
					var nodePtr = parent._dataDict[namePart];
					if( nodePtr !== undefined ) {
						node = nodePtr;
					} else {
						if( [FrameSearchMode.setWithParents, FrameSearchMode.set].indexOf(mode) >= 0 ) {
							throw new errors.IvyError(
								'Cannot set node with name: ' + varName + ', because parent node: ' + namePart
								+ ' not exists or cannot set value in foreign execution frame!'
							);
						} else {
							return {allowUndef: allowUndef};
						}
					}
					break;
				}
				case DataNodeType.ClassNode: {
					// If there is class nodes in the path to target path, so it's property this way
					// No matter if it's set or get mode. The last node setting is handled by code at the start of loop
					var tmpNode = parent.getAttr(namePart);
					if( tmpNode !== undefined ) {
						node = tmpNode;
					} else {
						if( mode === FrameSearchMode.setWithParents || mode === FrameSearchMode.set ) {
							loger.error(
								'Cannot set node with name: ' + varName + ', because parent node: ' + namePart.text
								+ `not exist or cannot add new attribute to class node!`
							);
						} else {
							return {allowUndef: allowUndef};
						}
					}
					break;
				}
				default: {
					return {allowUndef: false, parent: parent};
				}
			}
		}

		return {allowUndef: (allowUndef || node === undefined), node: node, parent: parent};
	},

	findValue: function(varName, mode)
	{
		// If current frame has it's own scope then try to find in it.
		// If it is noscope then search into it's _moduleFrame, because we could still have some symbols there
		var result = this.findLocalValue(varName, mode);
		if( result.node !== undefined ) {
			return result;
		}

		var modResult = {};
		if( this._moduleFrame ) {
			modResult = this._moduleFrame.findLocalValue(varName, mode);
		}

		if( modResult.node !== undefined || modResult.allowUndef ) {
			return modResult;
		}
		return result;
	},

	_assignNodeAttribute: function(parent, value, varName) {
		var attrName = iu.back(varName.split('.'));
		switch( iu.getDataNodeType(parent) ) {
			case DataNodeType.AssocArray:
				parent[attrName] = value;
				break;
			case DataNodeType.ClassNode:
				parent.classNode.setAttr(value, attrName);
				break;
			default:
				throw new errors.IvyError('Unexpected node type');
		}
	},

	setValue: function(varName, value) {
		var result = this.findValue(varName, FrameSearchMode.set);
		this._assignNodeAttribute(result.parent, value, varName);
	},

	setValueWithParents(varName, value) {
		var result = this.findValue(varName, FrameSearchMode.setWithParents);
		this._assignNodeAttribute(result.parent, value, varName);
	},

	hasOwnScope: function() {
		return !!this._isNoscope;
	}
});
});