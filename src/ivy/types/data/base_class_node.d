module ivy.types.data.base_class_node;

import ivy.types.data.iface.class_node: IClassNode;

class BaseClassNode: IClassNode
{
	import ivy.types.data.iface.range: IvyDataRange;
	import ivy.types.data: IvyData;
	import ivy.types.data.exception: NotImplException;
	import ivy.types.iface.callable_object: ICallableObject;

protected:
	string _getClassName() {
		return typeid(this).name;
	}
	enum string notImplMixin = `throw new NotImplException(_getClassName(), __FUNCTION__);`;

public:
	override {
		IvyDataRange opSlice() {
			mixin(notImplMixin);
		}
		IClassNode opSlice(size_t, size_t) {
			mixin(notImplMixin);
		}
		IvyData opIndex(IvyData) {
			mixin(notImplMixin);
		}
		IvyData __getAttr__(string) {
			mixin(notImplMixin);
		}
		void __setAttr__(IvyData, string) {
			mixin(notImplMixin);
		}
		IvyData __serialize__() {
			mixin(notImplMixin);
		}
		ICallableObject __call__() {
			mixin(notImplMixin);
		}
		size_t length() @property {
			mixin(notImplMixin);
		}
		bool empty() @property
		{
			// By default implement empty with check for length
			try {
				return this.length == 0;
			} catch(NotImplException) {}
			// If there is no logic of emptyness implemented then consider it's not empty
			return false;
		}
	}
}