
let global = this

;(function () {
    /**
     * type which can be used in return
     * @type {string[]}
     * @private
     */
    let _hf_p_rtnTypes = ['BOOL', 'bool', 'size_t', 'int', 'void', 'char', 'short',
        'unsigned short', 'unsigned int', 'long,unsigned long', 'long long', 'unsigned long long',
        'float', 'double', 'CGFloat',
        'CGSize', 'CGRect', 'CGPoint', 'CGVector', 'NSRange',
        'NSInteger', 'NSUInteger',
        'id', 'Class', 'SEL', 'void*', 'void *']

    /**
     * type which can be used in argument
     * @type {*[]}
     * @private
     */
    let _hf_p_agrTypes = ['BOOL', 'bool', 'size_t', 'int', 'char', 'short',
        'unsigned short', 'unsigned int', 'long,unsigned long', 'long long', 'unsigned long long',
        'float', 'double', 'CGFloat',
        'CGSize', 'CGRect', 'CGPoint', 'NSRange',
        'NSInteger', 'NSUInteger',
        'id', 'Class', 'SEL', 'void*', 'void *']

    /**
     * Funcation Declare
     * @param self          object, instance if instance method, class if class method
     * @param invocation    object, including 3 function below
     *  run: Function() call the original method
     *  updateArgsAndRun: Function(array) update all arguments and call the original method
     *  updateArgAtIndexAndRun: Function(arg, index) update signal argument and call the original method
     * @param args          array,
     * @param _super        object, to call super method, only available under instance method
     * @private
     */
    let _hf_p_funcType = function (self, invocation, args, _super) {
        console.log(self, invocation, args, _super)
    }

    // log输出
    if (global.console) {
        let jsLogger = console.log;
        global.console.log = function () {
            global._hf_call_log.apply(global, arguments);
            if (jsLogger) {
                jsLogger.apply(global.console, arguments);
            }
        }
    } else {
        global.console = {
            log: global._hf_call_log
        }
    }

    /**
     * 注册类名，添加到global
     * @param clsName
     * @returns {*}
     * @private
     */
    let _hf_p_registerClass = function (clsName) {
        if (!global[clsName]) {
            global[clsName] = {
                _hf_v_clsName: clsName
            }
        }
        return global[clsName]
    }

    /**
     * 注册类名
     *
     * @returns {*}
     * @private
     */
    let _hf_g_require = function () {
        let hfLastRequire = undefined
        for (let i = 0; i < arguments.length; i++) {
            arguments[i].split(',').forEach(function (clsName) {
                hfLastRequire = _hf_p_registerClass(clsName.trim())
            })
        }
        return hfLastRequire
    }

    /**
     * 返回hook后的函数
     * @param fixFunction 实际调用函数
     * @returns {function(*=, *=, *): *}
     * @private
     */
    let _hf_p_realFunc = function (fixFunction) {
        return function (instance, invocation, args) {
            let _super = {
                _hf_v_instance: instance,
                _hf_v_isSuper: true
            }

            let fix_args = []
            for (let arg of args) {
                fix_args.push(arg ?? false)
            }

            return fixFunction(instance, invocation, fix_args, _super)
        }
    }

    /**
     * fix 方法
     * @param clsName       String，类名
     * @param selector      String，方法名
     * @param isClassMethod BOOL，是否为类方法，为空则 false
     * @param selectorType  String，方法类型，'before'/'instead'/'after'，为空则 instead
     * @param fixFunction   具体方法
     * @private
     * @discussion          可以通过 _super 使用 super
     */
    let _hf_g_fixMethod = function (clsName, selector, isClassMethod, selectorType, fixFunction) {
        /**
         * 设置默认值
         * isClassMethod: false
         * selectorType: 'instead'
         */
        if (isClassMethod instanceof Function) {
            fixFunction = isClassMethod
            selectorType = 'instead'
            isClassMethod = false
        } else if (typeof (isClassMethod) == 'string') {
            fixFunction = selectorType
            selectorType = isClassMethod
            isClassMethod = false
        } else if (selectorType instanceof Function) {
            fixFunction = selectorType
            selectorType = 'instead'
        }

        let realFun = _hf_p_realFunc(fixFunction)

        _hf_call_fixMethod(clsName, selector, isClassMethod, selectorType, realFun)
    }

    /**
     * 自定义函数，内嵌
     * @type {{_hf_catch_realFun: (function(*=): ((function(): boolean)|(function(): void)))}}
     * @private
     */
    let _hf_p_bind_customMethods = {
        /**
         * 核心替换函数
         *
         * @param methodName
         * @returns {(function(): boolean)|(function(): void)}
         * @private
         */
        _hf_catch_realFun: function (methodName) {
            let slf = this

            // nil 替换为 false
            if (slf instanceof Boolean || typeof (slf) == 'boolean') {
                return function () {
                    return false
                }
            }

            // 适配 string 类型被转义成 String object
            if (slf instanceof String) {
                slf = slf.toString()
            }

            // 内部方法
            if (slf[methodName]) {
                return slf[methodName].bind(slf);
            }

            return function () {
                let args = Array.prototype.slice.call(arguments)

                let isSuper = !!slf._hf_v_isSuper
                if (isSuper) slf = slf._hf_v_instance

                let clsName = slf._hf_v_clsName
                if (clsName) slf = undefined

                methodName = methodName.replace(/__/g, "-")
                methodName = methodName.replace(/_/g, ":").replace(/-/g, "_")
                let marchArr = methodName.match(/:/g)
                let numOfArgs = marchArr ? marchArr.length : 0
                if (args.length > numOfArgs) {
                    methodName += ":"
                }

                let rtn = _hf_call_invocation(slf, clsName, methodName, args, isSuper)
                if (!rtn) rtn = false
                return rtn
            }
        },
    }

    /**
     * 绑定内置方法
     */
    for (let method in _hf_p_bind_customMethods) {
        if (_hf_p_bind_customMethods.hasOwnProperty(method)) {
            Object.defineProperty(Object.prototype, method, {
                value: _hf_p_bind_customMethods[method],
                configurable: false,
                enumerable: false
            })
        }
    }

    /**
     * 包装block
     * @param rtnType       String, 参考 _hf_p_rtnTypes
     * @param args          Array, 参考 _hf_p_agrTypes
     * @param callbackFun   Function
     * @returns             {{_hf_v_callback: (function(): *), _hf_v_argCount: *, _hf_v_isBlock: number, _hf_v_args: Array, _hf_v_rtnType: string}}
     * @private
     * @discussion
     */
    let _hf_g_block = function (rtnType, args, callbackFun) {
        /**
         * 设置默认值
         * rtnType：''
         * args：[]
         */
        if (rtnType instanceof Function) {
            callbackFun = rtnType
            args = []
            rtnType = 'void'
        } else if (rtnType instanceof Array) {
            callbackFun = args
            args = rtnType
            rtnType = 'void'
        } else if (args instanceof Function) {
            callbackFun = args
            args = []
        }

        let that = this
        // 用函数包装，获取入参
        let realCallback = function () {
            let args = Array.prototype.slice.call(arguments)
            let fix_args = []
            for (let arg of args) {
                fix_args.push(arg ?? false)
            }

            return callbackFun.apply(that, fix_args)
        }

        return {
            _hf_v_rtnType: rtnType,
            _hf_v_args: args,
            _hf_v_callback: realCallback,
            _hf_v_argCount: callbackFun.length,
            _hf_v_isBlock: 1
        }
    }

    /**
     * 调用block
     * @private
     */
    let _hf_g_callBlock = function () {
        let args = Array.prototype.slice.call(arguments)
        return _hf_call_callBlock(args[0], args.slice(1, args.length))
    }

    /**
     * 生成协议
     */
    let _hf_g_protocol = function (protocol) {
        return _hf_call_protocol(protocol)
    }

    /**
     * 定义类，属性，实例方法，类方法
     * @param clsName       string，类名，若类不存在，则动态创建
     * @param superName     string，父类名, 若类已存在, 可省略, 默认为 NSObject
     * @param implenment    object，包括3个key: property/instanceMethod/classMethod
     *  property:       object 可省略, 简写：{name: type}, 详细：{name: {type: 'type', role: 'weak/copy/strong/assign', getter: 'function', setter: 'function'}}
     *  instanceMethod: object 实例方法, 可省略, 简写：{name: function}, 详细：{name: {rtnType: 'rtnType', arges: '[args]', func: 'function'}}
     *  classMethod:    object 类方法, 可省略, 与实例方法一致
     * @private
     */
    let _hf_g_definedClass = function (clsName, superName, implenment) {
        if (superName instanceof Object) {
            implenment = superName
            superName = 'NSObject'
        }

        // 动态添加类
        _hf_call_addCls(clsName, superName)
        _hf_g_require(clsName)
        
        implenment = implenment ?? {}
        let propertys = implenment['property'] ?? {}
        let instanceMethods = implenment['instanceMethod'] ?? {}
        let classMethods = implenment['classMethod'] ?? {}

        if (!implenment.hasOwnProperty('property') && !implenment.hasOwnProperty('instanceMethod') && !implenment.hasOwnProperty('classMethod')) {
            instanceMethods = implenment
        }

        for (let propertyName in propertys) {
            let propertysAtt = propertys[propertyName]
            if (typeof propertysAtt == 'string') {
                propertysAtt = {'type': propertysAtt}
            }

            let proType = propertysAtt['type']
            let getter = propertysAtt['getter']
            let setter = propertysAtt['setter']

            // 暂时不支持
            // let readonly = propertysAtt['readonly']
            // let atomic = propertysAtt['atomic']
            // let isClass = propertysAtt['isClass']

            let att = {}
            if (propertysAtt['role']) {
                att['_hf_v_role'] = propertysAtt['role']
            }

            _hf_call_addProperty(propertyName, clsName, proType, att, getter, setter)
        }

        let _method_implement = function (methodName, methodAtt, isClass) {

            let fixType = methodAtt['fixType'] ?? 'instesd'

            let rtnType = methodAtt['rtnType'] ?? 'void'
            let args = methodAtt['args'] ?? []
            let func = methodAtt['func']

            methodName = methodName.replace(/__/g, "-")
            methodName = methodName.replace(/_/g, ":").replace(/-/g, "_")
            let marchArr = methodName.match(/:/g)
            let numOfArgs = marchArr ? marchArr.length : 0
            if (args.length > numOfArgs) {
                methodName += ":"
            }

            if (numOfArgs > 0 && !methodName.endsWith(':')) {
                methodName += ":"
            }

            let realFun = _hf_p_realFunc(func)
            if (fixType == 'before' || fixType == 'after') {
                _hf_call_fixMethod(clsName, methodName, isClass, fixType, realFun)
            } else {
                _hf_call_addMethod(methodName, clsName, isClass, rtnType, args, realFun)
            }
        }

        for (let method in instanceMethods) {
            let methodAtt = instanceMethods[method]
            if (methodAtt instanceof Function) {
                methodAtt = {func: methodAtt}
            }
            _method_implement(method.toString(), methodAtt, false)
        }

        for (let method in classMethods) {
            let methodAtt = classMethods[method]
            if (methodAtt instanceof Function) {
                methodAtt = {func: methodAtt}
            }
            _method_implement(method.toString(), methodAtt, true)
        }
    }

    /**
     * 构建异步类，具体解析见 _hf_g_dispatch
     * @returns {{main: (function(): {async: function(*=): void, isMain, after: function(*, *=): void, priority, sync: function(*=): void}), globalQueue: (function(*=): {async: function(*=): void, isMain, after: function(*, *=): void, priority, sync: function(*=): void})}}
     * @private
     */
    let _hf_p_dispatch = function () {
        // 定义任务
        let _hf_p_dispatch_done = function (isMain, priority, async, after, func) {
            _hf_call_dispatch(isMain, priority, async, after, func)
        }

        let _hf_p_dispatch_async = function (func) {
            _hf_p_dispatch_done(this._hf_v_isMain, this._hf_v_priority, true, 0, func)
        }

        let _hf_p_dispatch_sync = function (func) {
            _hf_p_dispatch_done(this._hf_v_isMain, this._hf_v_priority, false, 0, func)
        }

        let _hf_p_dispatch_after = function (after, func) {
            _hf_p_dispatch_done(this._hf_v_isMain, this._hf_v_priority, true, after ?? 0, func)
        }

        // 定义线程
        let _hf_p_dispatch_queue = function (isMain, priority) {
            return {
                async: _hf_p_dispatch_async,
                sync: _hf_p_dispatch_sync,
                after: _hf_p_dispatch_after,
                _hf_v_isMain: isMain ?? true,
                _hf_v_priority: priority ?? 'default'
            }
        }

        let _hf_p_dispatch_main = function () {
            return _hf_p_dispatch_queue(true)
        }

        let _hf_p_dispatch_global = function (priority) {
            return _hf_p_dispatch_queue(false, priority)
        }

        return {
            main: _hf_p_dispatch_main,
            globalQueue: _hf_p_dispatch_global
        }
    }

    /**
     * 异步调用类，返回对象包含参数为线程函数：
     *  main: function 主线程;
     *  globalQueue：function(priority: 'default/high/low') 异步线程
     * 线程返回对象参数为任务函数，函数最后入参均为 function()
     *  async: function 异步，非堵塞;
     *  sync: function 同步，堵塞;
     *  after: function(after: '时间（秒/浮点型）') 延时调用，异步，非堵塞;
     * @type {{main: (function(): {async: function(*=): void, isMain, after: function(*, *=): void, priority, sync: function(*=): void}), globalQueue: (function(*=): {async: function(*=): void, isMain, after: function(*, *=): void, priority, sync: function(*=): void})}}
     * @private
     */
    let _hf_g_dispatch = _hf_p_dispatch()

    /**
     * 定义单例
     * @param key   string 单例唯一标识
     * @param func  无参函数
     * @private
     */
    let _hf_g_dispatch_once = function (key, func) {
        _hf_call_once(key, func)
    }

    // global.YES = 1
    // global.NO = 0

    // 声明 OC类，可以是字符串，或者字符串数组
    global.hf_require = _hf_g_require
    // 替换方法
    global.hf_fixMethod = _hf_g_fixMethod
    // 包装block
    global.hf_block = _hf_g_block
    // 调用block, 第一个参数为 fun， 之后是block的参数
    // 只有当block的入参包含block时，才需要调用，其他情况直接 block() 即可
    global.hf_callBlock = _hf_g_callBlock
    // 生成协议
    global.hf_protocol = _hf_g_protocol
    // 类定义
    global.hf_definedClass = _hf_g_definedClass
    // 异步类
    global.hf_dispatch = _hf_g_dispatch
    // 单例
    global.hf_dispatchOnce = _hf_g_dispatch_once

    /**
     * 结构体
     */
    global.hf_rect = _hf_call_rect   // CGRect   解包模式，没有origin和size，直接调用x, y, width, height
    global.hf_piont = _hf_call_point // CGPoint
    global.hf_size = _hf_call_size   // CGSize
    global.hf_range = _hf_call_range // NSRange

    /**
     * 以下的方法，均为无入参方法，直接调用即可
     */
    global.hf_null = _hf_call_null   // 空对象

    global.hf_floatMin = _hf_call_floatMin   // CGFLOAT_MIN
    global.hf_floatMax = _hf_call_floatMax   // CGFLOAT_MAX
    global.hf_intMin = _hf_call_intMin       // NSIntegerMin
    global.hf_intMax = _hf_call_intMax       // NSIntegerMax

})()


