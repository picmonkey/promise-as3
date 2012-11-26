////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2011 CodeCatalyst, LLC - http://www.codecatalyst.com/
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
////////////////////////////////////////////////////////////////////////////////

package com.picmonkey.promise
{
    /**
     * Deferred.
     *
     * A chainable utility object that can register multiple callbacks into callback queues, invoke callback queues,
     * and relay the success, failure and progress _state of any synchronous or asynchronous operation.
     *
     * @see com.picmonkey.util.promise.Promise
     *
     * Inspired by jQuery's Deferred implementation.
     *
     * @author John Yanarella
     * @author Thomas Burleson
     */
    public class Deferred
    {
        // ========================================
        // Public constants
        // ========================================

        /**
         * State for a Deferred that has not yet been resolved or rejected.
         */
        public static const PENDING_STATE:String = "pending";

        /**
         * State for a Deferred that has been resolved.
         */
        public static const RESOLVED_STATE:String = "resolved";

        /**
         * State for a Deferred that has been rejected.
         */
        public static const REJECTED_STATE:String = "rejected";

        // ========================================
        // Public properties
        // ========================================

        /**
         * Promise.
         */
        public function get promise():Promise
        {
            return _promise;
        }

        /**
         * Exposes read-only value of current state
         */
        public function get state():String
        {
            return _state;
        }


        /**
         * Indicates this Deferred has not yet been resolved or rejected.
         */
        public function get pending():Boolean
        {
            return ( _state == PENDING_STATE );
        }


        /**
         * Indicates this Deferred has been resolved.
         * Alias function; used to match jQuery API
         */
        public function get resolved():Boolean {
            return ( _state == RESOLVED_STATE );
        }

        /**
         * Indicates this Deferred has been rejected.
         * Alias function; used to match jQuery API
         */
        public function get rejected():Boolean {
            return ( _state == REJECTED_STATE );
        }

        /**
         * Progress supplied when this Deferred was updated.
         */
        public function get status():*
        {
            return notifyDispatcher.lastMemory;
        }

        /**
         * Result supplied when this Deferred was resolved.
         */
        public function get result():*
        {
            return resolveDispatcher.lastMemory;
        }

        /**
         * Error supplied when this Deferred was rejected.
         */
        public function get error():*
        {
            return rejectDispatcher.lastMemory;
        }

        // ========================================
        // Constructor
        // ========================================

        /**
         * Constructor.
         */
        public function Deferred(callback:Function=null)
        {
            super();
            init();

            if ( callback != null )
                {
                    // Only change handler/callback context if
                    // it expects an instance of Deferred

                    callback.apply( this, callback.length ? [this] : [ ] );
                }
        }



        // ========================================
        // Public Callback-registration Methods
        // ========================================

        /**
         * Alias to support jQuery API
         *
         * @param callbacks Function or Function[ ]
         */
        public function done( callbacks:*=null ) :Deferred {
            return onResult(callbacks);
        }

        /**
         * Alias to support jQuery API
         *
         * @param callbacks Function or Function[ ]
         */
        public function fail( callbacks:*=null ) :Deferred {
            return onError(callbacks);
        }

        /**
         * Alias to support jQuery API
         *
         * @param callbacks Function or Function[ ]
         */
        public function progress( callbacks:*=null ) :Deferred {
            return onProgress(callbacks);
        }

        /**
         * Register callbacks to be called when this Deferred is resolved, rejected and updated.
         */
        public function then( resultCallback:Function=null, errorCallback:Function = null, progressCallback:Function = null ):Deferred
        {
            return onResult  ( resultCallback   ).
                onError   ( errorCallback    ).
                onProgress( progressCallback );
        }

        /**
         * Registers a callback to be called when this Deferred is
         * either resolved or rejected.
         *
         * @param callbacks Function or Function[ ]
         */
        public function always( callbacks:*=null ):Deferred
        {
            onResult  ( callbacks );
            onError       ( callbacks );

            return this;
        }

        /**
         * Utility method to filter and/or chain Deferreds.
         */
        public function pipe( fnResolve:*=null, fnReject:*=null, fnUpdate:*=null ):Promise
        {
            // Create closure reference to `this` context

            var origin : Deferred = this;

            // Return wrapper Deferred that will be triggered when `origin` responds
            // via origin.resolve(), origin.reject(), origin.notify(), or origin.cancel()

            return new Deferred( function( dfd:Deferred ):void {

                    iterate(
                            {
                            done       : [fnResolve, "resolve"],
                                    fail       : [fnReject,  "reject"],
                                    progress   : [fnUpdate,  "notify"]
                                    },
                            function (handler:String, data:Array):void {

                                var func     : *      = data[0],
                                    action   : String = data[1];

                                if (func is Function)
                                    {
                                        // When current/origin future responds, then call the func()

                                        origin[handler]( function(...args):void {

                                                // func() could produce another promise or a value that must be <xxx>With()

                                                var val     : *       = func.apply(origin, args),
                                                    promise : Promise = (val is Deferred) ? Deferred(val).promise   :
                                                    (val is Promise)  ? Promise(val)            : null;

                                                if ( promise ) {
                                                    // This code supports pipe(<doneFunc>) rejecting with a Promise

                                                    promise.then(dfd.resolve, dfd.reject, dfd.notify );

                                                } else {
                                                    // Call the resolveWith(), rejectWith(), etc functions

                                                    dfd[action + "With"]( this==origin ? dfd : origin, [ val ] );
                                                }
                                            });

                                    } else {
                                    // e.g. this.done( dfd.resolve )

                                    origin[handler]( dfd[action] );
                                }
                            }
                             );

            }).promise;
        }

        /**
         * Registers a callback to be called when this Deferred is resolved.
         *
         * @param callbacks Function or Function[ ]
         */
        public function onResult( callbacks:* ):Deferred
        {
            resolveDispatcher.add( callbacks );
            return this;
        }

        /**
         * Registers a callback to be called when this Deferred is rejected.
         *
         * @param callbacks Function or Function[ ]
         */
        public function onError( callbacks:* ):Deferred
        {
            rejectDispatcher.add( callbacks );
            return this;
        }


        /**
         * Registers a callback to be called when this Deferred is updated.
         *
         * @param callbacks Function or Function[ ]
         */
        public function onProgress( callbacks:* ):Deferred
        {
            notifyDispatcher.add( callbacks );
            return this;
        }


        // *******************************************************************
        // Public actions/triggers
        // *******************************************************************


        /**
         * Resolve this Deferred and notifyCallbacks relevant callbacks.
         */
        public function resolve(...args):Deferred
        {
            resolveDispatcher.fire.apply(null, args);
            return this;
        }

        /**
         * Reject this Deferred and notifyCallbacks relevant callbacks.
         */
        public function reject(...args):Deferred
        {
            rejectDispatcher.fire.apply(null, args);
            return this;
        }

        /**
         *  Update this Deferred and notifyCallbacks relevant callbacks.
         */
        public function notify(...args):Deferred
        {
            notifyDispatcher.fire.apply(null, args);
            return this;
        }

        // ***************************************************************
        // Special methods used by the pipe() feature
        // ***************************************************************

        internal function resolveWith(context:Object,args:Array):Deferred
        {
            resolveDispatcher.fireWith(context,args);
            return this;
        }

        internal  function rejectWith(context:Object,args:Array):Deferred
        {
            rejectDispatcher.fireWith(context,args);
            return this;
        }

        internal  function notifyWith(context:Object,args:Array):Deferred
        {
            notifyDispatcher.fireWith(context,args);
            return this;
        }


        // ========================================
        // Protected methods
        // ========================================

        /**
         * Configure the callbacks and then add `actions` to be performed
         * when resolved or rejected.
         */
        protected function init():void {

            _promise            = new Promise( this );

            resolveDispatcher   = new Callbacks("once memory");
            rejectDispatcher    = new Callbacks("once memory");
            notifyDispatcher    = new Callbacks("memory");

            // Add actions to be triggered when resolved!

            resolveDispatcher.add(
                                  function():void  { setState( Deferred.RESOLVED_STATE ); },
                                  function():void  { rejectDispatcher.disable();              },
                                  function():void  { notifyDispatcher.lock();             }
                                  );

            // Add actions to be triggered when rejected!

            rejectDispatcher.add(
                                 function():void  { resolveDispatcher.disable();         },
                                 function():void  { setState( Deferred.REJECTED_STATE ); },
                                 function():void  { notifyDispatcher.lock();             }
                                 );
        }

        /**
         * Set the _state for this Deferred.
         *
         * @see #pending
         * @see #resolved
         * @see #rejected
         */
        protected function setState( value:String ):void
        {
            if ( value != _state )
                {
                    _state = value;
                }
        }

        /**
         * For each item in `list` call the `iterator` function
         */
        protected function iterate( list:Object, iterator:Function) : void {
            /**
             * Note: In AS3, Typed-Class properties cannot be enumerated this way
             *       but this works for array and dynamic objects
             */
            for (var key:* in list)
                {
                    iterator.call( null, key, list[key] );
                }
        }

        // ========================================
        // Protected properties
        // ========================================

        /**
         * Backing variable for <code>promise</code> property.
         */
        protected var _promise:Promise = null;


        /**
         * Deferred _state.
         *
         * @see #STATE_PENDING
         * @see #STATE_RESOLVED
         * @see #STATE_REJECTED
         */
        protected var _state:String = Deferred.PENDING_STATE;

        /**
         * Callbacks to be called when this Deferred is resolved.
         */
        protected var resolveDispatcher:Callbacks;;

        /**
         * Callbacks to be called when this Deferred is rejected.
         */
        protected var rejectDispatcher:Callbacks;;

        /**
         * Callbacks to be called when this Deferred is updated.
         */
        protected var notifyDispatcher:Callbacks;;
    }
}
