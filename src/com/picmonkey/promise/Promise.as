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
    import flash.utils.clearInterval;
    import flash.utils.setTimeout;

    /**
     * Promise.
     *
     * An object that acts as a proxy for observing deferred result, fault or progress state from a synchronous or asynchronous operation.
     *
     * Inspired by jQuery's Promise implementation.
     *
     * @author John Yanarella
     * @author Thomas Burleson
     */
    public class Promise
    {
        // ========================================
        // Public properties
        // ========================================

        /**
         * Indicates this Promise has not yet been fulfilled.
         */
        public function get pending():Boolean
        {
            return deferred.pending;
        }

        /**
         * Indicates this Promise has been fulfilled.
         */
        public function get resolved():Boolean
        {
            return deferred.resolved;
        }

        /**
         * Indicates this Promise has failed.
         */
        public function get rejected():Boolean
        {
            return deferred.rejected;
        }

        /**
         * Progress supplied when this Promise was updated.
         */
        public function get status():*
        {
            return deferred.status;
        }

        /**
         * Result supplied when this Promise was fulfilled.
         */
        public function get result():*
        {
            return deferred.result;
        }

        /**
         * Error supplied when this Promise failed.
         */
        public function get error():*
        {
            return deferred.error;
        }

        // ========================================
        // Protected properties
        // ========================================

        /**
         * Deferred operation for which this is a Promise.
         */
        protected var deferred:Deferred = null;

        // ========================================
        // Constructor
        // ========================================

        /**
         * Constructor should only be called/instantiated by a Deferred constructor
         */
        public function Promise( deferred:Deferred )
        {
            super();

            this.deferred = deferred;
        }

        // ========================================
        // Public static methods
        // ========================================

        /**
         * Utility method to create a new Promise based on one or more Promises (i.e. parallel chaining).
         *
         * NOTE: Result and progress handlers added to this new Promise will be passed an Array of aggregated result or progress values.
         */
        public static function when( ...promises ):Promise
        {
            // Insure we have an array of promises
            promises = sanitize(promises);

            var size        :int      = promises.length,

                results     :Array    = fill( new Array( size ) ),
                errors      :Array    = fill( new Array( size ) ),
                statuses    :Array    = fill( new Array( size ) ),

                deferred    :Deferred = new Deferred( function(dfd:Deferred):* {
                        // If no promise, immediately resolve
                        return !promises.length && dfd.resolve();
                    });

            for each ( var promise:Promise in promises )
                         {
                             /**
                              * Use IIFE closure to manage promise reference in the then() handlers
                              */
                             (function (promise:Promise) : void {
                                 promise.then(
                                              // All promises must resolve() before the when() resolves

                                              function ( result:* ):void {
                                                  results[ promises.indexOf( promise ) ] = result;

                                                  if ( --size == 0 )
                                                      deferred.resolve.apply(deferred, results );
                                              },

                                              // Any promise reject(), rejects the when()

                                              function ( error:* ):void {
                                                  errors[ promises.indexOf( promise ) ] = error;

                                                  deferred.reject.apply(deferred, errors);
                                              },

                                              // Only most recent notify value forwarded

                                              function ( status:* ):void {
                                                  statuses[ promises.indexOf( promise ) ] = status;

                                                  deferred.notify.apply(deferred, statuses );
                                              }
                                              );
                             }(promise));
                         }

            return deferred.promise;
        }


        // ========================================
        // Public methods
        // ========================================

        /**
         * Register callbacks to be called when this Promise is resolved or rejected.
         */
        public function then( resultCallback:Function, errorCallback:Function = null, progressCallback:Function = null ):Promise
        {
            return deferred.then( resultCallback, errorCallback, progressCallback ).promise;
        }

        /**
         * Registers a callback to be called when this Promise is either resolved or rejected.
         */
        public function always( alwaysCallback:Function ):Promise
        {
            return deferred.always( alwaysCallback ).promise;
        }

        /**
         * Alias to Deferred.then().
         * More intuitive with syntax:  $.when( ... ).done( ... )
         *
         * @param resultCallback Function to be called when the Promise resolves.
         */
        public function done ( resultCallback : Function ):Promise
        {
            return deferred.then( resultCallback ).promise;
        }

        /**
         * Alias to Deferred.fail(); match jQuery API
         *
         * @param resultCallback Function to be called when the Promise resolves.
         */
        public function fail ( resultCallback : Function ):Promise
        {
            return deferred.fail( resultCallback ).promise;
        }

        /**
         * Registers a callback to be called when this Promise is updated.
         */
        public function progress( progressCallback:Function ):Promise
        {
            return deferred.progress( progressCallback ).promise;
        }


        /**
         * Utility method to filter and/or chain Deferreds.
         */
        public function pipe( resultCallback:Function, errorCallback:Function = null, progressCallback:Function=null ):Promise
        {
            return deferred.pipe( resultCallback, errorCallback, progressCallback );
        }

        // ========================================
        // Protected methods
        // ========================================

        /**
         * Convert all elements of `list` to promises.
         * Scalar values are converted to `resolved` promises
         */
        protected static function sanitize( list:Array ) : Array
        {
            // Special handling for when an Array of Promises is specified instead of variable numbe of Promise arguments.
            if ( ( list.length == 1 ) && ( list[ 0 ] is Array ) )
                {
                    list = list[ 0 ];
                }

            // Ensure the promises Array is populated with Promises.
            var count:int = list ? list.length : 0;

            for ( var j:int = 0; j <  count; j++ )
                {
                    var parameter:* = list[ j ];

                    if (parameter == null)
                        {
                            list[ j ] = new Deferred().resolve(null).promise;

                        } else {

                        switch ( parameter.constructor )
                            {
                            case Promise:
                                break;

                            case Deferred:
                                // Replace the promises Array element with the associated Promise for the specified Deferred value.
                                list[ j ] = parameter.promise;
                                break;

                            default:
                                // Create a new Deferred resolved with the specified parameter value,
                                // and replace the list Array element with the associated Promise.

                                var func : Function = parameter as Function;

                                // NOTE: check if this works when the func() returns a Promise instance?

                                list[ j ] = new Deferred( func ).resolve( (func != null) ? null : parameter).promise;
                                break;
                            }
                    }
                }

            return list;
        }

        /**
         * Initialize all elements of an array with specified value.
         */
        protected static function fill( list:Array, val:*= undefined ):Array
        {
            for ( var j:uint=0; j<list.length; j++ )
                {
                    list[j] = val;
                }

            return list;
        }
    }
}
