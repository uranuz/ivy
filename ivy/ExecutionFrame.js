define('ivy/ExecutionFrame', [
	'ivy/Consts'
], function(
	Consts
) {
var FrameSearchMode = Consts.FrameSearchMode;
function ExecutionFrame(callableObj, modFrame, dataDict, isNoscope) {
	this._callableObj = callableObj;
	this._moduleFrame = modFrame;
	this._dataDict = dataDict || {};
	this._isNoscope = isNoscope || false;
};
return __mixinProto(ExecutionFrame, {
	// Basic method used to search symbols in context
	// This method searches inside current frame without taking _moduleFrame into account
	findLocalValue: function(varName, mode)
	{
		if( !varName ) {
			throw new Error('Variable name cannot be empty');
		}

		var
			node = _dataDict,
			nameSplitted = varName.split('.'),
			allowUndef = false,
			parent,
			namePart;

		for( var partIdx = 0; partIdx < nameSplitted.length; ++partIdx )
		{
			namePart = nameSplitted[partIdx];
			// Determines if in get mode we can return undef without error
			allowUndef = nameSplitted.length > 1 && (nameSplitted.length - partIdx) === 1;
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
							if( nameSplitted.length - partIdx === 1 ) {
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
					if( parent._dataDict.type !== DataNodeType.AssocArray )
					{
						if( mode === FrameSearchMode.tryGet ) {
							return {allowUndef: allowUndef};
						} else {
							throw new Error(`Cannot find node, because execution frame data dict is not of assoc array type!!!`);
						}
					}
					var nodePtr = parent._dataDict[namePart];
					if( if nodePtr !== undefined  ) {
						node = nodePtr;
					} else {
						if( [FrameSearchMode.setWithParents, FrameSearchMode.set].indexOf(mode) > 0 ) {
							throw new Error(
								`Cannot set node with name: ` ~ varName ~ `, because parent node: ` ~ namePart
								~ ` not exists or cannot set value in foreign execution frame!`
							);
						} else {
							return {allowUndef: allowUndef};
						}
					}
					break;
				}
				case DataNodeType.ClassNode:
				{
					if( !parent.classNode )
					{
						if( mode === FrameSearchMode.tryGet ) {
							return {allowUndef: allowUndef};
						} else {
							loger.error(`Cannot find node, because class node is null!!!`);
						}
					}

					// If there is class nodes in the path to target path, so it's property this way
					// No matter if it's set or get mode. The last node setting is handled by code at the start of loop
					TDataNode tmpNode = parent.classNode.__getAttr__(namePart);
					if( !tmpNode.isUndef )  {
						node = tmpNode;
					} else {
						if( mode === FrameSearchMode.setWithParents || mode === FrameSearchMode.set ) {
							loger.error(
								`Cannot set node with name: ` ~ varName ~ `, because parent node: ` ~ namePart.text
								~ `not exist or cannot add new attribute to class node!`
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

		return {allowUndef: allowUndef || node === undefined, node: node, parent: parent};
	},

	findValue: function(varName, mode)
	{
		// If current frame has it's own scope then try to find in it.
		// If it is noscope then search into it's _moduleFrame, because we could still have some symbols there
		FrameSearchResult result = findLocalValue!(mode)(varName);

		if( !result.node.isUndef )
			return result;

		FrameSearchResult modResult;
		if( _moduleFrame ) {
			modResult = _moduleFrame.findLocalValue!(mode)(varName);
		}

		if( !modResult.node.isUndef || modResult.allowUndef )
			return modResult;
		return result;
	}
});
});