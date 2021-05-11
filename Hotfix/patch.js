// GUARD
;(function () {
    // import Class
    hf_require('UIView', 'UIColor')

    // Thread Tasks
    ;(function () {
        // Async Task on Main Queue
        hf_dispatch.main().async(function () {
            console.log('run in main queue async')
        })

        // Sync Task on Main Queue
        // Js run on Main Queue, if run a sync task on Main Queue, will make a dead lock
//        hf_dispatch.main().sync(function () {
//            console.log('run in main queue sync')
//        })

        // Async Task run After 1s on Main Queue
        hf_dispatch.main().after(1, function () {
            console.log('run in main queue async after 1 second')
        })

        // GlobalQueue argument: default/high/low, defalut is `default`
        // The same as Main, with Task type: async/sync/after
        hf_dispatch.globalQueue('defalut').async(function () {
            console.log('run in global queue async')
        })

        // without argument, `default`
        hf_dispatch.globalQueue().async(function () {
            console.log('run in global queue async')
        })
        
        /**
         * Once Task
         *
         *  key: string, signature of the task, make sure key is unique
         *  func: func
         */
        hf_dispatchOnce('once', function () {
            console.log('static once mode')
        })
    })()


    ;(function () {

        /**
         * Define the Class, property, instance method, class method
         *  define a class dynamically if it is not exist
         *  defind instance/class method if it is not exist, hook if exist
         *
         *  className: string, class name
         *  superName: string(nullable), super class name, default is `NSObject`
         *  object: object
         *      property:       object(nullable), define property
         *      instanceMethod: object(nullable), define or hook instance Method
         *      classMethod:    object(nullable), define or hook class Method
         */
        hf_definedClass('TestClass', 'JsPatchTestBase', {

            /**
             * Add property dynamically, with `getter` and `setter` method automatically
             *
             *  key: string, property name
             *  value: object/string, property type if string, object as below
             *      type: string, property type, can not be `Void`, reference with `_hf_p_rtnTypes` on `patchGlobal.js`
             *      role: string, property retain type in `weak/copy/strong/assign`, default is `assign` or `strong`
             *      getter: Function, getter method, the base getter method will be implemented Whether with a getter Func or not.
             *      setter: Function, setter method, as getter
             *
             */
            property: {
                /**
                 * add `pro1` property with `id` type, Obj-C Code as below
                 * @property (nonatomic, strong) id pro1;
                 */
                pro1: 'id',


                /**
                 * Add `pro2` property with `id` type, and hook getter and setter method
                 *  using invocation.run() to call the original method and get the return value
                 *
                 * @property (nonatomic, weak) id pro2;
                 */
                pro2: {
                    type: 'id',
                    role: 'weak',
                    getter: function (self, invocation, args) {
                        console.log(self, invocation, args)
                        return invocation.run()
                    },
                    setter: function (self, invocation, args) {
                        console.log(self, invocation, args)
                        invocation.run()
                    }
                },

                
                /**
                 * add `pro3` property with `NSInteger` type, Obj-C Code as below
                 * @property (nonatomic, assign) NSInteger pro3;
                 */
                pro3: 'NSInteger',

                
                /**
                 * add `pro4` property with `NSInteger` type, Obj-C Code as below
                 * @property (nonatomic, assign) NSInteger pro4;
                 */
                pro4: {
                    type: 'NSInteger',
                    role: 'assign',
                    getter: function (self, invocation, args) {
                        console.log(self, invocation, args)
                        return invocation.run()
                    },
                    setter: function (self, invocation, args) {
                        console.log(self, invocation, args)
                        invocation.run()
                    }
                }
            },

            /**
             * Define method dynamically if not exist, hook if exist
             *
             *  key: strong, method name, `_` instead of `:`, `__` instead of `_`
             *      like `p_test:name:age:` write as `p__test_name_age_` or `p__test_name_age`
             *          PS: the last `_` can be ignore as below
             *          1. `_` has already exist
             *          2. the count of `args` more than count of `_`,
             *              like `test:` can be write as test: , args: ['id']
             *  value: object / Function, default: fixType: instead, rtnType: 'void', args: []
             *      rtnType: string(nullable), return type, default is `Void`, reference with `_hf_p_rtnTypes` on `patchGlobal.js`
             *      args: Array<string>(nullbale), args type, defult is `[]`
             *      fixType: string(nullbale), hook type, the method must be exist, default is `instead`
             *      func: Function, reference with `_hf_p_funcType` on `patchGlobal.js`
             *
             */
            instanceMethod: {
                /**
                 * add or hook `method0:`
                 *  - (NSInteger)method0:(id)arg0;
                 */
                method0_: {
                    rtnType: 'NSInteger',
                    args: ['id'],
                    func: function (self, invocation, args, _super) {
                        console.log(self, invocation, args, _super)
                        return 1
                    }
                },

                /**
                 * hook `method1:name:age:` method, if the method is exist, rtnType and args can be ignore.
                 * @param self
                 * @param invocation
                 * @param args
                 */
                method1_name_age: function (self, invocation, args, _super) {
                    console.log(self, invocation, args, _super)
                },

                /**
                 * add or hook `method2` method, rtnType: 'void', args: []
                 *  - (void)method2;
                 *
                 * @param self
                 * @param invocation
                 * @param args
                 */
                method2: function (self, invocation, args, _super) {
                    console.log(self, invocation, args, _super)
                },

                /**
                 * add or hook `method3:name:age:` method,
                 *  - (CGFloat)method3:(id)method name:(id)name age:(NSInteger)age;
                 *
                 * @param self
                 * @param invocation
                 * @param args
                 */
                method3_name_age: {
                    rtnType: 'CGFloat',
                    args: ['id', 'id', 'NSInteger'],
                    func: function (self, invocation, args, _super) {
                        console.log(self, invocation, args, _super)
                        return 1
                    }
                },

            },

            /**
             * class method, as instance method
             */
            classMethod: {}

        })

        /**
         * define class `TestClass` which super class is `NSObject`
         */
        hf_definedClass('TestClass', {
            // ...
        })

    })()

})()


/**
 *  DEMO
 *
 */

hf_require('UIView', 'UIColor', 'UIButton');

hf_definedClass('ViewController', {
    instanceMethod: {
        // hook viewDidLoad
        viewDidLoad: function (self, invocation, args, _super) {
            _super.viewDidLoad()
            var button = UIButton.buttonWithType(0)
            button.setFrame(hf_rect(100, 100, 100, 100))
            button.setTitle_forState('push', 0)
            button.setBackgroundColor(UIColor.redColor())
            button.addTarget_action_forControlEvents(self, 'click', 64)
            self.view().addSubview(button)
        },
        
        // add click method
        click: function (self, invocation, args, _super) {
            console.log('push')
            var vc = DynamicViewController.alloc().init()
            self.navigationController().pushViewController_animated(vc, true)
        }
    }
});

// add DynamicViewController class
hf_definedClass('DynamicViewController', 'UIViewController', {
    instanceMethod: {
        // hook viewDidLoad
        viewDidLoad: function (self, invocation, args, _super) {
            _super.viewDidLoad()
            self.setTitle("dynamic VC")
            self.view().setBackgroundColor(UIColor.greenColor())
        },
    }
});

// sharedInstance
var _sharedInstance_ShareObject
hf_definedClass('ShareObject', {
    classMethod: {
        sharedInstance: {
            rtnType: 'id',
            func: function (self, invocation, args, _super) {
                hf_dispatchOnce('_sharedInstance', function () {
                    _sharedInstance_ShareObject = ShareObject.alloc().init()
                })
                return _sharedInstance_ShareObject
            },
        }
    }
});
